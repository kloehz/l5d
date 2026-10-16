extends Node
signal status_changed
signal shot_confirmed(result: Dictionary)
signal shot_submitted(origin: Vector3, endpoint: Vector3)
const PROTOCOL = "corridor/1;godot4.7;netfox1.35.3;map-scene;cfg1"
const PLAYER_ACTOR_SCENE_PATH := "res://scenes/player_actor.tscn"
var args = {}
var weapon_range = 35.0
var weapon_rate = 6.0
var weapon_damage = 25
var is_server = false
var is_bot = false
var epoch = 0
var status = "Main menu"
var is_ready = false
var world_root: Node3D
var players_root: Node3D
var actors = {}
var players = {}
var gameplay = {}
var store = MobClientStore.new()
var mobs: MathematicalMobs
var combat: CommittedCombat
var publisher: InterestPublisher
var control_move = Vector2.ZERO
var control_look = Vector2.ZERO
var control_fire = false
var shot_id = 0
var next_fire = 0.0
var own_life = 0
var last_committed = -1
var pending_ticks = []
var loop_start = 0
var rollback_start = 0
var rollback_us = 0
var motion_us = 0
var motion_new = 0
var motion_replays = 0
var app_tx = 0
var app_rx = 0
var tx_by_peer = {}
var rx_by_peer = {}
var process_frames = 0
var physics_frames = 0
var polls = 0
var new_ticks = 0
var committed_ticks = 0
var movement_new_sample = 0
var movement_replays_sample = 0
var rollback_unique_replays = {}
var last_metrics = {}
var last_tick_ms = 0.0
var started_usec = 0
var sample_usec = 0
var connection_usec = 0
var last_status_send = 0.0
var next_sample = 1.0
var log_file: FileAccess
var report_file: FileAccess
var run_id = ""
var scenario = "play"
var local_server_pid = 0
var local_second_pid = 0
var local_readiness_path = ""
var local_launch_generation = 0
var bot_connected_seconds = 0.0
var bot_start_pose = Vector3.ZERO
var bot_distance = 0.0
var bot_hits = 0
var bot_kills = 0
var bot_deaths = 0
var bot_respawns = 0
var bot_updates = 0
var bot_report_clock = 0.0
var receipt_cache = {}
var retired = []
var challenge = {}
var rtt_samples = []
var ping_clock = 0.0
var ping_pending = {}
var ping_sequence = 0
var captured_frame = false
var connection_generation = 0
var reconnect_action_done = false
var last_process_delta = 0.0
var transport_trace = []
const INPUT_BUDGET = preload("res://game/input_publication_budget.gd")
var input_publication = INPUT_BUDGET.new()

func _ready() -> void:
	var settings=JSON.parse_string(FileAccess.get_file_as_string("res://config/default-config.json"))
	if not settings is Dictionary:
		push_error("Gameplay configuration missing or invalid")
		get_tree().quit(2)
		return
	weapon_range=clampf(float(settings.get("weapon_range_m",35)),1,65)
	weapon_rate=clampf(float(settings.get("weapon_shots_per_second",6)),1,20)
	weapon_damage=clampi(int(settings.get("weapon_damage",25)),1,1000)
	var tokens = OS.get_cmdline_user_args()
	var index = 0
	while index<tokens.size():
		var key = tokens[index].trim_prefix("--")
		if index+1<tokens.size() and not tokens[index+1].begins_with("--"):
			args[key] = tokens[index+1]
			index += 2
		else:
			args[key] = true
			index += 1
	is_server = args.has("server") or OS.has_feature("dedicated_server")
	is_bot = args.has("bot")
	if is_bot: is_server = false
	scenario = str(args.get("scenario","play"))
	Engine.max_fps = 60
	get_tree().multiplayer_poll = false
	_configure_multiplayer_api()
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): _error("Connection failed"))
	multiplayer.server_disconnected.connect(func(): _error("Server disconnected"))
	NetworkTime.after_client_sync.connect(_client_synced)
	NetworkTime.before_tick_loop.connect(_loop_begin)
	NetworkTime.after_tick.connect(_new_tick)
	NetworkTime.after_tick_loop.connect(_loop_commit)
	NetworkRollback.before_loop.connect(func(): rollback_start=Time.get_ticks_usec())
	NetworkRollback.after_loop.connect(func(): rollback_us=Time.get_ticks_usec()-rollback_start)
	started_usec = Time.get_ticks_usec()
	sample_usec = started_usec
	run_id = str(args.get("run-id",str(started_usec)))
	if args.has("metrics"):
		log_file = FileAccess.open(str(args.metrics),FileAccess.WRITE)
		_write({"kind":"metadata","run_id":run_id,"scenario":scenario,"engine":Engine.get_version_info().string,"netfox":"1.35.3","server_relay":multiplayer.server_relay,"cpu_scope":"100%=one core; harness ps delta CPU-time; RSS MiB","network_scope":"var_to_bytes encoded custom RPC arguments; excludes Netfox channel0 and Godot/ENet wire overhead","tick_boundary":"network loop including movement rollback amortized over new ticks + individual committed gameplay; per-commit subsystem durations reset; serialization nested in interest/publication/combat, movement nested in rollback; do not add; slide/replay counts amortized; physics_ray_queries zero because all hits are analytic","headless_max_fps":60,"physics_hz":30,"network_hz":30,"seed":99})
	if args.has("report"): report_file = FileAccess.open(str(args.report),FileAccess.WRITE)
	get_tree().auto_accept_quit = false

func launch() -> void:
	if not _validate_geometry_before_network():
		return
	if is_server:
		start_server(int(args.get("port",27015)))
	elif is_bot or args.has("client"):
		connect_to(str(args.get("connect","127.0.0.1")),int(args.get("port",27015)))
func local_peer() -> int: return multiplayer.get_unique_id()
func _set_status(value: String) -> void:
	status = value
	status_changed.emit()
	print("STATUS ",value)
func _error(value: String) -> void:
	_set_status(value)
	is_ready = false
	disconnect_session(false)
	if is_bot: get_tree().quit(2)
func start_server(port: int) -> void:
	if not _validate_geometry_before_network():
		return
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(port,4,16)
	if result != OK:
		_set_status("UDP bind failed on port %s: %s" % [port,error_string(result)])
		get_tree().quit(2)
		return
	# Godot 4.7 create_server misroutes max_channels into incoming bandwidth.
	# Restore the intended unlimited budget and 16 + 2 ENet system channels.
	# This does not disable ENet's RTT-based packet throttle.
	peer.host.bandwidth_limit(0,0)
	peer.host.channel_limit(18)
	multiplayer.multiplayer_peer = peer
	_configure_multiplayer_api()
	epoch = int(Time.get_unix_time_from_system()) ^ int(randi() & 0x7fffffff)
	mobs = MathematicalMobs.new()
	combat = CommittedCombat.new()
	publisher = InterestPublisher.new()
	mobs.stable_profile = scenario not in ["play","smoke","combat","validation"]
	if scenario in ["active20","combat","validation","smoke"]: mobs.spawn_group(20,-15,0)
	elif scenario=="active50": mobs.spawn_group(50,-15,0)
	elif scenario=="dormant20": mobs.spawn_group(20,-140,0)
	elif scenario=="dormant100": mobs.spawn_group(100,-130,0)
	elif scenario=="split":
		mobs.spawn_group(10,-20,0)
		mobs.spawn_group(10,-145,0)
	elif scenario=="play":
		mobs.spawn_wave(6,-16,0)
		mobs.spawn_group(12,-130,0)
	NetworkTime.start()
	_set_status("Server listening on UDP %s" % port)
	print("SERVER_READY ",port)
	if args.has("ready-file"):
		var ready_file=FileAccess.open(str(args["ready-file"]),FileAccess.WRITE)
		if ready_file: ready_file.store_string(JSON.stringify({"port":port,"epoch":epoch,"pid":OS.get_process_id()})); ready_file.close()
func connect_to(host: String, port: int) -> void:
	if not _validate_geometry_before_network():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer: disconnect_session(false)
	connection_generation+=1
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(host,port,16)
	if result != OK: _error("Invalid endpoint: "+error_string(result)); return
	multiplayer.multiplayer_peer = peer
	_configure_multiplayer_api()
	connection_usec = Time.get_ticks_usec()
	input_publication.begin_session(connection_generation, peer, NetworkTimeSynchronizer)
	_set_status("Connecting to %s:%s" % [host,port])
func _connected() -> void:
	# Refresh RTT baseline frequently enough for the 60 Hz poll/bootstrap cadence.
	# Positive acceleration/deceleration preserve congestion-based unreliable drops.
	multiplayer.multiplayer_peer.get_peer(1).throttle_configure(100,2,2)
	_set_status("Negotiating protocol and map")
	send_rpc("hello",1,["invalid-test-protocol" if args.has("reject-protocol-test") else protocol_signature()])
@rpc("any_peer","call_remote","reliable",8)
func hello(version: String) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[version])
	if not is_server: return
	var peer = multiplayer.get_remote_sender_id()
	if version != protocol_signature():
		send_rpc("denied",peer,["Protocol/map/build incompatible"])
		return
	if players.has(peer): return
	var split = scenario=="split" and players.size()==1
	var pose = Vector3(-1.5+players.size(),0,-145 if split else -7.0)
	players[peer] = {"peer":peer,"life":1,"pose":pose,"hp":100,"kills":0,"ready":false,"next_shot":0.0,"high":0,"floor":0,"cache":{},"queued":{},"pending":0,"respawn_at":0.0,"spawn_tick":NetworkTime.tick+2,"known_actors":{},"world_initialized":false,"invulnerable_until":0.0}
	publisher.add_peer(peer)
	_create_actor(players[peer])
	send_rpc("welcome",peer,[epoch,_roster()])
	for other in players:
		if other!=peer: send_rpc("spawn_player",other,[epoch,players[peer]])
	_create_actor(players[peer])
@rpc("authority","call_remote","reliable",8)
func denied(reason: String) -> void: _error(reason)
@rpc("authority","call_remote","reliable",8)
func welcome(session: int, roster: Array) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,roster])
	epoch = session
	for row in roster:
		_create_actor(row)
		gameplay[row.peer] = {"hp":row.hp,"life":row.life,"kills":row.kills,"pose":row.pose}
	_set_status("Synchronizing network clock")
	var generation=connection_generation
	var sync_result=await NetworkTime.start()
	if not _input_session_current(generation): return
	if sync_result!=OK: _error("Network clock could not start"); return
	_set_status("Waiting for usable input clock budget")
	# Netfox timestamp/ping exchange and after_client_sync do not depend on
	# world_ready. Keep combat inactive until the same outbound budget fits.
	if not await _await_input_publication(generation): return
	send_rpc("world_ready",1,[epoch])
	is_ready = true
	own_life = gameplay[local_peer()].life
	bot_start_pose = own_actor().position
	_set_status("Connected • dedicated server")
	print("CLIENT_READY ",local_peer())

func _await_input_publication(generation: int) -> bool:
	while _input_session_current(generation):
		if Time.get_ticks_usec()-connection_usec >= 20000000:
			_error("Input clock budget timed out")
			return false
		var local_actor = actors.get("%s_%s" % [local_peer(),gameplay.get(local_peer(),{}).get("life",0)])
		if local_actor != null and local_actor.rb._history_transmitter._is_initialized:
			var tail: int = local_actor.rb._history_transmitter._input_encoder.redundancy - 1
			if input_publication_status(NetworkTime.tick + NetworkRollback.input_delay, tail).allowed:
				return true
		await get_tree().process_frame
	return false
func _input_session_current(generation: int) -> bool:
	return generation == connection_generation and multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer

func input_publication_status(wire_tick: int, tail: int) -> Dictionary:
	var fresh: bool = input_publication.fresh_measurement(connection_generation, multiplayer.multiplayer_peer, NetworkTimeSynchronizer, Time.get_ticks_usec())
	return INPUT_BUDGET.evaluate(NetworkTime.tick, wire_tick, tail, NetworkRollback.history_limit,
		NetworkTime.ticktime, NetworkTimeSynchronizer.get_time() - NetworkTime.time,
		NetworkTimeSynchronizer.remote_offset, NetworkTimeSynchronizer.rtt,
		NetworkTimeSynchronizer.rtt_jitter, fresh)

@rpc("any_peer","call_remote","reliable",8)
func world_ready(session: int) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session])
	var peer = multiplayer.get_remote_sender_id()
	if not is_server or session!=epoch or not players.has(peer): return
	players[peer].world_initialized = true
	players[peer].ready = NetworkTime.is_client_synced(peer)
	for actor in actors.values():
		players[peer].known_actors[actor.name] = true
		actor.rb.visibility_filter.update_visibility()
	mobs.activate(players,NetworkTime.time)
	publisher.refresh(players,mobs)
@rpc("authority","call_remote","reliable",8)
func spawn_player(session: int, row: Dictionary) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,row])
	if session!=epoch: return
	_create_actor(row)
	send_rpc("actor_ready",1,[epoch,"p_%s_%s" % [row.peer,row.life]])
	gameplay[row.peer] = {"hp":row.hp,"life":row.life,"kills":row.kills,"pose":row.pose}
	if row.peer == local_peer():
		own_life = row.life
		shot_id = 0
		bot_respawns += 1
@rpc("authority","call_remote","reliable",8)
func retire_player(session: int, peer: int, life: int, tick: int) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,peer,life,tick])
	if session!=epoch: return
	_retire(peer,life,tick)
func _create_actor(row: Dictionary) -> void:
	var key = "%s_%s" % [row.peer,row.life]
	if actors.has(key): return
	var actor_scene := load(PLAYER_ACTOR_SCENE_PATH) as PackedScene
	var actor := actor_scene.instantiate() as CorridorPlayer if actor_scene else null
	if actor == null:
		push_error("Player actor scene root must be a CorridorPlayer")
		return
	actor.configure(row.peer,row.life,row.pose,row.spawn_tick)
	actors[key] = actor
	players_root.add_child(actor)
func own_actor() -> CorridorPlayer:
	return actors.get("%s_%s" % [local_peer(),own_life])
func _retire(peer: int, life: int, tick: int) -> void:
	var key = "%s_%s" % [peer,life]
	if actors.has(key):
		actors[key].retire_tick = tick
		retired.append([key,tick+150])
func _peer_left(peer: int) -> void:
	if is_server and players.has(peer):
		var life = players[peer].life
		_retire(peer,life,NetworkTime.tick)
		for other in players:
			if other!=peer and players[other].ready: send_rpc("retire_player",other,[epoch,peer,life,NetworkTime.tick])
		players.erase(peer)
		publisher.remove_peer(peer)
		mobs.activate(players,NetworkTime.time)
func player_in_interest(owner: int, peer: int) -> bool:
	if not is_server: return true
	if not players.has(owner) or not players.has(peer): return false
	var key = "p_%s_%s" % [owner,players[owner].life]
	return players[peer].ready and players[peer].known_actors.has(key) and (owner==peer or players[owner].pose.distance_squared_to(players[peer].pose)<80.0*80.0)
func _loop_begin() -> void:
	loop_start = Time.get_ticks_usec()
	pending_ticks.clear()
	motion_us = 0
	motion_new = 0
	motion_replays = 0
	rollback_unique_replays.clear()
func _new_tick(_delta: float, tick: int) -> void:
	pending_ticks.append(tick)
	new_ticks += 1
func _loop_commit() -> void:
	_cleanup_retired()
	if not is_server: return
	var network_us = Time.get_ticks_usec()-loop_start
	for tick in pending_ticks:
		if tick<=last_committed: continue
		var start = Time.get_ticks_usec()
		mobs.reset_tick_metrics()
		publisher.reset_tick_metrics()
		CorridorGeometry.wall_queries=0; CorridorGeometry.capsule_queries=0
		var now = (tick+1)/30.0
		for peer in players:
			var p = players[peer]
			var actor = actors.get("%s_%s" % [peer,p.life])
			if actor and tick>=actor.spawn_tick and tick<actor.retire_tick:
				p.pose = actor.pose_at(tick)
				actor.accepted_position = p.pose
		if tick%15==0:
			mobs.activate(players,now)
			publisher.refresh(players,mobs)
			for actor in actors.values(): actor.rb.visibility_filter.update_visibility()
		if tick%6==0: mobs.ai(players)
		if tick%2==0: mobs.move(players,now,tick,_damage)
		var combat_start=Time.get_ticks_usec()
		combat.process(players,mobs,now)
		var combat_ms=(Time.get_ticks_usec()-combat_start)/1000.0
		_respawns(now,tick)
		if tick%3==0: publisher.snapshots(tick)
		var needs_wave = (scenario=="play" and mobs.wave_alive()==0) or (scenario in ["combat","smoke"] and mobs.counts().alive < (12 if scenario=="combat" else 1))
		if needs_wave and not players.is_empty():
			if mobs.next_wave == 0.0: mobs.next_wave = now+4
			elif now>=mobs.next_wave:
				mobs.wave += 1
				if scenario=="play":
					var base = clampf(players.values()[0].pose.z-12.0,-165,-15)
					mobs.spawn_wave(mini(6+mobs.wave*2,20),base,now)
				else: mobs.spawn_group(20 if scenario=="combat" else mini(6+mobs.wave*2,20),-18,now)
				mobs.next_wave = 0.0
		last_committed = tick
		committed_ticks += 1
		last_tick_ms = (Time.get_ticks_usec()-start+network_us/maxi(1,pending_ticks.size()))/1000.0
		if log_file:
			_write({"kind":"tick","run_id":run_id,"scenario":scenario,"elapsed_s":elapsed(),"tick_ms":last_tick_ms,"rollback_ms":rollback_us/1000.0/maxi(1,pending_ticks.size()),"rollback_ticks":float(rollback_unique_replays.size())/maxi(1,pending_ticks.size()),"rollback_entity_steps":float(motion_replays)/maxi(1,pending_ticks.size()),"movement_new_steps":float(motion_new)/maxi(1,pending_ticks.size()),"physics_slide_calls":float(motion_new+motion_replays)/maxi(1,pending_ticks.size()),"physics_ray_queries":0,"analytic_wall_queries":CorridorGeometry.wall_queries,"analytic_capsule_queries":CorridorGeometry.capsule_queries,"movement_ms":motion_us/1000.0/maxi(1,pending_ticks.size()),"mob_movement_ms":mobs.movement_ms,"mob_ai_ms":mobs.ai_ms,"activation_ms":mobs.activation_ms,"serialization_ms":publisher.serialization_ms,"interest_ms":publisher.interest_ms,"publication_ms":publisher.publication_ms,"combat_ms":combat_ms,"new_ticks":1,"network_tick":tick,"physics_factor":NetworkTime.physics_factor})
func _cleanup_retired() -> void:
	for retired_actor in retired.duplicate():
		if NetworkTime.tick>retired_actor[1]:
			if actors.has(retired_actor[0]): actors[retired_actor[0]].queue_free(); actors.erase(retired_actor[0])
			for p in players.values(): p.known_actors.erase("p_"+retired_actor[0])
			retired.erase(retired_actor)
func _damage(peer: int, amount: int) -> void:
	if not players.has(peer) or players[peer].hp<=0 or NetworkTime.time<players[peer].invulnerable_until: return
	var p = players[peer]
	p.hp = maxi(0,p.hp-amount)
	if p.hp==0:
		p.respawn_at = NetworkTime.time+3.0
		_retire(peer,p.life,NetworkTime.tick)
		for other in players:
			if players[other].ready: send_rpc("retire_player",other,[epoch,peer,p.life,NetworkTime.tick])
	_send_gameplay()
func _respawns(now: float, tick: int) -> void:
	for peer in players:
		var p = players[peer]
		if p.hp==0 and now>=p.respawn_at:
			p.life += 1
			p.hp = 100
			p.invulnerable_until = now+2.0
			p.pose = Vector3(2,0,-3)
			p.spawn_tick = tick+3
			p.cache.clear()
			p.queued.clear()
			p.high = 0; p.floor = 0; p.pending = 0
			_create_actor(p)
			for other in players:
				if players[other].ready: send_rpc("spawn_player",other,[epoch,p])
			mobs.activate(players,now)
			publisher.refresh(players,mobs)
func _send_gameplay() -> void:
	for peer in players:
		if players[peer].ready: send_rpc("game_state",peer,[epoch,_roster(),mobs.wave,mobs.kills])
@rpc("authority","call_remote","reliable",8)
func game_state(session: int, roster: Array, wave: int, kills: int) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,roster,wave,kills])
	if session!=epoch: return
	last_metrics.wave = wave
	last_metrics.kills = kills
	var live_peers = {}
	for p in roster:
		live_peers[p.peer] = true
		if p.peer==local_peer() and gameplay.has(p.peer) and gameplay[p.peer].hp>0 and p.hp==0: bot_deaths += 1
		gameplay[p.peer] = {"hp":p.hp,"life":p.life,"kills":p.kills,"pose":p.pose}
	for peer in gameplay.keys():
		if not live_peers.has(peer): gameplay.erase(peer)
@rpc("any_peer","call_remote","reliable",10)
func shoot(session: int, life: int, id: int, direction: Vector3, view_time: float) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,life,id,direction,view_time])
	if not is_server: return
	pass # Receive accounting is performed at the RPC boundary.
	combat.enqueue(multiplayer.get_remote_sender_id(),session,life,id,direction,view_time,players,epoch)
@rpc("authority","call_remote","reliable",10)
func shot_result(session: int, life: int, id: int, result: Dictionary) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,life,id,result])
	if session!=epoch or life!=own_life or receipt_cache.has("%s_%s" % [life,id]): return
	receipt_cache["%s_%s" % [life,id]] = true
	if receipt_cache.size()>128: receipt_cache.erase(receipt_cache.keys()[0])
	if result.hit: bot_hits += 1
	if result.kill: bot_kills += 1
	shot_confirmed.emit(result)
@rpc("authority","call_remote","reliable",8)
func mob_enter(session: int, bytes: PackedByteArray) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,bytes])
	if session!=epoch: return
	for row in MobCodec.decode(bytes):
		store.enter(row)
		send_rpc("mob_ack",1,[epoch,row.id,row.interest_epoch])
@rpc("any_peer","call_remote","reliable",8)
func mob_ack(session: int, id: int, visit: int) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,id,visit])
	if is_server and session==epoch: publisher.ack(multiplayer.get_remote_sender_id(),id,visit)
@rpc("authority","call_remote","unreliable",9)
func mob_snapshot(session: int, bytes: PackedByteArray) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,bytes])
	if session!=epoch: return
	for row in MobCodec.decode(bytes):
		if store.update(row): bot_updates += 1
@rpc("authority","call_remote","reliable",8)
func mob_final(session: int, bytes: PackedByteArray) -> void: mob_snapshot(session,bytes)
@rpc("authority","call_remote","reliable",8)
func mob_leave(session: int, id: int, visit: int, killed: bool) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,id,visit,killed])
	if session==epoch: store.leave(id,visit,killed)
@rpc("any_peer","call_remote","unreliable",11)
func ping_request(sequence: int) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[sequence])
	if is_server: send_rpc("ping_reply",multiplayer.get_remote_sender_id(),[sequence])
@rpc("authority","call_remote","unreliable",11)
func ping_reply(sequence: int) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[sequence])
	if ping_pending.has(sequence):
		rtt_samples.append((Time.get_ticks_usec()-ping_pending[sequence])/1000.0)
		if rtt_samples.size()>120: rtt_samples.pop_front()
		ping_pending.erase(sequence)
@rpc("authority","call_remote","unreliable",11)
func server_metrics(session: int, metrics: Dictionary) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,metrics])
	if session==epoch:
		last_metrics.merge(metrics,true)
		challenge = metrics
func _physics_process(_delta: float) -> void: physics_frames += 1
func _process(delta: float) -> void:
	last_process_delta=delta
	process_frames += 1
	if args.has("capture-frame") and not captured_frame and elapsed()>=float(args.get("capture-delay",3)):
		captured_frame = true
		_capture_frame.call_deferred()
	if multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.poll()
		polls += 1
		if args.has("transport-trace"): _trace_transport_poll()
	if args.has("local-action-test") and not is_server and not is_bot and local_server_pid==0 and elapsed()>.5: start_local()
	if args.has("reconnect-action-test") and is_ready and not reconnect_action_done and elapsed()>3:
		reconnect_action_done=true
		print("RECONNECT_ACTION")
		connect_to(str(args.get("connect","127.0.0.1")),int(args.get("port",27015)))
	if args.has("duration") and elapsed()>=float(args.duration): shutdown(); return
	if not is_server and connection_usec>0 and not is_ready and Time.get_ticks_usec()-connection_usec>20000000: _error("Handshake/clock timed out")
	if is_server:
		if elapsed()>=next_sample:
			_sample()
			next_sample += 1.0
	else:
		if is_ready:
			bot_connected_seconds += delta
			if is_bot: _bot(delta)
			ping_clock += delta
			if ping_clock>=.5:
				ping_clock = 0
				ping_sequence += 1
				ping_pending[ping_sequence] = Time.get_ticks_usec()
				send_rpc("ping_request",1,[ping_sequence])
				for key in ping_pending.keys():
					if ping_sequence-key>20: ping_pending.erase(key)
			var now = Time.get_ticks_msec()/1000.0
			if control_fire and now>=next_fire and gameplay.get(local_peer(),{}).get("hp",0)>0:
				next_fire = now+1.0/weapon_rate+.0133333333
				shot_id += 1
				var dir = local_shot_direction()
				send_rpc("shoot",1,[epoch,own_life,shot_id,dir,shot_view_time_seconds()])
				var actor = own_actor()
				if actor: shot_submitted.emit(actor.position+Vector3(0,1.55,0),actor.position+Vector3(0,1.55,0)+dir*weapon_range)
				if args.get("behavior","")=="malicious":
					if shot_id>1: send_rpc("shoot",1,[epoch,own_life,shot_id-1,dir,NetworkTime.time-.1])
					send_rpc("shoot",1,[epoch,own_life,shot_id+1000,dir,NetworkTime.time])
					send_rpc("shoot",1,[epoch,own_life,shot_id+1,dir,NetworkTime.time])
					send_rpc("shoot",1,[epoch,own_life,shot_id,dir,NetworkTime.time-.1])
					send_rpc("shoot",1,[epoch,own_life-1,shot_id+1,dir,NetworkTime.time])
					send_rpc("shoot",1,[epoch,own_life,shot_id+2,Vector3(NAN,0,0),NetworkTime.time])
					send_rpc("shoot",1,[epoch+1,own_life,shot_id+3,dir,NetworkTime.time])
					send_rpc("shoot",1,[epoch,own_life,shot_id+4,dir,NetworkTime.time+100])
		if report_file and elapsed()-bot_report_clock>=1.0: _bot_report(); bot_report_clock=elapsed()
func shot_view_time_seconds() -> float:
	var presentation := _mob_presentation()
	if presentation and presentation.has_method("get_display_time_seconds"):
		return float(presentation.get_display_time_seconds())
	return maxf(0.0, NetworkTime.time - .1)

func displayed_mob_foot(id: Variant, fallback: Vector3) -> Vector3:
	var presentation := _mob_presentation()
	if presentation and presentation.has_method("get_rendered_mob_foot"):
		var rendered: Variant = presentation.get_rendered_mob_foot(id)
		if rendered is Vector3 and CorridorGeometry.finite_vector(rendered):
			return rendered
	return fallback

func _mob_presentation() -> Node:
	var candidates := get_tree().get_nodes_in_group("mob_presentation")
	return candidates[0] if not candidates.is_empty() else null

func local_shot_direction() -> Vector3:
	var actor = own_actor()
	if actor and actor.has_method("camera_aim_direction"):
		var camera_direction: Vector3 = actor.camera_aim_direction(weapon_range)
		if CorridorGeometry.finite_vector(camera_direction) and camera_direction.length() > 0.001:
			return camera_direction.normalized()
	return Vector3(0,0,-1).rotated(Vector3.RIGHT,control_look.y).rotated(Vector3.UP,-control_look.x).normalized()

func _bot(_delta: float) -> void:
	var actor = own_actor()
	if not actor: return
	var behavior = str(args.get("behavior","move"))
	control_move = Vector2(0,-1) if bot_connected_seconds<2.0 and scenario != "split" else Vector2.ZERO
	bot_distance = maxf(bot_distance,actor.position.distance_to(bot_start_pose))
	if behavior in ["combat","malicious"]:
		var nearest = INF
		var aim = Vector3.ZERO
		for row in store.records.values():
			var diff: Vector3 = row.position+Vector3(0,1.25,0)-(actor.position+Vector3(0,1.55,0))
			if diff.length()<nearest:
				nearest = diff.length()
				aim = diff.normalized()
		if nearest<35:
			control_look = Vector2(atan2(aim.x,-aim.z),asin(clampf(aim.y,-1,1)))
			control_fire = true
		else: control_fire = false
func elapsed() -> float: return (Time.get_ticks_usec()-started_usec)/1000000.0
func _sample() -> void:
	var counts = mobs.counts()
	var dt = (Time.get_ticks_usec()-sample_usec)/1000000.0
	var transport = multiplayer.multiplayer_peer.host
	var enet_tx = transport.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)/dt
	var enet_rx = transport.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)/dt
	last_metrics = {"kind":"sample","run_id":run_id,"scenario":scenario,"elapsed_s":elapsed(),"players":players.size(),"active_mobs":counts.active,"dormant_mobs":counts.dormant,"relevant_mobs":publisher.relevant(),"tx_bytes_s":app_tx/dt,"rx_bytes_s":app_rx/dt,"enet_tx_bytes_s":enet_tx,"enet_rx_bytes_s":enet_rx,"peer_app_tx_bytes":tx_by_peer.duplicate(),"peer_app_rx_bytes":rx_by_peer.duplicate(),"dormant_movement_steps":mobs.dormant_movement_steps,"dormant_ai_steps":mobs.dormant_ai_steps,"dormant_navigation_steps":mobs.dormant_navigation_steps,"movement_steps":mobs.movement_steps,"ai_steps":mobs.ai_steps,"peer_transport":_transport_stats(),"main_loop_hz":process_frames/dt,"physics_hz":physics_frames/dt,"network_hz":new_ticks/dt,"poll_hz":polls/dt,"committed_ticks":committed_ticks,"snapshot_hz":publisher.cycles/dt,"snapshot_packets_s":publisher.packets/dt,"movement_new_steps_s":movement_new_sample/dt,"movement_replays_s":movement_replays_sample/dt,"rollback_replays":motion_replays,"rollback_ms":rollback_us/1000.0,"server_tick_ms":last_tick_ms,"wave":mobs.wave,"kills":mobs.kills,"combat_accepted":combat.accepted_shots,"combat_hits":combat.hits,"combat_cached_retries":combat.cached_retries,"combat_rejected":combat.rejected,"player_states":_roster(),"mob_states":_mob_states()}
	app_tx=0; app_rx=0; tx_by_peer.clear(); rx_by_peer.clear()
	for peer in players:
		if players[peer].ready:
			var public_metrics = last_metrics.duplicate()
			public_metrics.erase("mob_states")
			public_metrics.erase("player_states")
			public_metrics.erase("peer_transport") # Server-only input age/readiness diagnostics.
			send_rpc("server_metrics",peer,[epoch,public_metrics])
	_send_gameplay()
	_write(last_metrics)
	if log_file: log_file.flush()
	sample_usec = Time.get_ticks_usec()
	process_frames=0; physics_frames=0; polls=0; new_ticks=0; publisher.packets=0; publisher.cycles=0; movement_new_sample=0; movement_replays_sample=0
func _mob_states() -> Array:
	var result = []
	for row in mobs.records.values(): result.append({"id":row.id,"hp":row.hp,"position":[row.position.x,row.position.z],"state":row.state})
	return result
func _write(row: Dictionary) -> void:
	if log_file: log_file.store_line(JSON.stringify(row))
func _bot_report() -> void:
	var pose = own_actor().position if own_actor() else Vector3.ZERO
	var data = {"elapsed_s":elapsed(),"ready":is_ready,"peer":local_peer(),"life":own_life,"pose":[pose.x,pose.z],"accepted_pose":[gameplay.get(local_peer(),{}).get("pose",Vector3.ZERO).x,gameplay.get(local_peer(),{}).get("pose",Vector3.ZERO).z],"distance":bot_distance,"hits":bot_hits,"kills":bot_kills,"deaths":bot_deaths,"respawns":bot_respawns,"relevant":store.records.size(),"updates":bot_updates,"rejected_snapshots":store.rejected,"rtt_ms":rtt_samples,"server":challenge,"state_owners":[],"control_input_broadcast":false,"connected_delta_seconds":bot_connected_seconds,"last_process_delta":last_process_delta,"client_tick":NetworkTime.tick,"client_process_frames":process_frames,"client_polls":polls,"enet_peer":_transport_peer_stats(1)}
	for actor in actors.values(): data.state_owners.append([actor.get_multiplayer_authority(),actor.input.get_multiplayer_authority(),actor.owner_peer_id,actor.rb.enable_input_broadcast])
	report_file.store_line(JSON.stringify(data))
	report_file.flush()
func disconnect_session(reset_status: bool=true) -> void:
	connection_generation+=1
	input_publication.end_session()
	_stop_local_children()
	is_ready = false
	control_move=Vector2.ZERO; control_fire=false
	for actor in actors.values(): actor.queue_free()
	actors.clear(); retired.clear()
	NetworkTime.stop()
	if multiplayer.has_multiplayer_peer(): multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear(); gameplay.clear(); store.clear(); receipt_cache.clear()
	own_life=0; epoch=0; connection_usec=0; shot_id=0; next_fire=0
	last_metrics.clear(); challenge.clear(); ping_pending.clear(); rtt_samples.clear(); ping_clock=0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if reset_status: _set_status("Disconnected • ready to reconnect")
func start_local() -> void:
	disconnect_session(false)
	var launch_generation=local_launch_generation
	var port = 27015
	var probe = PacketPeerUDP.new()
	while probe.bind(port,"127.0.0.1")!=OK and port<27115: port += 1
	probe.close()
	var common = PackedStringArray()
	if OS.has_feature("editor"): common.append_array(["--path",ProjectSettings.globalize_path("res://")])
	var server_args = common.duplicate()
	var readiness_path = ProjectSettings.globalize_path("user://local-ready-%s-%s.json" % [OS.get_process_id(),randi()])
	local_readiness_path=readiness_path
	server_args.append_array(["--headless","--","--server","--port",str(port),"--ready-file",readiness_path])
	local_server_pid = OS.create_process(OS.get_executable_path(),server_args)
	if local_server_pid<=0: _error("Unable to launch dedicated server"); return
	_set_status("Starting separate local server")
	var deadline = Time.get_ticks_msec()+10000
	while not FileAccess.file_exists(readiness_path):
		if Time.get_ticks_msec()>deadline or not OS.is_process_running(local_server_pid):
			_error("Local dedicated server failed readiness")
			return
		await get_tree().create_timer(.05).timeout
		if launch_generation!=local_launch_generation: return
	DirAccess.remove_absolute(readiness_path)
	local_readiness_path=""
	connect_to("127.0.0.1",port)
	var second_args = common.duplicate()
	second_args.append_array(["--","--client","--connect","127.0.0.1","--port",str(port)])
	local_second_pid = OS.create_process(OS.get_executable_path(),second_args)
	print("LOCAL_CHILDREN ",local_server_pid," ",local_second_pid," ",port)
func shutdown() -> void:
	_flush_transport_trace()
	if report_file: _bot_report()
	if log_file: log_file.flush()
	_stop_local_children()
	get_tree().quit()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: shutdown()

func _roster() -> Array:
	var rows = []
	for p in players.values(): rows.append({"peer":p.peer,"life":p.life,"pose":p.pose,"hp":p.hp,"kills":p.kills,"ready":p.ready,"spawn_tick":p.spawn_tick})
	return rows

@rpc("any_peer","call_remote","reliable",8)
func actor_ready(session: int, key: String) -> void:
	if is_server: receive_payload(multiplayer.get_remote_sender_id(),[session,key])
	var peer = multiplayer.get_remote_sender_id()
	if is_server and session==epoch and players.has(peer) and key.length()<60:
		players[peer].known_actors[key]=true
		for actor in actors.values(): actor.rb.visibility_filter.update_visibility()

func send_rpc(method: String, peer: int, values: Array) -> void:
	if not _can_send_to_peer(peer):
		return
	if is_server:
		var size = var_to_bytes(values).size()
		app_tx += size
		tx_by_peer[peer] = tx_by_peer.get(peer,0)+size
	callv("rpc_id",[peer,method]+values)

func _configure_multiplayer_api() -> void:
	multiplayer.server_relay = false

func _can_send_to_peer(peer: int) -> bool:
	if peer <= 0 or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return false
	if not multiplayer.get_peers().has(peer):
		return false
	if not multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return true
	var packet_peer: ENetPacketPeer = multiplayer.multiplayer_peer.get_peer(peer)
	return packet_peer != null and packet_peer.is_active() and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED

func receive_payload(peer: int, values: Array) -> void:
	var size = var_to_bytes(values).size()
	app_rx += size
	rx_by_peer[peer] = rx_by_peer.get(peer,0)+size

func _capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var error = image.save_png(str(args["capture-frame"]))
	print("FRAME_CAPTURE ",error," ",args["capture-frame"]," ",image.get_size())

func _stop_local_children() -> void:
	local_launch_generation+=1
	if not local_readiness_path.is_empty(): DirAccess.remove_absolute(local_readiness_path); local_readiness_path=""
	if local_server_pid>0 and OS.is_process_running(local_server_pid): OS.kill(local_server_pid)
	if local_second_pid>0 and OS.is_process_running(local_second_pid): OS.kill(local_second_pid)
	local_server_pid=0; local_second_pid=0

func protocol_signature() -> String:
	if not _validate_geometry_before_network():
		return PROTOCOL+";map=invalid;config="+FileAccess.get_sha256("res://config/default-config.json")
	return PROTOCOL+";map="+CorridorGeometry.map_hash()+";config="+FileAccess.get_sha256("res://config/default-config.json")

func _validate_geometry_before_network() -> bool:
	if CorridorGeometry.ensure_loaded():
		return true
	var reason := "Invalid authored map geometry: %s" % ", ".join(CorridorGeometry.validation_errors())
	_set_status(reason)
	push_error(reason)
	if is_server or is_bot:
		get_tree().quit(2)
	return false

func _client_synced(peer: int) -> void:
	if not is_server or not players.has(peer) or not players[peer].world_initialized: return
	players[peer].ready=true
	mobs.activate(players,NetworkTime.time)
	publisher.refresh(players,mobs)
	for actor in actors.values(): actor.rb.visibility_filter.update_visibility()

func _transport_peer_stats(peer: int) -> Dictionary:
	if not multiplayer.multiplayer_peer is ENetMultiplayerPeer: return {}
	var packet_peer=multiplayer.multiplayer_peer.get_peer(peer)
	if not packet_peer or not packet_peer.is_active(): return {}
	return {"rtt_ms":packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"rtt_variance_ms":packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE),"last_rtt_ms":packet_peer.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME),"last_rtt_variance_ms":packet_peer.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME_VARIANCE),"throttle":packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE),"throttle_limit":packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT),"throttle_counter":packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_COUNTER),"throttle_epoch":packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_EPOCH),"throttle_interval_ms":packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_INTERVAL),"throttle_acceleration":packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_ACCELERATION),"throttle_deceleration":packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION)}
func _trace_transport_poll() -> void:
	if transport_trace.size()>=8192: return # Bounded diagnostic buffer; no per-poll I/O.
	var peers=players.keys() if is_server else [1]
	for peer in peers:
		var row=_transport_peer_stats(peer)
		row.merge({"elapsed_s":elapsed(),"peer":peer,"network_tick":NetworkTime.tick,"process_delta":last_process_delta,"connected_delta_seconds":bot_connected_seconds,"ready":players[peer].ready if is_server else is_ready,"accepted_pose_tick":last_committed})
		var actor=actors.get("%s_%s" % [peer,players[peer].life]) if is_server else own_actor()
		if actor:
			row["latest_submitted_input_tick"]=NetworkRollback.get_latest_input_tick(actor)
			row["last_simulated_input_tick"]=actor.last_simulated_input_tick
			row["accepted_pose"]=[actor.accepted_position.x,actor.accepted_position.z]
		transport_trace.append(row)
func _flush_transport_trace() -> void:
	if not args.has("transport-trace"): return
	var file=FileAccess.open(str(args["transport-trace"]),FileAccess.WRITE)
	if file:
		for row in transport_trace: file.store_line(JSON.stringify(row))
		file.close()
	transport_trace.clear()
func _transport_stats() -> Dictionary:
	var result={}
	for peer in players:
		var data=_transport_peer_stats(peer)
		var actor=actors.get("%s_%s" % [peer,players[peer].life])
		data["ready"]=players[peer].ready
		data["clock_synced"]=NetworkTime.is_client_synced(peer)
		data["network_tick"]=NetworkTime.tick
		if actor:
			data["latest_input_tick"]=NetworkRollback.get_latest_input_tick(actor)
			data["input_age_ticks"]=NetworkTime.tick-data.latest_input_tick
		result[peer]=data
	return result
