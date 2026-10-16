extends Node
const Budget = preload("res://game/input_publication_budget.gd")
var assertions := 0
var failures: Array[String] = []

# These collaborators test app callback ordering, not native wire delivery.
class Recorder extends _RollbackHistoryRecorder:
	var events: Array
	func record_input(_tick: int) -> void: events.append("record_input")
	func record_state(_tick: int) -> void: events.append("record_state")
	func trim_history() -> void: events.append("trim_history")
class Transmitter extends _RollbackHistoryTransmitter:
	var events: Array
	func transmit_input(_tick: int) -> void: events.append("transmit_input")
	func transmit_state(_tick: int) -> void: events.append("transmit_state")
class Freshness extends RollbackFreshnessStore:
	var events: Array
	func trim() -> void: events.append("trim_freshness")
class Sync extends "res://game/movement_sync.gd":
	var publish := false
	func _can_publish_input(_tick: int) -> bool: return publish
class Body extends Node:
	var retire_tick := 100
class Samples extends RefCounted:
	var _sample_buffer: _RingBuffer
	var _awaiting_samples := {}
	var rtt := .1
	var rtt_jitter := .02
	var sync_interval := .25
	var sync_samples := 8

func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	assertions += 1
	if not value: failures.append(label)

func decision(age := 0, tail := 3, offset := 10.0, phase := 0.0, rtt := 1.0, jitter := 0.0, fresh := true) -> Dictionary:
	# One-second ticks make cutoff arithmetic exact; measured 30 Hz below.
	return Budget.evaluate(40, 40-age, tail, 16, 1.0, phase, offset, rtt, jitter, fresh)

func sample() -> NetworkClockSample:
	var result := NetworkClockSample.new()
	result.ping_sent = 1.0
	result.ping_received = 1.05
	result.pong_sent = 1.05
	result.pong_received = 1.1
	return result

func run() -> void:
	var clock_before := NetworkTime.tick
	check(decision().allowed, "16-tick cutoff equality is admissible")
	check(not decision(1).allowed, "one additional record-age tick exceeds window")
	check(decision(3,0).allowed and not decision(4,0).allowed, "actual oldest sibling tail is budgeted")
	check(not decision(0,3,10.0,1.0).allowed, "stepping phase cannot be discarded")
	check(not decision(0,3,10.0,0.0,1.0,1.0).allowed, "jitter consumes budget")
	check(not decision(0,3,10.0,0.0,1.0,0.0,false).allowed, "initial zero offset is not fresh measurement")
	for bad in [NAN, INF, -INF]:
		check(not decision(0,3,bad).allowed, "nonfinite offset fails closed")
		check(not decision(0,3,0.0,bad).allowed, "nonfinite phase fails closed")
		check(not decision(0,3,0.0,0.0,bad).allowed, "nonfinite RTT fails closed")
	for invalid in [decision(0,-1), decision(0,3,0.0,0.0,0.0), decision(0,3,0.0,0.0,1.0,-1.0)]:
		check(not invalid.allowed, "invalid metric fails closed")
	check(not Budget.evaluate(37,23,0,16,1.0/30.0,0.0,0.0,.1,0.0,true).allowed, "observed packet23 already14 ticks behind at send37 cannot fit transit")
	check(23 < 40-16, "actual packet23 rejected at receiver40/cutoff24")
	check(31 == 47-16 and 28 < 47-16, "packet31 newest fits but three siblings do not")
	check(not Budget.evaluate(47,31,3,16,1.0/30.0,0.0,0.0,.1,0.0,true).allowed, "receipt of newest31 is not whole-packet admissibility")
	check(Budget.evaluate(47,47,3,16,1.0/30.0,0.0,0.0,.15,.04,true).allowed, "steady measured asymmetric full-RTT policy fits")

	var sync := Samples.new()
	var budget := Budget.new()
	var peer := OfflineMultiplayerPeer.new()
	var old := sample()
	sync._sample_buffer = _RingBuffer.new(8)
	sync._sample_buffer.push(old)
	var late := sample()
	sync._awaiting_samples[4] = late
	budget.begin_session(1,peer,sync)
	check(not budget.fresh_measurement(1,peer,sync,100), "retained positive RTT and old buffer are not current session")
	sync._sample_buffer = _RingBuffer.new(8)
	check(not budget.fresh_measurement(1,peer,sync,100), "new empty buffer not measured")
	sync._sample_buffer.push(late)
	check(not budget.fresh_measurement(1,peer,sync,100), "late old pending pong in NEW buffer rejected")
	sync._sample_buffer.clear()
	sync._sample_buffer.push(sample())
	check(budget.fresh_measurement(1,peer,sync,100), "new completed native sample object admits current session")
	check(not budget.fresh_measurement(2,peer,sync,101), "generation mismatch rejected")
	check(not budget.fresh_measurement(1,OfflineMultiplayerPeer.new(),sync,101), "different peer identity rejected")
	check(not budget.fresh_measurement(1,peer,sync,3000000), "measurement expires after native estimator window")
	budget.begin_session(2,peer,sync)
	check(not budget.fresh_measurement(2,peer,sync,3000001), "reconnect cannot reuse last generation's sample")
	budget.end_session()
	check(not budget.fresh_measurement(2,peer,sync,3000002), "disconnect invalidates admission")

	var events: Array = []
	var movement := Sync.new()
	movement.enable_prediction = true # Match the authored production actor.
	var body := Body.new()
	var recorder := Recorder.new()
	var transmitter := Transmitter.new()
	var freshness := Freshness.new()
	recorder.events = events; transmitter.events = events; freshness.events = events
	movement.root = body
	movement._history_recorder = recorder
	movement._history_transmitter = transmitter
	movement._freshness_store = freshness
	movement._after_tick(NetworkTime.ticktime,1)
	check(events == ["record_input","trim_history","trim_freshness"], "held publication retains exact local recording/trim/freshness order")
	check(movement.enable_prediction, "prediction not disabled")
	events.clear()
	movement.publish = true
	movement._after_tick(NetworkTime.ticktime,1)
	check(events == ["record_input","transmit_input","trim_history","trim_freshness"], "usable publication preserves original hook order")
	events.clear()
	movement._on_record_tick(1)
	check(events == ["record_state","transmit_state"], "state publication and ACK hook remain independent")
	events.clear(); body.retire_tick = 1
	movement._after_tick(NetworkTime.ticktime,1)
	check(events == ["trim_history","trim_freshness"], "retired early return unchanged")
	events.clear()
	movement._on_record_tick(2)
	check(events.is_empty(), "retired state hook unchanged")
	# Off-tree RBS eagerly owns an unparented filter; free that owner too.
	movement.visibility_filter.free()
	movement.free(); transmitter.free(); body.free()

	# Actual app coroutine and native ENet peer, not fake packets or clock writes.
	NetSession.set_process(false)
	var native := ENetMultiplayerPeer.new()
	check(native.create_server(0,4,16) == OK, "owned native ENet endpoint starts")
	NetSession.multiplayer.multiplayer_peer = native
	var generation: int = NetSession.connection_generation
	NetSession.connection_usec = Time.get_ticks_usec()
	check(NetSession._input_session_current(generation), "live native peer is current")
	_cancel_session.call_deferred()
	check(not await NetSession._await_input_publication(generation), "disconnect cancels readiness await without world_ready")
	check(not NetSession.is_ready and not NetSession._input_session_current(generation), "disconnect never marks gameplay ready")
	var native2 := ENetMultiplayerPeer.new()
	check(native2.create_server(0,4,16) == OK, "second owned native endpoint starts")
	NetSession.multiplayer.multiplayer_peer = native2
	generation = NetSession.connection_generation
	NetSession.connection_usec = Time.get_ticks_usec() - 20000000
	check(not await NetSession._await_input_publication(generation), "existing20s deadline fails closed without clock advancement")
	check(NetSession.status == "Input clock budget timed out" and not NetSession.is_ready, "timeout uses existing error cleanup and status")
	check(not NetSession._input_session_current(generation), "timeout closes peer and invalidates generation")
	check(NetworkTime.tick == clock_before, "no fixture clock assignment or advancement")
	print(JSON.stringify({"startup_input_budget":assertions,"failures":failures,"callback_order":"semantic collaborators; no wire claim"}))
	get_tree().quit(0 if failures.is_empty() else 1)

func _cancel_session() -> void:
	NetSession.disconnect_session(false)
