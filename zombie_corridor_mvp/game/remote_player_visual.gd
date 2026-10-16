class_name RemotePlayerVisual
extends RefCounted

const SAMPLE_LIMIT := 24
const TICK_RATE := 30.0
const DISPLAY_DELAY_TICKS := 10.5 # 350 ms; validated against decoder-write ages in direct and 150 ms RTT runs.
const MAX_FRAME_DELTA := 0.1
const MAX_CURSOR_LEAD_TICKS := 0.5
const CLOCK_SLEW_FRACTION := 0.25
const MAX_RESYNC_TICKS := 6.0
const TELEPORT_SPEED_MPS := 5.0
const TELEPORT_EPSILON_M := 0.25

var _samples: Array[Dictionary] = []
var _generation := -1
var _life_id := -1
var _cursor := NAN
var _last_public_time := NAN

func reset() -> void:
	_samples.clear()
	_generation = -1
	_life_id = -1
	_cursor = NAN
	_last_public_time = NAN

func ingest(sample: Dictionary, life_id: int) -> bool:
	if not sample.has("tick") or not sample.has("generation") or not sample.has("position") or not sample.has("facing"):
		return false
	var tick := int(sample.tick)
	var generation := int(sample.generation)
	var position: Variant = sample.position
	var facing: Variant = sample.facing
	if tick < 0 or not position is Vector3 or not facing is Vector2:
		return false
	if not _finite3(position) or not is_finite(facing.x) or not is_finite(facing.y):
		return false
	if _generation != generation or _life_id != life_id:
		_samples.clear()
		_generation = generation
		_life_id = life_id
		_cursor = NAN
		_last_public_time = NAN
	if not _samples.is_empty():
		var previous: Dictionary = _samples.back()
		if tick <= int(previous.tick):
			return false
		var elapsed_ticks := tick - int(previous.tick)
		var allowed_distance := TELEPORT_SPEED_MPS * float(elapsed_ticks) / TICK_RATE + TELEPORT_EPSILON_M
		if (position as Vector3).distance_to(previous.position) > allowed_distance:
			_samples.clear()
			_cursor = NAN
			_last_public_time = NAN
	var copied := {"tick": tick, "generation": generation, "position": position, "facing": facing}
	_samples.append(copied)
	while _samples.size() > SAMPLE_LIMIT:
		_samples.pop_front()
	return true

func advance(delta: float, public_tick: float) -> float:
	if not is_finite(public_tick):
		return _cursor
	var target := public_tick - DISPLAY_DELAY_TICKS
	if not is_finite(_last_public_time) or absf(public_tick - _last_public_time) > MAX_RESYNC_TICKS:
		_cursor = target
	else:
		var safe_delta := delta if is_finite(delta) else 0.0
		var elapsed_ticks := clampf(safe_delta, 0.0, MAX_FRAME_DELTA) * TICK_RATE
		var error_ticks := target - (_cursor + elapsed_ticks)
		var correction := clampf(error_ticks * CLOCK_SLEW_FRACTION, -elapsed_ticks * CLOCK_SLEW_FRACTION, elapsed_ticks * CLOCK_SLEW_FRACTION)
		var stepped := _cursor + elapsed_ticks + correction
		_cursor = maxf(_cursor, minf(stepped, target + MAX_CURSOR_LEAD_TICKS))
	_last_public_time = public_tick
	return _cursor

func sample_at(tick: float) -> Dictionary:
	if _samples.is_empty():
		return {}
	if tick <= float(_samples.front().tick):
		return _pose(_samples.front())
	if tick >= float(_samples.back().tick):
		return _pose(_samples.back())
	for index in range(1, _samples.size()):
		var right: Dictionary = _samples[index]
		if tick <= float(right.tick):
			var left: Dictionary = _samples[index - 1]
			var amount := (tick - float(left.tick)) / float(int(right.tick) - int(left.tick))
			var left_facing: Vector2 = left.facing
			var right_facing: Vector2 = right.facing
			var left_yaw := -left_facing.x
			var right_yaw := -right_facing.x
			return {"tick": tick, "position": (left.position as Vector3).lerp(right.position, amount), "yaw": lerp_angle(left_yaw, right_yaw, amount)}
	return _pose(_samples.back())

func get_display_tick() -> float:
	return _cursor

func retained_count() -> int:
	return _samples.size()

func retained_samples_copy() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sample: Dictionary in _samples:
		result.append(sample.duplicate(true))
	return result

func _pose(sample: Dictionary) -> Dictionary:
	var facing: Vector2 = sample.facing
	return {"tick": float(sample.tick), "position": sample.position, "yaw": -facing.x}

func _finite3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
