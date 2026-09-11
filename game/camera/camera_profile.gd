class_name CameraProfile
extends Resource

@export var height: float = 32.0
@export_range(40.0, 80.0, 0.5) var pitch_degrees: float = 56.0
@export var world_yaw_degrees: float = 18.0
@export var baseline_extent: float = 35.0
@export var magnification: float = 1.15
@export var forward_look_ahead: float = 1.5
@export var velocity_look_ahead: float = 0.22 # seconds
@export var maximum_look_ahead: float = 7.0
@export var smoothing: float = 9.0 # response/s
@export var orthographic: bool = true
@export var field_of_view: float = 40.0
@export var follow_heading: bool = false # experiment only; stable world is default
