class_name BeatClock
extends RefCounted
## Read model of the native sample clock. Never integrates frame delta.
var beat_position: float = 0.0
var bpm: float = 132.0
var current_beat: int: get = _beat
var current_bar: int: get = _bar
var current_phrase: int: get = _phrase
var time_to_next_beat: float: get = _next_beat
var time_to_next_bar: float: get = _next_bar
var time_to_next_phrase: float: get = _next_phrase
func _beat() -> int: return floori(beat_position)
func _bar() -> int: return floori(beat_position / 4.0)
func _phrase() -> int: return floori(beat_position / 32.0)
func boundary_seconds(beats: float) -> float:
	return (beats - fposmod(beat_position, beats)) * 60.0 / bpm
func _next_beat() -> float: return boundary_seconds(1.0)
func _next_bar() -> float: return boundary_seconds(4.0)
func _next_phrase() -> float: return boundary_seconds(32.0)
