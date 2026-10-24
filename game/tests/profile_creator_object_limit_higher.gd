extends "res://tests/profile_creator_object_limit.gd"
## COL-A04: remove the initial tenfold assumption; no shipping-limit change.

func record(row: Dictionary) -> void:
	rows.append(row); print("HIGHER_CAPACITY ",JSON.stringify(row))
	var file:=FileAccess.open(output_dir+"results-higher.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"scope":"desktop components, higher-count analysis; unchanged production capacity; no device certification","rows":rows},"\t")+"\n")

func documents() -> void:
	validator=GDScript.new()
	var source: String=FileAccess.get_file_as_string("res://editor/track_document.gd").replace("\r\n","\n")
	check(source.count("data.objects.size() > 96")==1,"exact shipping count guard")
	validator.source_code=source.replace("class_name TrackDocument\n","").replace("data.objects.size() > 96","data.objects.size() > 16384")
	check(validator.reload()==OK,"higher count-only candidate loads")
	compiler=GDScript.new()
	source=FileAccess.get_file_as_string("res://editor/track_compiler.gd").replace("\r\n","\n")
	check(source.count("if not TrackDocument.validate(document).is_empty():")==1,"exact compiler gate")
	compiler.source_code=source.replace("class_name TrackCompiler\n","").replace("if not TrackDocument.validate(document).is_empty():","if false: # count-only candidate checked before compiling")
	check(compiler.reload()==OK,"higher compiler loads")
	for count: int in [960,2048,4096,8192,16384]:
		var doc: Dictionary=fixture(count,["grass_clump"])
		var start: int=Time.get_ticks_usec(); var errors: Array=validator.validate(doc); var validation_ms: float=(Time.get_ticks_usec()-start)/1000.0
		check(errors.is_empty(),"higher fixture domain checks "+str(count))
		check(not TrackDocument.validate(doc).is_empty(),"shipping cap unchanged "+str(count))
		var encoded_bytes: int=JSON.stringify(doc,"",true).to_utf8_buffer().size()
		var compact: Dictionary=fixture(count,["flag"])
		for index: int in range(count):
			compact.objects[index].position=[index%200-100,index/200-100]
			compact.objects[index].rotation=0
		check(validator.validate(compact).is_empty(),"compact fixture domain checks")
		var compact_bytes: int=JSON.stringify(compact,"",true).to_utf8_buffer().size()
		var compile_ms: float=-1.0; var compiled_objects: int=0
		if encoded_bytes<=TrackDocument.MAX_BYTES:
			start=Time.get_ticks_usec(); var track: NativeTrack=compiler.compile(doc); compile_ms=(Time.get_ticks_usec()-start)/1000.0
			compiled_objects=track.hazard_objects.size(); check(compiled_objects==count,"all higher objects survive compile")
		var history: Array=[]
		start=Time.get_ticks_usec()
		for revision: int in range(40):
			doc.objects[0].rotation=float(revision)
			history.append(HISTORY.capture(doc,history.back() if not history.is_empty() else {})); HISTORY.trim(history,[])
		check(HISTORY.bytes_used([history])<=HISTORY.BUDGET,"higher history remains byte bounded")
		record({"stage":"higher_documents","count":count,"fractional_grass_json_bytes":encoded_bytes,"integer_flag_json_bytes":compact_bytes,"document_byte_limit":TrackDocument.MAX_BYTES,"fractional_fixture_fits":encoded_bytes<=TrackDocument.MAX_BYTES,"compact_fixture_fits":compact_bytes<=TrackDocument.MAX_BYTES,"validation_ms":validation_ms,"compile_ms":compile_ms,"compiled_objects":compiled_objects,"forty_history_ms":(Time.get_ticks_usec()-start)/1000.0,"history_steps":history.size(),"history_bytes":HISTORY.bytes_used([history])})
		await process_frame
	check(not validator.validate(fixture(16385,["flag"])).is_empty(),"probe has a finite count guard")

func higher_physics() -> void:
	var config: HandlingConfig=load("res://resources/balanced.tres")
	var world:=NativeTrack.new(); world.grid_width=512; world.grid_height=512; world.cell_size=0.5; world.half_extent=Vector2(128,128); world.cells.resize(512*512); world.cells.fill(1)
	for count: int in [960,2048,4096,4097,8192]:
		var doc: Dictionary=fixture(count,["tyre_stack"]); var origins: PackedVector2Array=LooseTyres.positions(doc)
		var state:=VehicleState.new(); state.position=origins[0]-Vector2(2,0); state.velocity=Vector2(12,0)
		var timings: Array=[]
		for tick: int in range(60):
			var previous: Vector2=state.position; state.position+=state.velocity*VehicleSimulation.STEP
			var start: int=Time.get_ticks_usec(); LooseTyres.step(state,origins,world._contact,previous,config,VehicleSimulation.STEP); timings.append((Time.get_ticks_usec()-start)/1000.0)
		var work: Dictionary=state.get_meta(&"native_tyre_contacts").work_stats()
		check(int(work.bodies)==(count if count<=4096 else 0),"live native boundary at higher count")
		record({"stage":"higher_tyre_physics","count":count,"native_prepared_bodies":work.bodies,"impact_ticks":stats(timings),"packed_rewind_bytes":var_to_bytes(RewindHistory.pack_state(state)).size(),"scope":"60 sequential solver steps; car initially hits one separated stack; no full-race/GPU cost"})
		await process_frame
	for count: int in [2048,4096,8192]:
		var doc: Dictionary=fixture(count,["grass_clump"]); var state:=VehicleState.new(); state.position=Vector2(-105,-105)
		var timings: Array=[]
		for tick: int in range(31):
			var start: int=Time.get_ticks_usec()
			LightProps.step(state,doc.objects,world._contact,state.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			TrackHazards.factors(state,doc.objects); TrackHazards.launch(state,state.position,doc.objects); TrackHazards.ramp_pitch(state.position,Vector2.UP,doc.objects)
			if tick>0: timings.append((Time.get_ticks_usec()-start)/1000.0)
		record({"stage":"higher_static_scans","count":count,"ticks":stats(timings),"scope":"current retained prop/hazard scans on decorative objects; not a full physics tick"})
		await process_frame

func higher_visuals() -> void:
	for kind: String in ["tyre_stack","grass_clump"]:
		for count: int in [2048,4096,8192]:
			var doc: Dictionary=fixture(count,[kind]); var track:=NativeTrack.new(); track.metadata={"creator_document":doc,"scenery_objects":[]}; track.content_hash="higher"; track.tyre_origins=LooseTyres.positions(doc)
			var kit:=NativeTrackVisual.new(); kit.theme_id="pine"; kit.colors=TrackTheme.palette("pine"); root.add_child(kit)
			var before: int=OS.get_static_memory_usage(); var start: int=Time.get_ticks_usec(); await kit.refresh_editor_objects(track,false,false)
			var build_ms: float=(Time.get_ticks_usec()-start)/1000.0; var allocation: int=OS.get_static_memory_usage()-before
			var detail: Dictionary=geometry(kit); var scene_bytes: int=BYTES.scene(kit)
			doc.objects[count/2].position[0]+=0.125
			start=Time.get_ticks_usec(); await kit.refresh_editor_objects(track,false,false); var move_ms: float=(Time.get_ticks_usec()-start)/1000.0
			check(kit.editor_objects._editor_authored_batches.sources.size()==count,"higher editor retains every object")
			record({"stage":"higher_editor_props","kind":kind,"count":count,"build_ms":build_ms,"move_one_ms":move_ms,"static_allocation_delta":allocation,"estimated_scene_bytes":scene_bytes,"geometry":detail,"scope":"headless full-detail props; no roads, GPU execution, app peak or device claim; oversized JSON fixtures are component-only"})
			kit.free(); CreatorPropVisual.trim_cache(); await process_frame; await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capacity-output="): output_dir=argument.trim_prefix("--capacity-output=").replace("\\","/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	await documents(); await higher_physics(); await higher_visuals()
	check(TrackDocument.validate(fixture(97,["tree"])).size()>0,"shipping cap unchanged after higher probe")
	record({"stage":"complete","checks":checks,"failures":failures})
	quit(1 if failures else 0)
