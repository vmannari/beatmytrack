extends RefCounted
## Presentation clock from mixed playback positions and a monotonic render stamp.
## Avoids waiting on the audio driver's mix mutex on every rendered frame.
const MAX_EXTRAPOLATION: float = 0.05
var initialized: bool = false
var previous_position: float = 0.0
var previous_usec: int = 0
var unwrapped: float = 0.0
var origin: float = 0.0
var progress_time: float = 0.0

func reset() -> void:
	initialized = false

func sample(position: float, length: float, stamp_usec: int) -> float:
	if not is_finite(position) or not is_finite(length) or length <= 0.0: return 0.0
	var now: float = float(stamp_usec) / 1000000.0
	position = fposmod(position,length)
	if not initialized or stamp_usec < previous_usec:
		_anchor(position,now,stamp_usec)
		return position
	var elapsed: float = float(stamp_usec-previous_usec)/1000000.0
	var advance: float = position-previous_position
	# Unwrap a continuing loop even after a long presentation stall.
	advance += round((elapsed-advance)/length)*length
	if absf(advance-elapsed) > 0.25:
		_anchor(position,now,stamp_usec)
		return position
	unwrapped += advance
	if advance > 0.000001: progress_time = now
	# Mixed positions lag the audible clock by a fraction of one mix block.
	# The earliest observed origin removes that sampling lag without a mutex.
	origin = minf(origin,now-unwrapped)
	if now-progress_time > MAX_EXTRAPOLATION: origin = now-unwrapped
	previous_position = position
	previous_usec = stamp_usec
	return fposmod(minf(now-origin,unwrapped+MAX_EXTRAPOLATION),length)

func _anchor(position: float, now: float, stamp_usec: int) -> void:
	initialized = true
	previous_position = position
	previous_usec = stamp_usec
	unwrapped = position
	origin = now-position
	progress_time = now
