extends Node

const RemotePlayerVisualScript = preload("res://game/remote_player_visual.gd")
const PLAYER_SCENE := "res://scenes/player_actor.tscn"

class IsolatedClockPlayer:
	extends CorridorPlayer
	var isolated_clock: Node
	func _network_time() -> Node:
		return isolated_clock

class IsolatedTestClock:
	extends Node
	var tick: int = 0
	var tick_factor: float = 0.0

var assertions: int = 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var movement_sync_script: Script = load("res://game/movement_sync.gd") as Script
	var received_states_script: Script = load("res://game/received_player_states.gd") as Script
	_check(movement_sync_script != null and received_states_script != null, "receipt adapter scripts load explicitly")
	var sync: Node = movement_sync_script.new()
	var base: _PropertyHistoryBuffer = sync._states
	var view: _PropertyHistoryBuffer = received_states_script.new(base, 1)
	_check(view.get_buffer() == base.get_buffer(), "receipt view aliases the original shared history dictionary")
	var cache := PropertyCache.new(sync)
	var full := _SnapshotHistoryEncoder.new(base, cache)
	var diff := _DiffHistoryEncoder.new(base, cache)
	full._history = view
	diff._history = view
	_check(full.apply(100, _snapshot(Vector3(1, 0, 0), Vector2.ZERO)), "actual full encoder apply writes through the receipt view")
	_check(view.get_latest_sample().tick == 100, "full decoder write creates exact receipt sample")
	base.set_snapshot(105, _snapshot(Vector3(50, 0, 0), Vector2.ZERO))
	_check(diff.apply(105, _PropertySnapshot.new(), 100), "empty diff apply reports success under pinned Netfox behavior")
	_check(base.has(105) and view.get_latest_sample().tick == 100, "empty diff plus recorder held key cannot invent a received sample")
	_check(full.apply(101, _snapshot(Vector3(2, 0, 0), Vector2.UP)), "actual full apply continues to write receipt samples")
	_check(diff.apply(103, _snapshot(Vector3(3, 0, 0), Vector2.RIGHT), 101), "actual nonempty diff apply writes through the receipt view")
	_check(view.get_latest_sample().tick == 103 and view.get_latest_sample().position == Vector3(3, 0, 0), "nonempty diff yields its exact applied snapshot")
	var returned: Dictionary = view.get_latest_sample()
	returned.position = Vector3(90, 90, 90)
	_check(view.get_latest_sample().position == Vector3(3, 0, 0), "receipt getter returns a defensive copy")
	view.set_snapshot(102, _snapshot(Vector3.ZERO, Vector2.ZERO))
	_check(view.get_latest_sample().tick == 103, "stale writes preserve shared history but cannot rewind receipt cache")
	view.set_snapshot(104, _PropertySnapshot.from_dictionary({":position": Vector3.ZERO}))
	view.set_snapshot(105, _snapshot(Vector3(INF, 0, 0), Vector2.ZERO))
	_check(view.get_latest_sample().tick == 103, "incomplete and nonfinite writes are not admitted")
	_check(base.has(102) and base.has(104) and base.has(105), "rejected cache samples retain normal shared-history writes")
	view.clear_sample_cache(2)
	_check(view.get_latest_sample().is_empty() and view.get_buffer() == base.get_buffer(), "generation reset clears only cache and preserves shared history")
	_check(view.get_latest_sample().is_empty(), "cache remains empty until a decoder write in the new generation")
	var playback: RefCounted = RemotePlayerVisualScript.new()
	_check(playback.ingest({"tick": 10, "generation": 1, "position": Vector3.ZERO, "facing": Vector2(PI - .1, 0)}, 1), "first valid sample is accepted")
	_check(playback.ingest({"tick": 12, "generation": 1, "position": Vector3(.2, 0, 0), "facing": Vector2(-PI + .1, 0)}, 1), "sparse actual sample is accepted")
	var middle: Dictionary = playback.sample_at(11.0)
	_check((middle.position as Vector3).is_equal_approx(Vector3(.1, 0, 0)), "sparse bracket interpolates position")
	_check(absf(absf(float(middle.yaw)) - PI) < .01, "yaw interpolation takes shortest wrap path")
	_check((playback.sample_at(8).position as Vector3) == Vector3.ZERO and (playback.sample_at(15).position as Vector3) == Vector3(.2, 0, 0), "history endpoints hold without extrapolation")
	_check(not playback.ingest({"tick": 12, "generation": 1, "position": Vector3.ZERO, "facing": Vector2.ZERO}, 1), "duplicate tick is rejected")
	_check(not playback.ingest({"tick": 11, "generation": 1, "position": Vector3.ZERO, "facing": Vector2.ZERO}, 1), "out-of-order tick is rejected")
	_check(not playback.ingest({"tick": 13, "generation": 1, "position": Vector3(INF, 0, 0), "facing": Vector2.ZERO}, 1), "non-finite sample is rejected")
	_check(not playback.ingest({"tick": 13, "generation": 1, "position": Vector3.ZERO}, 1), "incomplete sample is rejected")
	for tick in range(13, 50):
		playback.ingest({"tick": tick, "generation": 1, "position": Vector3.ZERO, "facing": Vector2.ZERO}, 1)
	_check(playback.retained_count() == 24, "retained actual sample history is bounded at24")
	var cursor_playback: RefCounted = RemotePlayerVisualScript.new()
	var cursor: float = cursor_playback.advance(1.0 / 30.0, 50.0)
	var steady_cursor: float = cursor_playback.advance(1.0 / 30.0, 50.5)
	_check(steady_cursor > cursor and steady_cursor <= 51.0, "continuous cursor advances with fractional steady public time and stays within lead bound")
	var skew_cursor: float = cursor_playback.advance(-.5, 50.4)
	_check(skew_cursor >= steady_cursor and skew_cursor <= 50.9, "negative render delta and small backward clock skew remain monotonic and bounded")
	var invalid_delta_cursor: float = cursor_playback.advance(NAN, 50.5)
	_check(invalid_delta_cursor >= skew_cursor and invalid_delta_cursor <= 51.0, "non-finite render delta cannot rewind or unbound cursor")
	var before_stall: float = cursor_playback.get_display_tick()
	var after_stall: float = cursor_playback.advance(5.0, 50.6)
	_check(after_stall >= before_stall and after_stall - before_stall <= 3.001, "five-second render stall advances by at most the clamped three ticks")
	var resynced: float = cursor_playback.advance(.016, 60.0)
	_check(is_equal_approx(resynced, 49.5), "clock jump beyond six ticks explicitly resets to 350ms delayed public time")
	_check(playback.ingest({"tick": 51, "generation": 2, "position": Vector3.ZERO, "facing": Vector2.ZERO}, 1) and playback.retained_count() == 1, "receipt generation resets history")
	_check(playback.ingest({"tick": 52, "generation": 2, "position": Vector3(100, 0, 0), "facing": Vector2.ZERO}, 1) and playback.retained_count() == 1, "teleport discontinuity clears prior trajectory")
	var post_teleport_cursor: float = playback.advance(1.0 / 30.0, 52.5)
	_check(is_finite(post_teleport_cursor) and is_finite(float(playback.sample_at(post_teleport_cursor).position.x)), "teleport reset reinitializes cursor and endpoint sampling")
	_check(playback.ingest({"tick": 53, "generation": 2, "position": Vector3(100.1, 0, 0), "facing": Vector2.ZERO}, 1), "nearby receipt after teleport resumes normally")
	_check(playback.ingest({"tick": 54, "generation": 2, "position": Vector3.ZERO, "facing": Vector2.ZERO}, 2) and playback.retained_count() == 1, "life change resets history")
	await _check_actual_player_process(received_states_script)
	print(JSON.stringify({"kind": "player_presentation", "assertions": assertions, "failures": failures}))
	var visibility_filter: Node = sync.visibility_filter
	if visibility_filter != null and visibility_filter.get_parent() == null:
		visibility_filter.free()
		sync.visibility_filter = null
	sync.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_actual_player_process(received_states_script: Script) -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	_check(packed != null, "authored player actor scene loads for actual process integration")
	if packed == null:
		return
	var session := get_tree().root.get_node("NetSession")
	var network_time := get_tree().root.get_node("NetworkTime")
	var remote_peer := 2 if session.local_peer() == 1 else 1
	var test_world := Node3D.new()
	test_world.name = "PlayerPresentationWorld"
	get_tree().root.add_child(test_world)
	var remote := packed.instantiate() as CorridorPlayer
	remote.set_script(IsolatedClockPlayer)
	var clock := IsolatedTestClock.new()
	remote.isolated_clock = clock
	remote.configure(remote_peer, 7, Vector3(4, 0, 0), 0)
	remote.set_multiplayer_authority(session.local_peer())
	test_world.add_child(remote)
	await get_tree().process_frame
	var authority_before := remote.get_multiplayer_authority()
	var logical_before := remote.global_position
	var root_velocity := remote.velocity
	var logical_facing: Vector2 = remote.facing
	remote.rb._received_state_generation += 1
	remote.rb._received_state_view = received_states_script.new(remote.rb._states, remote.rb.get_received_generation())
	var generation: int = remote.rb.get_received_generation()
	clock.tick = 111
	remote.rb._received_state_view.set_snapshot(100, _snapshot(Vector3(4, 0, 0), Vector2.ZERO))
	remote._process(1.0 / 30.0)
	_check(remote._remote_visual_playback.retained_count() == 1, "actual remote player process consumes first accepted receipt")
	remote.rb._received_state_view.set_snapshot(102, _snapshot(Vector3(4.2, 0, 0), Vector2(.2, 0)))
	remote._process(1.0 / 30.0)
	var actual := remote.visual.global_position
	var expected_pose: Dictionary = remote._remote_visual_playback.sample_at(remote._remote_visual_playback.get_display_tick())
	_check(actual.is_equal_approx(expected_pose.position), "actual remote process applies the helper's displayed sample bracket pose")
	_check(is_equal_approx(remote.visual.rotation.y, float(expected_pose.yaw)), "actual remote process applies yaw from the same bracket")
	_check(remote.global_position == logical_before and remote.velocity == root_velocity and remote.facing == logical_facing and remote.get_multiplayer_authority() == authority_before, "actual remote playback leaves logical root, velocity, facing, and authority unchanged")
	_check(remote.rb.get_received_generation() == generation, "presentation integration does not mutate adapter generation")
	var local := packed.instantiate() as CorridorPlayer
	local.configure(session.local_peer(), 8, Vector3(1, 0, 0), 0)
	test_world.add_child(local)
	await get_tree().process_frame
	var local_pose := Vector3(2, 0, 0)
	local.position = local_pose
	local._process(1.0 / 60.0)
	_check(local.visual.global_position.is_equal_approx(local.global_position), "actual local process keeps immediate visual following")
	_check(local.camera == null or local.camera.current, "actual local process preserves local camera ownership")
	_check(local._remote_visual_playback == null, "local actor does not allocate remote playback history")
	_prime_sync_disconnects(test_world)
	test_world.queue_free()
	await get_tree().process_frame
	clock.free()
	_check(network_time != null, "isolated integration leaves the global network clock available and untouched")

func _prime_sync_disconnects(node: Node) -> void:
	if node is CorridorPlayer and node.rb and node.rb.has_method("_connect_signals"):
		node.rb._connect_signals()
	for child in node.get_children():
		_prime_sync_disconnects(child)

func _snapshot(position: Variant, facing: Variant) -> _PropertySnapshot:
	return _PropertySnapshot.from_dictionary({":position": position, ":facing": facing})

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
