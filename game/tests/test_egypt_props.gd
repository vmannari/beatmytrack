extends SceneTree
## Geometry, authoring, canonical footprint and retained-material integration.
const OUTPUT: String = "res://../docs/evidence/egypt-props-2026-10-16"
var checks: int = 0
var failures: int = 0
var metrics: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func run() -> void:
	for biome: String in TrackTheme.IDS:
		var offered: Array = CreatorCatalog.filtered("Buildings","",[],biome)
		var families: int = 0
		for family: Array in offered:
			if str(family[0]).begins_with("egypt_"): families += 1
		check(families == (4 if biome == "desert" else 0),biome+" offers exactly the appropriate Egyptian families")
	var kit := NativeTrackVisual.new(); kit.theme_id = "desert"
	for kind: String in PropEgypt.KINDS:
		print("EGYPT_GEOMETRY: ",kind)
		var source := SurfaceTool.new(); source.begin(Mesh.PRIMITIVE_TRIANGLES)
		check(CreatorPropVisual.append(source,kit,kind,Vector3.ZERO,1,0),kind+" builds using the shared shipping model")
		var mesh: ArrayMesh = source.commit()
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var valid: bool = vertices.size()>0 and vertices.size()==normals.size() and vertices.size()==colors.size()
		var degenerate: int = 0
		var normal_match: float = 1.0
		for i: int in range(vertices.size()):
			valid = valid and vertices[i].is_finite() and normals[i].is_finite() and normals[i].length()>0.95
		for i: int in range(0,vertices.size(),3):
			if (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length_squared()<1e-15: degenerate += 1
			var face: Vector3=(vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
			for j: int in range(3): normal_match=minf(normal_match,face.dot(normals[i+j]))
		check(valid,kind+" has finite opaque pigments and unit outward-capable normals")
		check(degenerate==0,kind+" has no zero-area triangles")
		check(normal_match>0.0 if kind in ["egypt_column","egypt_column_broken"] else normal_match>0.999,kind+" preserves outward curved or flat stone normals through the model cache")
		check(vertices.size()/3<10000,kind+" remains below ten thousand triangles")
		var footprint: Vector2 = CreatorObjects.dimensions(kind)
		var bounds: AABB = mesh.get_aabb()
		check(bounds.position.x>=-footprint.x*0.5 and bounds.end.x<=footprint.x*0.5 and bounds.position.z>=-footprint.y*0.5 and bounds.end.z<=footprint.y*0.5,kind+" stays inside its collision and selection footprint")
		metrics.append({"kind":kind,"triangles":vertices.size()/3,"bounds":str(bounds)})
		var transformed := SurfaceTool.new(); transformed.begin(Mesh.PRIMITIVE_TRIANGLES)
		CreatorPropVisual.append(transformed,kit,kind,Vector3(4,0,-8),1.5,0.73)
		var actual: PackedVector3Array = transformed.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var pose := Transform3D(Basis(Vector3.UP,0.73).scaled(Vector3.ONE*1.5),Vector3(4,0,-8))
		var exact: bool = actual.size()==vertices.size()
		for i: int in range(actual.size()): exact = exact and (pose*vertices[i]).distance_to(actual[i])<0.00001
		check(exact,kind+" cached geometry preserves independent scale and rotation")
		var doc: Dictionary = TrackDocument.create_default(); doc.theme = "desert"
		doc.objects = [{"kind":kind,"position":[0,0],"rotation":37.0,"scale":1.5}]
		check(TrackDocument.validate(doc).is_empty(),kind+" survives the bounded authoring contract")
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track!=null and track.cell_at(Vector2.ZERO)==4,kind+" compiles a real solid obstacle")
		var serialized: String = JSON.stringify(doc)
		var restored: Dictionary = JSON.parse_string(serialized)
		check(TrackDocument.validate(restored).is_empty() and TrackCompiler.compile(restored).content_hash==track.content_hash,kind+" round-trips without a document or compiled hash change")
		var cells: PackedInt32Array = track.cells.duplicate(); var route: PackedVector2Array = track.route.duplicate()
		var visual := NativeTrackVisual.new(); visual.theme_id = "desert"
		visual._build_placed_objects(track)
		check(track.cells==cells and track.route==route and JSON.stringify(doc)==serialized,kind+" presentation leaves canonical data unchanged")
		check(visual.has_node("EgyptianStonework"),kind+" receives the shared stone material")
		var rendered: Array=visual.get_node("EgyptianStonework").mesh.surface_get_arrays(0)
		var render_vertices: PackedVector3Array=rendered[Mesh.ARRAY_VERTEX]
		var render_normals: PackedVector3Array=rendered[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=rendered[Mesh.ARRAY_INDEX]
		var assembled_match: float=1.0
		var basis:=Basis(Vector3.UP,deg_to_rad(37.0))
		# The source keeps hidden faces until final normal generation. Compare
		# the draw contract, including every surviving authored normal, rather
		# than requiring enclosed preparation faces to be drawn as well.
		var source_arrays: Array=PropGeometry.arrays(source)
		var source_draw: PackedInt32Array=source_arrays[Mesh.ARRAY_INDEX] if source_arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if source_draw.is_empty():
			source_draw.resize(vertices.size())
			for i: int in range(vertices.size()): source_draw[i]=i
		check(indices.size()==source_draw.size(),kind+" world assembly retains every prepared draw triangle")
		for i: int in range(indices.size()): assembled_match=minf(assembled_match,(basis*normals[source_draw[i]]).dot(render_normals[indices[i]]))
		check(assembled_match>0.999,kind+" world assembly preserves the authored normals under the Desert sun")
		visual.free()
	kit.free()
	await retained_materials()
	check(CreatorPropVisual.meshes.size()<=CreatorPropVisual.CACHE_LIMIT and CreatorPropVisual.cache_bytes<=CreatorPropVisual.CACHE_BUDGET,"mesh reuse respects the existing entry and byte caps")
	print("EGYPT_MODEL_METRICS: ",JSON.stringify(metrics))
	if DisplayServer.get_name()!="headless": await captures()
	print("EGYPT_PROPS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func retained_materials() -> void:
	var doc: Dictionary = TrackDocument.create_default(); doc.theme = "desert"
	doc.objects = [{"kind":"egypt_obelisk","position":[0,0],"rotation":0},{"kind":"crate","position":[4,0],"rotation":0},{"kind":"hut","position":[8,0],"rotation":0},{"kind":"egypt_column","position":[12,0],"rotation":0}]
	var track: NativeTrack = TrackCompiler.compile(doc)
	var visual := NativeTrackVisual.new(); visual.theme_id="desert"; visual.colors=TrackTheme.palette("desert")
	root.add_child(visual)
	var batches = preload("res://editor/placed_object_batches.gd").new()
	check(await batches.refresh(visual,track,false,func() -> bool: return true),"retained mixed editor batch prepares")
	var egypt: int = 0; var ordinary: int = 0
	for key: String in batches.groups:
		for node: Node in batches.groups[key].nodes:
			if node is MeshInstance3D and node.material_override is ShaderMaterial:
				if node.material_override.shader==preload("res://track/egypt_stone.gdshader"): egypt += 1
			if node is MeshInstance3D and node.material_override is StandardMaterial3D: ordinary += 1
	check(egypt>0 and ordinary>0,"Egyptian shader stays separate from ordinary opaque editor props")
	check(not await batches.refresh(visual,track,false,func() -> bool: return true),"unchanged editor batch is retained")
	visual.queue_free(); await process_frame

func frames(count: int) -> void:
	for i: int in range(count): await process_frame
	await RenderingServer.frame_post_draw

func save(name: String) -> void:
	var folder: String = ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(folder)
	var pixels: Image = root.get_texture().get_image()
	check(pixels!=null and not pixels.is_empty() and pixels.save_png(folder+"/"+name+".png")==OK,name+" native capture saved")

func captures() -> void:
	root.size=Vector2i(1600,900); root.content_scale_size=root.size
	var buttons := Control.new(); root.add_child(buttons)
	for i: int in range(PropEgypt.KINDS.size()):
		var kind: String=PropEgypt.KINDS[i]
		var button: ObjectThumbnail = ObjectThumbnail.make(kind,CreatorCatalog.label(kind),false,func() -> void: pass,"desert")
		buttons.add_child(button); button.position=Vector2(30+i*312,50); button.scale=Vector2(2.8,2.8)
	await frames(18); await save("palette-models")
	for button: ObjectThumbnail in buttons.get_children():
		check(button._viewport==null and button._image.texture!=null,"Egyptian icon bakes and releases its viewport")
	buttons.queue_free(); await process_frame
	for kind: String in PropEgypt.KINDS:
		var host := Button.new(); root.add_child(host)
		var view: SubViewport = ObjectThumbnail._render_preview(host,kind,"desert")
		view.size=Vector2i(1600,1000)
		var camera: Camera3D
		for child: Node in view.get_children():
			if child is Camera3D: camera=child
		camera.size*=1.08
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		await frames(4)
		var pixels: Image = view.get_texture().get_image()
		var folder: String=ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method())
		check(pixels.save_png(folder+"/"+kind+".png")==OK,kind+" actual model closeup saved")
		host.queue_free(); await process_frame
	var doc: Dictionary=TrackDocument.create_default(); doc.theme="desert"
	doc.objects=[{"kind":"egypt_pyramid","position":[-17,0],"rotation":12},{"kind":"egypt_obelisk","position":[-23,12],"rotation":0},{"kind":"egypt_column","position":[-18,16],"rotation":0},{"kind":"egypt_column_broken","position":[-13,13],"rotation":24},{"kind":"egypt_wall","position":[-6,15],"rotation":10}]
	var race: Node=load("res://core/game.tscn").instantiate()
	race.set("production_mode",true); race.set("initial_track",TrackCompiler.compile(doc)); root.add_child(race)
	await frames(20)
	race.set_physics_process(false); race.set_process(false); race.set("countdown_ticks",0)
	(race.get("race_cues") as Control).hide()
	var camera: Camera3D=race.get("camera")
	camera.set_process(false); camera.set_physics_process(false)
	camera.look_at_from_position(Vector3(18,51,-48),Vector3(0,0,0)); camera.size=65
	await frames(5); await save("desert-monuments-overview")
	if "--diagnose-shadows" in OS.get_cmdline_user_args():
		var sunlight: DirectionalLight3D=race.get("biome_light")
		var old_bias: float=sunlight.shadow_normal_bias
		sunlight.shadow_normal_bias=0.0
		await frames(4); await save("diagnostic-zero-normal-bias")
		sunlight.shadow_enabled=false
		await frames(4); await save("diagnostic-no-shadows")
		sunlight.shadow_enabled=true; sunlight.shadow_normal_bias=old_bias
		camera.look_at_from_position(Vector3(-9,15,-19),Vector3(-17,3,0)); camera.size=19
		await frames(4); await save("diagnostic-pyramid-sun-closeup")
		camera.look_at_from_position(Vector3(18,51,-48),Vector3.ZERO); camera.size=65
	# Actual production follow-camera framing, with no camera changes shipped.
	var state: VehicleState=race.get("sim").state
	var track: NativeTrack=race.get("native_track")
	state.position=track.route[track.nearest_route(Vector2(-30,8))]
	state.heading=0; race.set("previous_position",state.position); race.set("previous_heading",state.heading)
	race.call("_present_frame",0.0)
	(camera as FollowCamera).follow(state.position,Vector2.ZERO,state.heading,0,true)
	await frames(5); await save("desert-driving-camera")
	race.queue_free(); await frames(3)
	await editor_capture(doc)

func editor_capture(doc: Dictionary) -> void:
	var app: Node=load("res://core/app.gd").new()
	var directory: String="user://egypt_props_"+TrackLibrary.unique_id()
	app.set("library",TrackLibrary.new(directory)); app.set("records",LocalRecords.new(directory+"/records.json"))
	root.add_child(app)
	var deadline: int=Time.get_ticks_msec()+25000
	while not app.get("startup_complete") and Time.get_ticks_msec()<deadline: await process_frame
	check(app.get("startup_complete"),"actual editor fixture completes covered startup")
	app.set("document",doc); app.call("_show_screen","create")
	deadline=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<deadline:
		var canvas: EditorCanvas=app.get("canvas")
		if canvas!=null and canvas.native_preview!=null and not app.get("editor_world")._building and app.get("editor_preview_thread")==null: break
		await process_frame
	check(app.get("canvas")!=null and app.get("canvas").native_preview!=null,"actual Desert editor prepares Egyptian prop document")
	app.call("_editor_category","objects")
	var browser: ObjectBrowser=app.get("object_browser")
	browser.category="Buildings"; browser.page=0; browser.refresh()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=size; root.content_scale_size=size
		await frames(22); await save("editor-buildings-"+str(size.x))
	app.queue_free(); await frames(3)
