class_name HandlingConfig
extends Resource
## SI units unless noted. Arcade forces, not a physical tire model.

const BODY_SCALE: float = 0.88 # Owner-requested smaller physical car, shared with visuals/trails.
@export var vehicle_id: String = "compact"
@export var air_cushion: bool = false # Fan thrust and rudder steering; no wheel traction.
@export var vector_thrust: bool = false # Independent heading and world-space thrust for the UFO-style cushion.
@export_range(0.0, 5.0, 0.1) var thrust_lateral_damping: float = 0.0 # Dissipative side-slip recovery while applying fan power.
@export var rear_wheel_drive: bool = false # Optional driven rear-axle traction budget.
@export var single_pedal: bool = false # Accelerator plus stopped D/R selection; no brake/handbrake pedals.
@export var handbrake_enabled: bool = true
@export var blended_regeneration: bool = false # Automatic four-wheel lift-off braking independent of pedal layout.
@export_range(0.0, 30.0, 0.1) var regeneration: float = 0.0 # Lift-off deceleration, m/s²; one pedal blends automatic brakes.
@export_range(0.05, 0.4, 0.01) var coast_pedal: float = 0.18 # Neutral accelerator point for one-pedal cars.
@export var rear_steering: bool = false # Rear wheels oppose input; the fixed front axle leads the turn.
@export var loose_surface_grip: float = 1.0 # Multiplier on loose soil only.
@export_range(0.5, 1.0, 0.01) var winter_road_grip: float = 1.0 # Additional multiplier on winter asphalt only.
@export_range(0.1, 1.0, 0.01) var winter_lateral_grip: float = 1.0 # Sideways traction on winter asphalt; leaves straight-line traction intact.
@export var soil_drag_multiplier: float = 1.0
@export var wheel_soil_drag: bool = true # Four wheel contacts apply soil resistance and asymmetric pull.
@export var lift_off_rotation: float = 0.0 # Bounded rear unloading, rad/s at speed while coasting and steering.
@export var lift_off_grip_loss: float = 0.0
@export var track_width: float = 1.66 * BODY_SCALE
@export var profile_name: String = "Balanced"
@export var version: String = "handling-0.14"
@export var progressive_handling: bool = true # Original and Original+ use the original steering model.
@export_range(150.0, 3000.0, 10.0) var mass: float = 1050.0
@export_range(1000.0, 80000.0, 100.0) var engine_force: float = 16500.0
@export_range(2000.0, 30000.0, 100.0) var braking_force: float = 18000.0
@export_range(0.0, 4.0, 0.1) var drag: float = 0.65 # N per (m/s)^2
@export_range(0.0, 800.0, 10.0) var rolling_resistance: float = 180.0 # N
@export_range(10.0, 60.0, 1.0) var maximum_speed: float = 46.0 # m/s
@export_range(0.0, 0.2, 0.01) var turn_speed_reduction: float = 0.0 # Fraction of top speed lost in a sustained high-speed full-lock turn.
@export_range(2.0, 12.0, 0.5) var reverse_speed: float = 7.0
@export_range(0.1, 1.0, 0.05) var reverse_delay: float = 0.35 # seconds stopped
@export_range(1.0, 40.0, 0.1) var steering_rate: float = 8.5 # 118 ms centre to full input.
@export_range(1.0, 40.0, 0.1) var countersteering_rate: float = 20.0 # normalized input/s while unwinding/reversing.
@export_range(0.2, 1.0, 0.01) var steering_angle: float = 0.65 # radians
@export_range(0.0, 0.95, 0.01) var high_speed_steering_reduction: float = 0.65
@export_range(0.1, 1.0, 0.01) var low_speed_steering_scale: float = 1.0 # Full scale by 8 m/s; soften parking-speed lock only.
@export_range(0.1, 1.0, 0.01) var low_speed_steering_rate_scale: float = 1.0 # Slow steering buildup at parking speed; retain quick unwind/countersteer.
@export_range(0.02, 1.0, 0.01) var launch_lateral_response_scale: float = 1.0 # Retain some sideways momentum during a powered low-speed rear-drive turn.
@export_range(0.1, 1.0, 0.01) var power_lateral_response_scale: float = 1.0 # Optional rear-drive power slide; lift and straight steering restore normal response.
@export_range(0.5, 1.0, 0.01) var power_slide_full_pedal: float = 0.85 # Pedal position that fully develops the optional rear-drive slide.
@export_range(0.0, 1.0, 0.01) var power_slide_high_speed_scale: float = 1.0 # Power-slide strength near maximum speed; full strength below 28 m/s.
@export var continuous_turn_radius: bool = false # Apply a smooth curvature envelope at every speed, without a low-speed fade.
@export_range(0.0, 20.0, 0.1) var low_speed_turn_radius: float = 0.0 # Base radius for continuous steering; legacy low-speed radius floor.
@export_range(1.0, 80.0, 0.1) var low_speed_turn_acceleration: float = 9.0 # Continuous radius adds speed squared / this value; legacy acceleration bound.
@export_range(1.0, 3.5, 0.05) var wheelbase: float = 2.55 * BODY_SCALE
@export_range(6.0, 80.0, 0.25) var lateral_grip: float = 58.0 # maximum lateral acceleration
@export_range(6.0, 55.0, 0.25) var longitudinal_grip: float = 19.0 # maximum longitudinal acceleration
@export_range(0.6, 1.4, 0.01) var front_grip: float = 1.0
@export_range(0.6, 1.4, 0.01) var rear_grip: float = 1.0
@export_range(0.1, 0.6, 0.01) var slip_threshold: float = 0.26 # radians
@export_range(0.4, 1.0, 0.01) var sliding_grip: float = 0.86 # fraction of lateral grip
@export_range(1.0, 12.0, 0.1) var grip_recovery: float = 5.0 # response/s
@export_range(2.0, 30.0, 0.1) var lateral_response: float = 17.0 # response/s
@export_range(0.4, 1.0, 0.01) var high_speed_lateral_response_scale: float = 1.0 # Retain mild sideslip near top speed; normal response below 70% of maximum.
@export_range(0.4, 1.0, 0.01) var high_speed_lateral_grip_scale: float = 1.0 # Reduce the force turning momentum into the corner at high speed.
@export_range(0.0, 1.0, 0.05) var corner_energy_retention: float = 0.50 # lateral energy redirected into travel
@export_range(50.0, 4000.0, 10.0) var rotational_inertia: float = 500.0 # kg m^2 approximation
@export_range(0.0, 3.0, 0.05) var countersteer_assistance: float = 0.8 # Extra yaw response when actively catching rotation.
@export_range(0.0, 1.5, 0.05) var brake_rotation: float = 0.65 # rad/s at full brake and steer; fades below 12 m/s.
@export_range(0.0, 0.4, 0.01) var brake_grip_loss: float = 0.18 # Rear unloading while trail braking.
@export_range(0.0, 0.8, 0.01) var slide_drive_loss: float = 0.45 # Engine traction sacrificed in broad slides.
@export_range(0.0, 1.0, 0.05) var slide_power_recovery: float = 0.0 # Fraction of speed-related engine falloff restored during a slide.
@export_range(0.0, 1.5, 0.05) var throttle_rotation: float = 0.0
@export_range(0.0, 0.4, 0.01) var throttle_grip_loss: float = 0.06
@export_range(0.5, 4.0, 0.1) var maximum_yaw_rate: float = 2.7 # rad/s
@export_range(0.0, 0.8, 0.01) var collision_energy_loss: float = 0.35
@export_range(0.0, 0.7, 0.01) var restitution: float = 0.30 # Fraction of impact-normal speed returned as recoil.
@export_range(0.0, 0.5, 0.01) var dirty_tire_grip_loss: float = 0.45 # Maximum fractional grip penalty.
@export_range(5.0, 80.0, 1.0) var tire_pickup_distance: float = 10.0 # Metres of loose dirt to fully coat tires.
@export_range(10.0, 150.0, 1.0) var tire_clean_distance: float = 140.0 # Clean-road metres to remove a full coating.
@export_range(0.0, 1.0, 0.01) var collision_turn_strength: float = 0.45 # Angular impulse per impact speed, weighted by angle.
@export_range(0.5, 4.0, 0.1) var wall_slide_speed: float = 2.0 # Inward m/s where the hard-impact blend begins (full at 4x).
@export_range(0.0, 4.0, 0.1) var wall_alignment_rate: float = 2.4 # Gradual chassis alignment during rubbing.
@export_range(1.0, 2.5, 0.05) var collision_radius: float = 1.55 * BODY_SCALE # planar circle approximation


func maximum_deceleration() -> float:
	return regeneration if single_pedal else braking_force/mass


func accelerator_for_acceleration(acceleration: float, drive_acceleration: float) -> float:
	# Inverse of the one-pedal map for canonical development drivers. Zero demand
	# holds the neutral pedal point; negative demand releases towards full regen.
	if acceleration < 0.0:
		return coast_pedal*(1.0-clampf(-acceleration/maxf(regeneration,0.001),0.0,1.0))
	return coast_pedal+(1.0-coast_pedal)*clampf(acceleration/maxf(drive_acceleration,0.1),0.0,1.0)


func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_EDITOR:
			result[property.name] = get(property.name)
	# Additive vehicle capability: retain exact established front-steer config hashes.
	if not air_cushion: result.erase("air_cushion")
	if not vector_thrust: result.erase("vector_thrust")
	if thrust_lateral_damping == 0.0: result.erase("thrust_lateral_damping")
	if not rear_steering: result.erase("rear_steering")
	if winter_road_grip == 1.0: result.erase("winter_road_grip")
	if winter_lateral_grip == 1.0: result.erase("winter_lateral_grip")
	if high_speed_lateral_response_scale == 1.0: result.erase("high_speed_lateral_response_scale")
	if high_speed_lateral_grip_scale == 1.0: result.erase("high_speed_lateral_grip_scale")
	if not rear_wheel_drive: result.erase("rear_wheel_drive")
	if not single_pedal: result.erase("single_pedal")
	if handbrake_enabled: result.erase("handbrake_enabled")
	if not blended_regeneration: result.erase("blended_regeneration")
	if low_speed_steering_scale == 1.0: result.erase("low_speed_steering_scale")
	if low_speed_steering_rate_scale == 1.0: result.erase("low_speed_steering_rate_scale")
	if launch_lateral_response_scale == 1.0: result.erase("launch_lateral_response_scale")
	if power_lateral_response_scale == 1.0: result.erase("power_lateral_response_scale")
	if power_slide_full_pedal == 0.85: result.erase("power_slide_full_pedal")
	if power_slide_high_speed_scale == 1.0: result.erase("power_slide_high_speed_scale")
	if turn_speed_reduction == 0.0: result.erase("turn_speed_reduction")
	if not continuous_turn_radius: result.erase("continuous_turn_radius")
	if low_speed_turn_radius == 0.0:
		result.erase("low_speed_turn_radius")
		result.erase("low_speed_turn_acceleration")
	if regeneration == 0.0:
		result.erase("regeneration")
		result.erase("coast_pedal")
	return result
