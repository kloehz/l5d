extends Node

# Native vendor encoders/buffers; delivery and trimming ticks are explicitly modeled.
# Budget model leaves singleton time untouched; the separate ENet fixture below
# uses public clock start/stop. Neither fixture establishes arbitrary-loss or WAN safety.
const BASE_TICK := 17678
const RECEIVER_TICK := 17696
const PLAYER_SCENE := preload("res://scenes/player_actor.tscn")

var failures: Array[String] = []
var assertions := 0
var evidence := {}
var cache: PropertyCache
var properties: Array[PropertyEntry] = []

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var clock_before := NetworkTime.tick
	var actor := PLAYER_SCENE.instantiate() as CorridorPlayer
	actor.configure(NetSession.local_peer(), 1, Vector3.ZERO, 0)
	check(not actor.is_inside_tree(), "production actor is configured before entering the tree")
	check(actor.rb.full_state_interval == 7, "production full-state interval reserves receiver history margin")
	check(NetworkRollback.history_limit == 16, "existing history limit remains 16 ticks")
	check(actor.rb.diff_ack_interval == 0, "existing diff ACK policy remains disabled")
	check(actor.get_multiplayer_authority() == 1, "production state authority remains the server")
	cache = PropertyCache.new(actor)
	for path in actor.rb.state_properties:
		var entry := cache.get_entry(path)
		check(entry.is_valid(), "configured state property is valid: %s" % path)
		properties.append(entry)

	_check_trim_boundary()
	_check_expired_reference()
	var interval: int = actor.rb.full_state_interval
	for delivery in [[1, 1], [2, 2]]:
		var result := _model_delivery(interval, delivery[0], delivery[1], false)
		check(result.missing_references == 0, "refresh preserves references with modeled forward/reverse delay %s" % [delivery])
		check(result.delivered_diffs > 0 and result.preserved_diffs == result.delivered_diffs, "native diff reconstruction preserves every baseline field with delay %s" % [delivery])
		check(result.full_gaps.size() > 1 and result.full_gaps.all(func(gap): return gap == 8), "strict full scheduling uses eight-tick gaps with delay %s" % [delivery])
		evidence["modeled_delivery_%s_%s" % delivery] = result

	# One dropped full plus two ticks each way exceeds this bounded refresh budget.
	# The native warning is deliberately retained, not muted or accepted as recovery.
	var loss := _model_delivery(7, 2, 2, true)
	check(loss.dropped_full == 1 and loss.missing_references == 1, "a lost full can still expire a baseline")
	check(loss.lost_unchanged_field, "lost-full negative case exposes incomplete native reconstruction")
	evidence["lost_full_limitation"] = loss
	check(NetworkTime.tick == clock_before, "budget model never advances or rewrites the singleton clock")

	# Off-tree RollbackSynchronizer creates an unparented filter during configuration.
	if actor.rb.visibility_filter and actor.rb.visibility_filter.get_parent() == null:
		actor.rb.visibility_filter.free()
		actor.rb.visibility_filter = null
	properties.clear()
	cache.clear()
	cache = null
	actor.free()
	await _check_guarded_transmitter()
	print(JSON.stringify({"state_refresh_budget": assertions, "failures": failures, "evidence": evidence}))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_trim_boundary() -> void:
	var history := _PropertyHistoryBuffer.new()
	var cutoff := RECEIVER_TICK - NetworkRollback.history_limit
	history.set_snapshot(cutoff - 1, _state_at(cutoff - 1))
	history.set_snapshot(cutoff, _state_at(cutoff))
	history.trim(cutoff)
	check(history.has(cutoff), "real history buffer retains exact cutoff equality")
	check(not history.has(cutoff - 1), "real history buffer removes cutoff minus one")
	evidence["trim_boundary"] = {"current": RECEIVER_TICK, "cutoff": cutoff, "equal_retained": history.has(cutoff), "older_removed": not history.has(cutoff - 1)}

func _check_expired_reference() -> void:
	var channel := _new_channel()
	var apply_tick := BASE_TICK + 16
	channel.sender.set_snapshot(BASE_TICK, _state_at(BASE_TICK))
	channel.sender.set_snapshot(apply_tick, _state_at(apply_tick))
	channel.receiver.set_snapshot(BASE_TICK, _state_at(BASE_TICK))
	var cutoff := RECEIVER_TICK - NetworkRollback.history_limit
	channel.receiver.trim(cutoff)
	check(apply_tick >= cutoff and apply_tick >= NetworkRollback.history_start, "apply tick is valid despite an eighteen-tick-old reference")
	check(not channel.receiver.has(BASE_TICK), "real buffer trims expired reference before native diff arrives")
	var bytes: PackedByteArray = channel.sender_diff.encode(apply_tick, BASE_TICK, properties)
	var patch: _PropertySnapshot = channel.receiver_diff.decode(bytes, properties)
	check(patch.has(":position") and not patch.has(":velocity"), "real wire diff omits unchanged velocity")
	print("EXPECTED_NEGATIVE expired-reference: native missing-reference warning follows; this is not valid recovery")
	var applied: bool = channel.receiver_diff.apply(apply_tick, patch, BASE_TICK, 1)
	var reconstructed: _PropertySnapshot = channel.receiver.get_snapshot(apply_tick)
	check(applied, "vendor currently accepts an admissible diff with missing reference")
	check(reconstructed.has(":position") and not reconstructed.has(":velocity"), "missing baseline loses unchanged field despite successful apply")
	evidence["expired_reference"] = {"reference": BASE_TICK, "apply": apply_tick, "current": RECEIVER_TICK, "age": RECEIVER_TICK - BASE_TICK, "accepted": applied, "unchanged_velocity_missing": not reconstructed.has(":velocity")}

func _new_channel() -> Dictionary:
	var sender := _PropertyHistoryBuffer.new()
	var receiver := _PropertyHistoryBuffer.new()
	var sender_diff := _DiffHistoryEncoder.new(sender, cache)
	var receiver_diff := _DiffHistoryEncoder.new(receiver, cache)
	sender_diff.add_properties(properties)
	receiver_diff.add_properties(properties)
	var sender_full := _SnapshotHistoryEncoder.new(sender, cache)
	var receiver_full := _SnapshotHistoryEncoder.new(receiver, cache)
	sender_full.set_properties(properties)
	receiver_full.set_properties(properties)
	return {"sender": sender, "receiver": receiver, "sender_diff": sender_diff, "receiver_diff": receiver_diff, "sender_full": sender_full, "receiver_full": receiver_full}

func _model_delivery(interval: int, forward_ticks: int, reverse_ticks: int, drop_first_full: bool) -> Dictionary:
	var channel := _new_channel()
	# Start from an already delivered/acknowledged full, excluding startup staggering.
	channel.sender.set_snapshot(BASE_TICK, _state_at(BASE_TICK))
	channel.receiver.set_snapshot(BASE_TICK, _state_at(BASE_TICK))
	var acknowledged_tick := BASE_TICK
	var next_full_tick := BASE_TICK + interval
	var last_full_tick := BASE_TICK
	var pending: Array[Dictionary] = []
	var result := {"interval": interval, "forward_ticks": forward_ticks, "reverse_ticks": reverse_ticks, "delivery_budget_ticks": 2 * forward_ticks + reverse_ticks, "history_limit": NetworkRollback.history_limit, "full_gaps": [], "delivered_diffs": 0, "preserved_diffs": 0, "missing_references": 0, "dropped_full": 0, "lost_unchanged_field": false}
	print("MODELED_DELIVERY interval=%d forward=%d reverse=%d drop_first_full=%s" % [interval, forward_ticks, reverse_ticks, drop_first_full])
	for now in range(BASE_TICK + 1, BASE_TICK + 81):
		channel.sender.set_snapshot(now, _state_at(now))
		# Explicit simulated cutoff; actual singleton time remains untouched.
		channel.sender.trim(now - NetworkRollback.history_limit)
		channel.receiver.trim(now - NetworkRollback.history_limit)
		for event in pending.duplicate():
			if event.due != now:
				continue
			pending.erase(event)
			if event.kind == "ack":
				acknowledged_tick = event.tick
			elif event.kind == "full":
				var full: _PropertySnapshot = channel.receiver_full.decode(event.data, properties)
				check(channel.receiver_full.apply(event.tick, full, 1), "native full snapshot applies in modeled delivery")
				pending.append({"kind": "ack", "due": now + reverse_ticks, "tick": event.tick})
			else:
				var reference_present: bool = channel.receiver.has(event.reference)
				var patch: _PropertySnapshot = channel.receiver_diff.decode(event.data, properties)
				if not reference_present:
					result.missing_references += 1
					print("EXPECTED_NEGATIVE modeled expired baseline: reference=%d apply=%d current=%d drop=%s; native warning follows" % [event.reference, event.tick, now, drop_first_full])
				check(channel.receiver_diff.apply(event.tick, patch, event.reference, 1), "native diff apply returns success in modeled delivery")
				var state: _PropertySnapshot = channel.receiver.get_snapshot(event.tick)
				result.delivered_diffs += 1
				if state.equals(_state_at(event.tick)):
					result.preserved_diffs += 1
				if not reference_present:
					result.lost_unchanged_field = not state.has(":velocity")
					return result

		# Model T.transmit_state's strict comparison and sender-retention fallback.
		# This is not an RPC/transport exercise or a replacement implementation.
		var scheduled_full := interval > 0 and now > next_full_tick
		if scheduled_full:
			result.full_gaps.append(now - last_full_tick)
			last_full_tick = now
			next_full_tick = now + interval
		if scheduled_full or not channel.sender.has(acknowledged_tick):
			if scheduled_full and drop_first_full and result.dropped_full == 0:
				result.dropped_full += 1
				continue
			pending.append({"kind": "full", "due": now + forward_ticks, "tick": now, "data": channel.sender_full.encode(now, properties)})
		else:
			pending.append({"kind": "diff", "due": now + forward_ticks, "tick": now, "reference": acknowledged_tick, "data": channel.sender_diff.encode(now, acknowledged_tick, properties)})
	return result

func _state_at(tick: int) -> _PropertySnapshot:
	return _PropertySnapshot.from_dictionary({":position": Vector3(tick - BASE_TICK, 0, 0), ":velocity": Vector3(5, 0, 0), ":facing": Vector2(0.3, 0.1)})

# Only a full-send loss tap is substituted; selection, encoders, RPC submission,
# receiver application and reliable ACK handling are the real Netfox implementation.
class LossyTransmitter extends _RollbackHistoryTransmitter:
	var drop_full_to := -1
	var full_sends: Array[int] = []
	func _send_full_state(tick: int, peer: int = 0) -> void:
		full_sends.append(peer)
		if peer != drop_full_to:
			super(tick, peer)

class WireBody extends Node3D:
	var velocity := Vector3(5, 0, 0)
	var facing := Vector2(0.3, 0.1)
	var retire_tick := 2147483647

func _check_guarded_transmitter() -> void:
	var process := NetSession.is_processing()
	var physics := NetSession.is_physics_processing()
	NetSession.set_process(false)
	NetSession.set_physics_process(false)
	NetworkTime.stop()
	var socket := PacketPeerUDP.new()
	check(socket.bind(0, "127.0.0.1") == OK, "wire fixture reserves an ephemeral UDP port")
	var port := socket.get_local_port()
	socket.close()
	var previous_peer := multiplayer.multiplayer_peer
	var clock_peer := ENetMultiplayerPeer.new()
	var clock_error := clock_peer.create_server(port, 1, 16)
	check(clock_error == OK, "public clock bootstrap owns an ENet server")
	if clock_error != OK:
		NetSession.set_process(process)
		NetSession.set_physics_process(physics)
		return
	multiplayer.multiplayer_peer = clock_peer
	var bootstrap_started := Time.get_ticks_msec()
	var clock_started: int = await NetworkTime.start()
	var bootstrap_deadline := bootstrap_started + 3000
	while clock_started == OK and NetworkTime.tick < 16 and Time.get_ticks_msec() < bootstrap_deadline:
		await get_tree().process_frame
	var current := NetworkTime.tick
	NetworkTime.stop() # Public stop retains the real clock; no synthetic restoration.
	var bootstrap_ms := Time.get_ticks_msec() - bootstrap_started
	check(clock_started == OK and current >= 16 and NetworkTime.tick == current, "public clock reaches sixteen ticks within three seconds and stop retains it")
	multiplayer.multiplayer_peer = previous_peer
	clock_peer.close()
	if clock_started != OK or current < 16 or NetworkTime.tick != current:
		NetSession.set_process(process)
		NetSession.set_physics_process(physics)
		return
	var apis: Array[SceneMultiplayer] = []
	var branches: Array[Node] = []
	for index in range(3):
		var branch := Node.new()
		branch.name = "Wire%d" % index
		add_child(branch)
		branches.append(branch)
		var api := SceneMultiplayer.new()
		api.root_path = branch.get_path()
		get_tree().set_multiplayer(api, branch.get_path())
		var peer := ENetMultiplayerPeer.new()
		var error := peer.create_server(port, 2, 16) if index == 0 else peer.create_client("127.0.0.1", port, 16)
		check(error == OK, "wire fixture ENet endpoint %d starts" % index)
		api.multiplayer_peer = peer
		apis.append(api)
	var deadline := Time.get_ticks_msec() + 3000
	while apis[0].get_peers().size() != 2 and Time.get_ticks_msec() < deadline:
		_wire_pump(apis, 10)
	check(apis[0].get_peers().size() == 2, "two real SceneMultiplayer peers connect")
	_wire_pump(apis)
	var endpoints: Array[Dictionary] = []
	for index in range(3):
		endpoints.append(_wire_endpoint(branches[index], apis[index].get_unique_id()))
	var host := endpoints[0]
	var a: int = apis[1].get_unique_id()
	var b: int = apis[2].get_unique_id()
	var tx: LossyTransmitter = host.tx
	var sync := CorridorMovementSync.new()
	sync.root = host.body
	sync.visibility_filter.free()
	sync.visibility_filter = host.filter
	sync._history_transmitter = tx
	sync._history_recorder = _RollbackHistoryRecorder.new()
	sync._history_recorder.configure(host.states, host.inputs, host.config, host.input_config, host.cache, host.skipset)
	tx._visibility_filter.update_visibility()
	tx._next_full_state_tick = current + 7 # Isolate the per-peer fallback from periodic fulls.
	for reference in [(current - 9), (current - 8)]:
		host.states.set_snapshot(reference, _state_at(reference))
	endpoints[1].states.set_snapshot((current - 8), _state_at((current - 8)))
	tx._ackd_state = {a: (current - 8), b: (current - 9)}
	_wire_record(sync, (current - 7)) # Replay ages 1/2; current network ages 8/9.
	check(tx._ackd_state.has(a) and not tx._ackd_state.has(b), "age 8 survives and age 9 is pruned using current, not replay time")
	check(tx.full_sends == [b], "real transmitter selects diff for fresh peer and full fallback for stale peer")
	_wire_pump(apis)
	check(endpoints[1].states.get_snapshot((current - 7)).equals(_state_at((current - 7))), "age-8 diff readback preserves unchanged velocity/facing")
	check(endpoints[2].states.get_snapshot((current - 7)).equals(_state_at((current - 7))), "age-9 full readback needs no receiver baseline")
	check(tx._ackd_state.get(b) == (current - 7) and tx._ackd_state.get(a) == (current - 8), "only real full RPC produces a reliable ACK")
	check(host.states.has((current - 9)) and host.states.has((current - 8)) and NetworkRollback.history_limit == 16, "guard does not delete or resize shared history")
	# Lose two full attempts; then deliver a full but hold its ACK by not polling host.
	tx._ackd_state[b] = (current - 9)
	tx.drop_full_to = b
	for replay in [(current - 6), (current - 5)]:
		_wire_record(sync, replay)
	_wire_pump(apis)
	check(not tx._ackd_state.has(b) and tx.full_sends.count(b) == 3, "lost fulls keep peer in vendor full fallback")
	check(not endpoints[2].states.has((current - 6)) and not endpoints[2].states.has((current - 5)), "lost full tap delivers no phantom receiver state")
	tx.drop_full_to = -1
	_wire_record(sync, (current - 4))
	apis[0].multiplayer_peer.host.flush()
	_wire_pump([apis[1], apis[2]])
	check(endpoints[2].states.get_snapshot((current - 4)).equals(_state_at((current - 4))) and not tx._ackd_state.has(b), "delivered full with delayed reliable ACK cannot authorize a diff before arrival")
	_wire_record(sync, (current - 3))
	check(tx.full_sends.count(b) == 5, "full fallback continues while ACK is delayed")
	_wire_pump(apis)
	check(endpoints[2].states.get_snapshot((current - 3)).equals(_state_at((current - 3))), "delivered fallback restores all fields after losses")
	# A genuinely late old reliable ACK may overwrite the map; prune it again.
	endpoints[2].tx._ack_full_state.rpc_id(1, (current - 9))
	_wire_pump(apis)
	check(tx._ackd_state.get(b) == (current - 9), "real late ACK recreates stale reference")
	_wire_record(sync, (current - 2))
	check(not tx._ackd_state.has(b), "late stale ACK is pruned again before super")
	_wire_pump(apis)
	check(tx._ackd_state.get(b) == (current - 2), "fresh full ACK resumes usable baseline")
	var full_count := tx.full_sends.count(b)
	_wire_record(sync, (current - 1))
	_wire_pump(apis)
	check(tx.full_sends.count(b) == full_count, "fresh ACK resumes real diff traffic")
	check(endpoints[2].states.get_snapshot((current - 1)).equals(_state_at((current - 1))), "resumed diff preserves every unchanged field")
	sync.root.retire_tick = (current - 1)
	tx._ackd_state[b] = (current - 9)
	var attempts := tx.full_sends.size()
	sync._on_record_tick(current)
	check(tx._ackd_state.get(b) == (current - 9) and not host.states.has(current) and tx.full_sends.size() == attempts, "retired early return precedes ACK pruning, recording and transmission")
	sync._states = host.states
	sync._inputs = host.inputs
	sync._after_tick(NetworkTime.ticktime, current)
	check(host.states.has((current - 9)) and tx.full_sends.size() == attempts, "retired after-tick keeps admissible history without traffic")
	check(sync.input_properties.is_empty() and sync.root.get_node_or_null("Input") == null, "inputless fixture creates no root input properties")
	evidence["native_guard"] = {"current": current, "bootstrap_ms": bootstrap_ms, "replay": (current - 7), "kept_age": 8, "pruned_age": 9, "lost_full_attempts": 2, "peer_full_attempts": tx.full_sends.count(b), "fresh_diff_readback": endpoints[2].states.get_snapshot((current - 1)).as_dictionary()}
	check(NetworkTime.tick == current, "wire stage leaves the publicly stopped clock unchanged")
	sync.free()
	for index in range(3):
		apis[index].multiplayer_peer.close()
		var branch_path := branches[index].get_path()
		endpoints[index].cache.clear()
		branches[index].free()
		get_tree().set_multiplayer(null, branch_path)
	NetSession.set_process(process)
	NetSession.set_physics_process(physics)

func _wire_endpoint(branch: Node, local_id: int) -> Dictionary:
	var body := WireBody.new()
	body.name = "Body"
	branch.add_child(body)
	var property_cache := PropertyCache.new(body)
	var config := _PropertyConfig.new()
	config.local_peer_id = local_id
	var paths: Array[String] = [":position", ":velocity", ":facing"]
	config.set_properties_from_paths(paths, property_cache)
	var input_config := _PropertyConfig.new()
	input_config.local_peer_id = local_id
	var filter := PeerVisibilityFilter.new()
	body.add_child(filter)
	var tx := LossyTransmitter.new()
	tx.name = "Transmitter"
	body.add_child(tx)
	var states := _PropertyHistoryBuffer.new()
	var inputs := _PropertyHistoryBuffer.new()
	var skipset := _Set.new()
	tx.sync_settings(body, false, 7, 0)
	tx.configure(states, inputs, config, input_config, filter, property_cache, skipset)
	return {"body": body, "tx": tx, "states": states, "inputs": inputs, "config": config, "input_config": input_config, "filter": filter, "cache": property_cache, "skipset": skipset}

func _wire_record(sync: CorridorMovementSync, tick: int) -> void:
	sync.root.position = _state_at(tick).get_value(":position")
	sync._on_record_tick(tick)

func _wire_pump(apis: Array, milliseconds: int = 120) -> void:
	var until := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < until:
		for api in apis:
			api.poll()
		OS.delay_msec(1)

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
