class_name HandlingConfig
extends Resource
## SI units unless noted. Arcade forces, not a physical tire model.

const BODY_SCALE: float = 0.88 # Owner-requested smaller physical car, shared with visuals/trails.

@export var profile_name: String = "Balanced"
@export var version: String = "handling-0.14"
@export var progressive_handling: bool = true # False only for the frozen comparison preset.
@export_range(500.0, 2000.0, 10.0) var mass: float = 1050.0
@export_range(1000.0, 22000.0, 100.0) var engine_force: float = 16500.0
@export_range(2000.0, 30000.0, 100.0) var braking_force: float = 18000.0
@export_range(0.0, 4.0, 0.1) var drag: float = 0.65 # N per (m/s)^2
@export_range(0.0, 800.0, 10.0) var rolling_resistance: float = 180.0 # N
@export_range(10.0, 60.0, 1.0) var maximum_speed: float = 46.0 # m/s
@export_range(2.0, 12.0, 0.5) var reverse_speed: float = 7.0
@export_range(0.1, 1.0, 0.05) var reverse_delay: float = 0.35 # seconds stopped
@export_range(1.0, 40.0, 0.1) var steering_rate: float = 8.5 # 118 ms centre to full input.
@export_range(1.0, 40.0, 0.1) var countersteering_rate: float = 20.0 # normalized input/s while unwinding/reversing.
@export_range(0.2, 0.8, 0.01) var steering_angle: float = 0.65 # radians
@export_range(0.0, 0.95, 0.01) var high_speed_steering_reduction: float = 0.65
@export_range(2.0, 3.5, 0.05) var wheelbase: float = 2.55 * BODY_SCALE
@export_range(6.0, 60.0, 0.25) var lateral_grip: float = 58.0 # maximum lateral acceleration
@export_range(6.0, 30.0, 0.25) var longitudinal_grip: float = 19.0 # maximum longitudinal acceleration
@export_range(0.6, 1.4, 0.01) var front_grip: float = 1.0
@export_range(0.6, 1.4, 0.01) var rear_grip: float = 1.0
@export_range(0.1, 0.6, 0.01) var slip_threshold: float = 0.26 # radians
@export_range(0.4, 1.0, 0.01) var sliding_grip: float = 0.86 # fraction of lateral grip
@export_range(1.0, 12.0, 0.1) var grip_recovery: float = 5.0 # response/s
@export_range(2.0, 20.0, 0.1) var lateral_response: float = 17.0 # response/s
@export_range(0.0, 1.0, 0.05) var corner_energy_retention: float = 0.50 # lateral energy redirected into travel
@export_range(400.0, 4000.0, 50.0) var rotational_inertia: float = 500.0 # kg m^2 approximation
@export_range(0.0, 3.0, 0.05) var countersteer_assistance: float = 0.8 # Extra yaw response when actively catching rotation.
@export_range(0.0, 1.5, 0.05) var brake_rotation: float = 0.65 # rad/s at full brake and steer; fades below 12 m/s.
@export_range(0.0, 0.4, 0.01) var brake_grip_loss: float = 0.18 # Rear unloading while trail braking.
@export_range(0.0, 0.8, 0.01) var slide_drive_loss: float = 0.45 # Engine traction sacrificed in broad slides.
@export_range(0.0, 1.5, 0.05) var throttle_rotation: float = 0.0
@export_range(0.0, 0.4, 0.01) var throttle_grip_loss: float = 0.06
@export_range(0.5, 4.0, 0.1) var maximum_yaw_rate: float = 2.7 # rad/s
@export_range(0.0, 0.8, 0.01) var collision_energy_loss: float = 0.35
@export_range(0.0, 0.7, 0.01) var restitution: float = 0.30 # Fraction of impact-normal speed returned as recoil.
@export_range(0.0, 0.5, 0.01) var dirty_tire_grip_loss: float = 0.25 # Maximum fractional grip penalty.
@export_range(5.0, 80.0, 1.0) var tire_pickup_distance: float = 20.0 # Metres of loose dirt to fully coat tires.
@export_range(10.0, 150.0, 1.0) var tire_clean_distance: float = 80.0 # Clean-road metres to remove a full coating.
@export_range(0.0, 1.0, 0.01) var collision_turn_strength: float = 0.45 # Angular impulse per impact speed, weighted by angle.
@export_range(0.5, 4.0, 0.1) var wall_slide_speed: float = 2.0 # Inward m/s blending rubbing into impact.
@export_range(0.0, 4.0, 0.1) var wall_alignment_rate: float = 2.4 # Gradual chassis alignment during rubbing.
@export_range(1.0, 2.5, 0.05) var collision_radius: float = 1.55 * BODY_SCALE # planar circle approximation


func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_EDITOR:
			result[property.name] = get(property.name)
	return result
