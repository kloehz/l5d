extends SceneTree

const WORLD_SCENE := "res://scenes/world.tscn"
const WORLD_VISUALS_SCENE := "res://scenes/world_visuals.tscn"
const CORRIDOR_GEOMETRY_SCENE := "res://scenes/corridor_geometry.tscn"
const BOOTSTRAP_SCENE := "res://scenes/bootstrap.tscn"
const UI_SCENE := "res://scenes/ui.tscn"
const PLAYER_ACTOR_SCENE := "res://scenes/player_actor.tscn"
const PRESENTATION_SCENE := "res://scenes/presentation.tscn"
const MOB_VISUAL_SCENE := "res://scenes/mob_visual.tscn"
const SHOT_TRACER_SCENE := "res://scenes/shot_tracer.tscn"
const TRACER_MESH_RESOURCE := "res://scenes/resources/tracer_mesh.tres"
const TRACER_PREDICTED_RESOURCE := "res://scenes/resources/tracer_predicted.tres"
const TRACER_CONFIRMED_RESOURCE := "res://scenes/resources/tracer_confirmed.tres"
const LOOK_SCALE := 0.0025
const FLOOR_BOX := AABB(Vector3(-6, -1, -181), Vector3(12, 1, 182))
const STRIP_SIZE := Vector3(9, 0.025, 0.07)
const GREEN_STRIP := Color(.13, .8, .65)
const ORANGE_STRIP := Color(.8, .48, .16)

var failures: Array[String] = []
var assertions := 0
var net_session: Node
var original_is_server := false
var original_is_bot := false
var original_world_root: Node3D
var original_players_root: Node3D
var original_status := ""
var original_args: Dictionary = {}
var original_control_look := Vector2.ZERO
var original_control_move := Vector2.ZERO
var original_control_fire := false
var original_own_life := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_capture_net_session_state()
	_check_authored_visual_scene()
	await _check_client_world_runtime_behavior()
	await _check_server_and_bot_runtime_behavior()
	await _check_authored_ui_scene_and_runtime_behavior()
	_check_authored_mob_and_tracer_templates()
	await _check_presentation_runtime_template_behavior()
	await _check_player_actor_scene_and_runtime_behavior()
	await _check_bootstrap_uses_authored_world_without_duplicate()
	_restore_net_session_state()
	print(JSON.stringify({
		"kind": "editable_scenes_harness",
		"assertions": assertions,
		"failures": failures,
		"world_scene": WORLD_SCENE,
		"world_visuals_scene": WORLD_VISUALS_SCENE,
		"corridor_geometry_scene": CORRIDOR_GEOMETRY_SCENE,
		"bootstrap_scene": BOOTSTRAP_SCENE,
		"ui_scene": UI_SCENE,
		"player_actor_scene": PLAYER_ACTOR_SCENE,
		"presentation_scene": PRESENTATION_SCENE,
		"mob_visual_scene": MOB_VISUAL_SCENE,
		"shot_tracer_scene": SHOT_TRACER_SCENE,
		"remaining_runtime_authority": "authored corridor_geometry.tscn boxes are the source for physics, preview meshes, analytic bounds and map hash"
	}))
	quit(0 if failures.is_empty() else 1)

func _capture_net_session_state() -> void:
	net_session = root.get_node("NetSession")
	original_is_server = net_session.is_server
	original_is_bot = net_session.is_bot
	original_world_root = net_session.world_root
	original_players_root = net_session.players_root
	original_status = net_session.status
	original_args = net_session.args.duplicate(true)
	original_control_look = net_session.control_look
	original_control_move = net_session.control_move
	original_control_fire = net_session.control_fire
	original_own_life = net_session.own_life

func _restore_net_session_state() -> void:
	net_session.is_server = original_is_server
	net_session.is_bot = original_is_bot
	net_session.world_root = original_world_root
	net_session.players_root = original_players_root
	net_session.status = original_status
	net_session.args = original_args
	net_session.control_look = original_control_look
	net_session.control_move = original_control_move
	net_session.control_fire = original_control_fire
	net_session.own_life = original_own_life
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _check_authored_visual_scene() -> void:
	var packed := load(WORLD_VISUALS_SCENE) as PackedScene
	check(packed != null, "world visuals scene loads as a PackedScene")
	if packed == null:
		return
	var visuals := packed.instantiate() as Node3D
	check(visuals != null, "world visuals instantiate as a Node3D")
	if visuals == null:
		return
	check(visuals.name == "WorldVisuals", "world visuals root keeps the client-only role guard name")
	_check_environment(visuals.get_node_or_null("WorldEnvironment"))
	_check_sun(visuals.get_node_or_null("Sun"))
	check(visuals.get_node_or_null("Floor") == null and visuals.get_node_or_null("Baffle") == null, "decorative world visuals no longer duplicate physical floor/wall boxes")
	_check_strips(visuals.get_node_or_null("FloorStrips"))
	visuals.free()
	_check_authored_physical_geometry_scene()

func _check_environment(node: Node) -> void:
	check(node is WorldEnvironment, "visual scene authors a WorldEnvironment node")
	if not node is WorldEnvironment:
		return
	var env := (node as WorldEnvironment).environment
	check(env != null, "WorldEnvironment owns an Environment resource")
	if env == null:
		return
	check(env.background_mode == Environment.BG_COLOR, "environment preserves background color mode")
	check(_color_eq(env.background_color, Color(.09, .13, .18)), "environment preserves background color")
	check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "environment preserves ambient source")
	check(_color_eq(env.ambient_light_color, Color(.62, .75, 1)), "environment preserves ambient color")
	check(is_equal_approx(env.ambient_light_energy, .7), "environment preserves ambient energy")
	check(env.fog_enabled, "environment preserves fog enabled")
	check(_color_eq(env.fog_light_color, Color(.12, .2, .27)), "environment preserves fog light color")
	check(is_equal_approx(env.fog_density, .013), "environment preserves fog density")

func _check_sun(node: Node) -> void:
	check(node is DirectionalLight3D, "visual scene authors a DirectionalLight3D")
	if not node is DirectionalLight3D:
		return
	var sun := node as DirectionalLight3D
	check(sun.rotation_degrees.is_equal_approx(Vector3(-65, -20, 0)), "sun preserves old rotation")
	check(is_equal_approx(sun.light_energy, 1.2), "sun preserves old light energy")

func _check_mesh(node: Node, expected_position: Vector3, expected_size: Vector3, expected_color: Color, message: String) -> void:
	check(node is MeshInstance3D, message + " node type")
	if not node is MeshInstance3D:
		return
	var mesh_instance := node as MeshInstance3D
	check(mesh_instance.position.is_equal_approx(expected_position), message + " placement")
	check(mesh_instance.mesh is BoxMesh, message + " mesh type")
	if mesh_instance.mesh is BoxMesh:
		check((mesh_instance.mesh as BoxMesh).size.is_equal_approx(expected_size), message + " dimensions")
	check(mesh_instance.material_override is StandardMaterial3D, message + " material type")
	if mesh_instance.material_override is StandardMaterial3D:
		check(_color_eq((mesh_instance.material_override as StandardMaterial3D).albedo_color, expected_color), message + " color")

func _check_strips(strips_root: Node) -> void:
	check(strips_root is Node3D, "floor strips are grouped under an editable Node3D")
	if not strips_root:
		return
	var strips := strips_root.get_children()
	check(strips.size() == 17, "visual scene authors exactly 17 old floor strips")
	var shared_mesh: Mesh = null
	var green_material: Material = null
	var orange_material: Material = null
	for index in range(strips.size()):
		var strip := strips[index] as MeshInstance3D
		check(strip != null, "floor strip %s is a MeshInstance3D" % index)
		if strip == null:
			continue
		var z := -10 * (index + 1)
		check(strip.position.is_equal_approx(Vector3(0, .01, z)), "floor strip %s preserves old placement" % z)
		check(strip.mesh is BoxMesh and (strip.mesh as BoxMesh).size.is_equal_approx(STRIP_SIZE), "floor strip %s preserves old dimensions" % z)
		if shared_mesh == null:
			shared_mesh = strip.mesh
		else:
			check(strip.mesh == shared_mesh, "floor strip %s shares the authored strip mesh resource" % z)
		var expected_color := GREEN_STRIP if z > -70 else ORANGE_STRIP
		check(strip.material_override is StandardMaterial3D, "floor strip %s has a StandardMaterial3D" % z)
		if strip.material_override is StandardMaterial3D:
			check(_color_eq((strip.material_override as StandardMaterial3D).albedo_color, expected_color), "floor strip %s preserves old material color" % z)
			if z > -70:
				if green_material == null:
					green_material = strip.material_override
				else:
					check(strip.material_override == green_material, "green strips share one material resource")
			else:
				if orange_material == null:
					orange_material = strip.material_override
				else:
					check(strip.material_override == orange_material, "orange strips share one material resource")

func _check_authored_physical_geometry_scene() -> void:
	var packed := load(CORRIDOR_GEOMETRY_SCENE) as PackedScene
	check(packed != null, "corridor geometry scene loads as a PackedScene")
	if packed == null:
		return
	var geometry := packed.instantiate() as Node3D
	check(geometry != null, "corridor geometry instantiates as a Node3D")
	if geometry == null:
		return
	var errors := CorridorGeometry.validation_errors_for_instance(geometry)
	check(errors.is_empty(), "authored corridor geometry validates without errors: %s" % [errors])
	var expected := {
		&"floor": FLOOR_BOX,
		&"boundary_left": AABB(Vector3(-6, -1, -180), Vector3(1, 6, 180)),
		&"boundary_right": AABB(Vector3(5, -1, -180), Vector3(1, 6, 180)),
		&"boundary_front": AABB(Vector3(-6, -1, 0), Vector3(12, 6, 1)),
		&"boundary_back": AABB(Vector3(-6, -1, -181), Vector3(12, 6, 1)),
		&"baffle": AABB(Vector3(-5, 0, -70), Vector3(6, 3, 1)),
	}
	for child in geometry.get_children():
		if child is StaticBody3D:
			var body := child as StaticBody3D
			var role := StringName(body.get("role"))
			check(expected.has(role), "%s has a required geometry role" % body.name)
			_check_authored_body(body, expected.get(role, AABB()), role)
	_check_mutated_geometry_coupling(packed)
	_check_child_reorder_hash_stability(packed)
	_check_invalid_geometry_validation(packed)
	geometry.free()

func _check_authored_body(body: StaticBody3D, expected_box: AABB, role: StringName) -> void:
	check(body.collision_layer == 1 and body.collision_mask == 0, "%s collision layer/mask remain layer 1 mask 0" % role)
	check(body.position.is_equal_approx(expected_box.get_center()), "%s position preserves old AABB center" % role)
	var collider := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	check(collider != null and collider.shape is BoxShape3D, "%s owns the BoxShape3D authority" % role)
	if collider and collider.shape is BoxShape3D:
		check((collider.shape as BoxShape3D).size.is_equal_approx(expected_box.size), "%s BoxShape3D size preserves old AABB size" % role)
	var mesh := collider.get_node_or_null("MeshInstance3D") as MeshInstance3D if collider else null
	check(mesh != null and mesh.mesh is BoxMesh, "%s previews with a BoxMesh child under the collider" % role)
	if mesh and mesh.mesh is BoxMesh and collider and collider.shape is BoxShape3D:
		check(mesh.transform == Transform3D.IDENTITY, "%s preview mesh local transform is identity, including translation" % role)
		check((mesh.mesh as BoxMesh).size.is_equal_approx((collider.shape as BoxShape3D).size), "%s preview mesh derives from shape.size" % role)
		check(mesh.mesh.resource_local_to_scene, "%s preview mesh is scene-local" % role)
		check((collider.shape as BoxShape3D).resource_local_to_scene, "%s collision shape is scene-local" % role)

func _check_mutated_geometry_coupling(packed: PackedScene) -> void:
	var first := packed.instantiate() as Node3D
	var second := packed.instantiate() as Node3D
	var original_hash := CorridorGeometry.map_hash()
	var left := first.get_node("BoundaryLeft") as StaticBody3D
	var collider := left.get_node("CollisionShape3D") as CollisionShape3D
	var shape := collider.shape as BoxShape3D
	shape.size.x = 2.0
	left.position.x = -6.0
	var records: Array = CorridorGeometry.extract_records(first).records
	var left_record: Dictionary = {}
	for record in records:
		if record.role == &"boundary_left":
			left_record = record
	check((left_record.aabb as AABB).size.x == 2.0 and (left_record.aabb as AABB).position.x == -7.0, "isolated authored wall edit changes extracted physical AABB")
	check(((collider.get_node("MeshInstance3D") as MeshInstance3D).mesh as BoxMesh).size.x == 2.0, "isolated authored wall shape.size edit updates derived visual BoxMesh")
	var typed_records: Array[Dictionary] = []
	for record in records:
		typed_records.append(record)
	var mutated_hash := CorridorGeometry._hash_records(typed_records)
	check(mutated_hash != original_hash, "isolated authored wall edit changes normalized map hash")
	shape.size.x = 1.00001
	var subtle_records: Array[Dictionary] = []
	for record in CorridorGeometry.extract_records(first).records:
		subtle_records.append(record)
	check(CorridorGeometry._hash_records(subtle_records) != original_hash, "sub-1e-4 authored size edits change the exact canonical map hash")
	left.position.x = -5.50001
	shape.size.x = 1.0
	var subtle_position_records: Array[Dictionary] = []
	for record in CorridorGeometry.extract_records(first).records:
		subtle_position_records.append(record)
	check(CorridorGeometry._hash_records(subtle_position_records) != original_hash, "sub-1e-4 authored position edits change the exact canonical map hash")
	left.position.x = -6.0
	shape.size.x = 2.0
	check(CorridorGeometry.ray_box(Vector3(-8, 1, -60), Vector3.RIGHT, left_record.aabb, 10.0) < 2.0, "mutated extracted wall changes actual analytic ray intersection")
	var second_shape := ((second.get_node("BoundaryLeft/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D)
	check(is_equal_approx(second_shape.size.x, 1.0), "scene-local shape resources prevent mutation leaking to another instance")
	first.free(); second.free()

func _check_child_reorder_hash_stability(packed: PackedScene) -> void:
	var reordered := packed.instantiate() as Node3D
	var original_hash := CorridorGeometry.map_hash()
	reordered.move_child(reordered.get_node("Baffle"), 0)
	var records: Array[Dictionary] = CorridorGeometry.extract_records(reordered).records
	check(CorridorGeometry._hash_records(records) == original_hash, "child reordering preserves normalized physical map hash")
	reordered.free()

func _check_authored_box_binding_behavior() -> void:
	var authored_box_script := load("res://game/authored_box.gd")
	var body: StaticBody3D = authored_box_script.new()
	body.set("role", &"floor")
	body.collision_layer = 8
	body.collision_mask = 16
	var collider := CollisionShape3D.new()
	var first_shape := BoxShape3D.new()
	first_shape.size = Vector3(1, 2, 3)
	collider.shape = first_shape
	var mesh := MeshInstance3D.new()
	collider.add_child(mesh)
	body.add_child(collider)
	body.call("_ready")
	check(body.collision_layer == 8 and body.collision_mask == 16, "AuthoredBox.ready preserves authored layer/mask for validation")
	check(not body.is_processing(), "AuthoredBox runtime processing stays disabled outside the editor")
	check(mesh.mesh is BoxMesh and (mesh.mesh as BoxMesh).size.is_equal_approx(first_shape.size), "AuthoredBox ready derives preview mesh from initial shape")
	first_shape.size = Vector3(2, 2, 3)
	check((mesh.mesh as BoxMesh).size.is_equal_approx(first_shape.size), "AuthoredBox original shape changed signal updates preview without manual mesh update")
	var old_mesh_size := (mesh.mesh as BoxMesh).size
	var second_shape := BoxShape3D.new()
	second_shape.size = Vector3(4, 5, 6)
	collider.shape = second_shape
	body.call("_bind_shape_signal")
	check((mesh.mesh as BoxMesh).size.is_equal_approx(second_shape.size), "AuthoredBox binding method rebinds after shape resource replacement")
	first_shape.size = Vector3(7, 7, 7)
	check((mesh.mesh as BoxMesh).size.is_equal_approx(second_shape.size) and not (mesh.mesh as BoxMesh).size.is_equal_approx(first_shape.size) and not old_mesh_size.is_equal_approx((mesh.mesh as BoxMesh).size), "AuthoredBox disconnects old shape and keeps replacement as preview authority")
	body.free()

func _check_invalid_geometry_validation(packed: PackedScene) -> void:
	_check_authored_box_binding_behavior()
	var invalid := packed.instantiate() as Node3D
	(invalid.get_node("BoundaryLeft") as Node3D).rotation_degrees.y = 5.0
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects unsupported rotation")
	(invalid.get_node("BoundaryLeft") as Node3D).rotation_degrees = Vector3.ZERO
	((invalid.get_node("Floor/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size.y = 0.5
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects floor top desync from y0")
	((invalid.get_node("Floor/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size.y = 1.0
	(invalid.get_node("BoundaryRight/CollisionShape3D") as CollisionShape3D).shape = SphereShape3D.new()
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects non-box collider shapes")
	(invalid.get_node("BoundaryRight/CollisionShape3D") as CollisionShape3D).shape = BoxShape3D.new()
	((invalid.get_node("BoundaryRight/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size = Vector3(1, 6, 180)
	(invalid.get_node("BoundaryRight") as Node).set("role", &"boundary_left")
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects duplicate required roles")
	(invalid.get_node("BoundaryRight") as Node).set("role", &"boundary_right")
	(invalid.get_node("BoundaryRight") as Node3D).scale.x = 1.25
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects non-unit scale")
	(invalid.get_node("BoundaryRight") as Node3D).scale = Vector3.ONE
	(invalid.get_node("BoundaryRight") as Node3D).position.x = NAN
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects nonfinite placement")
	(invalid.get_node("BoundaryRight") as Node3D).position.x = 5.5
	(invalid.get_node("BoundaryRight") as StaticBody3D).collision_layer = 2
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation preserves and rejects invalid collision layer settings")
	(invalid.get_node("BoundaryRight") as StaticBody3D).collision_layer = 1
	(invalid.get_node("BoundaryRight/CollisionShape3D") as CollisionShape3D).disabled = true
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects disabled collision shapes")
	(invalid.get_node("BoundaryRight/CollisionShape3D") as CollisionShape3D).disabled = false
	var untagged := StaticBody3D.new()
	untagged.name = "UntaggedExtraBody"
	invalid.add_child(untagged)
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects untagged extra StaticBody3D nodes")
	invalid.remove_child(untagged)
	untagged.free()
	var extra_area := Area3D.new()
	extra_area.name = "ExtraArea"
	invalid.add_child(extra_area)
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects extra collision objects")
	invalid.remove_child(extra_area)
	extra_area.free()
	var polygon := CollisionPolygon3D.new()
	polygon.name = "ExtraPolygon"
	invalid.add_child(polygon)
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects collision polygons")
	invalid.remove_child(polygon)
	polygon.free()
	var loose_shape := CollisionShape3D.new()
	loose_shape.name = "LooseShape"
	loose_shape.shape = BoxShape3D.new()
	invalid.add_child(loose_shape)
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects unattached collision shapes")
	invalid.remove_child(loose_shape)
	loose_shape.free()
	var duplicate_shape := CollisionShape3D.new()
	duplicate_shape.name = "DuplicateShape"
	duplicate_shape.shape = BoxShape3D.new()
	invalid.get_node("BoundaryLeft").add_child(duplicate_shape)
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects duplicate attached collision shapes")
	invalid.get_node("BoundaryLeft").remove_child(duplicate_shape)
	duplicate_shape.free()
	var preview := invalid.get_node("BoundaryLeft/CollisionShape3D/MeshInstance3D") as MeshInstance3D
	preview.position.x = 0.01
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects preview mesh local translation desync")
	preview.position = Vector3.ZERO
	invalid.top_level = true
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects unsupported top_level root placement")
	invalid.top_level = false
	var translated_parent := Node3D.new()
	translated_parent.name = "TranslatedGeometryAnchor"
	translated_parent.position.x = 1.25
	translated_parent.add_child(invalid)
	var translated_records: Array = CorridorGeometry.extract_records(invalid).records
	var translated_left: Dictionary = {}
	for record in translated_records:
		if record.role == &"boundary_left":
			translated_left = record
	check((translated_left.aabb as AABB).position.x > -5.0, "analytic extraction accounts for translated ancestor placement")
	translated_parent.rotation_degrees.y = 1.0
	check(not CorridorGeometry.validation_errors_for_instance(invalid).is_empty(), "pure geometry validation rejects rotated ancestor placement")
	translated_parent.remove_child(invalid)
	translated_parent.free()
	invalid.free()

func _check_client_world_runtime_behavior() -> void:
	net_session.is_server = false
	net_session.is_bot = false
	var world := _instantiate_world_in_tree("ClientWorldUnderTest")
	await process_frame
	check(world.get_node_or_null("WorldVisuals") != null, "client world keeps editor-authored visuals active")
	_check_collision_runtime(world, "client")
	_check_collision_bodies_have_expected_meshes(world, "client")
	world.queue_free()
	await process_frame

func _check_server_and_bot_runtime_behavior() -> void:
	for role in [[true, false, "server"], [false, true, "bot"]]:
		net_session.is_server = role[0]
		net_session.is_bot = role[1]
		var world := _instantiate_world_in_tree("%sWorldUnderTest" % role[2])
		await process_frame
		check(world.get_node_or_null("WorldVisuals") == null, "%s world removes client-only authored visuals before role activation" % role[2])
		_check_collision_runtime(world, role[2])
		_check_collision_bodies_have_expected_meshes(world, role[2])
		world.queue_free()
		await process_frame

func _instantiate_world_in_tree(node_name: String) -> Node3D:
	var packed := load(WORLD_SCENE) as PackedScene
	check(packed != null, "%s world scene loads" % node_name)
	var world := packed.instantiate() as Node3D
	check(world != null and world is CorridorWorld, "%s instantiates CorridorWorld" % node_name)
	if world:
		world.name = node_name
		root.add_child(world)
	return world

func _check_collision_runtime(world: Node3D, role: String) -> void:
	if world == null:
		return
	var bodies := _collision_bodies(world)
	check(bodies.size() == CorridorGeometry.WALLS.size() + 1, "%s world builds floor plus authoritative wall collision bodies" % role)
	var expected := [FLOOR_BOX]
	expected.append_array(CorridorGeometry.WALLS)
	for box in expected:
		var found := false
		for body in bodies:
			if body.position.is_equal_approx(box.get_center()) and body.collision_layer == 1 and body.collision_mask == 0:
				var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if shape_node and shape_node.shape is BoxShape3D and (shape_node.shape as BoxShape3D).size.is_equal_approx(box.size):
					found = true
		check(found, "%s world preserves collision body at %s size %s layer 1 mask 0" % [role, box.get_center(), box.size])

func _check_collision_bodies_have_expected_meshes(world: Node3D, role: String) -> void:
	for body in _collision_bodies(world):
		var meshes := _mesh_count(body)
		if role == "client":
			check(meshes == 1, "%s physical body keeps one authored derived preview mesh for clients" % role)
		else:
			check(meshes == 0, "%s physical body removes authored preview meshes for nonvisual roles" % role)

func _mesh_count(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			total += 1
		total += _mesh_count(child)
	return total

func _collision_bodies(world: Node3D) -> Array[StaticBody3D]:
	var bodies: Array[StaticBody3D] = []
	_collect_collision_bodies(world, bodies)
	return bodies

func _collect_collision_bodies(node: Node, bodies: Array[StaticBody3D]) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			bodies.append(child)
		_collect_collision_bodies(child, bodies)

func _check_authored_ui_scene_and_runtime_behavior() -> void:
	var packed := load(UI_SCENE) as PackedScene
	check(packed != null, "UI scene loads as a PackedScene")
	if packed == null:
		return
	var ui := packed.instantiate() as CorridorUI
	check(ui != null, "UI scene instantiates as CorridorUI")
	if ui == null:
		return
	_check_authored_ui_tree(ui)
	root.add_child(ui)
	await process_frame
	_check_ui_ready_bindings(ui)
	await _check_ui_menu_hud_debug_feedback_states(ui)
	await _check_ui_input_routing(ui)
	ui.queue_free()
	await process_frame

func _check_authored_ui_tree(ui: CorridorUI) -> void:
	var root_control := ui.get_node_or_null("Root") as Control
	check(root_control != null, "UI authors a named fullscreen Root control")
	if root_control == null:
		return
	check(root_control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fullscreen UI root preserves mouse ignore routing")
	var background := root_control.get_node_or_null("Background") as ColorRect
	check(background != null, "UI authors a named background ColorRect")
	if background:
		check(_color_eq(background.color, Color(.045, .07, .095, .97)), "background preserves menu color")
		check(background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "background preserves mouse ignore routing")
	var panel := root_control.get_node_or_null("MenuPanel") as PanelContainer
	check(panel != null, "UI authors a named menu panel")
	if panel:
		check(panel.custom_minimum_size.is_equal_approx(Vector2(460, 430)), "menu panel preserves minimum size")
		check(is_equal_approx(panel.anchor_left, .5) and is_equal_approx(panel.anchor_top, .5) and is_equal_approx(panel.anchor_right, .5) and is_equal_approx(panel.anchor_bottom, .5), "menu panel remains centered by anchors")
		check(is_equal_approx(panel.offset_left, -230) and is_equal_approx(panel.offset_top, -215) and is_equal_approx(panel.offset_right, 230) and is_equal_approx(panel.offset_bottom, 215), "menu panel preserves centered offsets")
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		check(style != null, "menu panel owns editable panel style")
		if style:
			check(_color_eq(style.bg_color, Color(.08, .12, .17)), "menu panel style preserves background color")
			check(style.corner_radius_top_left == 12 and style.corner_radius_top_right == 12 and style.corner_radius_bottom_left == 12 and style.corner_radius_bottom_right == 12, "menu panel style preserves corner radii")
			check(is_equal_approx(style.content_margin_left, 28) and is_equal_approx(style.content_margin_top, 24) and is_equal_approx(style.content_margin_right, 28) and is_equal_approx(style.content_margin_bottom, 24), "menu panel style preserves content margins")
	var stack := root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack") as VBoxContainer
	check(stack != null, "UI authors a menu stack")
	if stack:
		check(stack.get_theme_constant("separation") == 12, "menu stack preserves separation")
	_check_label(root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/TitleLabel"), "CORRIDOR 99", 32, Color(.25, .94, .77), "title")
	_check_label(root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/SubtitleLabel"), "Cooperative capsule survival • 1–4 players", 15, Color(.85, .9, .94), "subtitle")
	_check_label(root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/StatusLabel"), "Main menu", 16, Color(.85, .9, .94), "status")
	_check_label(root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/ControlsLabel"), "WASD • Mouse • Hold left click • Esc • F3", 14, Color(.85, .9, .94), "controls")
	_check_button(root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/LocalButton"), "Probar local")
	_check_button(root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/ConnectButton"), "Conectar")
	_check_button(root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/ResumeButton"), "Resume / capture mouse")
	_check_button(root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/DisconnectButton"), "Disconnect")
	_check_button(root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/QuitButton"), "Quit")
	var ip := root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/EndpointRow/IP") as LineEdit
	check(ip != null, "UI authors the IP LineEdit")
	if ip:
		check(ip.text == "127.0.0.1", "IP field preserves default endpoint")
		check(ip.placeholder_text == "Server IP or DNS", "IP field preserves placeholder text")
		check(ip.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "IP field preserves horizontal expansion")
	var port := root_control.get_node_or_null("MenuPanel/MenuMargin/MenuStack/EndpointRow/Port") as SpinBox
	check(port != null, "UI authors the port SpinBox")
	if port:
		check(is_equal_approx(port.min_value, 1024) and is_equal_approx(port.max_value, 65535), "port field preserves allowed range")
		check(is_equal_approx(port.value, 27015), "port field preserves default value")
		check(is_equal_approx(port.custom_minimum_size.x, 110), "port field preserves minimum width")
	_check_label(root_control.get_node_or_null("HUD"), "", 22, Color(.85, .9, .94), "HUD")
	_check_label(root_control.get_node_or_null("Debug"), "", 15, Color(.85, .9, .94), "debug")
	_check_label(root_control.get_node_or_null("Feedback"), "", 24, Color(.5, 1, .7), "feedback")
	_check_label(root_control.get_node_or_null("Crosshair"), "+", 26, Color(.85, .96, 1), "crosshair")
	var feedback := root_control.get_node_or_null("Feedback") as Label
	if feedback:
		check(is_equal_approx(feedback.anchor_left, .5) and is_equal_approx(feedback.offset_left, -100) and is_equal_approx(feedback.offset_top, 36) and is_equal_approx(feedback.offset_right, 100) and is_equal_approx(feedback.offset_bottom, 70), "feedback preserves center anchors and offsets")
	var crosshair := root_control.get_node_or_null("Crosshair") as Label
	if crosshair:
		check(is_equal_approx(crosshair.anchor_left, .5) and is_equal_approx(crosshair.offset_left, -8) and is_equal_approx(crosshair.offset_top, -18) and is_equal_approx(crosshair.offset_right, 8) and is_equal_approx(crosshair.offset_bottom, 18), "crosshair preserves center anchors and offsets")

func _check_label(node: Node, expected_text: String, expected_size: int, expected_color: Color, label_name: String) -> void:
	check(node is Label, "%s label is authored as a Label" % label_name)
	if not node is Label:
		return
	var label := node as Label
	check(label.text == expected_text, "%s label preserves text" % label_name)
	check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s label preserves mouse ignore routing" % label_name)
	check(label.get_theme_font_size("font_size") == expected_size, "%s label preserves font size" % label_name)
	check(_color_eq(label.get_theme_color("font_color"), expected_color), "%s label preserves font color" % label_name)

func _check_button(node: Node, expected_text: String) -> void:
	check(node is Button, "%s button is authored as a Button" % expected_text)
	if not node is Button:
		return
	var button := node as Button
	check(button.text == expected_text, "%s button preserves mixed-language text" % expected_text)
	check(is_equal_approx(button.custom_minimum_size.y, 36), "%s button preserves minimum height" % expected_text)

func _check_ui_ready_bindings(ui: CorridorUI) -> void:
	check(ui.root_control != null, "UI binds Root with an explicit typed onready reference")
	check(ui.background != null and ui.background.name == "Background", "UI binds named background without metadata lookup")
	check(ui.panel != null and ui.status_label != null and ui.hud != null and ui.debug != null and ui.feedback != null and ui.crosshair != null, "UI binds menu, HUD, debug, feedback and crosshair labels")
	check(ui.ip != null and ui.ip.text == "127.0.0.1", "UI binds the authored IP field with its default")
	check(ui.port != null and is_equal_approx(ui.port.value, 27015), "UI binds the authored port field with its default")
	_check_button_connection(ui.local_button, ui, "_on_local_button_pressed", "local button")
	_check_button_connection(ui.connect_button, ui, "_on_connect_button_pressed", "connect button")
	_check_button_connection(ui.resume_button, ui, "_on_resume_button_pressed", "resume button")
	_check_button_connection(ui.disconnect_button, ui, "_on_disconnect_button_pressed", "disconnect button")
	_check_button_connection(ui.quit_button, ui, "_on_quit_button_pressed", "quit button")

func _check_button_connection(button: Button, target: Object, method: String, label: String) -> void:
	check(button != null, "%s exists for signal wiring" % label)
	if button == null:
		return
	var found := false
	for connection in button.pressed.get_connections():
		var callable := connection["callable"] as Callable
		if callable.get_object() == target and callable.get_method() == StringName(method):
			found = true
	check(found, "%s is wired to %s" % [label, method])

func _check_ui_menu_hud_debug_feedback_states(ui: CorridorUI) -> void:
	net_session.status = "Scene harness status"
	net_session.status_changed.emit()
	await process_frame
	check(ui.status_label.text == "Scene harness status", "status signal updates the authored status label")
	net_session.is_ready = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame
	check(ui.panel.visible, "menu panel is visible before gameplay readiness")
	check(ui.background.visible, "background is visible before gameplay readiness")
	check(not ui.hud.visible and not ui.crosshair.visible, "HUD and crosshair remain hidden before gameplay readiness")
	net_session.is_ready = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	var capture_supported := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if capture_supported:
		check(not ui.panel.visible, "menu panel hides during captured ready gameplay")
	else:
		check(DisplayServer.get_name().to_lower().contains("headless"), "only headless UI scene runs may report unsupported captured mouse")
	check(not ui.background.visible, "background hides during ready gameplay")
	check(ui.hud.visible and ui.crosshair.visible, "HUD and crosshair show during ready gameplay")
	check(ui.hud.text.begins_with("HP ") and ui.hud.text.contains("Wave"), "HUD keeps HP/kills/wave status format")
	check(not ui.debug.visible, "debug label stays hidden until F3 toggles diagnostics")
	net_session.shot_confirmed.emit({"hit": true, "kill": false, "hp": 75})
	await process_frame
	check(ui.feedback.text == "HIT • 75 HP", "shot feedback preserves hit text")
	check(ui.feedback.visible, "shot feedback becomes visible after hit confirmation")
	net_session.shot_confirmed.emit({"hit": true, "kill": true, "hp": 0})
	await process_frame
	check(ui.feedback.text == "ELIMINATED", "shot feedback preserves kill text")
	ui.resume_button.pressed.emit()
	await process_frame
	if capture_supported:
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "resume button recaptures the mouse only through UI behavior")
	else:
		check(DisplayServer.get_name().to_lower().contains("headless"), "headless UI scene keeps resume recapture as an unsupported display operation")

func _check_ui_input_routing(ui: CorridorUI) -> void:
	net_session.is_ready = true
	net_session.control_look = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	var capture_supported := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if capture_supported:
		var captured_baseline: Vector2 = net_session.control_look
		_push_mouse_motion_sync(Vector2(80, -20))
		var expected_captured: Vector2 = Vector2(
			wrapf(captured_baseline.x + 80.0 * LOOK_SCALE, -PI, PI),
			clampf(captured_baseline.y + 20.0 * LOOK_SCALE, -1.4, 1.4)
		)
		check(
			is_equal_approx(net_session.control_look.x, expected_captured.x),
			"authored UI scene routes captured viewport mouse yaw to gameplay (actual=%s expected=%s baseline=%s ready=%s mouse_mode=%s)" % [net_session.control_look.x, expected_captured.x, captured_baseline.x, net_session.is_ready, Input.mouse_mode]
		)
		check(
			is_equal_approx(net_session.control_look.y, expected_captured.y),
			"authored UI scene routes captured viewport mouse pitch to gameplay (actual=%s expected=%s baseline=%s ready=%s mouse_mode=%s)" % [net_session.control_look.y, expected_captured.y, captured_baseline.y, net_session.is_ready, Input.mouse_mode]
		)
		await process_frame
	else:
		check(DisplayServer.get_name().to_lower().contains("headless"), "headless UI scene run may skip captured mouse routing proof")
	await _push_key(KEY_F3)
	check(ui.show_debug, "F3 toggles diagnostics on the authored UI scene")
	await process_frame
	check(ui.debug.visible, "debug label is visible after F3 while ready")
	if capture_supported:
		await _push_key(KEY_ESCAPE)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases captured mouse through the authored UI scene")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var previous_look: Vector2 = net_session.control_look
	_push_mouse_motion_sync(Vector2(60, -10))
	check(net_session.control_look == previous_look, "released mouse no longer changes gameplay look through authored UI (actual=%s previous=%s ready=%s mouse_mode=%s)" % [net_session.control_look, previous_look, net_session.is_ready, Input.mouse_mode])
	await process_frame
	net_session.control_move = Vector2(1, 1)
	net_session.control_fire = true
	net_session.is_ready = false
	await process_frame
	check(net_session.control_move == Vector2.ZERO and not net_session.control_fire, "menu state clears movement and fire polling")

func _push_mouse_motion(relative: Vector2) -> void:
	_push_mouse_motion_sync(relative)
	await process_frame

func _push_mouse_motion_sync(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(320, 240) + relative
	event.global_position = event.position
	event.relative = relative
	root.push_input(event, true)

func _push_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)
	await process_frame

func _check_authored_mob_and_tracer_templates() -> void:
	var mob_packed := load(MOB_VISUAL_SCENE) as PackedScene
	check(mob_packed != null, "mob visual scene loads as a PackedScene")
	if mob_packed:
		var first := mob_packed.instantiate() as MeshInstance3D
		var second := mob_packed.instantiate() as MeshInstance3D
		check(first != null and second != null, "mob visual scene root is a MeshInstance3D")
		if first and second:
			check(first.mesh is CapsuleMesh, "mob visual authors the capsule mesh primitive")
			if first.mesh is CapsuleMesh:
				check(is_equal_approx((first.mesh as CapsuleMesh).radius, .4), "mob capsule radius remains scene-authored at 0.4")
				check(is_equal_approx((first.mesh as CapsuleMesh).height, 1.8), "mob capsule height remains scene-authored at 1.8")
			check(first.material_override is StandardMaterial3D, "mob visual authors a baseline StandardMaterial3D")
			if first.material_override is StandardMaterial3D and second.material_override is StandardMaterial3D:
				var first_material := first.material_override as StandardMaterial3D
				var second_material := second.material_override as StandardMaterial3D
				check(first_material.resource_local_to_scene, "mob baseline material opts into per-instance local resources")
				check(first_material != second_material, "two mob scene instances do not share mutable material resources")
				first_material.albedo_color = Color(.1, .2, .3)
				check(not _color_eq(second_material.albedo_color, first_material.albedo_color), "mutating one mob material does not recolor another mob")
				check(_color_eq(second_material.albedo_color, Color(.85, .26, .2)), "mob baseline material preserves the old default color")
		if first:
			first.free()
		if second:
			second.free()
	_check_tracer_resources_and_template()
	_check_authored_presentation_scene()

func _check_tracer_resources_and_template() -> void:
	var mesh := load(TRACER_MESH_RESOURCE) as ArrayMesh
	var predicted := load(TRACER_PREDICTED_RESOURCE) as StandardMaterial3D
	var confirmed := load(TRACER_CONFIRMED_RESOURCE) as StandardMaterial3D
	check(mesh != null, "tracer mesh resource loads as an ArrayMesh")
	if mesh:
		check(mesh.get_surface_count() == 1, "tracer mesh resource has one surface")
		if mesh.get_surface_count() == 1:
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			check(vertices.size() == 2, "tracer mesh resource keeps exactly two vertices")
			if vertices.size() == 2:
				check(vertices[0].is_equal_approx(Vector3.ZERO) and vertices[1].is_equal_approx(Vector3(0, 0, 1)), "tracer mesh resource keeps the same unit line geometry")
	check(predicted != null and confirmed != null, "tracer predicted and confirmed materials load")
	if predicted:
		check(predicted.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "predicted tracer material remains unshaded")
		check(_color_eq(predicted.albedo_color, Color(.98, .8, .35)), "predicted tracer material preserves the original color")
	if confirmed:
		check(confirmed.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "confirmed tracer material remains unshaded")
		check(_color_eq(confirmed.albedo_color, Color(.4, 1, .7)), "confirmed tracer material preserves the original color")
	var tracer_packed := load(SHOT_TRACER_SCENE) as PackedScene
	check(tracer_packed != null, "shot tracer scene loads as a PackedScene")
	if tracer_packed:
		var tracer := tracer_packed.instantiate() as MeshInstance3D
		check(tracer != null, "shot tracer scene root is a MeshInstance3D")
		if tracer:
			check(not tracer.visible, "shot tracer template is hidden by default")
			check(tracer.mesh == mesh, "shot tracer template references the serialized shared mesh")
			check(tracer.material_override == predicted, "shot tracer template references the predicted material by default")
			tracer.free()

func _check_authored_presentation_scene() -> void:
	var packed := load(PRESENTATION_SCENE) as PackedScene
	check(packed != null, "presentation scene loads as a PackedScene")
	if packed == null:
		return
	var presentation := packed.instantiate() as CorridorPresentation
	check(presentation != null, "presentation scene root is CorridorPresentation")
	if presentation == null:
		return
	var direct_tracer_slots: Array[MeshInstance3D] = []
	for child in presentation.get_children():
		if child is MeshInstance3D and child.name.begins_with("ShotTracer"):
			direct_tracer_slots.append(child)
	check(direct_tracer_slots.size() == 8, "presentation scene authors exactly eight direct ShotTracer children")
	var shared_mesh: Mesh = null
	var shared_predicted: Material = null
	for index in range(direct_tracer_slots.size()):
		var tracer := presentation.get_node_or_null("ShotTracer%d" % index) as MeshInstance3D
		check(tracer != null, "presentation scene authors ShotTracer%d" % index)
		if tracer == null:
			continue
		check(tracer.get_parent() == presentation, "ShotTracer%d is a direct presentation child" % index)
		check(tracer.has_meta("shot_tracer") and tracer.get_meta("shot_tracer") == true, "ShotTracer%d authors static shot_tracer metadata" % index)
		check(not tracer.visible, "ShotTracer%d authors hidden default state" % index)
		check(not tracer.has_meta("shot_tracer_sequence"), "ShotTracer%d does not author runtime sequence metadata" % index)
		if shared_mesh == null:
			shared_mesh = tracer.mesh
		else:
			check(tracer.mesh == shared_mesh, "ShotTracer%d shares the presentation tracer mesh" % index)
		if shared_predicted == null:
			shared_predicted = tracer.material_override
		else:
			check(tracer.material_override == shared_predicted, "ShotTracer%d shares the presentation predicted material" % index)
	if presentation.get_node_or_null("ShotTracer0"):
		var invalid_slots: Array[MeshInstance3D] = direct_tracer_slots.duplicate()
		(invalid_slots[0] as MeshInstance3D).visible = true
		check(not presentation._tracer_pool_configuration_errors(invalid_slots).is_empty(), "presentation reports invalid authored pool configuration instead of building a fallback tree")
	presentation.free()

func _check_presentation_runtime_template_behavior() -> void:
	var packed := load(PRESENTATION_SCENE) as PackedScene
	check(packed != null, "production presentation scene loads for runtime checks")
	if packed == null:
		return
	var presentation := packed.instantiate() as CorridorPresentation
	check(presentation != null, "production presentation scene instantiates for runtime checks")
	if presentation == null:
		return
	presentation.name = "TemplatePresentationHarness"
	root.add_child(presentation)
	await process_frame
	check(presentation._tracer_pool.size() == 8, "presentation initializes exactly eight authored tracer slots once")
	var shared_mesh: Mesh = null
	var predicted: Material = null
	for tracer in presentation._tracer_pool:
		check(tracer is MeshInstance3D and tracer.has_meta("shot_tracer"), "each tracer pool slot is an authored MeshInstance3D slot")
		check(not tracer.visible, "tracer pool slots start hidden")
		if shared_mesh == null:
			shared_mesh = tracer.mesh
		else:
			check(tracer.mesh == shared_mesh, "runtime tracer pool shares one serialized mesh resource")
		if predicted == null:
			predicted = tracer.material_override
		else:
			check(tracer.material_override == predicted, "runtime tracer pool starts on one shared predicted material")
	check(presentation._predicted_tracer_material == predicted, "presentation reuses the authored predicted material instead of constructing it")
	check(presentation._confirmed_tracer_material == load(TRACER_CONFIRMED_RESOURCE), "presentation reuses the authored confirmed material instead of constructing it")
	var store = net_session.store
	var tick: float = root.get_node("NetworkTime").tick
	var previous_records: Dictionary = store.records.duplicate(true)
	store.records.clear()
	store.records["mob_a"] = {"position": Vector3.ZERO, "yaw": 0.0, "state": 1, "hp": 100.0, "history": [{"tick": tick - 4, "position": Vector3.ZERO}, {"tick": tick - 2, "position": Vector3.ZERO}]}
	store.records["mob_b"] = {"position": Vector3(1, 0, -2), "yaw": .5, "state": 1, "hp": 25.0, "history": [{"tick": tick - 4, "position": Vector3(1, 0, -2)}, {"tick": tick - 2, "position": Vector3(1, 0, -2)}]}
	presentation._process(0.016)
	check(presentation.visuals.size() == 2, "presentation still creates mob visuals dynamically from authored templates")
	var mob_a := presentation.visuals.get("mob_a") as MeshInstance3D
	var mob_b := presentation.visuals.get("mob_b") as MeshInstance3D
	if mob_a and mob_b:
		check(mob_a.mesh is CapsuleMesh and is_equal_approx((mob_a.mesh as CapsuleMesh).radius, .4) and is_equal_approx((mob_a.mesh as CapsuleMesh).height, 1.8), "runtime mob visual keeps authored capsule dimensions")
		check(mob_a.material_override is StandardMaterial3D and mob_b.material_override is StandardMaterial3D, "runtime mob visuals keep editable standard materials")
		check(mob_a.material_override != mob_b.material_override, "runtime mob visuals isolate mutable HP/state albedo per instance")
		check(not _color_eq((mob_a.material_override as StandardMaterial3D).albedo_color, (mob_b.material_override as StandardMaterial3D).albedo_color), "runtime HP albedo mutation does not leak across mobs")
	store.records = previous_records
	presentation.queue_free()
	await process_frame

func _check_player_actor_scene_and_runtime_behavior() -> void:
	var packed := load(PLAYER_ACTOR_SCENE) as PackedScene
	check(packed != null, "player actor scene loads as a PackedScene")
	if packed == null:
		return
	var authored := packed.instantiate() as CorridorPlayer
	check(authored != null, "player actor scene root is CorridorPlayer")
	if authored == null:
		return
	_check_authored_player_actor_tree(authored)
	_free_off_tree_sync_filter(authored)
	authored.free()
	var network_time := root.get_node("NetworkTime")
	var previous_initial_sync_done: bool = network_time.is_initial_sync_done()
	if not previous_initial_sync_done:
		network_time.set("_initial_sync_done", true)
	await _check_player_actor_client_roles(packed)
	await _check_player_actor_non_visual_roles(packed)
	await _check_net_session_real_actor_creation_path()
	network_time.set("_initial_sync_done", previous_initial_sync_done)

func _free_off_tree_sync_filter(actor: CorridorPlayer) -> void:
	var sync_node = actor.rb if actor and actor.rb else actor.get_node_or_null("MovementSync") if actor else null
	if sync_node and sync_node.visibility_filter and sync_node.visibility_filter.get_parent() == null:
		sync_node.visibility_filter.free()
		sync_node.visibility_filter = null

func _check_authored_player_actor_tree(actor: CorridorPlayer) -> void:
	check(actor.get_node_or_null("CollisionShape3D") is CollisionShape3D, "player actor authors a CollisionShape3D child")
	var shape_node := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node:
		check(shape_node.position.is_equal_approx(Vector3(0, 0.9, 0)), "player collision capsule preserves vertical offset in the authored scene")
		check(shape_node.shape is CapsuleShape3D, "player collision uses an authored capsule shape")
		if shape_node.shape is CapsuleShape3D:
			var capsule := shape_node.shape as CapsuleShape3D
			check(is_equal_approx(capsule.radius, .35), "player capsule preserves radius as scene data")
			check(is_equal_approx(capsule.height, 1.8), "player capsule preserves height as scene data")
	var input_node := actor.get_node_or_null("Input")
	check(input_node != null and input_node.get_script() == load("res://game/player_input.gd"), "player actor authors the CorridorInput child")
	var sync_node := actor.get_node_or_null("MovementSync")
	check(sync_node != null and sync_node.get_script() == load("res://game/movement_sync.gd"), "player actor authors the CorridorMovementSync child")
	var visual := actor.get_node_or_null("Visual") as Node3D
	check(visual != null, "player actor authors a Visual rig")
	if visual:
		check(visual.top_level, "player Visual rig is authored as top-level for world-space smoothing")
		var body := visual.get_node_or_null("Body") as MeshInstance3D
		check(body != null, "player actor visual rig authors the capsule body mesh")
		if body:
			check(body.mesh is CapsuleMesh, "player visual body uses an authored capsule mesh")
			check(body.position.is_equal_approx(Vector3(0, 0.9, 0)), "player body mesh preserves authored offset")
			check(body.material_override is StandardMaterial3D and _color_eq((body.material_override as StandardMaterial3D).albedo_color, Color(.2, .75, 1)), "player body material preserves old capsule color")
		var camera := visual.get_node_or_null("ShoulderCamera") as Camera3D
		check(camera != null, "player visual rig authors the shoulder camera")
		if camera:
			check(camera.position.is_equal_approx(Vector3(0.72, 1.82, 3.15)), "shoulder camera offset is scene data")
			check(is_equal_approx(camera.fov, 78.0), "shoulder camera FOV is scene data")
			check(is_equal_approx(camera.near, 0.05) and is_equal_approx(camera.far, 100.0), "shoulder camera clipping is scene data")

func _check_player_actor_client_roles(packed: PackedScene) -> void:
	var players := Node3D.new()
	players.name = "PlayerActorClientHarness"
	root.add_child(players)
	var previous_server: bool = net_session.is_server
	var previous_bot: bool = net_session.is_bot
	net_session.is_server = false
	net_session.is_bot = false
	var local_peer: int = net_session.local_peer()
	var local_actor := _instantiate_configured_actor(packed, local_peer, 1, Vector3(0, 0, -4), players, true, "local")
	var remote_actor := _instantiate_configured_actor(packed, local_peer + 10, 1, Vector3(2, 0, -4), players, false, "remote")
	await process_frame
	if local_actor:
		_check_client_actor_runtime(local_actor, true, "local")
	if remote_actor:
		_check_client_actor_runtime(remote_actor, false, "remote")
		_check_remote_actor_jump_smoothing(remote_actor)
		check(remote_actor.camera == null or not remote_actor.camera.current, "remote authored camera is never current after presentation processing")
	if local_actor:
		_check_local_actor_visual_follow(local_actor)
	players.queue_free()
	await process_frame
	net_session.is_server = previous_server
	net_session.is_bot = previous_bot

func _check_player_actor_non_visual_roles(packed: PackedScene) -> void:
	for role in [[true, false, "server"], [false, true, "bot"]]:
		var players := Node3D.new()
		players.name = "%sPlayerActorHarness" % role[2]
		root.add_child(players)
		net_session.is_server = role[0]
		net_session.is_bot = role[1]
		var actor := packed.instantiate() as CorridorPlayer
		check(actor != null, "%s actor scene instantiates" % role[2])
		if actor:
			actor.configure(42, 1, Vector3(0, 0, -6), 3)
			_check_configured_actor_before_ready(actor, 42, role[0], role[2])
			check(actor.get_node_or_null("Visual") == null and actor.visual == null and actor.camera == null, "%s actor removes client-only visual/camera subtree before ready" % role[2])
			players.add_child(actor)
			await process_frame
			check(actor.input != null and actor.rb != null, "%s actor retains collision/input/MovementSync runtime children" % role[2])
			check(actor.get_node_or_null("CollisionShape3D") is CollisionShape3D, "%s actor retains collision capsule" % role[2])
		players.queue_free()
		await process_frame
	net_session.is_server = original_is_server
	net_session.is_bot = original_is_bot

func _check_net_session_real_actor_creation_path() -> void:
	var previous_root: Node3D = net_session.players_root
	var previous_server: bool = net_session.is_server
	var previous_bot: bool = net_session.is_bot
	var players := Node3D.new()
	players.name = "NetSessionActorCreationHarness"
	root.add_child(players)
	net_session.players_root = players
	net_session.is_server = false
	net_session.is_bot = false
	var peer: int = net_session.local_peer()
	var key := "%s_%s" % [peer, 77]
	net_session.actors.erase(key)
	net_session._create_actor({"peer": peer, "life": 77, "pose": Vector3(1, 0, -9), "spawn_tick": 11})
	var actor := net_session.actors.get(key) as CorridorPlayer
	check(actor != null, "NetSession creates players from the authored actor PackedScene")
	if actor:
		check(actor.get_parent() == players, "NetSession adds the authored actor to players_root")
		check(actor.name == "p_%s_%s" % [peer, 77], "NetSession configures actor name before ready")
		check(actor.position.is_equal_approx(Vector3(1, 0, -9)) and actor.accepted_position.is_equal_approx(Vector3(1, 0, -9)), "NetSession configures peer life pose before ready")
		_check_configured_actor_before_ready(actor, peer, true, "NetSession")
	await process_frame
	if actor:
		_check_client_actor_runtime(actor, true, "NetSession")
		net_session.actors.erase(key)
	players.queue_free()
	await process_frame
	net_session.players_root = previous_root
	net_session.is_server = previous_server
	net_session.is_bot = previous_bot

func _instantiate_configured_actor(packed: PackedScene, peer: int, life: int, pose: Vector3, players: Node3D, prediction_expected: bool, label: String) -> CorridorPlayer:
	var actor := packed.instantiate() as CorridorPlayer
	check(actor != null, "configured actor scene instantiates for peer %s" % peer)
	if actor == null:
		return null
	actor.configure(peer, life, pose, 5)
	_check_configured_actor_before_ready(actor, peer, prediction_expected, label)
	players.add_child(actor)
	return actor

func _check_configured_actor_before_ready(actor: CorridorPlayer, peer: int, prediction_expected: bool, label: String) -> void:
	check(actor.get_multiplayer_authority() == 1, "%s actor root authority is server before ready" % label)
	check(actor.owner_peer_id == peer and actor.life_id > 0 and actor.name.begins_with("p_%s_" % peer), "%s actor peer/life/name are configured before ready" % label)
	check(actor.input != null and actor.input.get_multiplayer_authority() == peer, "%s actor Input authority is owner before ready" % label)
	check(actor.rb != null, "%s actor MovementSync is bound before ready" % label)
	if actor.rb:
		check(actor.rb.root == actor, "%s MovementSync root is actor before ready" % label)
		check(actor.rb.state_properties == [":position", ":velocity", ":facing"], "%s MovementSync state properties are configured before ready" % label)
		check(actor.rb.input_properties == ["Input:movement", "Input:look"], "%s MovementSync input properties are configured before ready" % label)
		check(not actor.rb.enable_input_broadcast, "%s MovementSync input broadcast stays disabled before ready" % label)
		check(actor.rb.enable_prediction == prediction_expected, "%s MovementSync prediction flag is configured before ready" % label)
		check(actor.rb.full_state_interval == 15, "%s MovementSync full state interval is configured before ready" % label)

func _check_client_actor_runtime(actor: CorridorPlayer, local: bool, label: String) -> void:
	check(actor.visual != null and actor.get_node_or_null("Visual") == actor.visual, "%s client actor keeps authored visual subtree" % label)
	check(_visible_meshes_3d(actor.visual) > 0, "%s client actor keeps the capsule body visible" % label)
	check(actor.camera != null, "%s client actor binds the authored shoulder camera" % label)
	if actor.camera:
		check(actor.camera.current == local, "%s client actor camera current matches local ownership" % label)
		check(actor.camera.position.is_equal_approx(Vector3(0.72, 1.82, 3.15)), "%s camera keeps authored offset until obstruction updates it" % label)
		check(is_equal_approx(actor.camera.fov, 78.0), "%s camera keeps authored FOV at runtime" % label)

func _check_remote_actor_jump_smoothing(actor: CorridorPlayer) -> void:
	var previous_visual := actor.visual.global_position
	var new_pose := previous_visual + Vector3(4.0, 0.0, -3.0)
	actor.position = new_pose
	check(actor.global_position.is_equal_approx(new_pose), "remote actor logical pose accepts the authoritative jump")
	check(actor.visual.global_position.is_equal_approx(previous_visual), "remote top-level visual stays at the prior world pose immediately after an actor jump")
	var delta := 0.05
	var alpha := 1.0 - exp(-delta * 12.0)
	var expected := previous_visual.lerp(new_pose, alpha)
	actor.facing = Vector2(.4, 0)
	actor._process(delta)
	check(actor.visual.global_position.is_equal_approx(expected), "remote visual applies exact exponential world-space smoothing after process")
	check(actor.global_position.is_equal_approx(new_pose), "remote smoothing does not mutate the logical actor pose")
	check(actor.camera == null or not actor.camera.current, "remote camera remains non-current after actor jump smoothing")

func _check_local_actor_visual_follow(actor: CorridorPlayer) -> void:
	var new_pose := actor.global_position + Vector3(-1.0, 0.0, -2.0)
	actor.position = new_pose
	net_session.control_look = Vector2(0.25, -0.1)
	actor._process(0.05)
	check(actor.visual.global_position.is_equal_approx(actor.global_position), "local top-level visual follows the actor world pose immediately")
	check(is_equal_approx(actor.visual.rotation.y, -net_session.control_look.x), "local top-level visual still follows control yaw")
	if actor.camera:
		check(actor.camera.position.is_equal_approx(Vector3(0.72, 1.82, 3.15)), "local camera keeps its authored rest offset before obstruction")
		check(is_equal_approx(actor.camera.rotation.x, net_session.control_look.y), "local camera pitch still follows control look")

func _visible_meshes_3d(node: Node) -> int:
	var total := 0
	if node == null:
		return 0
	for child in node.get_children():
		if child is MeshInstance3D and child.visible:
			total += 1
		total += _visible_meshes_3d(child)
	return total

func _check_bootstrap_uses_authored_world_without_duplicate() -> void:
	var bootstrap_source := FileAccess.get_file_as_string("res://game/bootstrap.gd")
	check(bootstrap_source.contains("const UI_SCENE := preload(\"res://scenes/ui.tscn\")"), "bootstrap preloads the authored UI PackedScene")
	check(bootstrap_source.contains("const PRESENTATION_SCENE := preload(\"res://scenes/presentation.tscn\")"), "bootstrap preloads the authored presentation PackedScene")
	check(bootstrap_source.contains("if not NetSession.is_server and not NetSession.is_bot:"), "bootstrap keeps UI and presentation instantiation inside the client-only branch")
	check(not bootstrap_source.contains("CorridorPresentation.new()"), "bootstrap does not construct presentation by script class")
	net_session.is_server = false
	net_session.is_bot = false
	var packed := load(BOOTSTRAP_SCENE) as PackedScene
	check(packed != null, "bootstrap scene loads")
	if packed == null:
		return
	var bootstrap := packed.instantiate() as Node3D
	check(bootstrap != null, "bootstrap scene instantiates")
	if bootstrap == null:
		return
	var world_anchor := bootstrap.get_node_or_null("World")
	check(world_anchor != null, "bootstrap still exposes World anchor")
	check(bootstrap.get_node_or_null("Players") != null, "bootstrap still exposes Players anchor")
	check(world_anchor != null and world_anchor.get_child_count() == 1 and world_anchor.get_child(0) is CorridorWorld, "bootstrap authors exactly one CorridorWorld child before runtime")
	root.add_child(bootstrap)
	await process_frame
	var runtime_world_anchor := bootstrap.get_node_or_null("World")
	check(net_session.world_root == bootstrap, "bootstrap preserves NetSession.world_root assignment to the scene root")
	check(net_session.players_root == bootstrap.get_node_or_null("Players"), "bootstrap preserves NetSession.players_root assignment")
	check(runtime_world_anchor != null and runtime_world_anchor.get_child_count() == 1, "bootstrap runtime does not construct a duplicate CorridorWorld")
	check(_corridor_ui_count(bootstrap) == 1, "bootstrap instantiates exactly one production UI for an interactive client")
	check(_corridor_presentation_count(bootstrap) == 1, "bootstrap instantiates exactly one production presentation for an interactive client")
	check(_presentation_is_client_gated_in_bootstrap_source(bootstrap_source), "bootstrap presentation creation is textually gated with UI in the client-only branch")
	if runtime_world_anchor and runtime_world_anchor.get_child_count() == 1:
		check(runtime_world_anchor.get_child(0).get_node_or_null("WorldVisuals") != null, "bootstrap-authored CorridorWorld keeps visible client visuals")
	bootstrap.queue_free()
	await process_frame

func _corridor_ui_count(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is CorridorUI:
			total += 1
		total += _corridor_ui_count(child)
	return total

func _corridor_presentation_count(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is CorridorPresentation:
			total += 1
		total += _corridor_presentation_count(child)
	return total

func _presentation_is_client_gated_in_bootstrap_source(source: String) -> bool:
	var branch := "if not NetSession.is_server and not NetSession.is_bot:\n\t\tvar ui := UI_SCENE.instantiate() as CorridorUI\n\t\tadd_child(ui)\n\t\tvar presentation := PRESENTATION_SCENE.instantiate() as CorridorPresentation\n\t\tadd_child(presentation)"
	return source.contains(branch)

func _color_eq(actual: Color, expected: Color) -> bool:
	return is_equal_approx(actual.r, expected.r) and is_equal_approx(actual.g, expected.g) and is_equal_approx(actual.b, expected.b) and is_equal_approx(actual.a, expected.a)

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
