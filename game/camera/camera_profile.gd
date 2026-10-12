class_name CameraProfile
extends Resource

const MODES: Array[String] = ["overhead", "follow_car", "look_ahead"]
const DEFAULT_SPEED_ZOOM_STRENGTH: float = 0.30
const MAX_SPEED_ZOOM_STRENGTH: float = 0.50
const TITLES: Array[String] = ["Overhead", "Follow car", "Look ahead"]
const DESCRIPTIONS: Array[String] = [
	"The original fixed-angle overhead view.",
	"Turns smoothly with the car, viewed from a slightly lower angle.",
	"Keeps the world steady and shows more road in your direction of travel.",
]

@export var height: float = 32.0
@export_range(40.0, 80.0, 0.5) var pitch_degrees: float = 56.0
@export var world_yaw_degrees: float = 18.0
@export var baseline_extent: float = 35.0
@export var magnification: float = 1.15
@export var forward_look_ahead: float = 1.5
@export var velocity_look_ahead: float = 0.22 # seconds
@export var maximum_look_ahead: float = 7.0
@export var look_ahead_smoothing: float = 0.0 # optional separate response/s for the offset
@export var smoothing: float = 9.0 # response/s
@export var orthographic: bool = true
@export var field_of_view: float = 40.0
@export var follow_heading: bool = false # experiment only; stable world is default
@export var heading_smoothing: float = 3.5 # response/s; eases into alignment within the speed cap
@export_range(5.0, 180.0, 1.0) var maximum_yaw_speed_degrees: float = 60.0
@export var speed_zoom_start_kmh: float = 30.0
@export var speed_zoom_full_kmh: float = 160.0
@export var speed_zoom_smoothing: float = 1.5 # response/s; gentle acceleration/braking changes


static func valid_mode(value: String) -> String:
	return value if value in MODES else MODES[0]


static func for_mode(value: String) -> CameraProfile:
	# Each camera owns its profile; experiments never mutate the shared baseline.
	var result: CameraProfile = (load("res://resources/camera.tres") as CameraProfile).duplicate()
	match valid_mode(value):
		"follow_car":
			result.follow_heading = true
			result.world_yaw_degrees = 0.0
			result.pitch_degrees = 48.0
		"look_ahead":
			result.velocity_look_ahead = 0.4
			result.forward_look_ahead = 2.0
			result.maximum_look_ahead = 9.0
			result.look_ahead_smoothing = 2.0
	return result
