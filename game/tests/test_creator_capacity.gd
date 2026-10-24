extends SceneTree
const LIMITS = preload("res://editor/creator_limits.gd")
const HISTORY = preload("res://editor/editor_history.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var out: String = ""

class ReferenceTrack extends NativeTrack:
	func surface_factors(state: VehicleState) -> Vector2:
		var base: Vector2 = _native_surface_factors(state); var effects: Vector2 = TrackHazards.factors(state,hazard_objects)
		return Vector2(base.x*effects.x,base.y+effects.y)
	func step_props(state: VehicleState, from: Vector2, config: HandlingConfig, seconds: float) -> void:
		LooseTyres.step(state,tyre_origins,_contact,from,config,seconds)
		LightProps.step(state,hazard_objects,_contact,from,seconds,config.mass,config.collision_radius)
	func launch_jump(state: VehicleState, previous: Vector2) -> void: TrackHazards.launch(state,previous,hazard_objects)
	func step_speed_bumps(state: VehicleState, previous: Vector2, heading: float, velocity: Vector2, config: HandlingConfig, seconds: float) -> void:
		SpeedBumps.advance(state,previous,heading,velocity,config,speed_bump_objects,seconds)
	func tire_fluids(state: VehicleState) -> Vector2:
		if state.track_elevated or state.jump_height > 0.0: return Vector2.ZERO
		var coating := Vector2(0.0,1.0 if cell_at(state.position) in [3,6] else 0.0)
		for object: Dictionary in hazard_objects:
			if object.kind not in ["oil","puddle"] or not CreatorObjects.contains(object,state.position): continue
			if object.kind == "oil": coating.x = 1.0
			if object.kind == "puddle": coating.y = 1.0
		return coating

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func record(row: Dictionary) -> void:
	rows.append(row); print("CREATOR_CAPACITY ",JSON.stringify(row))
	var mode: String = "headless" if DisplayServer.get_name()=="headless" else RenderingServer.get_current_rendering_method()
	var file := FileAccess.open(out+"/results-"+mode+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"engine":Engine.get_version_info().string},"\t")+"\n")
func fixture(count: int, kind: String = "grass_clump") -> Dictionary:
	var doc: Dictionary = TrackDocument.create_default(); doc.id = "capacity_local"; doc["automatic_scenery"] = false
	var columns: int = ceili(sqrt(float(maxi(count,2))))
	for index: int in range(count): doc.objects.append({"kind":kind,"position":[-96.0+192.0*(index%columns)/maxi(1,columns-1),-96.0+192.0*(index/columns)/maxi(1,ceili(float(count)/columns)-1)],"rotation":0.0})
	return doc
func original(path: String, declaration: String = "") -> GDScript:
	var script := GDScript.new(); script.source_code = FileAccess.get_file_as_string(out+"/before/"+path).replace("\r\n","\n")
	if declaration == "NativeTrackVisual":
		var begin: int = script.source_code.find("\nfunc _build_placed_objects(")+1
		var end: int = script.source_code.find("\nfunc ",begin+1)
		script.source_code = "extends NativeTrackVisual\n"+script.source_code.substr(begin,end-begin)+"\n"
	elif not declaration.is_empty(): script.source_code = script.source_code.replace("class_name "+declaration+"\n","")
	check(script.reload()==OK,"captured original loads: "+path)
	return script

func contracts() -> void:
	var doc: Dictionary = fixture(4096)
	check(TrackDocument.validate(doc).is_empty(),"4096 light props are legal")
	check(not TrackDocument.validate(fixture(4097)).is_empty(),"4097 entries rejected")
	var tyres: Dictionary = fixture(682,"tyre_wall")
	for index: int in range(4): tyres.objects.append({"kind":"tyre_stack","position":[0.0,float(index)*2.0],"rotation":0.0})
	check(LIMITS.tyre_count(tyres.objects)==4096 and TrackDocument.validate(tyres).is_empty(),"wall expansion permits exactly 4096 bodies")
	check(not LIMITS.addition_error(tyres.objects,[{"kind":"tyre_stack","position":[0,10],"rotation":0}]).is_empty(),"placement rejects body 4097 before mutation")
	check(LIMITS.remaining(tyres.objects,"tyre_wall")==0,"run respects physical budget")
	var expensive: Dictionary = fixture(4096,"snow_castle"); expensive.theme = "winter"
	check(not TrackDocument.validate(expensive).is_empty(),"large complex scene rejected before mesh allocation")
	check(TrackDocument.validate(fixture(96,"tree")).is_empty(),"prior small scene allowance remains valid")
	check(LIMITS.memory_bytes(doc.objects)<LIMITS.PROP_MEMORY_BYTES,"4096 grass estimate fits live guard")
	check(LIMITS.MAX_DOCUMENT_BYTES==1048576 and TrackDocument.MAX_BYTES==1048576,"one MiB shared document bound")
	for stroke_index: int in range(32):
		var points: Array = []
		for index: int in range(512): points.append([-100.0+float(index%100)*2.0,-100.0+float(index/100)*2.0])
		doc.paint.append({"surface":1,"width":1.0,"shape":"round","points":points})
	var encoded: String = JSON.stringify(doc,"",true)
	check(encoded.to_utf8_buffer().size()>524288 and encoded.to_utf8_buffer().size()<TrackDocument.MAX_BYTES,"large props plus paint use expanded byte range")
	var library := TrackLibrary.new("user://creator_capacity_"+TrackLibrary.unique_id())
	check(library.save_document(doc)==OK,"save above old byte cap")
	var loaded: Dictionary = library.load_document(doc.id)
	check(loaded==JSON.parse_string(encoded),"exact large save/load authoring values")
	record({"stage":"contract","json_bytes":encoded.to_utf8_buffer().size(),"objects":doc.objects.size(),"memory_estimate":LIMITS.memory_bytes(doc.objects)})

func history() -> void:
	var doc: Dictionary = fixture(4096); var stack: Array = []
	var start: int = Time.get_ticks_usec()
	for revision: int in range(40):
		doc.objects[10].rotation=float(revision)
		stack.append(HISTORY.capture(doc,stack.back() if not stack.is_empty() else {})); HISTORY.trim(stack,[])
	var capture_ms: float = (Time.get_ticks_usec()-start)/1000.0
	check(stack.size()==40 and HISTORY.bytes_used([stack])<=HISTORY.BUDGET,"4096-object edits retain forty bounded states")
	for revision: int in range(40): check(HISTORY.restore(stack[revision]).objects[10].rotation==float(revision),"exact per-object undo "+str(revision))
	var before: Dictionary = HISTORY.restore(stack.back()); var previous: Dictionary = stack.back()
	doc.objects.remove_at(0); doc.objects.insert(20,{"kind":"flag","position":[0,0],"rotation":0})
	var changed: Dictionary = HISTORY.capture(doc,previous)
	check(HISTORY.restore(previous)==before and HISTORY.restore(changed)==doc,"insert/delete reuse preserves immutable exact states")
	check(changed.snapshot.objects.objects[0].id==previous.snapshot.objects.objects[1].id,"unchanged shifted objects share chunks")
	record({"stage":"history","steps":stack.size(),"bytes":HISTORY.bytes_used([stack]),"capture_40_ms":capture_ms})

func physics() -> void:
	var doc: Dictionary = fixture(4096)
	var kinds: Array = ["oil","puddle","jump","speed_bump","cone","barrel","tyre_stack"]
	for index: int in range(kinds.size()): doc.objects[index] = {"kind":kinds[index],"position":[-38.0+index*2.0,-10.0],"rotation":90.0}
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track!=null,"large scene compiles with guarded resources")
	var prior := ReferenceTrack.new()
	for property: Dictionary in track.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE: prior.set(property.name,track.get(property.name))
	for car: String in VehicleCatalog.IDS:
		var a:=VehicleSimulation.new(VehicleCatalog.config(car)); var b:=VehicleSimulation.new(VehicleCatalog.config(car)); a.reset(track.spawn,0.0); b.reset(track.spawn,0.0)
		for tick: int in range(240):
			var frame:=DriveFrame.new(); frame.throttle=255; frame.steer=24 if tick%120<60 else -24; frame.brake=90 if tick%90>75 else 0
			a.step(frame,prior); b.step(frame,track)
			check(var_to_bytes(a.state.snapshot())==var_to_bytes(b.state.snapshot()),"full canonical equivalence "+car+"/"+str(tick))
			if failures: return
	for index: int in range(100):
		var point:=Vector2(-45+index*0.4,-10)
		check(track.ramp_height(point)==TrackHazards.ramp_height(point,track.hazard_objects),"ramp height exact")
		check(track.ramp_pitch(point,Vector2.RIGHT)==TrackHazards.ramp_pitch(point,Vector2.RIGHT,track.hazard_objects),"ramp pitch exact")
	track.hazard_objects[0].position=[50,50]
	var state:=VehicleState.new(); state.position=Vector2(50,50)
	check(track.tire_fluids(state)==prior.tire_fluids(state),"in-place hazard mutation invalidates derived queries")
	check(not track._creator_query().source.is_empty(),"query cache prepared without canonical snapshot fields")
	record({"stage":"physics","cars":VehicleCatalog.IDS.size(),"ticks_per_car":240,"objects":4096})

func editor_work() -> void:
	var before: GDScript = original("game/editor/placed_object_batches.gd")
	for variant: int in range(2):
		var doc: Dictionary = fixture(4096); var track:=NativeTrack.new(); track.metadata={"creator_document":doc,"scenery_objects":[]}; track.content_hash="capacity"
		var kit:=NativeTrackVisual.new(); kit.theme_id="pine"; kit.colors=TrackTheme.palette("pine"); root.add_child(kit)
		var planner: RefCounted = before.new() if variant==0 else preload("res://editor/placed_object_batches.gd").new()
		var current: Callable=func() -> bool: return true
		var start: int=Time.get_ticks_usec(); await planner.refresh(kit,track,false,current); var build_ms: float=(Time.get_ticks_usec()-start)/1000.0
		var untouched: Dictionary={}
		for key: String in planner.groups: untouched[key]=planner.groups[key].nodes[0].mesh.get_instance_id()
		doc.objects[2048].position[0]+=0.125
		start=Time.get_ticks_usec(); await planner.refresh(kit,track,false,current); var edit_ms: float=(Time.get_ticks_usec()-start)/1000.0
		var retained: int=0
		for key: String in planner.groups:
			if untouched.get(key,0)==planner.groups[key].nodes[0].mesh.get_instance_id(): retained+=1
		check(planner.sources==doc.objects,"latest full scene visible after one-object change")
		check(retained>planner.groups.size()-8,"unaffected editor groups retain mesh uploads")
		record({"stage":"editor_paired","variant":"before" if variant==0 else "after","objects":4096,"build_ms":build_ms,"edit_ms":edit_ms,"retained_groups":retained,"groups":planner.groups.size()})
		kit.free(); planner=null; CreatorPropVisual.trim_cache(); await process_frame

func tyre_render() -> void:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(960,540); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-65,15,0); viewport.add_child(light)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=40; viewport.add_child(camera); camera.look_at_from_position(Vector3(-72,50,72),Vector3(-72,0,72),Vector3.FORWARD); camera.current=true
	var doc: Dictionary=fixture(1024,"tyre_stack"); var track:=NativeTrack.new(); track.metadata={"creator_document":doc,"scenery_objects":[]}; track.tyre_origins=LooseTyres.positions(doc)
	var script: GDScript=original("game/track/native_track_visual.gd","NativeTrackVisual")
	var old: Node3D=script.new(); old.theme_id="pine"; old.colors=TrackTheme.palette("pine"); viewport.add_child(old); await old._build_placed_objects(track)
	var fresh:=NativeTrackVisual.new(); fresh.theme_id="pine"; fresh.colors=TrackTheme.palette("pine"); viewport.add_child(fresh); await fresh._build_placed_objects(track); fresh.hide()
	var state:=VehicleState.new()
	for point: Vector2 in track.tyre_origins: state.loose_tyres.append([point.x,point.y,0.0,0.0,0.0])
	state.loose_tyres[0][0]=34.0; fresh.update_tyres(state,track.tyre_origins); old.update_tyres(state,track.tyre_origins)
	check(fresh.tyre_instances.batches.size()>1,"tyre draws have spatial owners")
	for index: int in range(track.tyre_origins.size()): check(fresh.tyre_instances.multimesh.get_instance_transform(index)==old.tyre_instances.multimesh.get_instance_transform(index),"exact tyre transform "+str(index))
	if DisplayServer.get_name()!="headless":
		for frame: int in range(5): await process_frame; await RenderingServer.frame_post_draw
		var before: Image=viewport.get_texture().get_image(); var rid: RID=viewport.get_viewport_rid()
		var old_primitives: int=RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		old.hide(); fresh.show()
		for frame: int in range(5): await process_frame; await RenderingServer.frame_post_draw
		var after: Image=viewport.get_texture().get_image()
		check(before.get_data()==after.get_data(),"exact native tyre pixels under one light")
		before.save_png(out+"/tyres-before-"+RenderingServer.get_current_rendering_method()+".png"); after.save_png(out+"/tyres-after-"+RenderingServer.get_current_rendering_method()+".png")
		record({"stage":"tyre_render","before_primitives":old_primitives,"after_primitives":RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"pixels_exact":before.get_data()==after.get_data()})
	var cached: Node3D=fresh.tyre_instances.duplicate(Node.DUPLICATE_SCRIPTS); viewport.add_child(cached); cached.flush(); check(cached.batches.size()>1,"duplicated retained tyre scene reconstructs spatial ownership"); cached.free()
	viewport.free(); await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capacity-evidence="): out=argument.trim_prefix("--capacity-evidence=")
	if out.is_empty(): out=ProjectSettings.globalize_path("res://../docs/evidence/creator-capacity-implementation-2026-10-23")
	await contracts(); history(); await physics(); await editor_work(); await tyre_render()
	record({"stage":"complete","checks":checks,"failures":failures}); print("CREATOR_CAPACITY checks=%d failures=%d" % [checks,failures]); quit(1 if failures else 0)
