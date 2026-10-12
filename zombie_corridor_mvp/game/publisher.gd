class_name InterestPublisher
extends RefCounted
var peers = {}
var serialization_ms = 0.0
var interest_ms = 0.0
var publication_ms = 0.0
var packets = 0
var cycles = 0
var last_snapshot_tick = 0
func reset_tick_metrics() -> void:
	serialization_ms=0.0; interest_ms=0.0; publication_ms=0.0
func encode(rows: Array) -> PackedByteArray:
	var start=Time.get_ticks_usec()
	var bytes=MobCodec.encode(rows)
	serialization_ms+=(Time.get_ticks_usec()-start)/1000.0
	return bytes
func add_peer(peer: int) -> void: peers[peer] = {"visible":{},"visits":{},"acked":{},"sent":{},"bytes":0}
func remove_peer(peer: int) -> void: peers.erase(peer)
func row_for(row: Dictionary, visit: int) -> Dictionary:
	return {"id":row.id,"generation":row.generation,"revision":row.revision,"interest_epoch":visit,"position":row.position,"yaw":row.yaw,"hp":row.hp,"state":row.state,"tick":row.tick}
func refresh(players: Dictionary, mobs: MathematicalMobs) -> void:
	var start=Time.get_ticks_usec()
	for peer in peers:
		if not players.has(peer) or not players[peer].ready: continue
		var state = peers[peer]
		var pose: Vector3 = players[peer].pose
		var candidates = {}
		var cell = mobs.chunk(pose)
		for c in range(cell-9,cell+10):
			for id in mobs.chunks.get(c,{}): candidates[id] = true
		for id in state.visible.keys():
			var row = mobs.records[id]
			if row.state == MathematicalMobs.State.DEAD or row.position.distance_squared_to(pose)>80.0*80.0:
				NetSession.send_rpc("mob_leave",peer,[NetSession.epoch,id,state.visible[id],row.state==MathematicalMobs.State.DEAD])
				state.visible.erase(id)
				state.acked.erase(id)
				state.sent.erase(id)
		for id in candidates:
			if state.visible.has(id): continue
			var row = mobs.records[id]
			if row.position.distance_squared_to(pose)>65.0*65.0: continue
			var visit = state.visits.get(id,0)+1
			state.visits[id] = visit
			state.visible[id] = visit
			_enter(peer,id)
	interest_ms+=(Time.get_ticks_usec()-start)/1000.0
func _enter(peer: int, id: int) -> void:
	var state = peers[peer]
	var bytes = encode([row_for(NetSession.mobs.records[id],state.visible[id])])
	NetSession.send_rpc("mob_enter",peer,[NetSession.epoch,bytes])
	state.sent[id] = Time.get_ticks_msec()/1000.0
func ack(peer: int, id: int, visit: int) -> void:
	if peers.has(peer) and peers[peer].visible.get(id,-1)==visit: peers[peer].acked[id] = visit
func snapshots(tick: int) -> void:
	var start = Time.get_ticks_usec()
	last_snapshot_tick = tick
	cycles += 1
	for peer in peers:
		var state = peers[peer]
		var rows = []
		var now = Time.get_ticks_msec()/1000.0
		var budget = 3200 # <=32 kB/s mob application payload per peer at 10 Hz.
		for id in state.visible:
			if not state.acked.has(id):
				if now-state.sent.get(id,0)>1.0: _enter(peer,id)
				continue
			rows.append(row_for(NetSession.mobs.records[id],state.visible[id]))
			if rows.size()==MobCodec.MAX_RECORDS:
				budget -= _send(peer,rows)
				rows.clear()
				if budget<842: break
		if not rows.is_empty(): _send(peer,rows)
	publication_ms += (Time.get_ticks_usec()-start)/1000.0
func _send(peer: int, rows: Array) -> int:
	var bytes = encode(rows)
	NetSession.send_rpc("mob_snapshot",peer,[NetSession.epoch,bytes])
	packets += 1
	return bytes.size()+12
func final_state(id: int) -> void:
	for peer in peers:
		var state = peers[peer]
		var row = NetSession.mobs.records[id]
		if row.state==MathematicalMobs.State.DEAD:
			state.visits.erase(id)
			state.sent.erase(id)
		if not state.visible.has(id): continue
		if row.state==MathematicalMobs.State.DEAD:
			NetSession.send_rpc("mob_leave",peer,[NetSession.epoch,id,state.visible[id],true])
			state.visible.erase(id)
			state.acked.erase(id)
		else:
			NetSession.send_rpc("mob_final",peer,[NetSession.epoch,encode([row_for(row,state.visible[id])])])
func relevant() -> int:
	var result = 0
	for state in peers.values(): result += state.visible.size()
	return result
