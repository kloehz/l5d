extends SceneTree

const PRESENTATION_SCENE := preload("res://scenes/presentation.tscn")
const SAMPLER := preload("res://game/mob_visual_sampler.gd")
const MOB_TIMING := preload("res://game/mob_timing.gd")

class TestClock:
	extends Node
	var tick := 0
	var tick_factor := 0.0

class TestPresentation:
	extends "res://game/presentation.gd"
	var test_clock: Node

	func _network_time() -> Node:
		return test_clock

var failures: Array[String] = []
var assertions := 0
var net_session: Node
var presentation: Node3D
var clock: TestClock
var original_records: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	net_session = root.get_node("NetSession")
	original_records = net_session.store.records.duplicate(true)
	_check_sampler_boundaries()
	await _check_production_presentation()
	net_session.store.records = original_records
	var result := {"kind": "mob_presentation", "assertions": assertions, "failures": failures}
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _check_sampler_boundaries() -> void:
	var history := _test_history()
	var original_history := history.duplicate(true)
	var first := SAMPLER.sample(history, 10.0, Vector3(99, 0, 0), 0.0)
	_check(first.position == Vector3.ZERO, "exact first endpoint returns the first authoritative sample")
	_check(is_equal_approx(first.yaw, deg_to_rad(170.0)), "exact yaw endpoint is not separately smoothed")
	var midpoint := SAMPLER.sample(history, 10.5, Vector3.ZERO, 0.0)
	_check(midpoint.position.is_equal_approx(Vector3(5, 0, 0)), "position is interpolated between history brackets")
	_check(absf(wrapf(midpoint.yaw - PI, -PI, PI)) < 0.0001, "wrapped yaw follows the short arc")
	var one_sample: Array = [history[0]]
	_check(SAMPLER.sample(one_sample, 20.0, Vector3.ZERO, 0.0).position == Vector3.ZERO, "single sample holds at every target")
	_check(SAMPLER.sample(history, 9.0, Vector3.ZERO, 0.0).position == Vector3.ZERO, "target before history holds oldest sample")
	_check(SAMPLER.sample(history, 11.0, Vector3.ZERO, 0.0).position == Vector3(10, 0, 0), "exact latest endpoint returns that sample")
	_check(SAMPLER.sample(history, 12.0, Vector3.ZERO, 0.0).position == Vector3(10, 0, 0), "target after history holds latest sample without extrapolation")
	var empty := SAMPLER.sample([], 12.0, Vector3(3, 0, 0), 0.75)
	_check(empty.position == Vector3(3, 0, 0) and is_equal_approx(empty.yaw, 0.75), "empty history uses the current authoritative row")
	_check(history == original_history, "sampling leaves authoritative test history unchanged")
	_check_unbuffered_hold_and_arrival_gaps()
	_check_shared_timing_and_combat_rewind()

func _check_unbuffered_hold_and_arrival_gaps() -> void:
	var stale_history := [
		{"tick": 10, "position": Vector3.ZERO, "yaw": 0.0},
		{"tick": 12, "position": Vector3(0.1, 0, 0), "yaw": 0.0},
		{"tick": 16, "position": Vector3(0.3, 0, 0), "yaw": 0.0},
	]
	var stale := SAMPLER.sample(stale_history, 20.0, Vector3(9, 0, 0), 0.0)
	_check(stale.mode == "held" and stale.position == Vector3(0.3, 0, 0), "history underflow holds the latest authoritative pose with no extrapolation")
	_check(is_equal_approx(stale.age_seconds, 4.0 / MOB_TIMING.NETWORK_TICK_RATE_HZ), "held degradation reports finite age from the latest sample")
	var recorded_style_ticks := [10, 12, 16, 18, 22, 24, 28, 30]
	var arrival_history: Array = []
	for tick in recorded_style_ticks:
		arrival_history.append({"tick": tick, "position": Vector3(float(tick) * 2.0 / 30.0, 0, 0), "yaw": 0.0})
	var buffered_tick := float(recorded_style_ticks.back()) - MOB_TIMING.interpolation_delay_ticks()
	var buffered := SAMPLER.sample(arrival_history, buffered_tick, Vector3.ZERO, 0.0)
	_check(is_equal_approx(buffered_tick, 21.0), "300ms buffer targets nine network ticks behind latest history")
	_check(buffered.mode == "interpolated" and buffered.position.distance_to(Vector3(1.4, 0, 0)) < .0001, "synthetic alternating 2/4-tick arrivals bracket buffered presentation without filling history")
	_check(SAMPLER.sample(arrival_history, buffered_tick, Vector3.ZERO, 0.0).position == buffered.position, "repeated buffered sample remains deterministic without arrival-state mutation")
	var duplicate_ticks := [
		{"tick": 10, "position": Vector3.ZERO, "yaw": 0.0},
		{"tick": 12, "position": Vector3(0.1, 0, 0), "yaw": 0.0},
		{"tick": 12, "position": Vector3(0.1, 0, 0), "yaw": 0.0},
	]
	_check(SAMPLER.sample(duplicate_ticks, 11.0, Vector3.ZERO, 0.0).position.is_equal_approx(Vector3(0.05, 0, 0)), "duplicate combat revisions do not divide by zero and preserve bracket interpolation")

func _check_shared_timing_and_combat_rewind() -> void:
	_check(is_equal_approx(MOB_TIMING.NETWORK_TICK_RATE_HZ, 30.0), "shared mob timing uses the existing public 30Hz network tick rate")
	_check(is_equal_approx(MOB_TIMING.INTERPOLATION_DELAY_SECONDS, .300) and is_equal_approx(MOB_TIMING.interpolation_delay_ticks(), 9.0), "shared interpolation policy is 300ms or nine ticks")
	_check(is_equal_approx(MOB_TIMING.MAX_REWIND_SECONDS, .450), "shared authoritative rewind bound is 450ms")
	_check(is_equal_approx(MOB_TIMING.MOB_HISTORY_SECONDS, .500) and MOB_TIMING.INTERPOLATION_DELAY_SECONDS < MOB_TIMING.MAX_REWIND_SECONDS and MOB_TIMING.MAX_REWIND_SECONDS < MOB_TIMING.MOB_HISTORY_SECONDS, "buffer and rewind remain strictly inside the existing 500ms history")
	var now := float(root.get_node("NetworkTime").time)
	for requested in [now - .450001, now - .450, now - .449999]:
		_check(is_equal_approx(MOB_TIMING.clamp_rewind_time(requested, now), maxf(requested, now - .450)), "shared rewind helper clamps below, at and above the 450ms boundary")
	_check(is_equal_approx(MOB_TIMING.clamp_rewind_time(now + .01, now), now), "shared rewind helper never queries after current authoritative time")

	# Synthetic fixture data exercises the real CommittedCombat and MathematicalMobs paths; it is not a network receipt.
	var combat: RefCounted = (load("res://game/combat.gd") as Script).new()
	var mobs: RefCounted = (load("res://game/mob_world.gd") as Script).new()
	var player_pose := Vector3(-1.5, 0, -7)
	var historical_pose := Vector3(-1.5, 0, -10)
	var current_pose := Vector3(4.0, 0, -10)
	var fixture_row := {"id": 9001, "state": 1, "born": now - 1.0, "position": current_pose, "hp": 100, "revision": 1, "history": [[now - .500, current_pose], [now - .450, historical_pose], [now, current_pose]]}
	mobs.records[9001] = fixture_row
	var player := {"life": 1, "hp": 100, "next_shot": 0.0, "pose": player_pose, "kills": 0, "high": 0, "floor": 0, "pending": 1, "queued": {}, "cache": {}}
	var shot_origin: Vector3 = player_pose + Vector3(0, 1.55, 0)
	var shot_direction := Vector3(0, 0, -1)
	var wall_distance: float = CorridorGeometry.wall_distance(shot_origin, shot_direction, net_session.weapon_range)
	var historical_hit_distance: float = CorridorGeometry.ray_capsule(shot_origin, shot_direction, historical_pose, wall_distance)
	_check(wall_distance > 3.0, "synthetic shot origin has authored corridor clearance beyond the historical target")
	_check(is_finite(historical_hit_distance) and historical_hit_distance < wall_distance, "synthetic historical capsule is actually intersected before authored walls")
	var old_rewind_pose: Vector3 = mobs.historic_pose(fixture_row, now - .250)
	var old_rewind_hit: float = CorridorGeometry.ray_capsule(shot_origin, shot_direction, old_rewind_pose, wall_distance)
	_check(old_rewind_pose.distance_to(historical_pose) > .4 and (is_inf(old_rewind_hit) or old_rewind_hit >= wall_distance), "counterfactual 250ms rewind misses the off-axis recorded pose in clear geometry")
	var original_publisher = net_session.publisher
	net_session.publisher = (load("res://game/publisher.gd") as Script).new()
	var shot_id := 0
	for requested in [now - .450001, now - .450, now - .449999]:
		shot_id += 1
		combat.queue = [{"peer": 1, "life": 1, "shot": shot_id, "dir": shot_direction, "view": requested, "received": Time.get_ticks_msec() / 1000.0}]
		player.queued[shot_id] = true
		player.pending = 1
		player.next_shot = 0.0
		combat.process({1: player}, mobs, now)
		_check(combat.hits == shot_id, "actual committed-combat path hits synthetic historical pose at, below, and above the 450ms bound")
	net_session.publisher = original_publisher

func _check_production_presentation() -> void:
	clock = TestClock.new()
	presentation = PRESENTATION_SCENE.instantiate() as Node3D
	presentation.set_script(TestPresentation)
	presentation.test_clock = clock
	root.add_child(clock)
	root.add_child(presentation)
	presentation.set_process(false)
	_check(presentation._tracer_pool.size() == 8, "production authored tracer pool remains eight slots")

	# Deterministic synthetic TESTDATA; these timestamps are not network or product receipts.
	var history := _test_history()
	net_session.store.records.clear()
	net_session.store.records[77] = {
		"position": Vector3(10, 0, 0),
		"yaw": deg_to_rad(-170.0),
		"state": 1,
		"hp": 100.0,
		"revision": 1,
		"interest_epoch": 1,
		"history": history,
	}
	var original_row: Dictionary = net_session.store.records[77].duplicate(true)
	clock.tick = 19
	clock.tick_factor = 0.2
	presentation._process(0.0)
	var mob: MeshInstance3D = presentation.visuals[77]
	_check(mob != null, "production presentation creates the authored mob visual")
	_check(mob.position.is_equal_approx(Vector3(2, 0.9, 0)), "render clock fraction moves the production mob inside one integer tick")
	var yaw_midpoint := mob.rotation.y
	_check(absf(wrapf(yaw_midpoint - deg_to_rad(174.0), -PI, PI)) < 0.0001, "production mob yaw interpolates over the short arc")

	clock.tick_factor = 0.7
	presentation._process(0.5 / 30.0)
	_check(mob.position.is_equal_approx(Vector3(7, 0.9, 0)), "fraction advances presentation within the same integer tick")
	clock.tick_factor = 0.99
	presentation._process(0.29 / 30.0)
	var before_crossing := mob.position.x
	clock.tick = 20
	clock.tick_factor = 0.0
	presentation._process(0.01 / 30.0)
	_check(is_equal_approx(before_crossing, 9.9) and is_equal_approx(mob.position.x, 10.0), "tick crossing advances continuously from the same fractional render clock")
	_check(mob.position.x > before_crossing, "tick crossing does not step backward")
	_check(absf(wrapf(mob.rotation.y - deg_to_rad(-170.0), -PI, PI)) < 0.0001, "production yaw holds exact latest endpoint")
	_check(net_session.store.records[77] == original_row, "production render sampling leaves authoritative state and history unchanged")
	var revised_row: Dictionary = net_session.store.records[77]
	revised_row.revision = 2
	revised_row.position = Vector3(10.1, 0, 0)
	revised_row.history = [history[0], {"tick": 11, "position": revised_row.position, "yaw": revised_row.yaw}]
	presentation._process(0.0)
	_check(is_equal_approx(presentation.visuals[77].position.x, 10.1), "new authoritative revision is sampled directly without packet-correction offsets")
	net_session.connection_generation += 1
	presentation._process(0.0)
	_check(is_equal_approx(presentation.visuals[77].position.x, 10.1), "reconnect resets only the public display cursor, with no stale per-mob offsets")
	net_session.connection_generation -= 1
	_check(is_equal_approx(presentation.get_display_time_seconds(), 12.0 / 30.0), "shot view timestamp uses the same display tick conversion exactly once")
	_check(is_equal_approx(net_session.shot_view_time_seconds(), presentation.get_display_time_seconds()), "NetSession submits the displayed view time without adding a second delay")
	_check(presentation.get_rendered_mob_foot(77).is_equal_approx(mob.position - Vector3(0, .9, 0)), "aim exposure returns the actual displayed foot pose")
	var cursor_before_stall: float = presentation.get_display_tick()
	presentation._process(5.0)
	var cursor_after_stall: float = presentation.get_display_tick()
	_check(cursor_after_stall >= cursor_before_stall and cursor_after_stall - cursor_before_stall <= .1 * 30.0 + .001, "render stall advances a bounded monotonic cursor rather than jumping by elapsed wall time")
	for _frame in range(100):
		presentation._process(.1)
	_check(presentation.get_display_tick() <= float(clock.tick) + float(clock.tick_factor) - presentation.DISPLAY_DELAY_TICKS + presentation.MAX_CURSOR_LEAD_TICKS + .001, "stalled public time cannot let the display cursor accumulate unbounded drift")
	var cursor_before_resync: float = presentation.get_display_tick()
	clock.tick += 20
	presentation._process(0.016)
	_check(presentation.get_display_tick() > cursor_before_resync + 10.0, "large public-clock resynchronization explicitly resets the display cursor")
	_check(is_equal_approx(presentation.visuals[77].position.x, 10.1), "production presentation holds latest received history after buffered underflow without extrapolation")
	var session_epoch := int(net_session.epoch)
	net_session.epoch += 1
	clock.tick += 1
	presentation._process(0.016)
	_check(is_equal_approx(presentation.get_display_tick(), float(clock.tick) + clock.tick_factor - presentation.DISPLAY_DELAY_TICKS), "session change resets the cursor to buffered public time")
	net_session.epoch = session_epoch
	var visited_row: Dictionary = net_session.store.records[77]
	visited_row.interest_epoch = 2
	visited_row.history = [{"tick": 32, "position": Vector3(32, 0, 0), "yaw": 0.0}, {"tick": 33, "position": Vector3(33, 0, 0), "yaw": 0.0}]
	visited_row.position = Vector3(33, 0, 0)
	clock.tick = 40
	presentation._process(0.016)
	_check(is_equal_approx(presentation.visuals[77].position.x, 32.0), "changed interest visit samples its own authoritative history without stale per-mob state")

	net_session.store.records.clear()
	presentation._process(0.0)
	await process_frame
	_check(not presentation.visuals.has(77) and not is_instance_valid(mob), "removed mob visual is queued and freed")
	_check(presentation._tracer_pool.size() == 8, "mob birth and removal do not alter authored tracer pool")
	presentation.queue_free()
	clock.queue_free()
	await process_frame
	_check(not is_instance_valid(presentation) and not is_instance_valid(clock), "presentation and test clock teardown cleanly")

func _test_history() -> Array:
	return [
		{"tick": 10, "position": Vector3.ZERO, "yaw": deg_to_rad(170.0)},
		{"tick": 11, "position": Vector3(10, 0, 0), "yaw": deg_to_rad(-170.0)},
	]

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
