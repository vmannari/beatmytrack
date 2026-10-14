class_name TrackTheme
extends RefCounted
## Allowlisted original art palettes shared by native scenery and creator previews.
## Winter asphalt uses the canonical icy-road traction defined in NativeTrack.

const IDS: Array[String] = ["pine", "desert", "night_city", "winter", "storm"]
const PINE: Array[Color] = [Color("343638"), Color("606b36"), Color("b49b70"), Color("32565e"), Color("717b72"), Color("d9d2b9"), Color("577c7e"), Color("786f5c")]
const DESERT: Array[Color] = [Color("7c6b51"), Color("c5a16b"), Color("c1a478"), Color("3b6165"), Color("9a8870"), Color("c7bc9e"), Color("718c85"), Color("948063")]


static func normalized(theme: String) -> String:
	return theme if theme in IDS else "pine"


static func title(theme: String) -> String:
	match normalized(theme):
		"night_city": return "Night"
		"winter": return "Winter"
		"storm": return "Storm"
		"desert": return "Desert"
	return "Grass"


static func palette(theme: String) -> Array[Color]:
	match normalized(theme):
		"night_city": return [Color("343943"), Color("555965"), Color("817a6c"), Color("24394b"), Color("737982"), Color("c3c8cd"), Color("486779"), Color("686575")]
		"winter": return [Color("657f95"), Color("b5c2cd"), Color("c5cdd0"), Color("41677c"), Color("a3b2bb"), Color("edf2f4"), Color("9bbecb"), Color("a0a8b0")]
		"storm": return [Color("37393a"), Color("566549"), Color("92846b"), Color("2c4959"), Color("687783"), Color("c0c7ca"), Color("4d7383"), Color("6f7163")]
		"desert": return DESERT.duplicate()
	return PINE.duplicate()


static func foliage(theme: String) -> Color:
	match normalized(theme):
		"night_city": return Color("354b48")
		"winter": return Color("b5cfce")
		"storm": return Color("304a40")
		"desert": return Color("646950")
	return Color("30432c")


static func stone(theme: String) -> Color:
	match normalized(theme):
		"night_city": return Color("858995")
		"winter": return Color("b4c3ce")
		"desert": return Color("a88a67")
	return Color("77776b")


static func apply_lighting(theme: String, environment: Environment, light: DirectionalLight3D) -> void:
	environment.fog_enabled = false
	environment.background_mode = Environment.BG_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	if theme != "storm": environment.sky = null
	light.rotation_degrees = Vector3(-58,-35,0)
	light.shadow_opacity = 1.0
	var night: bool = normalized(theme) == "night_city"
	environment.ambient_light_color = Color("7288b0") if night else Color("bac8ce")
	environment.ambient_light_energy = 0.045 if night else 0.35
	light.light_color = Color("8299cc") if night else Color("e7f2ff") if theme == "winter" else Color("fff1d8")
	light.light_energy = 0.025 if night else 0.50 if theme == "storm" else 1.0
	if theme == "winter":
		light.rotation_degrees = Vector3(-34,-55,0)
		light.shadow_opacity = 0.68
		light.light_color = Color("ffe3be")
		light.light_energy = 1.12
		environment.ambient_light_color = Color("879ec2")
		environment.ambient_light_energy = 0.48
		var sky := Sky.new()
		var material := ShaderMaterial.new()
		material.shader = preload("res://track/winter_reflection_sky.gdshader")
		sky.sky_material = material
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		sky.process_mode = Sky.PROCESS_MODE_QUALITY
		environment.sky = sky
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.fog_enabled = true
		environment.fog_density = 0.0011
		environment.fog_light_color = Color("bacbdf")
		environment.fog_light_energy = 0.45
		environment.fog_sun_scatter = 0.05
	# Grass: warm sunlight against the broad, deeper cloud projections.
	if theme in ["pine", "desert"]:
		light.light_energy = 1.32
		light.light_color = Color("ffedce")
	if theme == "desert":
		# Sun-baked daylight, with warm open shade rather than a sunset/haze pass.
		light.rotation_degrees = Vector3(-46,-48,0)
		light.shadow_opacity = 0.90
		environment.ambient_light_color = Color("c5b9a4")
		environment.ambient_light_energy = 0.30
	if theme == "storm":
		environment.sky = preload("res://track/storm_sky.tres")
		environment.background_mode = Environment.BG_SKY
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.ambient_light_color = Color("93a9bd")
		environment.ambient_light_energy = 0.42
		light.light_color = Color("c7d8ed")
