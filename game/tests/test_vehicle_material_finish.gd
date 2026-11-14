extends SceneTree
## VQR03: real material bindings, saved pigment and per-view glass isolation.
const FINISH = preload("res://vehicle/compact_finish.gd")
const ELECTRIC_GLASS = preload("res://vehicle/electric_glass.gdshader")
const WINDOW_GLASS = preload("res://vehicle/window_reflection.gdshader")
const RACE_GLASS = preload("res://race/electric_glass_lighting.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MATERIAL_FINISH_FAIL ",label)

func finite_response(material: StandardMaterial3D) -> bool:
	for value: float in [material.roughness,material.metallic,material.metallic_specular,material.clearcoat,material.clearcoat_roughness]:
		if not is_finite(value) or value < 0.0 or value > 1.0: return false
	return true

func opaque(material: StandardMaterial3D) -> bool:
	return material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(material.albedo_color.a,1.0)

func glass_bindings(car: CarVisual) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material != null and material.shader in [ELECTRIC_GLASS,WINDOW_GLASS]:
				result.append({"mesh":mesh,"surface":surface,"material":material})
	return result

func is_bound(car: CarVisual, material: Material) -> bool:
	for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			if mesh.get_active_material(surface) == material: return true
	return false

func configuration_hashes() -> Dictionary:
	var result: Dictionary = {}
	for file: String in DirAccess.get_files_at("res://resources/cars"):
		if file.ends_with(".tres"):
			var path: String = "res://resources/cars/"+file
			result[path] = FileAccess.get_sha256(path)
	for path: String in HandlingSelection.PROFILE_PATHS:
		result[path] = FileAccess.get_sha256(path)
	return result

func create_car(id: String, livery: Dictionary) -> CarVisual:
	var car := CarVisual.new()
	car.vehicle_id = id
	car.livery = livery.duplicate(true)
	car.cache_rest_pose = false
	root.add_child(car)
	while not car.model_ready: await process_frame
	return car

func run() -> void:
	# This gate checks current source, independent of pending prepared refreshes.
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var config_before: Dictionary = configuration_hashes()
	var pigment := Color("9a3e50")
	var finishes: Dictionary = {"paint":FINISH.paint(pigment),"rubber":FINISH.rubber(pigment),
		"alloy":FINISH.alloy(pigment),"glass":FINISH.glass(pigment),
		"industrial":FINISH.industrial_paint(pigment),"polymer":FINISH.polymer(pigment)}
	for role: String in finishes:
		var material: StandardMaterial3D = finishes[role]
		check(opaque(material),role+" opaque")
		check(finite_response(material),role+" finite physical response")
		check(material.albedo_color == pigment,role+" preserves caller pigment")
		check(material.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX,role+" enables GGX specular")
	check(finishes.glass.roughness < finishes.paint.roughness and finishes.paint.roughness < finishes.rubber.roughness,"glass/paint/rubber roughness separates surfaces")
	check(finishes.polymer.roughness > finishes.industrial.roughness and finishes.industrial.clearcoat < finishes.paint.clearcoat,"seat polymer and industrial paint separate")
	check(finishes.alloy.metallic > finishes.paint.metallic and finishes.rubber.metallic == 0.0,"metal versus dielectric response")
	check(finishes.glass.cull_mode == BaseMaterial3D.CULL_DISABLED,"opaque glazing remains double sided")
	check(FINISH.glass(Color(pigment,0.2)).albedo_color == pigment,"glass rejects accidental transparency without changing RGB")
	var alpha_write := RegEx.new()
	alpha_write.compile("\\bALPHA\\s*=")
	for shader: Shader in [WINDOW_GLASS,ELECTRIC_GLASS]:
		check(alpha_write.search(shader.code) == null,"analytic glass does not enter transparent pipeline "+shader.resource_path)
	var cars: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var user_livery: Dictionary = VehicleLivery.defaults(id)
		user_livery.colors = {"body":"9a3e50","accent":"e4b74c","detail":"507794"}
		var saved: PackedByteArray = var_to_bytes(user_livery)
		var car: CarVisual = await create_car(id,user_livery)
		cars[id] = car
		check(var_to_bytes(user_livery) == saved and var_to_bytes(car.livery) == saved,id+" saved pigment unchanged during construction")
		for role: String in car.paint_materials:
			var material: StandardMaterial3D = car.paint_materials[role]
			check(material.albedo_color == Color(str(user_livery.colors[role])) and opaque(material),id+" opaque exact user pigment "+role)
			check(finite_response(material),id+" finite finish "+role)
		check(car.paint_materials.body != car.paint_materials.accent,id+" body/accent materials separated")
		var bindings: Array[Dictionary] = glass_bindings(car)
		if id in ["compact","electric","hovercraft"]:
			check(not bindings.is_empty(),id+" native analytic glass is bound")
			ShowroomStudio._studio_glass(car,{})
			for binding: Dictionary in bindings:
				var active: ShaderMaterial = binding.mesh.get_active_material(binding.surface)
				check(active != binding.material and active.get_shader_parameter("studio_mode") == true,id+" showroom owns glass copy")
				check(binding.material.get_shader_parameter("studio_mode") != true,id+" showroom preserves source/race glass")
		if id == "super_rally":
			var materials: Dictionary = SuperRallyModel._materials(car)
			check(is_bound(car,materials.glass),"Challenger opaque glass is actually bound")
			check(opaque(materials.glass) and materials.glass.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX,"Challenger glass opacity and active specular")
			check(materials.glass != materials.paint and materials.rubber != materials.paint and materials.chrome != materials.paint,"Challenger material roles separated")
		if id == "forklift":
			check(is_equal_approx(car.paint_materials.body.roughness,finishes.industrial.roughness),"Forklift uses industrial finish")
			check(is_equal_approx(car.paint_materials.body.clearcoat,finishes.industrial.clearcoat),"Forklift retains restrained coating")
	# A fresh race car must remain independent of an already styled showroom.
	var race: CarVisual = await create_car("electric",VehicleLivery.defaults("electric"))
	var race_bindings: Array[Dictionary] = glass_bindings(race)
	check(not race_bindings.is_empty(),"fresh race has electric glass")
	check(race.paint_materials.body != cars.electric.paint_materials.body,"per-car user paint isolation")
	var showroom_color: Color = cars.electric.paint_materials.body.albedo_color
	var race_livery: Dictionary = VehicleLivery.defaults("electric")
	race_livery.colors.body = "164b86"
	race.apply_livery(race_livery)
	check(cars.electric.paint_materials.body.albedo_color == showroom_color,"race repaint preserves showroom pigment")
	var lighting = RACE_GLASS.new()
	lighting.configure(race,"night_city")
	for binding: Dictionary in race_bindings:
		var active: ShaderMaterial = binding.mesh.get_active_material(binding.surface)
		check(active != binding.material and active.get_shader_parameter("night_mode") == true,"night glass owns copy")
		check(active.get_shader_parameter("studio_mode") != true,"race uses world reflection instead of studio")
		check(binding.material.get_shader_parameter("night_mode") != true and binding.material.get_shader_parameter("studio_mode") != true,"night/studio leave shared source untouched")
	lighting.reset()
	for binding: Dictionary in race_bindings:
		check(binding.mesh.get_active_material(binding.surface) == binding.material,"day reset restores original glass binding")
	check(configuration_hashes() == config_before,"all car and Compact profile files unchanged by model/material operations")
	race.free()
	for car: CarVisual in cars.values(): car.free()
	await process_frame
	print("VEHICLE_MATERIAL_FINISH: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
