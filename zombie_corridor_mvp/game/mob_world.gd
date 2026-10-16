class_name MathematicalMobs
extends RefCounted

const MOB_TIMING := preload("res://game/mob_timing.gd")
enum State {DORMANT, ACTIVE, ATTACKING, DEAD}
var records = {}
var active = {}
var chunks = {}
var next_id = 1
var wave = 1
var wave_ids = []
var next_wave = 0.0
var kills = 0
var movement_steps = 0
var ai_steps = 0
var navigation_steps = 0
var dormant_movement_steps = 0
var dormant_ai_steps = 0
var dormant_navigation_steps = 0
var movement_ms = 0.0
var ai_ms = 0.0
var activation_ms = 0.0
var stable_profile = false
var dead_at = {}
func reset_tick_metrics() -> void:
	movement_ms=0.0; ai_ms=0.0; activation_ms=0.0
func chunk(pos: Vector3) -> int: return int(floor(pos.z/10.0))
func add(pos: Vector3, now: float) -> int:
	var id = next_id
	next_id += 1
	var row = {"id":id,"generation":id,"revision":1,"position":pos,"yaw":0.0,"hp":100,"state":State.DORMANT,"target":0,"far_since":-1.0,"next_attack":0.0,"born":now,"history":[[now,pos]],"tick":0,"chunk":chunk(pos)}
	records[id] = row
	if not chunks.has(row.chunk): chunks[row.chunk] = {}
	chunks[row.chunk][id] = true
	return id
func spawn_group(count: int, center: float, now: float) -> void:
	for i in range(count): add(Vector3(-3.2+(i%5)*1.6,0,center-float(i/5)*2.0),now)
func living(players: Dictionary) -> Array:
	var result = []
	for peer in players:
		if players[peer].hp > 0 and players[peer].ready: result.append(players[peer])
	return result
func activate(players: Dictionary, now: float) -> void:
	var start = Time.get_ticks_usec()
	for dead_id in dead_at.keys():
		if now-dead_at[dead_id]>5.0:
			records.erase(dead_id)
			dead_at.erase(dead_id)
	var live = living(players)
	var candidates = {}
	for player in live:
		var c = chunk(player.pose)
		for cell in range(c-5,c+6):
			for id in chunks.get(cell,{}): candidates[id] = true
	for id in candidates:
		var row = records[id]
		if row.state != State.DORMANT: continue
		for player in live:
			if row.position.distance_squared_to(player.pose) <= 45.0*45.0:
				row.state = State.ACTIVE
				row.revision += 1
				row.far_since = -1.0
				active[id] = true
				break
	for id in active.keys():
		var row = records[id]
		var near = false
		for player in live:
			if row.position.distance_squared_to(player.pose) <= 60.0*60.0: near = true
		if near: row.far_since = -1.0
		elif row.far_since < 0.0: row.far_since = now
		elif now-row.far_since >= 3.0:
			row.state = State.DORMANT
			row.target = 0
			row.revision += 1
			active.erase(id)
	activation_ms += (Time.get_ticks_usec()-start)/1000.0
func ai(players: Dictionary) -> void:
	var start = Time.get_ticks_usec()
	var live = living(players)
	for id in active:
		var row = records[id]
		ai_steps += 1
		if row.state==State.DORMANT: dormant_ai_steps += 1
		var best = INF
		row.target = 0
		for player in live:
			var dist = row.position.distance_squared_to(player.pose)
			if dist < best:
				best = dist
				row.target = player.peer
	ai_ms += (Time.get_ticks_usec()-start)/1000.0
func move(players: Dictionary, now: float, tick: int, damage: Callable) -> void:
	var start = Time.get_ticks_usec()
	for id in active.keys():
		var row = records[id]
		movement_steps += 1
		if row.state==State.DORMANT: dormant_movement_steps += 1
		if not players.has(row.target) or players[row.target].hp <= 0: continue
		var player = players[row.target]
		var diff: Vector3 = player.pose-row.position
		var distance = diff.length()
		var covered = distance>.0001 and CorridorGeometry.wall_distance(row.position+Vector3(0,.9,0),diff.normalized(),distance)<distance-.0001
		if distance > 1.2 or covered:
			var candidate = row.position+diff.normalized()*min(2.0/15.0,distance-1.2)
			# Fixed right-side route around the one authored rectangular baffle; no general navigation.
			var baffle_route := CorridorGeometry.baffle_route()
			if candidate.z >= baffle_route.min_z and candidate.z <= baffle_route.max_z and candidate.x < baffle_route.block_x:
				candidate.x = min(baffle_route.detour_x,row.position.x+2.0/15.0)
				candidate.z = row.position.z
			row.position = CorridorGeometry.constrain(candidate)
			row.yaw = atan2(-diff.x,-diff.z)
			row.state = State.ACTIVE
		else:
			row.state = State.ATTACKING
			if now >= row.next_attack and not stable_profile:
				row.next_attack = now+1.0
				damage.call(row.target,10)
		row.revision += 1
		row.tick = tick
		row.history.append([now,row.position])
		while row.history.size()>1 and row.history[1][0] < now-MOB_TIMING.MOB_HISTORY_SECONDS: row.history.pop_front()
		var cell = chunk(row.position)
		if cell != row.chunk:
			chunks[row.chunk].erase(id)
			if not chunks.has(cell): chunks[cell] = {}
			chunks[cell][id] = true
			row.chunk = cell
	movement_ms += (Time.get_ticks_usec()-start)/1000.0
func historic_pose(row: Dictionary, when: float) -> Vector3:
	var previous = row.history[0]
	for entry in row.history:
		if entry[0]>=when:
			var fraction = clampf((when-previous[0])/max(.0001,entry[0]-previous[0]),0,1)
			return previous[1].lerp(entry[1],fraction)
		previous = entry
	return row.position
func hit(id: int, damage: int) -> bool:
	var row = records[id]
	if row.state == State.DEAD: return false
	row.hp = maxi(0,row.hp-damage)
	row.revision += 1
	if row.hp == 0:
		row.state = State.DEAD
		active.erase(id)
		chunks[row.chunk].erase(id)
		kills += 1
		dead_at[id] = NetworkTime.time
		return true
	if row.state == State.DORMANT:
		row.state = State.ACTIVE
		active[id] = true
	return false
func counts() -> Dictionary:
	var dormant = 0
	var alive = 0
	for row in records.values():
		if row.state == State.DORMANT: dormant += 1
		if row.state != State.DEAD: alive += 1
	return {"active":active.size(),"dormant":dormant,"alive":alive}

func spawn_wave(count: int, center: float, now: float) -> void:
	wave_ids.clear()
	var first=next_id
	spawn_group(count,center,now)
	for id in range(first,next_id): wave_ids.append(id)
func wave_alive() -> int:
	var result=0
	for id in wave_ids:
		if records.has(id) and records[id].state!=State.DEAD: result+=1
	return result
