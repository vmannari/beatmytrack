extends RefCounted
## Temporary driving experiments. Values are deliberately local to a race and
## never change the catalog resources or the canonical handling contracts.

const LABELS: Array[String] = ["Stable", "Agile", "Flow", "Slide", "Loose"]
const KART_LABELS: Array[String] = ["Brake turn 5 (reference)", "Brake turn 5.1", "Brake turn 5.2", "Brake turn 5.3", "Brake turn 5.4", "Brake turn 5.5"]
const HOVER_LABELS: Array[String] = ["Slide 5 (reference)", "Slide 5.1", "Slide 5.2", "Slide 5.3", "Slide 5.4", "Slide 5.5"]
const VEHICLES: Array[String] = ["pickup", "kart", "hovercraft"]

# Steering, grip and recovery are tuned separately for each car. Engine, brakes,
# top speed, collision dimensions and vehicle-specific pedal layouts stay intact.
const TUNING: Dictionary = {
	"pickup": [
		{"steering_rate": 7.0, "lateral_grip": 54.0, "lateral_response": 14.0, "grip_recovery": 7.0, "countersteer_assistance": 0.7},
		{"steering_rate": 10.0, "steering_angle": 0.72, "lateral_grip": 50.0, "lateral_response": 13.0, "maximum_yaw_rate": 2.5},
		{"steering_rate": 8.0, "steering_angle": 0.68, "lateral_grip": 48.0, "lateral_response": 11.0, "corner_energy_retention": 0.7, "grip_recovery": 6.0},
		{"steering_rate": 8.0, "steering_angle": 0.70, "lateral_grip": 43.0, "lateral_response": 8.0, "brake_rotation": 0.4, "countersteer_assistance": 0.9, "grip_recovery": 6.0},
		{"steering_rate": 9.0, "steering_angle": 0.73, "lateral_grip": 39.0, "lateral_response": 6.5, "brake_rotation": 0.55, "countersteer_assistance": 1.0, "grip_recovery": 6.0},
	],
	"kart": [
		{"steering_rate": 16.0, "steering_angle": 0.94, "brake_rotation": 1.25, "brake_grip_loss": 0.14, "countersteer_assistance": 0.75},
		{"steering_rate": 16.0, "steering_angle": 0.94, "brake_rotation": 1.25, "brake_grip_loss": 0.14, "countersteer_assistance": 0.75, "lateral_grip": 84.0, "high_speed_steering_reduction": 0.56},
		{"steering_rate": 16.0, "steering_angle": 0.94, "brake_rotation": 1.25, "brake_grip_loss": 0.14, "countersteer_assistance": 0.75, "lateral_grip": 88.0, "high_speed_steering_reduction": 0.54},
		{"steering_rate": 16.0, "steering_angle": 0.94, "brake_rotation": 1.25, "brake_grip_loss": 0.14, "countersteer_assistance": 0.75, "lateral_grip": 92.0, "high_speed_steering_reduction": 0.52},
		{"steering_rate": 16.0, "steering_angle": 0.94, "brake_rotation": 1.25, "brake_grip_loss": 0.14, "countersteer_assistance": 0.75, "lateral_grip": 96.0, "high_speed_steering_reduction": 0.50},
		{"steering_rate": 16.0, "steering_angle": 0.94, "brake_rotation": 1.25, "brake_grip_loss": 0.14, "countersteer_assistance": 0.75, "lateral_grip": 100.0, "high_speed_steering_reduction": 0.48},
	],
	"forklift": [
		{"steering_rate": 5.5, "lateral_grip": 54.0, "lateral_response": 20.0, "grip_recovery": 7.0},
		{"steering_rate": 8.0, "countersteering_rate": 15.0, "high_speed_steering_reduction": 0.20, "lateral_grip": 50.0, "lateral_response": 18.0},
		{"steering_rate": 7.0, "countersteering_rate": 14.0, "lateral_grip": 46.0, "lateral_response": 13.0, "countersteer_assistance": 0.6},
		{"steering_rate": 7.0, "countersteering_rate": 15.0, "lateral_grip": 42.0, "lateral_response": 10.0, "brake_rotation": 0.25, "countersteer_assistance": 0.8},
		{"steering_rate": 8.0, "countersteering_rate": 16.0, "lateral_grip": 38.0, "lateral_response": 7.0, "brake_rotation": 0.4, "countersteer_assistance": 1.0},
	],
	"hovercraft": [
		{"steering_rate": 19.0, "maximum_yaw_rate": 2.7, "thrust_lateral_damping": 1.0, "lateral_response": 0.28},
		{"steering_rate": 19.0, "maximum_yaw_rate": 2.7, "thrust_lateral_damping": 0.9, "lateral_response": 0.28},
		{"steering_rate": 19.0, "maximum_yaw_rate": 2.7, "thrust_lateral_damping": 0.8, "lateral_response": 0.28},
		{"steering_rate": 19.0, "maximum_yaw_rate": 2.7, "thrust_lateral_damping": 0.7, "lateral_response": 0.28},
		{"steering_rate": 19.0, "maximum_yaw_rate": 2.7, "thrust_lateral_damping": 0.6, "lateral_response": 0.28},
		{"steering_rate": 19.0, "maximum_yaw_rate": 2.7, "thrust_lateral_damping": 0.5, "lateral_response": 0.28},
	],
}

static func names(vehicle_id: String) -> Array[String]:
	var result: Array[String] = []
	if vehicle_id in VEHICLES:
		result.assign(HOVER_LABELS if vehicle_id == "hovercraft" else KART_LABELS if vehicle_id == "kart" else LABELS)
	return result

static func config(vehicle_id: String, preset_index: int) -> HandlingConfig:
	var result: HandlingConfig = (load("res://tests/fixtures/kart_final_reference/kart7.tres") as HandlingConfig).duplicate() if vehicle_id == "kart" else VehicleCatalog.config(vehicle_id)
	if vehicle_id not in VEHICLES or preset_index < 0 or preset_index >= names(vehicle_id).size():
		return result
	var changes: Dictionary = TUNING[vehicle_id][preset_index]
	for property: String in changes:
		result.set(property, changes[property])
	if vehicle_id == "hovercraft":
		# Preserve the chosen Slide 5 snapshot and identity for comparison.
		result.profile_name = "%s / %s" % [result.profile_name, "Slide 5" if preset_index == 0 else HOVER_LABELS[preset_index]]
		result.version += "-hover-slide-5" if preset_index == 0 else "-hover-slide5-%d" % preset_index
	elif vehicle_id == "kart":
		# Preserve Brake turn 5's complete snapshot and identity.
		result.profile_name = "%s / %s" % [result.profile_name, "Brake turn 5" if preset_index == 0 else KART_LABELS[preset_index]]
		result.version += "-kart-brake-5" if preset_index == 0 else "-kart-brake5-turn-%d" % preset_index
	else:
		result.profile_name = "%s / %s" % [result.profile_name, LABELS[preset_index]]
		result.version += "-test-%d" % (preset_index + 1)
	return result
