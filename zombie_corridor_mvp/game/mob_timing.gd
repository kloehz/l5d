extends RefCounted

const NETWORK_TICK_RATE_HZ := 30.0
const INTERPOLATION_DELAY_SECONDS := 0.300
const MAX_REWIND_SECONDS := 0.450
const MOB_HISTORY_SECONDS := 0.500

static func interpolation_delay_ticks() -> float:
	return INTERPOLATION_DELAY_SECONDS * NETWORK_TICK_RATE_HZ

static func clamp_rewind_time(requested_time: float, current_time: float) -> float:
	return clampf(requested_time, current_time - MAX_REWIND_SECONDS, current_time)
