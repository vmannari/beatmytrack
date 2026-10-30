extends SceneTree
## Isolated persistence, staged UI, native layouts and actual race lifecycle.
const GRAPHICS = preload("res://presentation/graphics_preferences.gd")
const GAME = preload("res://core/game.gd")
const SCENE = preload("res://core/game.tscn")
var checks: int = 0
var failures: int = 0
var output: String
var records: LocalRecords

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	for frame: int in range(8): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> Image:
	await settle()
	if DisplayServer.get_name() == "headless": return null
	var picture: Image = root.get_texture().get_image()
	picture.save_png(output.path_join(label+".png"))
	return picture

func run() -> void:
	print("AUDIT_PID ",OS.get_process_id())
	var audit_config := ConfigFile.new()
	audit_config.set_value("backend","url","")
	assert(audit_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	output = ProjectSettings.globalize_path("res://../build/re-audit-2026-10-27/outputs/test_graphics_settings/"+DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://graphics_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	records = LocalRecords.new(directory.path_join("records.json"))
	persistence()
	policies()
	await settings_ui()
	await races()
	for filename: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("GRAPHICS_SETTINGS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func persistence() -> void:
	check(GRAPHICS.preferences({}) == GRAPHICS.DEFAULTS,"existing profiles retain all automatic graphics defaults")
	records.settings = {"favorites":["ellipse"],"simple_car_models":true}
	check(records.save_records() == OK,"old profile saves without new fields")
	for field: String in GRAPHICS.DEFAULTS:
		for value: String in GRAPHICS.OPTIONS[field]:
			records.settings[field] = value
			check(records.save_records() == OK,"graphics choice saves: "+field+"="+value)
			var reopened := LocalRecords.new(records.path)
			reopened.load_records()
			check(reopened.settings.get(field) == value and reopened.settings.get("favorites") == ["ellipse"],"graphics choice reloads with unrelated settings: "+field+"="+value)
		for invalid: Variant in [null,true,1,0.5,[],{},"invalid"]:
			var document: Dictionary = {"schema":LocalRecords.SCHEMA,"records":{},"settings":{field:invalid}}
			check(LocalRecords._normalize(document).is_empty(),"reject malformed graphics choice: "+field+"="+str(invalid))
	var committed: Dictionary = records.settings.duplicate(true)
	records.settings.shadow_quality = "invalid"
	check(records.save_records() == ERR_INVALID_DATA and records.settings == committed,"failed graphics save restores committed choices")

func policies() -> void:
	for safe_depth: bool in [false,true]:
		for mode: String in GRAPHICS.OPTIONS.anti_aliasing:
			var aa: Dictionary = GRAPHICS.antialiasing(mode,Viewport.MSAA_2X,safe_depth)
			if safe_depth:
				check(aa.msaa == Viewport.MSAA_DISABLED and aa.fxaa == (mode != "off"),"Adreno depth protection: "+mode)
			else:
				check(aa.fxaa == (mode == "fxaa"),"explicit FXAA policy: "+mode)
	check(GRAPHICS.antialiasing("auto",Viewport.MSAA_4X,false).msaa == Viewport.MSAA_4X,"Auto retains incoming MSAA")
	for theme: String in ["pine","desert","winter","storm","night_city"]:
		for value: String in GRAPHICS.OPTIONS.render_resolution:
			var base: float = GRAPHICS.resolution(value,0.667)
			var scale: float = GAME.render_scale_for(theme,base,true,Vector2i(3840,2160))
			check(scale > 0 and 3840.0*2160.0*scale*scale <= GAME.MOBILE_WORLD_PIXEL_BUDGET+0.01,"mobile world budget survives graphics choice: "+theme+"="+value)

func select(page: SettingsPage, field: String, value: String) -> void:
	var choice: OptionButton = page.find_child("GraphicsChoice_"+field,true,false)
	for index: int in range(choice.item_count):
		if choice.get_item_metadata(index) != value: continue
		choice.select(index)
		choice.item_selected.emit(index)
		return
	check(false,"missing graphics option "+value)

func settings_ui() -> void:
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = records
	app.library = TrackLibrary.new(records.path.get_base_dir())
	app.cloud_root_override = records.path.get_base_dir().path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.call("_show_screen","settings")
	await settle()
	var page: SettingsPage = app.root_ui.find_child("SettingsPage",true,false)
	page._show_section("graphics")
	await settle()
	var saved: Dictionary = records.settings.duplicate(true)
	select(page,"shadow_quality","off")
	select(page,"render_resolution","50")
	select(page,"anti_aliasing","fxaa")
	check(records.settings == saved,"graphics choices stage until Apply")
	page._show_section("audio")
	page._show_section("graphics")
	check(page.draft_graphics == {"shadow_quality":"off","render_resolution":"50","anti_aliasing":"fxaa"},"graphics drafts survive category changes")
	check(page._apply(),"Apply commits graphics together")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	check(GRAPHICS.preferences(reopened.settings) == page.draft_graphics,"Apply survives reopening local records")
	var saved_path: String = records.path
	records.path = saved_path.path_join("missing/records.json")
	select(page,"shadow_quality","high")
	check(not page._apply() and records.settings.shadow_quality == "off" and page.draft_graphics.shadow_quality == "high","failed Apply keeps the committed setting and retryable draft")
	records.path = saved_path
	page._reset()
	check(page.draft_graphics == GRAPHICS.DEFAULTS and not page.draft_simple_models and records.settings.shadow_quality == "off","Reset graphics stages defaults and detailed cars")
	check(page._apply() and records.settings.favorites == ["ellipse"],"Reset graphics preserves favorites")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		var scroll: ScrollContainer = page.find_child("SettingsScroll",true,false)
		scroll.scroll_vertical = 0
		await capture("graphics-"+str(dimensions.x))
		var panel: Control = page.find_child("SettingsContent",true,false)
		check(root.get_visible_rect().encloses(panel.get_global_rect()),"graphics panel fits "+str(dimensions))
		for field: String in GRAPHICS.DEFAULTS:
			var choice: OptionButton = page.find_child("GraphicsChoice_"+field,true,false)
			scroll.ensure_control_visible(choice)
			await settle()
			check(choice.size.y >= 52 and scroll.get_global_rect().encloses(choice.get_global_rect()),"reachable graphics choice "+field+" "+str(dimensions))
			if field == "shadow_quality" and DisplayServer.get_name() != "headless":
				root.grab_focus()
				await settle()
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.position = choice.get_global_rect().get_center()
				event.pressed = true
				root.push_input(event,true)
				event = event.duplicate() as InputEventMouseButton
				event.pressed = false
				root.push_input(event,true)
				await settle()
				check(choice.get_popup().visible,"mouse opens graphics menu "+str(dimensions))
				await capture("graphics-popup-"+str(dimensions.x))
				choice.get_popup().grab_focus()
				choice.get_popup().set_focused_item(0)
				await settle()
				var key := InputEventKey.new()
				key.keycode = KEY_UP
				key.physical_keycode = KEY_UP
				key.pressed = true
				Input.parse_input_event(key)
				await process_frame
				key = key.duplicate() as InputEventKey
				key.pressed = false
				Input.parse_input_event(key)
				await process_frame
				key = key.duplicate() as InputEventKey
				key.keycode = KEY_ENTER
				key.physical_keycode = KEY_ENTER
				key.pressed = true
				Input.parse_input_event(key)
				await process_frame
				key = key.duplicate() as InputEventKey
				key.pressed = false
				Input.parse_input_event(key)
				await settle()
				check(page.draft_graphics.shadow_quality == "high" and records.settings.shadow_quality == "auto","keyboard chooses the last shadow option without saving "+str(dimensions))
				choice.get_popup().hide()
				select(page,"shadow_quality","auto")
		var toggle: CheckButton = page.find_child("SimpleCarModels",true,false)
		scroll.ensure_control_visible(toggle)
		await capture("graphics-bottom-"+str(dimensions.x))
		check(toggle.size.y >= 52 and scroll.get_global_rect().encloses(toggle.get_global_rect()),"existing car detail remains reachable "+str(dimensions))
		var apply: Button = page.find_child("ApplySettings",true,false)
		check(root.get_visible_rect().encloses(apply.get_global_rect()),"Apply remains visible "+str(dimensions))
	app.free()
	await settle()

func races() -> void:
	root.size = Vector2i(1280,720)
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
	var shadow_view: SubViewport
	var original_shadow: Image
	var low_shadow: Image
	var high_shadow: Image
	if DisplayServer.get_name() != "headless":
		shadow_view = shadow_fixture()
		await settle()
		original_shadow = shadow_view.get_texture().get_image()
		original_shadow.save_png(output.path_join("shadow-original.png"))
	var prior_scale: float = root.scaling_3d_scale
	var prior_aa: Viewport.MSAA = root.msaa_3d
	var snapshots: Array = []
	var pictures: Array[Image] = []
	for profile: Dictionary in [GRAPHICS.DEFAULTS,{"shadow_quality":"off","render_resolution":"50","anti_aliasing":"off"},{"shadow_quality":"low","render_resolution":"75","anti_aliasing":"fxaa"},{"shadow_quality":"medium","render_resolution":"67","anti_aliasing":"msaa_2x"},{"shadow_quality":"high","render_resolution":"100","anti_aliasing":"msaa_4x"}]:
		records.settings.merge(profile,true)
		var game: Node = SCENE.instantiate()
		game.initial_track = track
		game.preference_records = records
		game.production_mode = true
		game.attempt_practice = true
		game.hitch_diagnostics_enabled = false
		root.add_child(game)
		game.paused = true
		game.set_process(false)
		game.set_physics_process(false)
		check(game.biome_light.shadow_enabled == (profile.shadow_quality != "off"),"race uses shadow choice "+profile.shadow_quality)
		check(is_equal_approx(root.scaling_3d_scale,GRAPHICS.resolution(profile.render_resolution,prior_scale)),"race uses chosen 3D resolution "+profile.render_resolution)
		var aa: Dictionary = GRAPHICS.antialiasing(profile.anti_aliasing,prior_aa,false)
		check(root.msaa_3d == aa.msaa and is_instance_valid(game.mobile_world_aa) == aa.fxaa,"race uses AA choice "+profile.anti_aliasing)
		game._update_weather()
		check(game.biome_light.shadow_enabled == (profile.shadow_quality != "off"),"biome refresh retains shadow preference")
		var snapshot: Array = game.sim.state.snapshot()
		snapshots.append(snapshot)
		game.call("_process",0.0)
		check(game.sim.state.snapshot() == snapshot and game.track_session.target_laps == RaceRules.LAPS,"graphics keep canonical state and five laps")
		pictures.append(await capture("race-"+profile.shadow_quality+"-"+profile.anti_aliasing))
		if shadow_view != null:
			var image: Image = shadow_view.get_texture().get_image()
			image.save_png(output.path_join("shadow-"+profile.shadow_quality+".png"))
			if profile.shadow_quality == "low": low_shadow = image
			if profile.shadow_quality == "high": high_shadow = image
		game.free()
		check(is_equal_approx(root.scaling_3d_scale,prior_scale) and root.msaa_3d == prior_aa,"race exit restores viewport settings")
		await settle()
	check(snapshots.all(func(value: Array) -> bool: return value == snapshots[0]),"every graphics profile starts with exact identical canonical state")
	if DisplayServer.get_name() != "headless":
		await settle()
		var restored_shadow: Image = shadow_view.get_texture().get_image()
		restored_shadow.save_png(output.path_join("shadow-restored.png"))
		var shadow_changes: int = pixel_changes(low_shadow,high_shadow,1.0/255.0)
		var restored_changes: int = pixel_changes(original_shadow,restored_shadow,1.0/255.0)
		check(shadow_changes > 100,"Low and High change the actual shared directional shadow map")
		check(restored_changes == 0,"leaving High restores original shadow rendering for other viewports")
		print("SHADOW_PIXELS low_high=",shadow_changes," restored=",restored_changes)
		shadow_view.free()
		var differences: int = 0
		for y: int in range(100,500,2):
			for x: int in range(150,1100,2):
				if pictures[0].get_pixel(x,y) != pictures[1].get_pixel(x,y): differences += 1
		check(differences > 100,"graphics choices alter actual native race pixels")

func pixel_changes(before: Image, after: Image, tolerance: float) -> int:
	var changed: int = 0
	for y: int in range(before.get_height()):
		for x: int in range(before.get_width()):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > tolerance: changed += 1
	return changed

func shadow_fixture() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.own_world_3d = true
	viewport.positional_shadow_atlas_size = 1024
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	world_environment.environment.background_mode = Environment.BG_COLOR
	world_environment.environment.background_color = Color("172229")
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment.ambient_light_color = Color.WHITE
	world_environment.environment.ambient_light_energy = 0.15
	world_environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	viewport.add_child(world_environment)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20,20)
	floor.mesh = plane
	viewport.add_child(floor)
	var cube := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1,4,1)
	cube.mesh = box
	cube.position.y = 2.0
	cube.rotation.y = 0.17
	viewport.add_child(cube)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-135,0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.0
	camera.far = 50.0
	camera.position = Vector3(10,14,10)
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)
	return viewport
