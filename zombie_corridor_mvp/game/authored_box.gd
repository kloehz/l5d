@tool
class_name AuthoredBox
extends StaticBody3D

@export var role: StringName = &"":
	set(value):
		role = value
		update_configuration_warnings()

@export var visual_color: Color = Color(.23, .3, .36, 1):
	set(value):
		visual_color = value
		_update_mesh_from_shape()

var _observed_shape: Shape3D

func _ready() -> void:
	set_process(Engine.is_editor_hint())
	_bind_shape_signal()
	_update_mesh_from_shape()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_monitor_shape_resource_identity()

func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		_bind_shape_signal()
		_update_mesh_from_shape()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var collider := _collision_shape()
	if role == &"":
		warnings.append("Set the authored geometry role used by CorridorGeometry validation.")
	if collision_layer != 1 or collision_mask != 0:
		warnings.append("CorridorGeometry validation expects collision layer 1 and mask 0; ready will not rewrite these values.")
	if collider == null:
		warnings.append("AuthoredBox requires a CollisionShape3D child.")
	elif not collider.shape is BoxShape3D:
		warnings.append("AuthoredBox supports only BoxShape3D as the collision authority.")
	if _mesh_instance() == null:
		warnings.append("AuthoredBox previews with a MeshInstance3D child under the CollisionShape3D.")
	return warnings

func _collision_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null

func _mesh_instance() -> MeshInstance3D:
	var collider := _collision_shape()
	if collider == null:
		return null
	for child in collider.get_children():
		if child is MeshInstance3D:
			return child
	return null

func _monitor_shape_resource_identity() -> void:
	var collider := _collision_shape()
	var shape := collider.shape if collider else null
	if _observed_shape != shape:
		_bind_shape_signal()
		_update_mesh_from_shape()

func _bind_shape_signal() -> void:
	var collider := _collision_shape()
	var shape := collider.shape if collider else null
	if _observed_shape == shape:
		return
	if _observed_shape != null and _observed_shape.changed.is_connected(_update_mesh_from_shape):
		_observed_shape.changed.disconnect(_update_mesh_from_shape)
	_observed_shape = shape
	if _observed_shape != null and not _observed_shape.changed.is_connected(_update_mesh_from_shape):
		_observed_shape.changed.connect(_update_mesh_from_shape)
	_update_mesh_from_shape()

func _update_mesh_from_shape() -> void:
	var collider := _collision_shape()
	var mesh_instance := _mesh_instance()
	if collider == null or mesh_instance == null or not collider.shape is BoxShape3D:
		return
	if mesh_instance.mesh == null or not mesh_instance.mesh is BoxMesh:
		mesh_instance.mesh = BoxMesh.new()
	var box_mesh := mesh_instance.mesh as BoxMesh
	box_mesh.resource_local_to_scene = true
	box_mesh.size = (collider.shape as BoxShape3D).size
	if mesh_instance.material_override == null or not mesh_instance.material_override is StandardMaterial3D:
		mesh_instance.material_override = StandardMaterial3D.new()
	var material := mesh_instance.material_override as StandardMaterial3D
	material.resource_local_to_scene = true
	material.albedo_color = visual_color
