class_name CorridorMovementSync
extends RollbackSynchronizer
# Pinned Netfox 1.35.3 encoder hook: shared storage, receipt-only copied cache.
const ReceivedPlayerStatesScript = preload("res://game/received_player_states.gd")

var _received_state_view: _PropertyHistoryBuffer
var _received_state_generation: int = 0

func get_latest_received_state_sample() -> Dictionary:
	if _received_state_view == null:
		return {}
	return _received_state_view.get_latest_sample()

func get_received_generation() -> int:
	return _received_state_generation

func process_settings() -> void:
	super()
	_received_state_generation += 1
	_received_state_view = null
	if root == null or not is_instance_valid(root) or multiplayer.is_server() or root.is_multiplayer_authority():
		return
	_received_state_view = ReceivedPlayerStatesScript.new(_states, _received_state_generation)
	_history_transmitter._full_state_encoder._history = _received_state_view
	_history_transmitter._diff_state_encoder._history = _received_state_view

func _after_tick(_delta: float, tick: int) -> void:
	if tick >= root.retire_tick:
		_history_recorder.trim_history()
		_freshness_store.trim()
		return
	# Pinned Netfox 1.35.3 hook decomposition: record -> optional publication ->
	# trim -> freshness, unchanged even while publication is unsuitable.
	_history_recorder.record_input(tick)
	if _can_publish_input(tick):
		_history_transmitter.transmit_input(tick)
	_history_recorder.trim_history()
	_freshness_store.trim()

func _can_publish_input(tick: int) -> bool:
	if multiplayer.is_server() or _get_owned_input_props().is_empty(): return true
	var tail := _history_transmitter._input_encoder.redundancy - 1
	return NetSession.input_publication_status(tick + NetworkRollback.input_delay, tail).allowed

func _on_record_tick(tick: int) -> void:
	if tick > root.retire_tick: return
	# Netfox 1.35.3 private ACK map: erase only peer references, not shared history.
	# Age 8 is allowed (half of history 16); age 9 forces vendor full fallback.
	# Use current network time, never the replay tick. The remaining eight ticks
	# are delivery margin, not a guarantee against arbitrary loss/delay or skew.
	var oldest_reference := NetworkTime.tick - floori(NetworkRollback.history_limit * 0.5)
	for peer in _history_transmitter._ackd_state.keys():
		if _history_transmitter._ackd_state[peer] < oldest_reference:
			_history_transmitter._ackd_state.erase(peer)
	if _history_transmitter._state_property_config == null:
		super(tick)
		return
	var owned_state := _history_transmitter._get_owned_state_props()
	if owned_state.is_empty():
		super(tick)
		return
	_history_recorder.record_state(tick)
	var exact_state := _history_recorder._state_history.get_snapshot(tick)
	for property in owned_state:
		var path := property.to_string()
		if not exact_state.has(path): return
		var value: Variant = exact_state.get_value(path)
		if value == null or typeof(value) != typeof(property.get_value()): return
	_history_transmitter.transmit_state(tick)

func _notify_resim() -> void:
	# A nonowner receives states only (input broadcast is disabled), and must not
	# request rollback from an input timestamp that will never advance.
	if not NetSession.is_server and root.owner_peer_id!=NetSession.local_peer(): return
	if NetworkTime.tick>root.retire_tick+NetworkRollback.history_limit: return
	var earliest = _history_transmitter.get_earliest_input_tick() if _get_owned_input_props().is_empty() else _history_transmitter.get_latest_state_tick()
	NetworkRollback.notify_resimulation_start(maxi(NetworkRollback.history_start,earliest))
