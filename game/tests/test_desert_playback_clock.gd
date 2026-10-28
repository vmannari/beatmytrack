extends SceneTree
const CLOCK = preload("res://track/desert_playback_clock.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func distance(a: float, b: float, length: float) -> float:
	return absf(wrapf(a-b,-length/2.0,length/2.0))
func run() -> void:
	var peak: float = 0.0
	for rate: float in [30.0,60.0,120.0]:
		for block: float in [0.005333333,0.010666667,0.021333333]:
			var clock: RefCounted = CLOCK.new()
			var phase: float = 0.0037
			var length: float = 12.7
			var bounded: bool = true
			var converged: bool = true
			for frame: int in range(int(rate*60.0)):
				var now: float = float(frame)/rate + sin(float(frame)*1.77)*0.0003
				var mixed: float = floor((now+phase)/block)*block
				var raw: float = fposmod(11.9+mixed,length)
				var actual: float = fposmod(11.9+now+phase,length)
				var estimate: float = clock.sample(raw,length,int((now+1000.0)*1000000.0))
				var error: float = distance(actual,estimate,length)
				peak = maxf(peak,error)
				bounded = bounded and error <= block+0.00001
				if frame > int(rate*2): converged = converged and error < 0.004
			check(bounded,"mixed-position clock stays within one mix block across random offset/loop wraps: %.0fHz %.6fs" % [rate,block])
			check(converged,"clock converges below four milliseconds without a driver query")
	var clock: RefCounted = CLOCK.new()
	clock.sample(3.0,12.0,1000000)
	clock.sample(3.02,12.0,1020000)
	check(clock.sample(8.0,12.0,1040000) == 8.0,"explicit playback seek reanchors immediately")
	check(distance(clock.sample(7.9,12.0,1060000),7.9,12.0) <= CLOCK.MAX_EXTRAPOLATION+0.000001,"small playback correction stays within the bounded prediction")
	clock.reset()
	check(clock.sample(5.0,12.0,9000000) == 5.0,"pause/retry reset cannot extrapolate time spent stopped")
	var stalled: float = clock.sample(5.0,12.0,9200000)
	check(distance(stalled,5.0,12.0) <= CLOCK.MAX_EXTRAPOLATION,"stalled audio never advances sand beyond the bounded prediction")
	check(clock.sample(NAN,12.0,9300000) == 0.0 and clock.sample(0.0,0.0,9400000) == 0.0,"invalid cursor input cannot corrupt presentation")
	print("DESERT_PLAYBACK_CLOCK: ",checks," checks, ",failures," failures peak_error_ms=",peak*1000.0)
	quit(1 if failures else 0)
