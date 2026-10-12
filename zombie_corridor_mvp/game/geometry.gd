class_name CorridorGeometry
extends RefCounted

static var wall_queries = 0
static var capsule_queries = 0

const GEOMETRY_SCENE_PATH := "res://scenes/corridor_geometry.tscn"
const GEOMETRY_VERSION := "corridor-geometry-v1"
const REQUIRED_ROLES := [&"floor", &"boundary_left", &"boundary_right", &"boundary_front", &"boundary_back", &"baffle"]

static var _active_records: Array[Dictionary] = []
static var _active_errors: Array[String] = []
static var _active_hash := ""
static var _active_floor := AABB()
static var _active_play_bounds := {}
static var _active_baffle := AABB()
static var WALLS: Array[AABB] = _initialize_default_walls()

static func finite_vector(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

static func _initialize_default_walls() -> Array[AABB]:
	if _active_records.is_empty() and _active_errors.is_empty():
		_load_default_scene()
	var walls: Array[AABB] = []
	for record in _active_records:
		if record.role != &"floor":
			walls.append(record.aabb)
	return walls

static func ensure_loaded() -> bool:
	if _active_records.is_empty() and _active_errors.is_empty():
		_load_default_scene()
	return _active_errors.is_empty()

static func _load_default_scene() -> void:
	if _active_records.is_empty() and _active_errors.is_empty():
		var packed := load(GEOMETRY_SCENE_PATH) as PackedScene
		if packed == null:
			_active_errors = ["corridor geometry scene is missing: %s" % GEOMETRY_SCENE_PATH]
			return
		var instance := packed.instantiate() as Node3D
		if instance == null:
			_active_errors = ["corridor geometry scene root must be Node3D"]
			return
		var result := extract_records(instance)
		instance.free()
		_apply_result(result)

static func activate_authored_instance(instance: Node3D) -> bool:
	var result := extract_records(instance)
	_apply_result(result)
	return _active_errors.is_empty()

static func validation_errors_for_instance(instance: Node3D) -> Array[String]:
	return extract_records(instance).errors.duplicate()

static func records() -> Array[Dictionary]:
	ensure_loaded()
	return _active_records.duplicate(true)

static func map_hash() -> String:
	ensure_loaded()
	return _active_hash

static func validation_errors() -> Array[String]:
	ensure_loaded()
	return _active_errors.duplicate()

static func play_bounds() -> Dictionary:
	ensure_loaded()
	return _active_play_bounds.duplicate()

static func baffle_route() -> Dictionary:
	if not ensure_loaded():
		push_error("Invalid corridor geometry: %s" % ", ".join(_active_errors))
		return {}
	return {"min_z": _active_baffle.position.z - 0.5, "max_z": _active_baffle.end.z + 0.5, "block_x": _active_baffle.end.x + 0.5, "detour_x": _active_play_bounds.max_x - 0.5}

static func _apply_result(result: Dictionary) -> void:
	_active_errors = result.errors.duplicate()
	if not _active_errors.is_empty():
		_active_records.clear()
		WALLS.clear()
		_active_hash = ""
		_active_floor = AABB()
		_active_baffle = AABB()
		_active_play_bounds = {}
		return
	_active_records = result.records.duplicate(true)
	_active_hash = _hash_records(_active_records)
	WALLS = []
	for record in _active_records:
		if record.role != &"floor":
			WALLS.append(record.aabb)
		else:
			_active_floor = record.aabb
	_active_baffle = _record_for_role(&"baffle").aabb
	var left: AABB = _record_for_role(&"boundary_left").aabb
	var right: AABB = _record_for_role(&"boundary_right").aabb
	var front: AABB = _record_for_role(&"boundary_front").aabb
	var back: AABB = _record_for_role(&"boundary_back").aabb
	_active_play_bounds = {
		"min_x": left.end.x + 0.5,
		"max_x": right.position.x - 0.5,
		"min_z": back.end.z + 0.5,
		"max_z": front.position.z - 0.5,
	}

static func _record_for_role(role: StringName) -> Dictionary:
	for record in _active_records:
		if record.role == role:
			return record
	return {}

static func extract_records(root: Node3D) -> Dictionary:
	var errors: Array[String] = []
	var records: Array[Dictionary] = []
	if root == null:
		return {"records": records, "errors": ["geometry root is null"]}
	var initial := _ancestor_transform_for(root, errors)
	_collect_records(root, initial, records, errors)
	_validate_records(records, errors)
	if not errors.is_empty():
		records.clear()
	else:
		records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var left := "%s/%s" % [a.role, a.name]
			var right := "%s/%s" % [b.role, b.name]
			return left < right
		)
	return {"records": records, "errors": errors}

static func _ancestor_transform_for(root: Node3D, errors: Array[String]) -> Transform3D:
	var origins: Array[Vector3] = []
	var current := root.get_parent()
	while current != null:
		if current is Node3D:
			var node3d := current as Node3D
			if node3d.top_level:
				errors.append("%s uses unsupported top_level ancestor placement" % _node_label(node3d))
			if not _basis_is_identity(node3d.transform.basis):
				errors.append("%s ancestor uses unsupported rotation/shear/non-unit scale" % _node_label(node3d))
			if not finite_vector(node3d.position):
				errors.append("%s ancestor placement must be finite" % _node_label(node3d))
			origins.append(node3d.position)
		current = current.get_parent()
	var transform := Transform3D.IDENTITY
	for index in range(origins.size() - 1, -1, -1):
		transform.origin += origins[index]
	return transform

static func _node_label(node: Node) -> String:
	return String(node.get_path()) if node.is_inside_tree() else String(node.name)

static func _collect_records(node: Node, parent_transform: Transform3D, records: Array[Dictionary], errors: Array[String]) -> void:
	if not node is Node3D:
		return
	var node3d := node as Node3D
	if node3d.top_level:
		errors.append("%s uses unsupported top_level placement" % _node_label(node3d))
	var local := node3d.transform
	if not _basis_is_identity(local.basis):
		errors.append("%s uses unsupported rotation/shear/non-unit scale" % _node_label(node3d))
	if not finite_vector(local.origin):
		errors.append("%s placement must be finite" % _node_label(node3d))
	var accumulated := parent_transform * Transform3D(Basis.IDENTITY, local.origin)
	if node3d is CollisionShape3D:
		if node3d.get_parent() == null or not node3d.get_parent() is StaticBody3D:
			errors.append("%s is an unattached CollisionShape3D; put shapes under a role-tagged StaticBody3D" % _node_label(node3d))
	if node3d is CollisionPolygon3D:
		errors.append("%s uses unsupported CollisionPolygon3D; authored corridor geometry requires BoxShape3D" % _node_label(node3d))
	if node3d is CollisionObject3D and not node3d is StaticBody3D:
		errors.append("%s is an unsupported collision object; authored corridor geometry accepts only StaticBody3D boxes" % _node_label(node3d))
	if node3d is StaticBody3D:
		var body := node3d as StaticBody3D
		var role := StringName(body.get("role")) if body.get("role") != null else &""
		if role == &"":
			errors.append("%s is an untagged StaticBody3D; set a recognized geometry role" % _node_label(body))
		else:
			var collider := _single_collision_shape(body, errors)
			if collider != null:
				if collider.disabled:
					errors.append("%s collider must be enabled" % _node_label(collider))
				if not _basis_is_identity(collider.transform.basis):
					errors.append("%s collider uses unsupported rotation/shear/non-unit scale" % _node_label(collider))
				if not collider.shape is BoxShape3D:
					errors.append("%s must use BoxShape3D" % _node_label(collider))
				else:
					var size := (collider.shape as BoxShape3D).size
					if not finite_vector(size) or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
						errors.append("%s BoxShape3D size must be finite and positive" % _node_label(collider))
					else:
						var center := accumulated.origin + collider.position
						if not finite_vector(center):
							errors.append("%s center must be finite" % _node_label(collider))
						else:
							records.append({"name": String(body.name), "role": role, "aabb": AABB(center - size * 0.5, size), "layer": body.collision_layer, "mask": body.collision_mask})
			_validate_preview_mesh(collider, errors)
	for child in node.get_children():
		_collect_records(child, accumulated, records, errors)

static func _single_collision_shape(node: Node3D, errors: Array[String]) -> CollisionShape3D:
	var found: CollisionShape3D = null
	for child in node.get_children():
		if child is CollisionShape3D:
			var shape := child as CollisionShape3D
			if found != null:
				errors.append("%s has duplicate CollisionShape3D children" % _node_label(node))
			found = shape
	if found == null:
		errors.append("%s is missing a CollisionShape3D child" % _node_label(node))
	return found

static func _validate_preview_mesh(collider: CollisionShape3D, errors: Array[String]) -> void:
	if collider == null:
		return
	var meshes: Array[MeshInstance3D] = []
	for child in collider.get_children():
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
	if meshes.size() != 1:
		errors.append("%s must have exactly one MeshInstance3D preview child" % _node_label(collider))
		return
	var mesh := meshes[0]
	if mesh.transform != Transform3D.IDENTITY:
		errors.append("%s preview mesh local transform must be identity" % _node_label(mesh))
	if not mesh.mesh is BoxMesh:
		errors.append("%s preview mesh must use BoxMesh" % _node_label(mesh))

static func _validate_records(records: Array[Dictionary], errors: Array[String]) -> void:
	var by_role := {}
	for record in records:
		if not REQUIRED_ROLES.has(record.role):
			errors.append("%s has unsupported role %s" % [record.name, record.role])
		if by_role.has(record.role):
			errors.append("duplicate geometry role %s" % record.role)
		by_role[record.role] = record
		if record.layer != 1 or record.mask != 0:
			errors.append("%s must use collision layer 1 and mask 0" % record.name)
	for role in REQUIRED_ROLES:
		if not by_role.has(role):
			errors.append("missing required geometry role %s" % role)
	if errors.is_empty():
		var floor_box: AABB = by_role[&"floor"].aabb
		if not is_equal_approx(floor_box.end.y, 0.0):
			errors.append("floor top must remain at y=0 for spawn/player convention")
		var left: AABB = by_role[&"boundary_left"].aabb
		var right: AABB = by_role[&"boundary_right"].aabb
		var front: AABB = by_role[&"boundary_front"].aabb
		var back: AABB = by_role[&"boundary_back"].aabb
		var baffle: AABB = by_role[&"baffle"].aabb
		if not (left.end.x < right.position.x and back.end.z < front.position.z):
			errors.append("boundary roles must describe a rectangular corridor with left/right/front/back ordering")
		var usable_min_x := left.end.x + 0.5
		var usable_max_x := right.position.x - 0.5
		var usable_min_z := back.end.z + 0.5
		var usable_max_z := front.position.z - 0.5
		if not (usable_min_x < usable_max_x and usable_min_z < usable_max_z):
			errors.append("0.5m gameplay margins must leave positive rectangular usable clearance")
		if not (floor_box.position.x <= usable_min_x and floor_box.end.x >= usable_max_x and floor_box.position.z <= usable_min_z and floor_box.end.z >= usable_max_z):
			errors.append("floor must cover the full usable play area after 0.5m margins")
		if baffle.end.x + 0.5 >= right.position.x - 0.5:
			errors.append("baffle must leave the existing right-side route clearance")

static func _basis_is_identity(basis: Basis) -> bool:
	return basis.x.is_equal_approx(Vector3.RIGHT) and basis.y.is_equal_approx(Vector3.UP) and basis.z.is_equal_approx(Vector3.BACK)

static func _hash_records(records: Array[Dictionary]) -> String:
	var lines := PackedStringArray([GEOMETRY_VERSION])
	for record in records:
		var box: AABB = record.aabb
		lines.append("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [record.role, record.name, _canonical_float(box.position.x), _canonical_float(box.position.y), _canonical_float(box.position.z), _canonical_float(box.size.x), _canonical_float(box.size.y), _canonical_float(box.size.z), record.layer, record.mask, GEOMETRY_VERSION])
	return "\n".join(lines).sha256_text()

static func _canonical_float(value: float) -> String:
	var canonical := 0.0 if value == 0.0 else value
	return PackedFloat64Array([canonical]).to_byte_array().hex_encode()

static func ray_box(o: Vector3, d: Vector3, box: AABB, limit: float) -> float:
	var near = 0.0
	var far = limit
	for axis in range(3):
		if abs(d[axis]) < 0.000001:
			if o[axis] < box.position[axis] or o[axis] > box.end[axis]: return INF
		else:
			var a = (box.position[axis] - o[axis]) / d[axis]
			var b = (box.end[axis] - o[axis]) / d[axis]
			near = max(near,min(a,b))
			far = min(far,max(a,b))
			if near > far: return INF
	return near if far >= 0.0 else INF

static func wall_distance(o: Vector3, d: Vector3, limit: float) -> float:
	wall_queries += 1
	if not ensure_loaded():
		push_error("Invalid corridor geometry: %s" % ", ".join(_active_errors))
		return INF
	var result = limit
	for box in WALLS: result = min(result,ray_box(o,d,box,limit))
	return result

static func ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var oc = o-c
	var b = oc.dot(d)
	var q = oc.length_squared()-r*r
	if q <= 0.0: return 0.0
	var disc = b*b-q
	if disc < -0.00001: return INF
	var t = -b-sqrt(maxf(0,disc))
	return t if t >= 0.0 else INF

# Vertical capsule: radius .4; bottom/top sphere centers .4/1.4 above floor.
static func ray_capsule(o: Vector3, d: Vector3, foot: Vector3, limit: float) -> float:
	capsule_queries += 1
	var r = 0.4
	var p = o-foot
	if p.y >= .4 and p.y <= 1.4 and p.x*p.x+p.z*p.z <= r*r: return 0.0
	var result = min(ray_sphere(o,d,foot+Vector3(0,.4,0),r),ray_sphere(o,d,foot+Vector3(0,1.4,0),r))
	var a = d.x*d.x+d.z*d.z
	if a > 0.000001:
		var b = p.x*d.x+p.z*d.z
		var c = p.x*p.x+p.z*p.z-r*r
		var disc = b*b-a*c
		if disc >= -0.00001:
			for t in [(-b-sqrt(maxf(0,disc)))/a,(-b+sqrt(maxf(0,disc)))/a]:
				var y = p.y+t*d.y
				if t >= 0.0 and y >= .4 and y <= 1.4: result = min(result,t)
	return result if result <= limit else INF

static func constrain(foot: Vector3) -> Vector3:
	if not ensure_loaded():
		push_error("Invalid corridor geometry: %s" % ", ".join(_active_errors))
		return foot
	foot.x = clampf(foot.x,_active_play_bounds.min_x,_active_play_bounds.max_x)
	foot.z = clampf(foot.z,_active_play_bounds.min_z,_active_play_bounds.max_z)
	foot.y = 0.0
	return foot
