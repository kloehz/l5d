class_name CommittedCombat
extends RefCounted
var queue = []
var rejected = {}
var accepted_shots = 0
var hits = 0
var kills = 0
var cached_retries = 0
func reject(reason: String) -> void: rejected[reason] = rejected.get(reason,0)+1
func enqueue(peer: int, epoch: int, life: int, shot: int, direction: Vector3, view_time: float, players: Dictionary, current_epoch: int) -> void:
	if not players.has(peer) or not players[peer].ready: reject("owner"); return
	var player = players[peer]
	if epoch != current_epoch or life != player.life: reject("life_session"); return
	if player.cache.has(shot):
		cached_retries += 1
		NetSession.send_rpc("shot_result",peer,[epoch,life,shot,player.cache[shot]])
		return
	if shot <= player.floor or shot > player.high+64: reject("id_window"); return
	if not CorridorGeometry.finite_vector(direction) or direction.length()<.9 or direction.length()>1.1 or not is_finite(view_time): reject("finite"); return
	if view_time > NetworkTime.time+.1 or view_time < NetworkTime.time-.75: reject("time"); return
	if queue.size()>=64 or player.pending>=8: reject("queue"); return
	if player.queued.has(shot): reject("queued_duplicate"); return
	player.queued[shot] = true
	player.pending += 1
	queue.append({"peer":peer,"life":life,"shot":shot,"dir":direction.normalized(),"view":view_time,"received":Time.get_ticks_msec()/1000.0})
func process(players: Dictionary, mobs: MathematicalMobs, now: float) -> void:
	for command in queue:
		if not players.has(command.peer): continue
		var p = players[command.peer]
		p.queued.erase(command.shot)
		p.pending = maxi(0,p.pending-1)
		if p.life != command.life or p.hp<=0: reject("dead_life"); continue
		var wall_now = Time.get_ticks_msec()/1000.0
		if wall_now-command.received > .35: reject("stale"); continue
		if wall_now < p.next_shot: reject("cadence"); continue
		if command.view > now+.1 or command.view < now-.75: reject("time"); continue
		p.next_shot = wall_now+1.0/NetSession.weapon_rate
		p.high = maxi(p.high,command.shot)
		p.floor = maxi(p.floor,p.high-128)
		var origin: Vector3 = p.pose+Vector3(0,1.55,0)
		var distance = CorridorGeometry.wall_distance(origin,command.dir,NetSession.weapon_range)
		var best = 0
		var view = clampf(command.view,now-.25,now)
		# Bounded room <=100 mobs: complete historical broadphase includes movers' old cells.
		for row in mobs.records.values():
			if row.state == MathematicalMobs.State.DEAD or row.born > view: continue
			var pose = mobs.historic_pose(row,view)
			var t = CorridorGeometry.ray_capsule(origin,command.dir,pose,distance)
			if t<distance:
				distance = t
				best = row.id
		var result = {"hit":best>0,"kill":false,"mob":best,"end":origin+command.dir*distance,"hp":0}
		accepted_shots += 1
		if best>0:
			result.kill = mobs.hit(best,NetSession.weapon_damage)
			result.hp = mobs.records[best].hp
			hits += 1
			if result.kill:
				kills += 1
				p.kills += 1
			NetSession.publisher.final_state(best)
		p.cache[command.shot] = result
		for key in p.cache.keys():
			if key<=p.floor: p.cache.erase(key)
		NetSession.send_rpc("shot_result",command.peer,[NetSession.epoch,p.life,command.shot,result])
	queue.clear()
