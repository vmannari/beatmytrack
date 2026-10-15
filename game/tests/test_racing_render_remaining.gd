extends SceneTree
## Exact original/new render state, redraw/upload counts and component timings.
var checks: int = 0
var failures: int = 0
var output: String = "res://../build/racing-render-remaining-2026-10-14"
var report: Dictionary = {}
var originals: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)

func original(name: String) -> GDScript:
	if originals.has(name): return originals[name]
	var source: String = FileAccess.get_file_as_string("res://tests/fixtures/racing_render_before/"+name.replace("/","_")+".txt")
	source = source.substr(source.find("\n")+1) # Omit only the registered class name.
	if name.ends_with("native_track_visual.gd"):
		# The original callback's self-typed editor signals belong to its own
		# registered class. Exercise the archived race callback on a plain host.
		source = "extends Node3D\nvar light_instances: Array[Node3D] = []\nvar theme_id: String = 'pine'\n"+source.substr(source.find("func update_light_props("),source.find("func _build_kerbs(")-source.find("func update_light_props("))
	if name.ends_with("playground_hud.gd"):
		# Retain the registered HUD type required by the unchanged pause menu.
		# Original callbacks override the current callbacks; model fields/layout
		# are identical and the archived callback still forces map redraws.
		source = "extends PlaygroundHUD\n"+source.substr(source.find("func _ready()"))
	if name.ends_with("breakable_prop_visual.gd"):
		source = source.replace("\t\t\tnode.multimesh.set_instance_transform(i,pose)","\t\t\tobserved_uploads += 1\n\t\t\tnode.multimesh.set_instance_transform(i,pose)")+"\nstatic var observed_uploads: int = 0\n"
	if name.ends_with("storm_weather.gd"): source = count_lens_uploads(source)
	var script := GDScript.new(); script.source_code = source
	check(script.reload() == OK,"original archived "+name+" parses")
	originals[name] = script
	return script

func count_lens_uploads(source: String) -> String:
	return source.replace("lens_material.set_shader_parameter(","_observed_parameter(lens_material,").replace("wet_glass_material.set_shader_parameter(","_observed_parameter(wet_glass_material,")+"\nvar observed_uploads: int = 0\nfunc _observed_parameter(material: ShaderMaterial, key: String, value: Variant) -> void:\n\tobserved_uploads += 1\n\tmaterial.set_shader_parameter(key,value)\n"

func instrument_storm() -> GDScript:
	var source: String = FileAccess.get_file_as_string("res://track/storm_weather.gd")
	var script := GDScript.new(); script.source_code = count_lens_uploads(source.substr(source.find("\n")+1))
	check(script.reload() == OK,"instrumented current rain parses")
	return script

func instrument_debris() -> GDScript:
	var source: String = FileAccess.get_file_as_string("res://track/breakable_prop_visual.gd")
	source = source.substr(source.find("\n")+1)
	source = source.replace("\t\t\tnode.multimesh.set_instance_transform(i,pose)","\t\t\tobserved_uploads += 1\n\t\t\tnode.multimesh.set_instance_transform(i,pose)")+"\nstatic var observed_uploads: int = 0\n"
	var script := GDScript.new(); script.source_code = source
	check(script.reload() == OK,"instrumented current debris parses")
	return script

func shaders() -> void:
	var before: GDScript = original("track/surface_shader_variants.gd")
	var binding := NativeTrackVisual.new()
	for theme: String in ["pine","winter","desert","storm","night_city"]:
		binding.theme_id = theme
		for shader: Shader in [preload("res://track/terrain.gdshader"),preload("res://track/creator_road.gdshader"),preload("res://track/winter_bank.gdshader"),preload("res://track/ground.gdshader")]:
			for packed: bool in [false,true]:
				var a := ShaderMaterial.new(); a.shader = shader; binding._bind_grass(a)
				a.set_shader_parameter("terrain_region_channel",-1)
				a.set_shader_parameter("terrain_packed",packed)
				a.set_shader_parameter("terrain_slots",Vector4i(0,1,3,7))
				var b: ShaderMaterial = a.duplicate()
				before.specialize(a); SurfaceShaderVariants.specialize(b)
				check(a.shader.code == b.shader.code,"exact original shader code for "+theme+"/"+shader.resource_path+"/"+str(packed))
				var c: ShaderMaterial = b.get_meta("surface_dynamic_material").duplicate()
				SurfaceShaderVariants.specialize(c)
				check(c.shader == b.shader,"prepared role reuses the immutable shader")
				check((c.get_meta("surface_dynamic_material") as ShaderMaterial).shader == shader,"each material retains its own dynamic source")
	var base := ShaderMaterial.new(); base.shader = preload("res://track/terrain.gdshader"); binding._bind_grass(base)
	base.set_shader_parameter("terrain_region_channel",3)
	var timings: Array[Dictionary] = []
	for cached: bool in [false,true,false,true]:
		var start: int = Time.get_ticks_usec()
		for index: int in range(80):
			var surface: ShaderMaterial = base.duplicate()
			if cached: SurfaceShaderVariants.specialize(surface)
			else: before.specialize(surface)
		timings.append({"prepared":cached,"calls":80,"total_ms":(Time.get_ticks_usec()-start)/1000.0})
	print("RENDER_SHADER_PREPARATION ",timings)
	report.shader_preparation = timings
	# Mutation, explicit cache clearing and eviction must never return stale roles.
	for index: int in range(80):
		var a: ShaderMaterial = base.duplicate()
		a.shader = a.shader.duplicate()
		a.shader.code += "\n// distinct source "+str(index)
		a.set_shader_parameter("terrain_uniform_enabled",index%2 == 1)
		a.set_shader_parameter("terrain_region_channel",index%4)
		a.set_shader_parameter("terrain_slots",Vector4i(index%8,(index+1)%8,(index+2)%8,(index+3)%8))
		a.set_shader_parameter("terrain_packed",true)
		var b: ShaderMaterial = a.duplicate()
		before.specialize(a); SurfaceShaderVariants.specialize(b)
		check(a.shader.code == b.shader.code,"channel/remap/role mutation retains exact shader code")
	check(SurfaceShaderVariants.cache.size() <= 64 and SurfaceShaderVariants.prepared_keys.size() <= 64,"both shader/lookup populations stay bounded")
	SurfaceShaderVariants.cache.clear()
	var expected: ShaderMaterial = base.duplicate(); var restored: ShaderMaterial = base.duplicate()
	before.specialize(expected); SurfaceShaderVariants.specialize(restored)
	check(expected.shader.code == restored.shader.code,"explicit shader eviction cannot return a stale preparation alias")
	var include: ShaderInclude = SurfaceShaderVariants.INCLUDES["res://track/terrain.gdshaderinc"]
	var original_code: String = include.code
	include.code += "\n// include mutation proof\n"
	expected = base.duplicate(); restored = base.duplicate()
	before.specialize(expected); SurfaceShaderVariants.specialize(restored)
	check(expected.shader.code == restored.shader.code,"changed include content fences prepared source roles")
	include.code = original_code
	binding.free()

func make_props(parent: Node3D) -> void:
	for index: int in range(3):
		var node := Node3D.new(); parent.add_child(node)
		node.position = Vector3(index*3,0.014,0); node.rotation.y = 0.4
		node.set_meta("prop_origin",node.position)
		if index < 2: BreakablePropVisual.build(node,parent,"hay_bale" if index == 0 else "crate",1.0)
		else: VisualGeometry.box(node,Vector3.ONE,Vector3.UP*0.5,VisualGeometry.material(Color("815338")))
		parent.light_instances.append(node)
	BreakablePropVisual.ensure_debris(parent)

func prop_signature(parent: Node3D) -> Array:
	var result: Array = []
	for node: Node3D in parent.light_instances:
		result.append([node.transform,node.visible])
		for child: Node3D in node.get_children(): result.append([child.transform,child.visible])
	return result

func props() -> void:
	var before: Node3D = original("track/native_track_visual.gd").new()
	var after := NativeTrackVisual.new(); root.add_child(before); root.add_child(after)
	make_props(before); make_props(after)
	var state := VehicleState.new()
	var snapshot: Array = state.snapshot()
	for phase: int in range(12):
		state.light_props = [[phase*0.01,1,0.2,-0.1,0.3],[4,phase*0.01,0.1,0.2,-0.2],[6,0,0,0,phase*0.1]]
		state.prop_destruction = [[1.0-phase*0.09,false,0],[1.0-phase*0.08,false,0]]
		before.update_light_props(state); after.update_light_props(state)
		check(prop_signature(before) == prop_signature(after),"all damage/movement phases preserve exact node transforms/visibility")
		state.light_props[0][0] += 0.25 # Same-tick, in-place canonical row edit.
		before.update_light_props(state); after.update_light_props(state)
		check(prop_signature(before) == prop_signature(after),"same-tick row edits cannot reuse stale prop state")
	var timings: Array[Dictionary] = []
	for parent: Node3D in [before,after,before,after]:
		var start: int = Time.get_ticks_usec()
		for index: int in range(2000): parent.update_light_props(state)
		timings.append({"prepared":parent==after,"calls":2000,"total_ms":(Time.get_ticks_usec()-start)/1000.0})
	report.resting_props = timings; print("RENDER_RESTING_PROPS ",timings)
	state.light_props.clear(); state.prop_destruction.clear()
	before.update_light_props(state); after.update_light_props(state)
	check(prop_signature(before) == prop_signature(after),"empty reset immediately restores original intact prop state")
	check(state.snapshot() == snapshot,"presentation does not mutate canonical fields")
	before.free(); after.free()
	var baseline: GDScript = original("track/breakable_prop_visual.gd")
	var current: GDScript = instrument_debris()
	var field := Node3D.new(); root.add_child(field); BreakablePropVisual.ensure_debris(field)
	for index: int in range(120): state.prop_fragments.append([BreakableProps.WOOD,index, index*0.2,0,0,0,0,0,0.3,0.2])
	current.update_debris(field,state)
	current.observed_uploads = 0; baseline.observed_uploads = 0
	for index: int in range(50): current.update_debris(field,state)
	check(current.observed_uploads == 0,"unchanged retained fragments make zero transform uploads")
	for index: int in range(50): baseline.update_debris(field,state)
	check(baseline.observed_uploads == 6000,"original 120-fragment fixture repeats 6000 uploads")
	state.prop_fragments[0][2] += 1
	current.update_debris(field,state)
	check(current.observed_uploads == 1,"in-place same-tick motion uploads exactly the changed fragment")
	var wood: MultiMeshInstance3D = field.get_node("WoodFragments")
	var replacement := MultiMesh.new()
	replacement.transform_format = MultiMesh.TRANSFORM_3D
	replacement.mesh = wood.multimesh.mesh
	wood.multimesh = replacement
	current.observed_uploads = 0; current.update_debris(field,state)
	check(current.observed_uploads == 120,"replacement mutable instance buffer receives all retained poses")
	state.prop_fragments.clear(); current.update_debris(field,state)
	check(wood.multimesh.instance_count == 0,"fragment reset clears the visible population immediately")
	field.free()

func shadows() -> void:
	var before: GDScript = original("track/contact_shading.gd")
	var parent := Node3D.new(); root.add_child(parent)
	var car := CarVisual.new(); car.vehicle_id = "kart"; parent.add_child(car)
	var old: MeshInstance3D = ContactShading.car_shadow(parent)
	var current: MeshInstance3D = ContactShading.car_shadow(parent)
	var state := VehicleState.new()
	for vehicle: String in VehicleCatalog.IDS:
		car.vehicle_id = vehicle
		for height: float in [0.0,0.3,1.5,2.5]:
			state.jump_height = height
			var retained: Array = state.snapshot()
			before.present_car(old,car,state,Vector2(3,-2),0.3,null,null)
			ContactShading.present_car(current,car,state,Vector2(3,-2),0.3,null,null)
			check(old.transform == current.transform and old.visible == current.visible and old.material_override.get_shader_parameter("strength") == current.material_override.get_shader_parameter("strength"),"exact contact volume/strength for "+vehicle+" at jump "+str(height))
			check(state.snapshot() == retained,"shadow updates preserve canonical state")
	parent.free()

func pixels(a: Image, b: Image) -> int:
	a.convert(Image.FORMAT_RGBA8); b.convert(Image.FORMAT_RGBA8)
	var aa: PackedByteArray = a.get_data(); var bb: PackedByteArray = b.get_data(); var maximum: int = 0
	for index: int in range(aa.size()): maximum = maxi(maximum,absi(int(aa[index])-int(bb[index])))
	return maximum

func capture(tag: String) -> Image:
	for index: int in range(5): await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	frame.save_png(output.path_join(tag+".png"))
	return frame

func graphics() -> void:
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json")))
	var before: CanvasLayer = original("ui/playground_hud.gd").new()
	var after := PlaygroundHUD.new()
	for hud: CanvasLayer in [before,after]:
		hud.config = load(HandlingSelection.PROFILE_PATHS[HandlingSelection.ORIGINAL_PLUS_INDEX]); hud.driver = DriverInput.new()
		hud.production_mode = true; hud.debug_enabled = false; root.add_child(hud)
		hud.set_track(track)
	var session := TrackSession.new(120,5)
	var state := VehicleState.new(); state.velocity = Vector2(0,12); state.position = track.spawn
	for hud: CanvasLayer in [before,after]: hud.update_values(state,DriveFrame.new(),0.1,false,false)
	for tick: int in [0,119,120,7199,7200,7210]:
		session.elapsed_ticks = tick
		before.show_session(session); after.show_session(session)
		check(before.race_timer.text == after.race_timer.text and before.lap_timer.text == after.lap_timer.text,"timer formatting and minute-boundary pixels retained")
	before.show(); after.hide(); var old_frame: Image = await capture("hud-before")
	before.hide(); after.show(); var new_frame: Image = await capture("hud-after")
	var maximum: int = pixels(old_frame,new_frame)
	report.pixel_proofs.append({"fixture":"HUD","max_delta":maximum})
	check(maximum == 0,"full HUD before/after pixels match exactly")
	var old_draws: Array[int] = [0]; var new_draws: Array[int] = [0]
	before.road_map.draw.connect(func() -> void: old_draws[0] += 1)
	after.road_map.draw.connect(func() -> void: new_draws[0] += 1)
	before.show(); after.show()
	for index: int in range(5): await RenderingServer.frame_post_draw
	old_draws[0] = 0; new_draws[0] = 0
	for index: int in range(24):
		before.update_values(state,DriveFrame.new(),0.1,false,false); after.update_values(state,DriveFrame.new(),0.1,false,false)
		await RenderingServer.frame_post_draw
	check(old_draws[0] > 0 and new_draws[0] == 0,"stationary player retains its map marker without repeated draws")
	report.stationary_map_callbacks = {"before":old_draws[0],"after":new_draws[0]}
	before.free(); after.free()
	var button := RewindHUDButton.new(); var old_button := RewindHUDButton.new()
	root.add_child(button); root.add_child(old_button)
	old_draws[0] = 0; new_draws[0] = 0
	old_button.draw.connect(func() -> void: old_draws[0] += 1)
	button.draw.connect(func() -> void: new_draws[0] += 1)
	button.set_race_state(false,3)
	for index: int in range(5): await RenderingServer.frame_post_draw
	old_draws[0] = 0; new_draws[0] = 0
	for index: int in range(24):
		old_button.queue_redraw(); button.set_race_state(false,3)
		await RenderingServer.frame_post_draw
	check(old_draws[0] == 24 and new_draws[0] == 0,"unchanged rewind eligibility removes all 24 forced button redraws")
	report.rewind_callbacks = {"before":old_draws[0],"after":new_draws[0]}
	button.set_race_state(true,2)
	check(button.disabled and button.race_remaining == 2,"rewind eligibility updates immediately on change")
	button.free(); old_button.free()
	var old: Control = original("track/storm_weather.gd").new(); var fresh: Control = instrument_storm().new()
	root.add_child(old); root.add_child(fresh); old.hide(); fresh.hide()
	for elapsed: float in [0.3,1.7,3.2,11.5,12.3]:
		for weather: Control in [old,fresh]:
			weather.elapsed = elapsed; weather._update_lens(); weather.queue_redraw()
		for index: int in range(6):
			check(old.lens_drops[index].position == fresh.lens_drops[index].position and old.lens_drops[index].size == fresh.lens_drops[index].size,"exact rain lens position/radius across hold/slip/reset")
			for name: String in ["fade","stretch","radius_px","shape_seed"]:
				check(old.lens_drops[index].material.get_shader_parameter(name) == fresh.lens_drops[index].material.get_shader_parameter(name),"exact lens material values")
		old.show(); fresh.hide(); old_frame = await capture("storm-"+str(elapsed)+"-before")
		old.hide(); fresh.show(); new_frame = await capture("storm-"+str(elapsed)+"-after")
		maximum = pixels(old_frame,new_frame)
		report.pixel_proofs.append({"fixture":"rain","elapsed":elapsed,"max_delta":maximum})
		check(maximum <= 2,"original rain/refraction/trail pixels retained")
		fresh.hide()
	old.observed_uploads = 0; fresh.observed_uploads = 0
	for index: int in range(24): old._update_lens(); fresh._update_lens()
	check(old.observed_uploads == 600 and fresh.observed_uploads == 0,"unchanged six lenses/glass remove 600 repeated shader writes")
	report.stationary_lens_uploads = {"before":old.observed_uploads,"after":fresh.observed_uploads}
	old.free(); fresh.free()

func run() -> void:
	root.size = Vector2i(1280,720)
	output = output.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	report = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"pixel_proofs":[],"note":"Isolated component checks/timings; no account, records, scoring or physical-phone FPS."}
	shaders(); props(); shadows()
	# A race can exit before a decorated HUD panel's initial deferred layout.
	var panel := PanelContainer.new(); root.add_child(panel)
	preload("res://ui/popup_style.gd").decorate_panel(panel)
	panel.size = Vector2(300,220)
	check(panel.material.get_shader_parameter("panel_size") == panel.size,"decorated panel publishes exact live size")
	panel.free()
	await process_frame
	check(true,"pending panel layout safely completes after immediate teardown")
	if DisplayServer.get_name() != "headless": await graphics()
	report.checks = checks; report.failures = failures
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RACING_RENDER_REMAINING ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
