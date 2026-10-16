extends "res://addons/netfox/properties/property-history-buffer.gd"

var _latest_sample: Dictionary = {}
var _generation: int = 0

func _init(original_states: _PropertyHistoryBuffer, generation: int) -> void:
	_buffer = original_states.get_buffer()
	_generation = generation

func set_snapshot(tick: int, data) -> void:
	super(tick, data)
	if tick <= int(_latest_sample.get("tick", -1)):
		return
	var snapshot: _PropertySnapshot = get_snapshot(tick)
	if snapshot == null or not snapshot.has(":position") or not snapshot.has(":facing"):
		return
	var position: Variant = snapshot.get_value(":position")
	var facing: Variant = snapshot.get_value(":facing")
	if not position is Vector3 or not facing is Vector2:
		return
	if not _finite_vector3(position) or not _finite_vector2(facing):
		return
	_latest_sample = {"tick": tick, "position": position, "facing": facing, "generation": _generation}

func get_latest_sample() -> Dictionary:
	return _latest_sample.duplicate()

func clear_sample_cache(generation: int) -> void:
	_latest_sample.clear()
	_generation = generation

func _finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _finite_vector2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
