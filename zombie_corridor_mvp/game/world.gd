class_name CorridorWorld
extends Node3D

const CLIENT_ONLY_VISUALS := &"WorldVisuals"
const PHYSICAL_GEOMETRY := &"CorridorGeometry"

func _ready() -> void:
	var geometry := get_node_or_null(NodePath(PHYSICAL_GEOMETRY)) as Node3D
	if geometry == null:
		push_error("World scene is missing CorridorGeometry physical scene")
		get_tree().quit(2)
		return
	if not CorridorGeometry.activate_authored_instance(geometry):
		push_error("Invalid authored corridor geometry: %s" % ", ".join(CorridorGeometry.validation_errors()))
		get_tree().quit(2)
		return
	if _is_non_visual_role():
		_remove_client_only_visuals()
		_remove_physical_preview_meshes(geometry)

func _is_non_visual_role() -> bool:
	var session := get_tree().root.get_node_or_null("NetSession")
	return session != null and (session.is_server or session.is_bot)

func _remove_client_only_visuals() -> void:
	var visuals := get_node_or_null(NodePath(CLIENT_ONLY_VISUALS))
	if visuals:
		remove_child(visuals)
		visuals.queue_free()

func _remove_physical_preview_meshes(node: Node) -> void:
	for child in node.get_children():
		_remove_physical_preview_meshes(child)
		if child is MeshInstance3D:
			node.remove_child(child)
			child.queue_free()
