extends SceneTree
## Native road passage, solid walls, all-car driving and the actual race camera.
const OUTPUT: String="res://../docs/evidence/warehouse-2026-10-16"
var checks: int=0
var failures: int=0
var metrics: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)
func object(scale: float=1.0, rotation: float=0.0, center: Vector2=Vector2.ZERO) -> Dictionary:
	return {"kind":"abandoned_warehouse","position":[center.x,center.y],"rotation":rotation,"scale":scale}
func document(scale: float=1.0, rotation: float=0.0, center: Vector2=Vector2.ZERO) -> Dictionary:
	var doc: Dictionary=TrackDocument.create_blank(); doc.theme="night_city"; doc["automatic_scenery"]=false
	var axis: Vector2=Vector2.UP.rotated(deg_to_rad(rotation))
	var reach: float=maxf(38.0,19.0*scale)
	var piece: Dictionary=RoadPieces.create("straight",center-axis*reach,fposmod(rad_to_deg(axis.angle()),360.0),10.0*scale)
	piece.length=reach*2; doc.pieces=[piece]; doc.objects=[object(scale,rotation,center)]
	doc["practice_start"]={"position":[(center-axis*25).x,(center-axis*25).y],"heading":fposmod(rad_to_deg(atan2(axis.x,axis.y)),360.0)}
	return doc
func local_point(p: Vector2, object_value: Dictionary) -> Vector2:
	return Vector2(object_value.position[0],object_value.position[1])+p.rotated(deg_to_rad(object_value.rotation))*float(object_value.scale)

func run() -> void:
	for biome: String in TrackTheme.IDS:
		var offered: bool=false
		for family: Array in CreatorCatalog.filtered("Buildings","warehouse",[],biome): offered=offered or family[0]=="abandoned_warehouse"
		check(offered==(biome=="night_city"),biome+" offers the warehouse only in Night")
	check(CreatorCatalog.behavior("abandoned_warehouse").contains("Drive through"),"placement guidance explains the open ends")
	var kit:=NativeTrackVisual.new(); kit.theme_id="night_city"
	var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	check(CreatorPropVisual.append(tool,kit,"abandoned_warehouse",Vector3.ZERO,1,0),"shipping model builds")
	var mesh: ArrayMesh=tool.commit(); var arrays: Array=mesh.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var valid: bool=points.size()>0 and normals.size()==points.size(); var collapsed: int=0
	for i: int in range(points.size()): valid=valid and points[i].is_finite() and normals[i].is_finite() and normals[i].length()>0.9
	for i: int in range(0,points.size(),3):
		if (points[i+1]-points[i]).cross(points[i+2]-points[i]).length_squared()<1e-16: collapsed+=1
	check(valid and collapsed==0,"warehouse normals/vertices are finite and all faces have area")
	check(points.size()/3<10000,"warehouse stays below the existing per-object triangle budget")
	print("WAREHOUSE_TRIANGLES: ",points.size()/3)
	var bounds: AABB=mesh.get_aabb(); var size: Vector2=CreatorObjects.dimensions("abandoned_warehouse")
	check(bounds.position.x>=-size.x*0.5 and bounds.end.x<=size.x*0.5 and bounds.position.z>=-size.y*0.5 and bounds.end.z<=size.y*0.5,"roof/gutters fit inside the selection outline")
	check(0.014+NativeTrackVisual.ROAD_HEIGHT.RISE+bounds.position.y*0.5<=-0.06,"buried foundations meet surrounding terrain even at minimum scale on raised asphalt")
	var lane_blocked: bool=false; var overhead_sheets: int=0
	for i: int in range(0,points.size(),3):
		var p: Vector3=(points[i]+points[i+1]+points[i+2])/3
		if absf(p.x)<5.8 and absf(p.z)<11.0 and p.y<3.0: lane_blocked=true
		if absf(p.x)<5.8 and absf(p.z)<11.0 and p.y>5.0 and (points[i+1]-points[i]).cross(points[i+2]-points[i]).length()>8.0: overhead_sheets+=1
	check(not lane_blocked,"no floor/prop triangles obstruct the central road at car height")
	check(overhead_sheets==0,"collapsed roof leaves the overhead driving view open")
	metrics.append({"triangles":points.size()/3,"bounds":str(bounds),"clear_portal_m":12.3,"length_m":24.0})
	kit.free()
	for scale: float in [0.5,0.75,1.0,1.5,2.0,3.0]:
		for rotation: float in [0.0,37.0,90.0,180.0,270.0]: passage(scale,rotation)
	for car: String in VehicleCatalog.IDS: drive(car)
	await editor_and_cache()
	if DisplayServer.get_name()!="headless": await captures(); await editor_capture()
	print("WAREHOUSE_METRICS: ",JSON.stringify(metrics))
	print("DRIVE_THROUGH_WAREHOUSE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func passage(scale: float, rotation: float) -> void:
	var center:=Vector2(7,-5); var doc: Dictionary=document(scale,rotation,center)
	check(TrackDocument.validate(doc).is_empty(),"road-mounted warehouse validates at scale/rotation "+str([scale,rotation]))
	var track: NativeTrack=TrackCompiler.compile(doc)
	check(track!=null,"road-mounted warehouse compiles")
	if track==null: return
	var stamp: Dictionary=doc.objects[0]
	var preserved: bool=true; var clear: bool=true
	for y: int in range(-15,16):
		for x: float in [-minf(4.5,9.5/scale),-2.0,0.0,2.0,minf(4.5,9.5/scale)]:
			var point: Vector2=local_point(Vector2(x,y),stamp)
			preserved=preserved and track.cell_at(point)==0
			clear=clear and not CreatorObjects.solid_contains(stamp,point)
	check(preserved and clear,"both doorways and the whole interior preserve actual road cells")
	check(CreatorObjects.solid_contains(stamp,local_point(Vector2(8.7,0),stamp)) and CreatorObjects.solid_contains(stamp,local_point(Vector2(-8.7,0),stamp)),"both side walls remain solid after rotate/scale")
	check(CreatorObjects.solid_contains(stamp,local_point(Vector2(7.5,11.8),stamp)) and CreatorObjects.solid_contains(stamp,local_point(Vector2(-7.5,-11.8),stamp)),"solid end panels flank the two openings")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(doc))
	check(TrackCompiler.compile(saved).content_hash==track.content_hash,"save/load preserves the warehouse track identity")
	var visual:=NativeTrackVisual.new(); visual.theme_id="night_city"
	var mask: PackedByteArray=visual._authored_barrier_cells(track)
	var no_wall: bool=true
	for y: int in range(-12,13):
		var p: Vector2=local_point(Vector2(0,y),stamp)
		var x_cell: int=clampi(floori((p.x+track.half_extent.x)/track.cell_size),0,track.grid_width-1)
		var y_cell: int=clampi(floori((track.half_extent.y-p.y)/track.cell_size),0,track.grid_height-1)
		no_wall=no_wall and mask[y_cell*track.grid_width+x_cell]==0
	check(no_wall,"native barrier suppression has no invisible slab across the route")
	visual.free()

func drive(car: String) -> void:
	var doc: Dictionary=document(); var track: NativeTrack=TrackCompiler.compile(doc)
	var config: HandlingConfig=VehicleCatalog.config(car)
	for direction: float in [-1.0,1.0]:
		var sim:=VehicleSimulation.new(config); sim.reset(Vector2(0,-24*direction)); sim.state.heading=0 if direction>0 else PI
		var frame:=DriveFrame.new(); frame.throttle=255
		var frames_used: int=0; var road: bool=true
		while sim.state.position.y*direction<24 and frames_used<1200:
			sim.step(frame,track); frames_used+=1
			road=road and track.cell_at(sim.state.position)==0
		check(sim.state.position.y*direction>=24 and sim.state.collision_count==0,car+" drives fully through both openings in direction "+str(direction))
		check(road,car+" retains asphalt through the entire warehouse")
		var replay:=VehicleSimulation.new(config); replay.reset(Vector2(0,-24*direction)); replay.state.heading=0 if direction>0 else PI
		for i: int in range(frames_used): replay.step(frame,track)
		check(replay.state.snapshot()==sim.state.snapshot(),car+" repeats exact driven state through the building")
	# A sideways approach hits the existing canonical solid-cell collision.
	var state:=VehicleState.new(); state.position=Vector2(6,0); state.velocity=Vector2(-20,0)
	track.resolve(state,Vector2(12,0),config)
	check(state.collision_count>0 and track.overlaps_obstacle(Vector2(8.7,0),0.5,false),car+" cannot pass through a side wall")

func editor_and_cache() -> void:
	var doc: Dictionary=document(); var track: NativeTrack=TrackCompiler.compile(doc)
	var kit:=NativeTrackVisual.new(); kit.theme_id="night_city"; kit.editor_preview=true; kit.colors=TrackTheme.palette("night_city"); root.add_child(kit)
	var batches=preload("res://editor/placed_object_batches.gd").new()
	check(await batches.refresh(kit,track,false,func() -> bool: return true),"editor prepares the warehouse at the actual road")
	check(kit.get_node("NightPropEffects").warm_lights.size()==2,"two interior lamps share the original light pool")
	var saved_objects: Array=track.metadata.creator_document.objects
	track.metadata.creator_document.objects=[object(1,45,Vector2(track.half_extent.x-18,0))]
	check(not kit._lamps_inside_terrain(track),"rotated interior lamps keep boundary terrain illuminated")
	track.metadata.creator_document.objects=saved_objects
	var fx: NightPropEffects=kit.get_node("NightPropEffects")
	check(not await batches.refresh(kit,track,false,func() -> bool: return true) and kit.get_node("NightPropEffects")==fx,"unchanged editor update retains model and lights")
	doc.objects[0].rotation=90; track=TrackCompiler.compile(doc)
	await batches.refresh(kit,track,false,func() -> bool: return true)
	check(kit.get_node("NightPropEffects")!=fx,"rotation rebuilds only changed placement resources")
	doc.objects=[]; track=TrackCompiler.compile(doc); await batches.refresh(kit,track,false,func() -> bool: return true)
	check(kit.get_node_or_null("NightPropEffects")==null,"deleting the warehouse removes its lights")
	kit.queue_free(); await process_frame

func frames(count: int) -> void:
	for i: int in range(count): await process_frame
	await RenderingServer.frame_post_draw
func save(name: String) -> void:
	var path: String=ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method()); DirAccess.make_dir_recursive_absolute(path)
	check(root.get_texture().get_image().save_png(path+"/"+name+".png")==OK,name+" native capture saved")

func captures() -> void:
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	var button:=Button.new(); root.add_child(button)
	var view: SubViewport=ObjectThumbnail._render_preview(button,"abandoned_warehouse","night_city"); view.size=Vector2i(1280,800)
	await frames(4)
	var path: String=ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method()); DirAccess.make_dir_recursive_absolute(path)
	check(view.get_texture().get_image().save_png(path+"/model.png")==OK,"actual native warehouse preview saved")
	button.queue_free(); await process_frame
	var game: Node=preload("res://core/game.tscn").instantiate(); game.initial_track=TrackCompiler.compile(document()); game.editor_test=true; game.vehicle_id="pickup"; root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	for point: float in [-22.0,-10.0,0.0,10.0,22.0]:
		game.sim.reset(Vector2(0,point)); game.sim.state.heading=0; game.previous_position=game.sim.state.position; game.previous_heading=0
		for i: int in range(24):
			game._present_frame(0.016)
			await process_frame
		await frames(4); await save("drive-"+str(point))
		check(game.sim.state.collision_count==0,"actual game view has no false warehouse contact")
	var before: Array=game.sim.state.snapshot(); game._present_frame(0.02)
	check(game.sim.state.snapshot()==before,"warehouse presentation preserves canonical state")
	game.queue_free(); await frames(3)

func editor_capture() -> void:
	var app: Node=load("res://core/app.gd").new(); var directory: String="user://warehouse_"+TrackLibrary.unique_id()
	app.set("library",TrackLibrary.new(directory)); app.set("records",LocalRecords.new(directory+"/records.json")); root.add_child(app)
	var deadline: int=Time.get_ticks_msec()+25000
	while not app.get("startup_complete") and Time.get_ticks_msec()<deadline: await process_frame
	check(app.get("startup_complete"),"actual editor finishes covered startup")
	var doc: Dictionary=document(); doc.objects=[]; app.set("document",doc); app.call("_show_screen","create")
	deadline=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<deadline:
		var canvas: EditorCanvas=app.get("canvas")
		if canvas!=null and canvas.native_preview!=null and not app.get("editor_world")._building and app.get("editor_preview_thread")==null: break
		await process_frame
	app.call("_editor_category","objects")
	var browser: ObjectBrowser=app.get("object_browser"); browser.category="Buildings"; browser.page=0; browser.refresh(); browser.choose("abandoned_warehouse")
	var canvas: EditorCanvas=app.get("canvas"); canvas._place(canvas.to_screen(Vector2.ZERO))
	check(app.get("document").objects.size()==1 and app.get("document").objects[0].kind=="abandoned_warehouse","actual browser places a warehouse directly on an existing road")
	var compiled: NativeTrack=TrackCompiler.compile(app.get("document"))
	check(compiled!=null and compiled.cell_at(Vector2.ZERO)==0 and compiled.cell_at(Vector2(8.7,0))==4,"actual placement retains road and solid walls")
	app.call("_undo"); check(app.get("document").objects.is_empty(),"one undo removes the warehouse")
	app.call("_redo"); check(app.get("document").objects.size()==1,"redo restores the same warehouse")
	await frames(30); await save("editor-buildings")
	app.queue_free(); await frames(3)
