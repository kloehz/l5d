class_name MobClientStore
extends RefCounted
var records = {}
var visits = {}
var dead = {}
var accepted = 0
var rejected = 0
func enter(row: Dictionary) -> bool:
	var id = row.id
	if dead.has(id) or row.interest_epoch <= visits.get(id,0):
		rejected += 1
		return false
	visits[id] = row.interest_epoch
	records[id] = row.duplicate()
	records[id].history = [row.duplicate()]
	accepted += 1
	return true
func leave(id: int, visit: int, killed: bool) -> void:
	visits[id] = maxi(visits.get(id,0),visit)
	if killed:
		dead[id] = true
		if dead.size()>1024:
			var oldest = dead.keys()[0]
			dead.erase(oldest)
			visits.erase(oldest)
	if records.has(id) and records[id].interest_epoch <= visit: records.erase(id)
func update(row: Dictionary) -> bool:
	var id = row.id
	if dead.has(id) or not records.has(id) or row.interest_epoch != records[id].interest_epoch or row.revision <= records[id].revision:
		rejected += 1
		return false
	var history = records[id].history
	history.append(row.duplicate())
	while history.size()>8: history.pop_front()
	records[id] = row.duplicate()
	records[id].history = history
	accepted += 1
	return true
func clear() -> void:
	records.clear()
	visits.clear()
	dead.clear()
