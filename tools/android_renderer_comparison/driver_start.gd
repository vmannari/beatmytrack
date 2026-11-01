extends RefCounted
## Wait through the production countdown and its early-throttle penalty window.
static func ready(countdown_ticks: int, simulation_tick: int) -> bool:
	return countdown_ticks <= 0 and simulation_tick >= 10
