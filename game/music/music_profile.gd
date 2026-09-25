class_name MusicProfile
extends Resource
## Grass MVP. Shared tuning resource, never canonical vehicle configuration.
@export_range(128,135,1) var bpm: int = 128
@export_range(1.0,3.0) var lookahead_seconds: float = 2.0
@export_range(0.0,1.0) var lookahead_weight: float = 0.6
@export_range(0.1,4.0) var smoothing_seconds: float = 0.8
@export_range(1.0,4.0) var sample_spacing: float = 2.0
@export_range(0.0,0.2) var trajectory_influence: float = 0.1
@export_range(0.0,1.0) var brightness: float = 0.65
@export_range(0.0,1.0) var metallicity: float = 0.35
@export_range(0.0,1.0) var decay: float = 0.65
@export_range(0.0,1.0) var stereo_width: float = 0.45
@export_range(-40.0,0.0) var volume_db: float = -9.0
@export var curvature_full_tension: float = 0.12
@export var target_lateral_acceleration: float = 9.0

@export_group("Clean driving progression")
@export_range(1.0,30.0) var clean_speed_mps: float = 10.0
@export_range(0.2,10.0) var speed_average_seconds: float = 3.0
@export_range(0.0,3.0) var speed_hysteresis_mps: float = 1.0
@export_range(0.0,15.0) var speed_qualification_seconds: float = 4.0
@export_range(4.0,90.0) var clean_build_seconds: float = 24.0
@export_range(1.0,60.0) var slow_decay_seconds: float = 12.0
@export_range(0.0,15.0) var collision_recovery_seconds: float = 5.0
