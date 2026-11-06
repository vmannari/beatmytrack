extends SceneTree
const PRUNE = preload("res://track/surface_shader_pruning.gd")
var checks: int = 0
var failures: int = 0
const NAMES: Array[String] = ["fixed_test"]
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var header := "const bool fixed_test = false;\n"
	var body := "RADIANCE = vec4(1.0);"
	var cases: Array = [
		["if (fixed_test) {"+body+"} else { ALBEDO = vec3(0.2); }","if (fixed_test) {} else { ALBEDO = vec3(0.2); }"],
		["if (fixed_test && (other || third)) {"+body+"}","if (fixed_test && (other || third)) {}"],
		["if (fixed_test) {if (other) {"+body+"}}","if (fixed_test) {}"],
		["if (fixed_test) {/* } é */ "+body+"}","if (fixed_test) {}"],
		["if (fixed_test) {"+body+"} if (fixed_test) {"+body+"}","if (fixed_test) {} if (fixed_test) {}"]]
	for pair: Array in cases:
		var source: String = header+pair[0]
		var result: String = PRUNE.reduce(source,NAMES)
		check(result == header+pair[1],"false guard preserves surrounding code")
		check(PRUNE.reduce(result,NAMES) == result,"pruning is idempotent")
	for condition: String in ["!fixed_test","fixed_test || other","fixed_test && other || third","fixed_test && other ? a : b","fixed_test ^^ other","other && fixed_test","(fixed_test)"]:
		var source: String = header+"if ("+condition+") {"+body+"}"
		check(PRUNE.reduce(source,NAMES) == source,"active or unsupported condition stays exact: "+condition)
	for source: String in ["",header+"if (fixed_test) "+body,header+"if (fixed_test) {"+body,
		header+"void helper(bool fixed_test) {if (fixed_test) {"+body+"}}",
		header+"void helper() {bool fixed_test = true; if (fixed_test) {"+body+"}}",
		header+"void helper() {bool other = true, fixed_test = true; if (fixed_test) {"+body+"}}",
		header+"void helper() {bool other = helper(), fixed_test = true; if (fixed_test) {"+body+"}}",
		"void helper() {\n"+header+"if (fixed_test) {"+body+"}}",
		header+"#define fixed_test other\nif (fixed_test) {"+body+"}",
		header+"if (fixed_test) {\n#define EXTERNAL 1\n"+body+"}",
		"// "+header+"if (fixed_test) {"+body+"}",
		"/* "+header+"*/ if (fixed_test) {"+body+"}"]:
		check(PRUNE.reduce(source,NAMES) == source,"empty, ambiguous, local and preprocessor cases stay exact")
	var unknown := "const bool other = false;\nif (other) {"+body+"}"
	check(PRUNE.reduce(unknown,NAMES) == unknown,"unknown constants stay exact")
	var true_source := "const bool fixed_test = true;\nif (!fixed_test) {"+body+"}"
	check(PRUNE.reduce(true_source,NAMES) == "const bool fixed_test = true;\nif (!fixed_test) {}","negated true guard is unreachable")
	var names: Array[String] = SurfaceShaderVariants.FLAGS.duplicate()
	for flag: String in SurfaceShaderVariants.MATERIAL_FLAGS: names.append("fixed_"+flag)
	var compatibility: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	for folded: bool in [false,true]:
		for icy: bool in [false,true]:
			var material := ShaderMaterial.new()
			material.shader = load("res://track/creator_road.gdshader")
			material.set_shader_parameter("icy_road",icy)
			material.set_shader_parameter("winter_snow",not icy)
			material.set_shader_parameter("asphalt_surface",true)
			SurfaceShaderVariants.specialize(material,false,folded)
			check(material.shader.code.contains("RADIANCE =") == (not compatibility or not folded or icy),"actual icy flag controls radiance, independently of snow flag")
			var copy: ShaderMaterial = material.get_meta("surface_dynamic_material").duplicate()
			SurfaceShaderVariants.specialize(copy,true,folded)
			check(copy.shader == material.shader,"prepared and fresh paths share the same result")
	print("SURFACE_SHADER_PRUNING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
