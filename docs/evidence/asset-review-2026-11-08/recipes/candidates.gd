extends "res://../build/asset-review-2026-11-08/audit.gd"
## AOR04: offline candidate comparisons. No shipping mesh or cache is written.
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var observations: Array=[]
func buffers(mesh: Mesh)->int:
	var data: Dictionary=Metrics.mesh_info(mesh)
	return data.raw_gpu_buffer_bytes+data.lod_index_bytes
func indexed(source: Mesh)->ArrayMesh:
	var result:=ArrayMesh.new()
	for surface: int in range(source.get_surface_count()):
		var tool:=SurfaceTool.new();tool.create_from(source,surface);tool.index()
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface),tool.commit_to_arrays())
		result.surface_set_material(surface,source.surface_get_material(surface))
	return result
func verify_attributes(a: Mesh,b: Mesh)->void:
	for surface: int in range(a.get_surface_count()):
		var old: Array=a.surface_get_arrays(surface);var now: Array=b.surface_get_arrays(surface)
		var old_indices: PackedInt32Array=old[Mesh.ARRAY_INDEX] if old[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var new_indices: PackedInt32Array=now[Mesh.ARRAY_INDEX] if now[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var corners: int=old_indices.size() if not old_indices.is_empty() else old[Mesh.ARRAY_VERTEX].size()
		check(corners==new_indices.size(),"index candidate keeps every ordered triangle")
		var exact: bool=true;var positions_exact: bool=true;var largest: float=0.0
		for corner: int in range(corners):
			var i: int=old_indices[corner] if not old_indices.is_empty() else corner
			var j: int=new_indices[corner]
			if old[Mesh.ARRAY_VERTEX][i]!=now[Mesh.ARRAY_VERTEX][j]:exact=false;positions_exact=false
			for attribute: int in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
				if old[attribute]==null:continue
				var x: Variant=old[attribute][i];var y: Variant=now[attribute][j]
				if x!=y:exact=false
				if x is Vector3:largest=maxf(largest,x.distance_to(y))
				elif x is Vector2:largest=maxf(largest,x.distance_to(y))
				elif x is Color:largest=maxf(largest,maxf(absf(x.r-y.r),maxf(absf(x.g-y.g),absf(x.b-y.b))))
		check(positions_exact,"index candidate preserves every ordered corner position")
		observations.append({"type":"index_attribute_check","vertices_before":old[Mesh.ARRAY_VERTEX].size(),"vertices_after":now[Mesh.ARRAY_VERTEX].size(),"positions_exact":positions_exact,"decoded_attributes_exact":exact,"largest_decoded_difference":largest})

func tyres(radial: int)->ArrayMesh:
	var kit:=NativeTrackVisual.new();kit.theme_id="pine"
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array=[Vector2(0.24,0.025),Vector2(0.38,0.025),Vector2(0.455,0.045),Vector2(0.48,0.095),Vector2(0.48,0.225),Vector2(0.455,0.275),Vector2(0.36,0.29),Vector2(0.24,0.285),Vector2(0.23,0.11),Vector2(0.24,0.025)]
	var colors: Array=[Color("2e3737"),Color("394342"),Color("3a4342"),Color("303938"),Color("3a4342"),Color("505956"),Color("454e4b"),Color("242f2e"),Color("242f2e")]
	for height: float in [0.0,0.3]:
		var center:=Vector3.UP*height
		for row: int in range(profile.size()-1):
			for index: int in range(radial):
				var a: float=TAU*index/radial;var b: float=TAU*(index+1)/radial
				var lo: Vector2=profile[row];var hi: Vector2=profile[row+1]
				tool.set_color(colors[row])
				kit._quad(tool,center+Vector3(cos(a)*lo.x,lo.y,sin(a)*lo.x),center+Vector3(cos(b)*lo.x,lo.y,sin(b)*lo.x),center+Vector3(cos(b)*hi.x,hi.y,sin(b)*hi.x),center+Vector3(cos(a)*hi.x,hi.y,sin(a)*hi.x))
		PropGeometry.ring(tool,center+Vector3.UP*0.290,Vector3.UP,0.395,0.38,0.006,Color("636b61"),16 if radial<20 else 24)
		# Retain all 24 authored tread cuts, rather than replacing the tyre by a cylinder.
		for index: int in range(24):
			var a: float=TAU*index/24;var b: float=a+0.028
			PropGeometry.face(tool,[center+Vector3(cos(a)*0.482,0.096,sin(a)*0.482),center+Vector3(cos(b)*0.482,0.096,sin(b)*0.482),center+Vector3(cos(b+0.055)*0.482,0.224,sin(b+0.055)*0.482),center+Vector3(cos(a+0.055)*0.482,0.224,sin(a+0.055)*0.482)],Color("242e2d"))
	tool.generate_normals();tool.index();kit.free()
	return tool.commit()
func observe()->Dictionary:
	for frame: int in range(6):await RenderingServer.frame_post_draw
	return {"image":viewport.get_texture().get_image(),"primitives":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),"draws":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}
func compare(model: Node3D,parts: Array,label: String,extent: float,target: Vector3)->void:
	stage.add_child(model)
	for view: String in ["overhead","close"]:
		camera.size=extent if view=="overhead" else minf(extent*0.4,maxf(ObjectThumbnail._mesh_bounds(model).size.length()*1.4,2.0))
		var pitch: float=deg_to_rad(56.0)
		camera.look_at_from_position(target+Vector3(-0.32*cos(pitch),sin(pitch),0.95*cos(pitch))*65.0,target)
		var a: Dictionary=await observe()
		for part: Dictionary in parts:
			if part.node is MeshInstance3D:part.node.mesh=part.candidate
			else:part.node.multimesh.mesh=part.candidate
		var b: Dictionary=await observe()
		for part: Dictionary in parts:
			if part.node is MeshInstance3D:part.node.mesh=part.mesh
			else:part.node.multimesh.mesh=part.mesh
		var control: Dictionary=await observe()
		var metrics: Dictionary=a.image.compute_image_metrics(b.image,false)
		var restored: Dictionary=a.image.compute_image_metrics(control.image,false)
		check(restored.max==0.0,"original restored exactly "+label+"/"+view)
		check(a.primitives>0 and a.draws>0,"native candidate is visible "+label)
		var reference_color: Color=a.image.get_pixel(0,0);var varied: int=0
		for y: int in range(a.image.get_height()):
			for x: int in range(a.image.get_width()):
				if a.image.get_pixel(x,y)!=reference_color:varied+=1
				if varied>64:break
			if varied>64:break
		check(varied>64,"native image contains actual shaded detail "+label+"/"+view)
		a.image.save_png(output.path_join(label+"-"+view+"-original.png"));b.image.save_png(output.path_join(label+"-"+view+"-candidate.png"))
		var before_bytes: int=0;var after_bytes: int=0;var seen: Dictionary={}
		for part: Dictionary in parts:
			if seen.has(part.mesh.get_instance_id()):continue
			seen[part.mesh.get_instance_id()]=true;before_bytes+=buffers(part.mesh);after_bytes+=buffers(part.candidate)
		observations.append({"case":label,"view":view,"original_primitives":a.primitives,"candidate_primitives":b.primitives,"original_draws":a.draws,"candidate_draws":b.draws,"original_unique_raw_buffers":before_bytes,"candidate_unique_raw_buffers":after_bytes,"image_metrics":metrics,"restoration_metrics":restored})
	model.free();await process_frame
	write("partial-candidates.json",{"complete":false,"checks":checks,"failures":failures,"rows":observations})

func run()->void:
	var skip_cars: bool=false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		if argument=="--skip-cars":skip_cars=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Engine.time_scale=0.0;root.size=Vector2i(1280,720)
	viewport=SubViewport.new();viewport.size=root.size;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;stage.add_child(camera)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-56,-25,0);light.shadow_enabled=true;stage.add_child(light)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("34434a");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_energy=0.65;stage.add_child(world)
	for kind: String in ["tree","tyre_wall","fence"]:
		var model: NativeTrackVisual=await prop("winter",kind)
		var parts: Array=[];Metrics.collect(model,parts)
		for part: Dictionary in parts:part.candidate=indexed(part.mesh);verify_attributes(part.mesh,part.candidate)
		await compare(model,parts,"indexed-winter-"+kind,35.0/1.15,Vector3(0,1.0,0))
	for radial: int in [16,12]:
		var original: NativeTrackVisual=await prop("pine","tyre_wall")
		var tyre_parts: Array=[];Metrics.collect(original,tyre_parts)
		var reduction: Mesh=tyres(radial)
		for part: Dictionary in tyre_parts:
			check(tyres(20).surface_get_arrays(0)==part.mesh.surface_get_arrays(0),"review tyre builder exactly reproduces current 20-sided source")
			part.candidate=reduction
		await compare(original,tyre_parts,"radial-tyres-"+str(radial),35.0/1.15,Vector3(0,0.35,0))
	# Isolate one actual current road section, retaining material, UVs and all corners.
	var doc: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/to_the_trees.json"));doc.theme="pine"
	var track: NativeTrack=TrackCompiler.compile(doc)
	var visual:=NativeTrackVisual.new();visual.cache_race_world=false;visual.cache_road_meshes=false;stage.add_child(visual)
	await visual.build(track,BridgePresentation.new(track))
	var available: Array=[];Metrics.collect(visual,available)
	var road: MeshInstance3D
	for part: Dictionary in available:
		if not part.node is MeshInstance3D:continue
		var material: Material=part.node.material_override
		if material is ShaderMaterial and "road_color" in material.shader.code and part.mesh.surface_get_array_len(0)>10000:
			if road==null or part.mesh.surface_get_array_len(0)>road.mesh.surface_get_array_len(0):road=part.node
	check(road!=null,"real road mesh selected for indexed prototype")
	if road!=null:
		var holder:=Node3D.new();var clone: MeshInstance3D=road.duplicate();holder.add_child(clone)
		var candidate: ArrayMesh=indexed(clone.mesh);verify_attributes(clone.mesh,candidate)
		var center: Vector3=VisualGeometry.world(track.route[0])
		visual.free()
		await compare(holder,[{"node":clone,"mesh":clone.mesh,"candidate":candidate,"instances":1}],"indexed-road",35.0/1.15,center)
	else:visual.free()
	# Current model observations use the actual reduced constructor, not old master scenes.
	var seen_chassis: Dictionary={}
	for id: String in VehicleCatalog.IDS:
		if skip_cars:break
		var chassis: String=VehicleCatalog.model_id(id)
		if seen_chassis.has(chassis):continue
		seen_chassis[chassis]=true
		var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=true;car.cache_rest_pose=false;stage.add_child(car)
		while not car.model_ready:await process_frame
		for view: String in ["overhead","close"]:
			camera.size=35.0/1.15 if view=="overhead" else maxf(ObjectThumbnail._mesh_bounds(car).size.length()*1.2,2.0)
			var target:=Vector3(0,0.6,0);var pitch: float=deg_to_rad(56.0)
			camera.look_at_from_position(target+Vector3(-0.32*cos(pitch),sin(pitch),0.95*cos(pitch))*65.0,target)
			var result: Dictionary=await observe()
			result.image.save_png(output.path_join("car-"+id+"-"+view+".png"))
			observations.append({"case":"current-car-"+id,"view":view,"visible_primitives":result.primitives,"draws":result.draws})
		car.free();await process_frame
	viewport.free()
	write("candidates.json",{"requirements":["AOR04"],"checks":checks,"failures":failures,"rows":observations,"scope":"Offline candidates only. No geometry/paint/condition/collision/production policy changes. Pixel metrics are observations, not relaxed appearance assertions."})
	print("ASSET_CANDIDATES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
