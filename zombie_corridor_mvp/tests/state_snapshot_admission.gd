extends Node

const WAIT_MS := 3000

var failures: Array[String] = []
var assertions := 0
var evidence := {}

class WireBody extends Node3D:
	var velocity := Vector3(4.0, 0.0, 0.0)
	var facing: Variant = Vector2(0.6, 0.8)
	var retire_tick := 2147483647

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var process := NetSession.is_processing()
	var physics := NetSession.is_physics_processing()
	NetSession.set_process(false)
	NetSession.set_physics_process(false)
	NetworkTime.stop()
	var socket := PacketPeerUDP.new()
	check(socket.bind(0, "127.0.0.1") == OK, "clock fixture reserves an ephemeral UDP port")
	var port := socket.get_local_port()
	socket.close()
	var previous_peer := multiplayer.multiplayer_peer
	var clock_peer := ENetMultiplayerPeer.new()
	var clock_error := clock_peer.create_server(port, 1, 16)
	check(clock_error == OK, "public clock bootstrap starts an ENet server")
	if clock_error != OK:
		_finish(process, physics, previous_peer, [], [], [])
		return
	multiplayer.multiplayer_peer = clock_peer
	var clock_started := await NetworkTime.start()
	var clock_deadline := Time.get_ticks_msec() + WAIT_MS
	while clock_started == OK and NetworkTime.tick < 16 and Time.get_ticks_msec() < clock_deadline:
		await get_tree().process_frame
	var current := NetworkTime.tick
	NetworkTime.stop()
	check(clock_started == OK and current >= 16, "public clock reaches a valid retained-history tick")
	multiplayer.multiplayer_peer = previous_peer
	clock_peer.close()
	if clock_started != OK or current < 16:
		_finish(process, physics, previous_peer, [], [], [])
		return

	var branches: Array[Node] = []
	var apis: Array[SceneMultiplayer] = []
	for index in range(3):
		var branch := Node.new()
		branch.name = "SnapshotWire%d" % index
		add_child(branch)
		branches.append(branch)
		var api := SceneMultiplayer.new()
		api.root_path = branch.get_path()
		get_tree().set_multiplayer(api, branch.get_path())
		var peer := ENetMultiplayerPeer.new()
		var error := peer.create_server(port, 2, 16) if index == 0 else peer.create_client("127.0.0.1", port, 16)
		check(error == OK, "actual ENet endpoint %d starts" % index)
		api.multiplayer_peer = peer
		apis.append(api)
	var connect_deadline := Time.get_ticks_msec() + WAIT_MS
	while apis[0].get_peers().size() != 2 and Time.get_ticks_msec() < connect_deadline:
		_pump(apis, 10)
	check(apis[0].get_peers().size() == 2, "two actual SceneMultiplayer peers connect")
	if apis[0].get_peers().size() != 2:
		_finish(process, physics, previous_peer, apis, [], branches)
		return
	_pump(apis)

	var host := _endpoint(branches[0], apis[0].get_unique_id())
	var client := _endpoint(branches[1], apis[1].get_unique_id())
	var client_b := _endpoint(branches[2], apis[2].get_unique_id())
	for endpoint in [host, client, client_b]:
		endpoint.filter.update_visibility(endpoint.body.get_multiplayer().get_peers())
	var fixture := _make_sync(host)
	var sync: CorridorMovementSync = fixture.sync
	var recorder: _RollbackHistoryRecorder = fixture.recorder
	var states: _PropertyHistoryBuffer = fixture.states
	var hole_tick := current + 1
	var later_tick := current + 2
	var next_tick := current + 3
	states.set_snapshot(current, _state_at(current, Vector3(1, 2, 3), Vector2(0.6, 0.8)))
	states.set_snapshot(later_tick, _state_at(later_tick, Vector3(7, 8, 9), Vector2(-0.6, 0.8)))
	recorder.set_latest_state_tick(later_tick)
	check(not recorder._should_record_tick(hole_tick), "unchanged historical hole is skipped when public latest-state tick is later")
	recorder.record_state(hole_tick)
	check(not states.has(hole_tick), "actual recorder leaves exact hole absent despite valid adjacent history")
	evidence["recorder"] = {"hole": hole_tick, "latest": later_tick, "prior": states.has(current), "later": states.has(later_tick), "hole_recorded": states.has(hole_tick)}

	# Modeled sparse-history/public-recorder ordering; not captured production causality.
	print("MODELED_SPARSE_HISTORY hole=%d prior=%d later=%d latest=%d" % [hole_tick, current, later_tick, later_tick])
	sync._on_record_tick(hole_tick)
	_pump(apis)
	var client_hole: _PropertyHistoryBuffer = client.states
	var hole_snapshot := client_hole.get_snapshot(hole_tick)
	var encoded_hole: Array = host.tx._full_state_encoder.encode(hole_tick, host.tx._get_owned_state_props())
	check(encoded_hole.size() == 4, "exact-hole full encoder retains its three-property schema and version")
	check(encoded_hole[0] == null and encoded_hole[1] == null and encoded_hole[2] == null, "exact-hole full encoder resolves absent recorded values as null")
	check(not client_hole.has(hole_tick), "app admission prevents absent exact state from reaching ENet or receiver history")
	check(client.body.facing == Vector2(0.6, 0.8), "skipped hole leaves the receiver's valid nondefault facing untouched")
	evidence["wire_hole"] = {"stored": client_hole.has(hole_tick), "encoded_hole": encoded_hole, "live_facing": client.body.facing}

	# A complete, newly recorded exact snapshot resumes the same native publication path.
	host.body.position = Vector3(11, 12, 13)
	host.body.velocity = Vector3(2, 3, 4)
	host.body.facing = Vector2(0.8, 0.6)
	sync._on_record_tick(next_tick)
	_pump(apis)
	var resumed: _PropertySnapshot = client.states.get_snapshot(next_tick)
	check(resumed.has(":position") and resumed.get_value(":position") == host.body.position, "next complete exact snapshot resumes position publication")
	check(resumed.has(":velocity") and resumed.get_value(":velocity") == host.body.velocity, "next complete exact snapshot resumes velocity publication")
	check(resumed.has(":facing") and resumed.get_value(":facing") == host.body.facing, "next complete exact snapshot resumes nondefault facing publication")
	check(host.body.get_multiplayer_authority() == apis[0].get_unique_id(), "source remains the actual server authority")
	check(client.body.facing == Vector2(0.6, 0.8), "decoded snapshot does not mutate the live receiver until apply")
	resumed.apply(client.cache)
	check(client.body.position == host.body.position and client.body.velocity == host.body.velocity, "actual stored snapshot applies valid state to receiver properties")
	check(client.body.facing == Vector2(0.8, 0.6), "actual apply retains the valid nondefault facing vector")
	check(client_b.states.get_snapshot(next_tick).equals(resumed), "publication reaches the second live client without fabricated authority")
	evidence["resume"] = {"tick": next_tick, "state": resumed.as_dictionary(), "applied_facing": client.body.facing}

	if sync.visibility_filter and sync.visibility_filter.get_parent() == null:
		sync.visibility_filter.free()
	fixture.sync.free()
	_finish(process, physics, previous_peer, apis, [host, client, client_b], branches)
	print(JSON.stringify({"state_snapshot_admission": assertions, "failures": failures, "evidence": evidence}))
	get_tree().quit(0 if failures.is_empty() else 1)

func _make_sync(endpoint: Dictionary) -> Dictionary:
	var sync := CorridorMovementSync.new()
	sync.root = endpoint.body
	sync._history_transmitter = endpoint.tx
	sync._history_recorder = _RollbackHistoryRecorder.new()
	sync._history_recorder.configure(endpoint.states, endpoint.inputs, endpoint.config, endpoint.input_config, endpoint.cache, endpoint.skipset)
	sync._states = endpoint.states
	sync._inputs = endpoint.inputs
	return {"sync": sync, "recorder": sync._history_recorder, "states": endpoint.states}

func _endpoint(branch: Node, local_id: int) -> Dictionary:
	var body := WireBody.new()
	body.name = "Body"
	body.set_multiplayer_authority(1)
	branch.add_child(body)
	var cache := PropertyCache.new(body)
	var config := _PropertyConfig.new()
	config.local_peer_id = local_id
	var paths: Array[String] = [":position", ":velocity", ":facing"]
	config.set_properties_from_paths(paths, cache)
	var input_config := _PropertyConfig.new()
	input_config.local_peer_id = local_id
	var native_filter := PeerVisibilityFilter.new()
	body.add_child(native_filter)
	native_filter.update_mode = PeerVisibilityFilter.UpdateMode.NEVER
	var tx := _RollbackHistoryTransmitter.new()
	tx.name = "Transmitter"
	body.add_child(tx)
	var states := _PropertyHistoryBuffer.new()
	var inputs := _PropertyHistoryBuffer.new()
	var skipset := _Set.new()
	tx.sync_settings(body, false, 7, 0)
	tx.configure(states, inputs, config, input_config, native_filter, cache, skipset)
	return {"body": body, "tx": tx, "states": states, "inputs": inputs, "config": config, "input_config": input_config, "filter": native_filter, "cache": cache, "skipset": skipset}

func _state_at(tick: int, position: Vector3, facing: Vector2) -> _PropertySnapshot:
	return _PropertySnapshot.from_dictionary({":position": position, ":velocity": Vector3(4, 0, 0), ":facing": facing})

func _pump(apis: Array, milliseconds: int = 120) -> void:
	var until := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < until:
		for api in apis:
			api.poll()
		OS.delay_msec(1)

func _finish(process: bool, physics: bool, previous_peer: MultiplayerPeer, apis: Array, endpoints: Array, branches: Array) -> void:
	for endpoint in endpoints:
		endpoint.cache.clear()
	var branch_paths: Array[NodePath] = []
	for branch in branches:
		branch_paths.append(branch.get_path())
	for api in apis:
		if api.multiplayer_peer:
			api.multiplayer_peer.close()
			api.multiplayer_peer = null
	for branch in branches:
		for child in branch.get_children():
			_free_tree(child)
	for endpoint in endpoints:
		check(not is_instance_valid(endpoint.filter), "endpoint visibility filter is freed with its owned nodes")
	for index in range(branch_paths.size()):
		get_tree().set_multiplayer(null, branch_paths[index])
	for branch in branches:
		branch.free()
	apis.clear()
	NetSession.set_process(process)
	NetSession.set_physics_process(physics)
	multiplayer.multiplayer_peer = previous_peer

func _free_tree(node: Node) -> void:
	var children := node.get_children()
	children.reverse()
	for child in children:
		_free_tree(child)
	node.free()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
