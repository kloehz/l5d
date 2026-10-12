extends Node
var failures = []
var assertions = 0
func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition: failures.append(message)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var G = preload("res://game/geometry.gd")
	check(is_equal_approx(G.ray_capsule(Vector3(0,.9,5),Vector3(0,0,-1),Vector3.ZERO,10),4.6),"horizontal capsule distance")
	check(is_equal_approx(G.ray_capsule(Vector3(.4,.9,5),Vector3(0,0,-1),Vector3.ZERO,10),5),"tangent")
	check(G.ray_capsule(Vector3(0,.9,0),Vector3.UP,Vector3.ZERO,10)==0,"origin inside cylinder")
	check(is_equal_approx(G.ray_capsule(Vector3(0,3,0),Vector3.DOWN,Vector3.ZERO,10),1.2),"parallel ray hits top sphere")
	check(is_inf(G.ray_capsule(Vector3(2,3,0),Vector3.DOWN,Vector3.ZERO,10)),"parallel miss")
	check(is_inf(G.ray_capsule(Vector3(0,.9,5),Vector3(0,0,-1),Vector3.ZERO,4)),"range clipping")
	check(is_equal_approx(G.wall_distance(Vector3(0,1.5,-60),Vector3(0,0,-1),35),9),"wall blocks before zombie behind baffle")
	check(not G.finite_vector(Vector3(NAN,0,0)),"NaN")
	check(not G.finite_vector(Vector3(INF,0,0)),"infinity")
	var row={"id":7,"generation":7,"revision":4,"interest_epoch":1,"position":Vector3(-2.12,0,-72.34),"hp":75,"state":1,"yaw":-1.2,"tick":50}
	var bytes=MobCodec.encode([row])
	var decoded=MobCodec.decode(bytes)
	check(decoded.size()==1 and decoded[0].position.distance_to(row.position)<.011,"signed centimeter roundtrip")
	check(MobCodec.decode(bytes.slice(0,bytes.size()-1)).is_empty(),"truncated packet rejected")
	var corrupt=bytes.duplicate(); corrupt.encode_u16(0,65535)
	check(MobCodec.decode(corrupt).is_empty(),"bounded count")
	var store=MobClientStore.new()
	check(store.enter(row),"baseline enter")
	var newer=row.duplicate(); newer.revision=6
	check(store.update(newer),"new absolute revision")
	check(not store.update(row),"out of order rejected")
	check(store.records.size()==1,"lost/partial packet never deletes")
	store.leave(7,1,false)
	check(not store.enter(row),"late ENTER after LEAVE")
	newer.interest_epoch=2
	check(store.enter(newer),"reentry rebuild")
	check(not store.update(row),"old interest visit snapshot")
	store.leave(7,2,true)
	newer.interest_epoch=3
	check(not store.enter(newer),"dead tombstone cannot resurrect")
	var mobs=MathematicalMobs.new()
	var id=mobs.add(Vector3(0,0,-100),0)
	mobs.records[id].hp=75
	var players={2:{"peer":2,"hp":100,"ready":true,"pose":Vector3(0,0,-5)},3:{"peer":3,"hp":100,"ready":true,"pose":Vector3(0,0,-110)}}
	mobs.activate(players,1)
	check(mobs.active.has(id),"union of all living players")
	players[3].pose=Vector3(0,0,-5)
	mobs.activate(players,2);mobs.activate(players,6)
	check(not mobs.active.has(id) and mobs.records[id].hp==75,"sleep keeps HP")
	var old=mobs.records[id].position
	for tick in range(60): mobs.move(players,7+tick/15.0,tick,func(_peer,_damage): failures.append("dormant attacked")); mobs.ai(players)
	check(mobs.records[id].position==old and mobs.movement_steps==0 and mobs.ai_steps==0 and mobs.dormant_navigation_steps==0,"dormant zero movement/AI/navigation")
	players[3].pose=Vector3(0,0,-110);mobs.activate(players,20)
	check(mobs.records[id].position==old and mobs.records[id].hp==75,"wake preserves, no catch-up")
	check(not mobs.hit(id,25) and not mobs.hit(id,25) and mobs.hit(id,25),"damage kills at correct HP")
	check(not mobs.hit(id,25) and mobs.kills==1,"death commits once")
	# An old live dormant identity must survive a bounded dead-cache eviction.
	var ancient=row.duplicate(); ancient.id=1; ancient.generation=1; ancient.interest_epoch=1
	var bounded=MobClientStore.new()
	check(bounded.enter(ancient),"ancient living baseline")
	bounded.leave(1,1,false)
	for dead_id in range(2,1100): bounded.leave(dead_id,1,true)
	ancient.interest_epoch=2
	check(bounded.dead.size()==1024 and bounded.enter(ancient),"dead cache bounded without rejecting older living IDs")
	check(not bounded.update(row),"evicted/unknown partial state cannot recreate a baseline")
	var routing=MathematicalMobs.new()
	var route_id=routing.add(Vector3(-2,0,-67.5),0)
	var route_players={2:{"peer":2,"hp":100,"ready":true,"pose":Vector3(-2,0,-73)}}
	routing.activate(route_players,0); routing.ai(route_players)
	var crossed_wall=false
	for tick in range(240):
		routing.move(route_players,tick/15.0,tick,func(_peer,_damage): pass)
		var point=routing.records[route_id].position
		if point.x<1.4 and point.z>-70.4 and point.z<-68.6: crossed_wall=true
	check(not crossed_wall and routing.records[route_id].position.z<-70.4,"mathematical mob routes around expanded wall, never through it")
	var covered_mobs=MathematicalMobs.new()
	var covered_id=covered_mobs.add(Vector3(0,0,-68.9),0)
	var behind={2:{"peer":2,"hp":100,"ready":true,"pose":Vector3(0,0,-70.1)}}
	covered_mobs.activate(behind,0); covered_mobs.ai(behind)
	var melee=[0]
	covered_mobs.move(behind,2,30,func(_peer,_damage): melee[0]+=1)
	check(melee[0]==0 and covered_mobs.records[covered_id].position.x>0,"map cover blocks mathematical melee and starts routing")
	var waves=MathematicalMobs.new()
	waves.spawn_wave(6,-16,0); waves.spawn_group(12,-130,0)
	for wave_id in waves.wave_ids: waves.hit(wave_id,100)
	check(waves.wave_alive()==0 and waves.counts().alive==12,"distant dormant pack never blocks the playable wave cycle")
	var signature=NetSession.protocol_signature().split(";")
	check(signature[-1].trim_prefix("config=").length()==64 and signature[-2].trim_prefix("map=").length()==64,"actual map/config SHA256 handshake")
	NetSession.players={2:{"hp":100,"ready":false,"invulnerable_until":NetworkTime.time+2,"peer":2}}
	NetSession._damage(2,10)
	check(NetSession.players[2].hp==100,"authoritative respawn grace prevents immediate melee damage")
	NetSession.players[2].invulnerable_until=0
	NetSession._damage(2,10)
	check(NetSession.players[2].hp==90,"server damage resumes after grace")
	NetSession.players.clear()
	var publication=InterestPublisher.new(); publication.add_peer(2)
	publication.peers[2].visits[1]=2; publication.peers[2].sent[1]=1
	NetSession.mobs=MathematicalMobs.new()
	var gone=NetSession.mobs.add(Vector3.ZERO,0); NetSession.mobs.hit(gone,100)
	publication.final_state(gone)
	check(publication.peers[2].visits.is_empty() and publication.peers[2].sent.is_empty(),"dead publication bookkeeping removed even after AOI leave")
	NetSession.mobs=null
	NetSession.players={2:{"known_actors":{"p_2_1":true,"p_2_2":true}}}
	NetSession.actors={"2_1":Node.new()}; NetSession.retired=[["2_1",-1]]
	NetSession._cleanup_retired()
	check(not NetSession.players[2].known_actors.has("p_2_1") and NetSession.players[2].known_actors.has("p_2_2") and NetSession.actors.is_empty(),"retired actor ACK bookkeeping bounded without removing current life")
	NetSession.players.clear()
	# Production gate exercised independently with malformed commands, not a mirrored validator.
	NetSession.epoch=123
	var combat=CommittedCombat.new()
	var p={"ready":true,"life":2,"cache":{},"floor":0,"high":0,"pending":0,"queued":{}}
	combat.enqueue(9,123,2,1,Vector3.FORWARD,0,{2:p},123)
	combat.enqueue(2,123,1,1,Vector3.FORWARD,0,{2:p},123)
	combat.enqueue(2,124,2,1,Vector3.FORWARD,0,{2:p},123)
	combat.enqueue(2,123,2,1,Vector3(NAN,0,0),0,{2:p},123)
	combat.enqueue(2,123,2,1000,Vector3.FORWARD,0,{2:p},123)
	combat.enqueue(2,123,2,1,Vector3.FORWARD,0,{2:p},123)
	combat.enqueue(2,123,2,1,Vector3.FORWARD,0,{2:p},123)
	check(combat.queue.size()==1 and combat.rejected.get("queued_duplicate",0)==1,"owner/life/session/finite/window/dedup")
	var root=Node3D.new()
	root.set_multiplayer_authority(1)
	var owner_input=CorridorInput.new()
	owner_input.name="Input"
	owner_input.set_multiplayer_authority(2)
	root.add_child(owner_input)
	add_child(root)
	var illegal=_PropertySnapshot.from_dictionary({":position":Vector3(100,0,0),"Input:movement":Vector2(10,0)})
	illegal.sanitize(2,PropertyCache.new(root))
	check(not illegal.has(":position") and illegal.has("Input:movement"),"Netfox rejects client position state, only owned input admitted")
	illegal.apply(PropertyCache.new(root))
	check(root.position==Vector3.ZERO and owner_input.movement.length()<=1.0,"malicious velocity normalized, position unchanged")
	root.queue_free()
	# Metric resets cannot replay the previous scheduler call on an empty tick.
	mobs.reset_tick_metrics()
	check(mobs.movement_ms==0 and mobs.ai_ms==0 and mobs.activation_ms==0,"mob per-commit timings reset on unscheduled tick")
	publication.encode([row]); publication.reset_tick_metrics()
	check(publication.serialization_ms==0 and publication.interest_ms==0 and publication.publication_ms==0,"publisher per-commit timing reset")
	CorridorGeometry.wall_queries=0; CorridorGeometry.capsule_queries=0
	G.wall_distance(Vector3.ZERO,Vector3.FORWARD,35); G.ray_capsule(Vector3(0,1,5),Vector3.FORWARD,Vector3.ZERO,35)
	check(CorridorGeometry.wall_queries==1 and CorridorGeometry.capsule_queries==1,"actual analytic query call counters")
	print(JSON.stringify({"invariants":assertions,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
