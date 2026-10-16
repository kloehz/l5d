extends RefCounted
# App admission only; never adjusts clocks, prediction, history, or wire data.
# Netfox 1.35.3 has no public completed-sample/session provenance API. Read its
# buffer and pending objects, retaining references so reconnect cannot mistake
# an old late pong (or retained positive RTT) for a new measurement.
var _generation := -1
var _peer: MultiplayerPeer
var _prior_buffer: RefCounted
var _excluded: Array = []
var _seen: Array = []
var _completion_usec := -1

func begin_session(generation: int, peer: MultiplayerPeer, sync: Object) -> void:
	_generation = generation
	_peer = peer
	_prior_buffer = sync._sample_buffer
	_excluded = sync._awaiting_samples.values().duplicate()
	if _prior_buffer != null:
		_excluded.append_array(_prior_buffer.get_data().duplicate())
	_seen.clear()
	_completion_usec = -1

func end_session() -> void:
	_generation = -1
	_peer = null
	_prior_buffer = null
	_excluded.clear()
	_seen.clear()
	_completion_usec = -1

func fresh_measurement(generation: int, peer: MultiplayerPeer, sync: Object, now_usec: int) -> bool:
	if generation != _generation or peer != _peer or peer == null:
		return false
	if sync._sample_buffer == null or sync._sample_buffer == _prior_buffer:
		return false
	for value in [sync.rtt, sync.rtt_jitter, sync.sync_interval]:
		if not is_finite(value) or value < 0.0: return false
	if sync.rtt <= 0.0 or sync.sync_interval <= 0.0 or sync.sync_samples <= 0:
		return false
	var samples: Array = sync._sample_buffer.get_data()
	if samples.is_empty(): return false
	var new_completion := false
	for sample in samples:
		if _excluded.has(sample): return false
		for value in [sample.ping_sent, sample.ping_received, sample.pong_sent, sample.pong_received, sample.get_rtt(), sample.get_offset()]:
			if not is_finite(value): return false
		if sample.get_rtt() <= 0.0 or sample.pong_sent < sample.ping_received:
			return false
		if not _seen.has(sample): new_completion = true
	if new_completion:
		_completion_usec = now_usec
		_seen = samples.duplicate()
	# A completed measurement expires after one native estimator window plus
	# its observed maximum RTT. No fabricated fixed drop/sleep interval.
	var lifetime_s: float = sync.sync_interval * sync.sync_samples + sync.rtt + sync.rtt_jitter
	return _completion_usec >= 0 and now_usec >= _completion_usec and float(now_usec - _completion_usec) / 1000000.0 <= lifetime_s

static func evaluate(current_tick: int, wire_tick: int, tail: int, history: int,
		tick_s: float, phase_s: float, offset_s: float, rtt_s: float,
		jitter_s: float, fresh: bool) -> Dictionary:
	var result := {"allowed": false, "reason": "no fresh session measurement"}
	for value in [tick_s, phase_s, offset_s, rtt_s, jitter_s]:
		if not is_finite(value):
			result.reason = "nonfinite metric"
			return result
	if tick_s <= 0.0 or rtt_s <= 0.0 or jitter_s < 0.0 or tail < 0 or history <= 0:
		result.reason = "invalid budget metric"
		return result
	if not fresh: return result
	# Full observed max RTT, NOT RTT/2, reserves asymmetric delivery. Positive
	# residual offset and sync-vs-stepping phase reserve clock lag. This remains
	# an estimator, not a bound against arbitrary WAN delay/loss or clock drift.
	var seconds := maxf(0.0, offset_s) + rtt_s + jitter_s + maxf(0.0, phase_s)
	var age := maxi(0, current_tick - wire_tick)
	# One sender scheduling tick + one receiver polling/rounding tick. The
	# oldest redundant sibling is tail ticks older, even when newest is fresh.
	var required := ceilf(seconds / tick_s) + age + tail + 2
	result.merge({"required_ticks": required, "history_ticks": history,
		"record_age_ticks": age, "tail_ticks": tail, "phase_s": phase_s,
		"offset_s": offset_s, "rtt_s": rtt_s, "jitter_s": jitter_s}, true)
	result.allowed = required <= history # cutoff equality is valid in Netfox.
	result.reason = "usable" if result.allowed else "input age budget exhausted"
	return result
