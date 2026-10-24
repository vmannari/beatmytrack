extends SceneTree
## COL-A01/A02/A03: local capacity analysis; shipping limits stay unchanged.
const OUT: String = "res://../docs/evidence/creator-object-limit-2026-10-23/"
const HISTORY = preload("res://editor/editor_history.gd")
const BYTES = preload("res://editor/cache_bytes.gd")
var output_dir: String=OUT
var rows: Array = []
var compiler: GDScript
var validator: GDScript
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL ",label)

func record(row: Dictionary) -> void:
	rows.append(row)
	print("OBJECT_CAPACITY ",JSON.stringify(row))
	var mode: String="boundary" if "--tyre-boundary" in OS.get_cmdline_user_args() else "headless" if DisplayServer.get_name()=="headless" else RenderingServer.get_current_rendering_method()
	var file := FileAccess.open(output_dir+"results-"+mode+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"scope":"desktop synthetic component timings; no device/FPS certification; in-memory count gate substitution only","rows":rows},"\t")+"\n")

func stats(values: Array) -> Dictionary:
	var sorted: Array = values.duplicate(); sorted.sort()
	return {"median_ms":sorted[sorted.size()/2],"max_ms":sorted.back(),"samples_ms":values}

func fixture(count: int, kinds: Array, theme: String = "pine") -> Dictionary:
	var doc: Dictionary = TrackDocument.create_default().duplicate(true)
	doc.id = "object_capacity_probe"; doc.theme = theme; doc["automatic_scenery"] = false
	var columns: int = ceili(sqrt(float(maxi(count,2))))
	for index: int in range(count):
		var position := Vector2(-96.0+192.0*float(index%columns)/maxi(columns-1,1),-96.0+192.0*float(index/columns)/maxi(ceili(float(count)/columns)-1,1))
		doc.objects.append({"kind":kinds[index%kinds.size()],"position":[position.x,position.y],"rotation":0.0})
	return doc

func contract_and_compile() -> void:
	# Keep every other domain check. The production file and schema are untouched.
	validator = GDScript.new()
	var source: String = FileAccess.get_file_as_string("res://editor/track_document.gd").replace("\r\n","\n")
	check(source.count("data.objects.size() > 96")==1,"exact count guard found")
	validator.source_code = source.replace("class_name TrackDocument\n","").replace("data.objects.size() > 96","data.objects.size() > 960")
	check(validator.reload()==OK,"candidate validator loads")
	compiler = GDScript.new()
	source = FileAccess.get_file_as_string("res://editor/track_compiler.gd").replace("\r\n","\n")
	check(source.count("if not TrackDocument.validate(document).is_empty():")==1,"exact compiler validation gate found")
	compiler.source_code = source.replace("class_name TrackCompiler\n","").replace("if not TrackDocument.validate(document).is_empty():","if false: # probe validates with count-only candidate first")
	check(compiler.reload()==OK,"probe compiler loads")
	for count: int in [0,96,288,480,960]:
		var doc: Dictionary = fixture(count,["tree","barrier","pebbles","broadleaf"])
		check(validator.validate(doc).is_empty(),"candidate accepts valid fixture "+str(count)+str(validator.validate(doc)))
		check(TrackDocument.validate(doc).is_empty()==(count<=96),"shipping count remains unchanged "+str(count))
		var encoded: String = JSON.stringify(doc,"",true)
		var timings: Array = []; var validations: Array = []; var copies: Array = []; var captures: Array = []
		var track: NativeTrack
		for repeat: int in range(3):
			var start: int = Time.get_ticks_usec(); validator.validate(doc); validations.append((Time.get_ticks_usec()-start)/1000.0)
			start = Time.get_ticks_usec(); doc.duplicate(true); copies.append((Time.get_ticks_usec()-start)/1000.0)
			start = Time.get_ticks_usec(); HISTORY.capture(doc); captures.append((Time.get_ticks_usec()-start)/1000.0)
			start = Time.get_ticks_usec(); track = compiler.compile(doc); timings.append((Time.get_ticks_usec()-start)/1000.0)
		check(track!=null and track.hazard_objects.size()==count,"compiler retains every object")
		var history: Array = []
		for revision: int in range(40):
			if count>0: doc.objects[0].rotation = float(revision)
			history.append(HISTORY.capture(doc,history.back() if not history.is_empty() else {})); HISTORY.trim(history,[])
		record({"stage":"document","count":count,"json_bytes":encoded.to_utf8_buffer().size(),"binary_bytes":var_to_bytes(doc).size(),"validation":stats(validations),"copy":stats(copies),"history_capture":stats(captures),"compile":stats(timings),"grid_cells":track.cells.size(),"history_40_edits_bytes":HISTORY.bytes_used([history]),"history_steps_retained":history.size()})
		await process_frame
	check(not validator.validate(fixture(961,["tree"])).is_empty(),"candidate still bounded")

func clear_contact(_p: Vector2,_r: float,_e: bool) -> Vector3: return Vector3.ZERO

func physics() -> void:
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var world := NativeTrack.new(); world.grid_width=512; world.grid_height=512; world.cell_size=0.5; world.half_extent=Vector2(128,128); world.cells.resize(512*512); world.cells.fill(1)
	for kind: String in ["tree","cone","oil","tyre_stack","tyre_wall"]:
		for count: int in [96,288,480,960]:
			var doc: Dictionary = fixture(count,[kind]); var state := VehicleState.new(); state.position=Vector2(-105,-105)
			var origins: PackedVector2Array = LooseTyres.positions(doc)
			var samples: Array = []
			var first: float = 0.0
			for repeat: int in range(41):
				var start: int = Time.get_ticks_usec()
				LooseTyres.step(state,origins,world._contact,state.position,config,VehicleSimulation.STEP)
				LightProps.step(state,doc.objects,world._contact,state.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
				TrackHazards.factors(state,doc.objects); TrackHazards.launch(state,state.position,doc.objects); TrackHazards.ramp_pitch(state.position,Vector2.UP,doc.objects)
				var elapsed: float = (Time.get_ticks_usec()-start)/1000.0
				if repeat==0: first=elapsed
				else: samples.append(elapsed)
			record({"stage":"prop_physics","kind":kind,"count":count,"tyre_bodies":origins.size(),"first_tick_ms":first,"warm_ticks":stats(samples),"snapshot_bytes":var_to_bytes(state.snapshot()).size(),"rewind_state_bytes":var_to_bytes(RewindHistory.pack_state(state)).size(),"scope":"separated stationary props; no car impact; native contact grid"})
			await process_frame
	for kind: String in ["tyre_stack","tyre_wall"]:
		for count: int in [96,288,480,960]:
			var doc: Dictionary=fixture(count,[kind]); var origins: PackedVector2Array=LooseTyres.positions(doc)
			var state:=VehicleState.new(); state.position=origins[0]-Vector2(2,0); state.velocity=Vector2(12,0)
			var samples: Array=[]
			for repeat: int in range(120):
				var previous: Vector2=state.position; state.position+=state.velocity*VehicleSimulation.STEP
				var start: int=Time.get_ticks_usec(); LooseTyres.step(state,origins,world._contact,previous,config,VehicleSimulation.STEP); samples.append((Time.get_ticks_usec()-start)/1000.0)
			record({"stage":"tyre_impact","kind":kind,"count":count,"bodies":origins.size(),"ticks":stats(samples),"scope":"120 sequential tyre solver ticks; initially moving car into first stack; excludes full vehicle and render work"})
			await process_frame
	for count: int in [96,288,576]:
		var origins := PackedVector2Array(); origins.resize(count); origins.fill(Vector2.ZERO)
		var samples: Array = []
		for repeat: int in range(3):
			var state := VehicleState.new(); state.position=Vector2(-105,-105)
			var start: int=Time.get_ticks_usec(); LooseTyres.step(state,origins,world._contact,state.position,config,VehicleSimulation.STEP); samples.append((Time.get_ticks_usec()-start)/1000.0)
		record({"stage":"overlapping_tyres","bodies":count,"first_tick":stats(samples),"scope":"fresh coincident bodies; intentionally excludes 5760-body pathological allocation"})
		await process_frame

func geometry(node: Node) -> Dictionary:
	var result: Dictionary = {"nodes":1,"geometry_nodes":0,"triangles":0,"lamps":0}
	if node is OmniLight3D: result.lamps=1
	var mesh: Mesh; var instances: int=1
	if node is MeshInstance3D: mesh=node.mesh
	elif node is MultiMeshInstance3D: mesh=node.multimesh.mesh; instances=node.multimesh.instance_count
	if mesh!=null:
		result.geometry_nodes=1
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array=mesh.surface_get_arrays(surface)
			result.triangles+=instances*(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	for child: Node in node.get_children():
		var part: Dictionary=geometry(child)
		for key: String in result: result[key]+=part[key]
	return result

func visuals() -> void:
	for scenario: Dictionary in [{"name":"tyre_stacks","kinds":["tyre_stack"],"theme":"pine","counts":[96,288,960]},{"name":"tyre_walls","kinds":["tyre_wall"],"theme":"pine","counts":[96,288,960]},{"name":"trees","kinds":["tree"],"theme":"pine","counts":[96,288,960]},{"name":"barriers","kinds":["barrier"],"theme":"pine","counts":[96,288,960]},{"name":"mixed","kinds":["tree","broadleaf","bush","barrier","guardrail","fence","pebbles","flag"],"theme":"pine","counts":[96,288,960]},{"name":"winter_castles","kinds":["snow_castle"],"theme":"winter","counts":[96,288]}]:
		for count: int in scenario.counts:
			var doc: Dictionary=fixture(count,scenario.kinds,scenario.theme)
			var track:=NativeTrack.new(); track.metadata={"creator_document":doc,"scenery_objects":[]}; track.content_hash="probe"; track.tyre_origins=LooseTyres.positions(doc)
			var kit:=NativeTrackVisual.new(); kit.theme_id=scenario.theme; kit.colors=TrackTheme.palette(scenario.theme); root.add_child(kit)
			var before: int=OS.get_static_memory_usage(); var start: int=Time.get_ticks_usec()
			await kit.refresh_editor_objects(track,false,false)
			var build_ms: float=(Time.get_ticks_usec()-start)/1000.0
			var allocation: int=OS.get_static_memory_usage()-before
			var details: Dictionary=geometry(kit)
			var estimated_bytes: int=BYTES.scene(kit)
			doc.objects[count/2].position[0]+=0.125
			start=Time.get_ticks_usec(); await kit.refresh_editor_objects(track,false,false)
			var edit_ms: float=(Time.get_ticks_usec()-start)/1000.0
			check(kit.editor_objects._editor_authored_batches.sources.size()==count,"editor retains all authored props")
			record({"stage":"editor_props","scenario":scenario.name,"count":count,"initial_build_ms":build_ms,"move_one_ms":edit_ms,"geometry":details,"estimated_scene_bytes":estimated_bytes,"static_allocation_delta":allocation,"scope":"full-detail props only; no roads, cover, LOD, GPU timing or whole-app peak"})
			kit.free(); CreatorPropVisual.trim_cache()
			await process_frame; await process_frame

func tyre_render_probe() -> void:
	for kind: String in ["tyre_stack","tyre_wall"]:
		for count: int in [96,288,960]:
			var viewport:=SubViewport.new(); viewport.size=Vector2i(1280,720); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
			var kit:=NativeTrackVisual.new(); kit.theme_id="pine"; kit.colors=TrackTheme.palette("pine"); viewport.add_child(kit)
			var doc: Dictionary=fixture(count,[kind]); var track:=NativeTrack.new(); track.metadata={"creator_document":doc,"scenery_objects":[]}; track.tyre_origins=LooseTyres.positions(doc)
			var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; viewport.add_child(camera); camera.current=true
			camera.position=Vector3(-90,50,90); camera.look_at(Vector3(-90,0,90),Vector3.FORWARD)
			var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-65,15,0); viewport.add_child(light)
			await kit.refresh_editor_objects(track,false,false)
			for view_size: float in [40.0,240.0]:
				camera.size=view_size
				for frame: int in range(8): await process_frame; await RenderingServer.frame_post_draw
				var rid: RID=viewport.get_viewport_rid()
				var primitives: int=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
				check(primitives==track.tyre_origins.size()*1200,"all tyre triangles submitted in both views")
				record({"stage":"tyre_render","kind":kind,"count":count,"bodies":track.tyre_origins.size(),"view_size_m":view_size,"draw_calls":RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"rendered_primitives":primitives,"scope":"1280x720 isolated tyre viewport; no road, car, shadows or GPU-time/FPS claim"})
			viewport.free(); await process_frame

func tyre_boundary_probe() -> void:
	var config: HandlingConfig=load("res://resources/balanced.tres")
	var world:=NativeTrack.new(); world.grid_width=512; world.grid_height=512; world.cell_size=0.5; world.half_extent=Vector2(128,128); world.cells.resize(512*512); world.cells.fill(1)
	for count: int in [640,682,683,960]:
		var doc: Dictionary=fixture(count,["tyre_wall"]); var origins: PackedVector2Array=LooseTyres.positions(doc)
		var state:=VehicleState.new(); state.position=origins[0]-Vector2(2,0); state.velocity=Vector2(12,0)
		var samples: Array=[]
		for repeat: int in range(120):
			var previous: Vector2=state.position; state.position+=state.velocity*VehicleSimulation.STEP
			var start: int=Time.get_ticks_usec(); LooseTyres.step(state,origins,world._contact,previous,config,VehicleSimulation.STEP); samples.append((Time.get_ticks_usec()-start)/1000.0)
		var work: Dictionary=state.get_meta(&"native_tyre_contacts").work_stats()
		check(int(work.bodies)==(origins.size() if origins.size()<=4096 else 0),"native body threshold matches live library")
		record({"stage":"tyre_solver_boundary","wall_objects":count,"bodies":origins.size(),"native_prepared_bodies":work.bodies,"ticks":stats(samples),"scope":"same 120-step ordinary separated-wall impact fixture; no density or overlap rejection"})
		await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capacity-output="): output_dir=argument.trim_prefix("--capacity-output=").replace("\\","/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if "--gpu-tyres" in OS.get_cmdline_user_args(): await tyre_render_probe()
	elif "--tyre-boundary" in OS.get_cmdline_user_args(): await tyre_boundary_probe()
	else:
		await contract_and_compile()
		await physics()
		await visuals()
	check(TrackDocument.validate(fixture(97,["tree"])).size()>0,"shipping cap unchanged after probe")
	record({"stage":"complete","checks":checks,"failures":failures})
	quit(1 if failures else 0)
