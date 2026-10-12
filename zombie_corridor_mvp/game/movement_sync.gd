class_name CorridorMovementSync
extends RollbackSynchronizer
# Netfox 1.35.3 adapter: retain retired history without generating new wire traffic.
func _after_tick(delta: float, tick: int) -> void:
	if tick >= root.retire_tick:
		_history_recorder.trim_history()
		_freshness_store.trim()
		return
	super(delta,tick)
func _on_record_tick(tick: int) -> void:
	if tick > root.retire_tick: return
	super(tick)

func _notify_resim() -> void:
	# A nonowner receives states only (input broadcast is disabled), and must not
	# request rollback from an input timestamp that will never advance.
	if not NetSession.is_server and root.owner_peer_id!=NetSession.local_peer(): return
	if NetworkTime.tick>root.retire_tick+NetworkRollback.history_limit: return
	var earliest = _history_transmitter.get_earliest_input_tick() if _get_owned_input_props().is_empty() else _history_transmitter.get_latest_state_tick()
	NetworkRollback.notify_resimulation_start(maxi(NetworkRollback.history_start,earliest))
