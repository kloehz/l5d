extends RefCounted

const MOB_TIMING := preload("res://game/mob_timing.gd")
const NETWORK_TICK_RATE_HZ := MOB_TIMING.NETWORK_TICK_RATE_HZ

static func sample(history: Array, target_tick: float, latest_position: Vector3, latest_yaw: float) -> Dictionary:
	if history.is_empty():
		return {"position": latest_position, "yaw": latest_yaw, "mode": "empty", "age_seconds": 0.0}

	var first: Dictionary = history[0]
	if target_tick <= float(first.tick):
		return _pose(first.position, float(first.yaw), "history", 0.0)

	var previous: Dictionary = first
	for index in range(1, history.size()):
		var current: Dictionary = history[index]
		var tick_span := int(current.tick) - int(previous.tick)
		if tick_span > 0 and target_tick <= float(current.tick):
			var fraction := clampf((target_tick - float(previous.tick)) / float(tick_span), 0.0, 1.0)
			var yaw_delta := wrapf(float(current.yaw) - float(previous.yaw), -PI, PI)
			return {
				"position": previous.position.lerp(current.position, fraction),
				"yaw": wrapf(float(previous.yaw) + yaw_delta * fraction, -PI, PI),
				"mode": "interpolated",
				"age_seconds": 0.0,
			}
		previous = current

	var latest: Dictionary = history[history.size() - 1]
	var age_ticks := maxf(0.0, target_tick - float(latest.tick))
	return _pose(latest.position, float(latest.yaw), "held", age_ticks / NETWORK_TICK_RATE_HZ)

static func _pose(position: Vector3, yaw: float, mode: String, age_seconds: float) -> Dictionary:
	return {"position": position, "yaw": yaw, "mode": mode, "age_seconds": age_seconds}
