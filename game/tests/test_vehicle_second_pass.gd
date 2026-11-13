extends "res://tests/test_vehicle_mesh_simplification.gd"
## VSP2: incremental accepted-model comparisons, exact ghost corners and budgets.
var old_policy: RefCounted
var old_ghost: GDScript
var accepted_control: bool=false
func attachment(root_node: Node, part: Node) -> String:
	var pieces: Array[String]=[]
	var cursor: Node=part
	while cursor!=root_node and cursor!=null:
		var token: String=str(cursor.name)
		for generated: String in ["_MeshInstance3D_","_Node3D_"]:
			if token.begins_with(generated) and token.trim_prefix(generated).is_valid_int():token=generated+"slot_"+str(cursor.get_index())
		pieces.push_front(token);cursor=cursor.get_parent()
	return "/".join(pieces)
func sequential_control(mesh: ArrayMesh) -> ArrayMesh:
	var surfaces: Array=mesh.get("_surfaces").duplicate(true)
	var surface: Dictionary=surfaces[0]
	var count: int=surface.vertex_count
	var data:=PackedByteArray();data.resize(count*(2 if count<=65536 else 4))
	for i: int in range(count):
		if count<=65536:data.encode_u16(i*2,i)
		else:data.encode_u32(i*4,i)
	surface.index_data=data;surface.index_count=count;surface.format=int(surface.format)|Mesh.ARRAY_FORMAT_INDEX
	var result:=ArrayMesh.new();result.set("_surfaces",surfaces)
	check(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==result.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"sequential-index control keeps positions")
	check(mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]==result.surface_get_arrays(0)[Mesh.ARRAY_NORMAL],"sequential-index control keeps normals")
	return result
func load_controls() -> void:
	before_root="res://../docs/evidence/vehicle-simplification-pass2-2026-11-07/before/"
	old_policy=load(before_root+"game/vehicle/car_mesh_lods.gd").new()
	old_ghost=GDScript.new()
	old_ghost.source_code=FileAccess.get_file_as_string(before_root+"game/vehicle/personal_ghost.gd").replace("class_name PersonalGhost","")
	check(old_ghost.reload()==OK,"archived ghost control compiles")
func ghost_pair(car: CarVisual) -> Array:
	var before: MeshInstance3D=old_ghost.new()
	var after:=PersonalGhost.new()
	before.configure(car);after.configure(car)
	var aa: Array=before.mesh.surface_get_arrays(0)
	var bb: Array=after.mesh.surface_get_arrays(0)
	var exact: bool=true
	var count: int=aa[Mesh.ARRAY_INDEX].size() if aa[Mesh.ARRAY_INDEX]!=null and not aa[Mesh.ARRAY_INDEX].is_empty() else aa[Mesh.ARRAY_VERTEX].size()
	check(bb[Mesh.ARRAY_INDEX].size()==count,"ghost retains all triangle corners "+car.vehicle_id)
	for corner: int in range(count):
		var left: int=aa[Mesh.ARRAY_INDEX][corner] if aa[Mesh.ARRAY_INDEX]!=null and not aa[Mesh.ARRAY_INDEX].is_empty() else corner
		var right: int=bb[Mesh.ARRAY_INDEX][corner]
		if aa[Mesh.ARRAY_VERTEX][left]!=bb[Mesh.ARRAY_VERTEX][right] or aa[Mesh.ARRAY_NORMAL][left]!=bb[Mesh.ARRAY_NORMAL][right]: exact=false;break
	check(exact,"ghost positions/normals exact per ordered corner "+car.vehicle_id)
	var before_bytes: int=aa[Mesh.ARRAY_VERTEX].size()*24
	var after_bytes: int=bb[Mesh.ARRAY_VERTEX].size()*24+bb[Mesh.ARRAY_INDEX].size()*4
	check(after_bytes<before_bytes,"indexed ghost reduces accounted memory "+car.vehicle_id)
	var total: int=0
	for entry: Dictionary in PersonalGhost.prepared_meshes:total+=int(entry.bytes)
	check(total<=PersonalGhost.MAX_BYTES and PersonalGhost.prepared_meshes.size()<=4,"existing ghost cache bounds")
	rows.append({"ghost":car.vehicle_id,"parts":car.customisation.duplicate(),"before_vertices":aa[Mesh.ARRAY_VERTEX].size(),"after_vertices":bb[Mesh.ARRAY_VERTEX].size(),"before_bytes":before_bytes,"after_bytes":after_bytes,"before_buffer_bytes":buffer_bytes(before.mesh),"after_buffer_bytes":buffer_bytes(after.mesh),"exact_corners":exact})
	return [before,after]
func buffer_bytes(mesh: ArrayMesh) -> int:
	var total: int=0
	for surface: Dictionary in mesh.get("_surfaces"):
		for value: Variant in surface.values():
			if value is PackedByteArray:total+=value.size()
	return total
func lod_indices(raw: Variant, vertices: int) -> PackedInt32Array:
	if raw is PackedInt32Array:return raw
	var stride: int=2 if vertices<=65536 else 4
	var result:=PackedInt32Array();result.resize(raw.size()/stride)
	for i: int in range(result.size()):result[i]=raw.decode_u16(i*stride) if stride==2 else raw.decode_u32(i*stride)
	return result
func audit_triangle_order() -> void:
	var paths: Array[String]=[]
	for folder: String in [Base.DIRECTORY,Kits.DIRECTORY,"res://assets/garage/cars_v1","res://assets/menu/header_car_templates_v1"]:scene_paths(folder,paths)
	for path: String in paths:
		if not ResourceLoader.exists(before_root+"game/"+path.trim_prefix("res://")):continue
		var before_scene: PackedScene=load(before_root+"game/"+path.trim_prefix("res://"))
		var after_scene: PackedScene=load(path)
		var before: Node=before_scene.instantiate();var after: Node=after_scene.instantiate()
		var left: Array[Node]=before.find_children("*","MeshInstance3D",true,false)
		var right: Array[Node]=after.find_children("*","MeshInstance3D",true,false)
		for i: int in range(mini(left.size(),right.size())):
			if not left[i].mesh is ArrayMesh or not right[i].mesh is ArrayMesh:continue
			var aa: Array=left[i].mesh.get("_surfaces");var bb: Array=right[i].mesh.get("_surfaces")
			for surface: int in range(mini(aa.size(),bb.size())):
				var old_lods: Array=aa[surface].get("lods",[]);var new_lods: Array=bb[surface].get("lods",[])
				if old_lods.is_empty() and not new_lods.is_empty():
					check(str(right[i].name)=="SportPressureSkirt","only separate Hover skirt gains a new LOD family "+path)
					continue
				check(old_lods.size()==new_lods.size(),"same LOD family count "+path)
				for level: int in range(0,mini(old_lods.size(),new_lods.size()),2):
					check(old_lods[level]==new_lods[level],"same geometric LOD error "+path)
					var old_indices: PackedInt32Array=lod_indices(old_lods[level+1],aa[surface].vertex_count)
					var new_indices: PackedInt32Array=lod_indices(new_lods[level+1],bb[surface].vertex_count)
					var triangles: Dictionary={}
					for corner: int in range(0,old_indices.size(),3):
						var key:=Vector3i(old_indices[corner],old_indices[corner+1],old_indices[corner+2]);triangles[key]=int(triangles.get(key,0))+1
					for corner: int in range(0,new_indices.size(),3):
						var key:=Vector3i(new_indices[corner],new_indices[corner+1],new_indices[corner+2]);triangles[key]=int(triangles.get(key,0))-1
					var exact: bool=old_indices.size()==new_indices.size()
					for count: int in triangles.values():
						if count!=0:exact=false;break
					check(exact,"all LOD triangles/corner winding exact "+path)
		before.free();after.free()
func ghost_pictures(car: CarVisual,label: String) -> void:
	var pair: Array=ghost_pair(car)
	var reference: MeshInstance3D=pair[0]
	var ghost: PersonalGhost=pair[1]
	stage.add_child(ghost);ghost.show();car.hide()
	for view: String in ["overhead","macro"]:
		camera.size=35.0/1.15 if view=="overhead" else 3.4
		camera.position=Vector3(8,32,20) if view=="overhead" else Vector3(5.4,3.8,-7.1)
		camera.look_at(Vector3(0,0.65,0))
		var target: Mesh=ghost.mesh
		ghost.mesh=reference.mesh;await settle()
		var a: Image=viewport.get_texture().get_image()
		ghost.mesh=target;await settle()
		var b: Image=viewport.get_texture().get_image()
		var delta: Dictionary=image_difference(a,b)
		ghost.mesh=sequential_control(reference.mesh);await settle()
		var c: Image=viewport.get_texture().get_image()
		var indexed_control: Dictionary=image_difference(a,c)
		print("GHOST_DRAW_CONTROL ",label,"-",view," candidate=",JSON.stringify(delta)," sequential=",JSON.stringify(indexed_control))
		# Changing only draw-arrays to sequential draw-elements reproduces the
		# small GPU interpolation differences despite identical raw vertices.
		# Keep exact corner geometry checks and the established appearance gates;
		# additionally bound the candidate by that same-geometry control plus the
		# existing one-byte render-restoration rounding allowance.
		check(delta.max_channel_delta<=maxi(1,indexed_control.max_channel_delta+1),"ghost stays within exact-geometry indexing control precision "+label+"-"+view)
		check(delta.mean_rgb_delta<0.25 and delta.pixels_over_8_fraction<0.005,"retained native ghost appearance gates "+label+"-"+view)
		check(a.save_png(output.path_join("ghost-"+label+"-"+view+"-before.png"))==OK,"ghost before capture")
		check(b.save_png(output.path_join("ghost-"+label+"-"+view+"-after.png"))==OK,"ghost after capture")
		rows.append({"ghost_case":label+"-"+view,"difference":delta,"sequential_control":indexed_control})
	ghost.free();reference.free();car.show()
func native_case(car: CarVisual,label: String,meshes: Array,full: Array) -> void:
	for index: int in range(meshes.size()): meshes[index].node.mesh=full[index]
	await settle()
	var before: Image = viewport.get_texture().get_image()
	var before_primitives: int = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	for item: Dictionary in meshes: item.node.mesh=item.original
	await settle()
	var after: Image = viewport.get_texture().get_image()
	var after_primitives: int = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	for index: int in range(meshes.size()): meshes[index].node.mesh=full[index]
	await settle()
	var control: Image = viewport.get_texture().get_image()
	var metrics: Dictionary = image_difference(before,after)
	var restoration: Dictionary = image_difference(before,control)
	check(metrics.mean_rgb_delta<0.25,"retained appearance energy gate "+label)
	check(metrics.pixels_over_8_fraction<0.005,"retained visible-pixel gate "+label)
	check(restoration.max_channel_delta<=1,"full-detail frame restored "+label)
	check(after_primitives<=before_primitives,"no added visible primitives "+label)
	if car.vehicle_id!="hovercraft": check(after_primitives==before_primitives,"same visible triangle set "+label)
	elif label.ends_with("stock-day-overhead"): check(after_primitives<before_primitives,"additional Hover skirt reduction "+label)
	for image_entry: Array in [[before,"before"],[after,"after"],[control,"control"]]:
		check(image_entry[0].save_png(output.path_join(label+"-"+image_entry[1]+".png"))==OK,"capture "+label+"-"+image_entry[1])
	rows.append({"case":label,"vehicle":car.vehicle_id,"difference":metrics,"restoration":restoration,"full_primitives":before_primitives,"lod_primitives":after_primitives})
	print("VEHICLE_LOD_NATIVE ",label," ",before_primitives," -> ",after_primitives," ",JSON.stringify(metrics))
	for item: Dictionary in meshes: item.node.mesh=item.original

func native_review(only: String) -> void:
	Engine.time_scale=0.0
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,720); viewport.own_world_3d=true
	viewport.mesh_lod_threshold=1.0; viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	stage=Node3D.new(); viewport.add_child(stage)
	camera=Camera3D.new(); stage.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.current=true
	light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-58,-35,0); light.shadow_enabled=true; stage.add_child(light)
	var world:=WorldEnvironment.new(); environment=Environment.new(); world.environment=environment
	environment.background_mode=Environment.BG_COLOR; environment.background_color=Color("34434a")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_energy=0.5; stage.add_child(world)
	var floor:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(90,90); floor.mesh=plane; floor.position.y=-0.025
	floor.material_override=VisualGeometry.material(Color("73796c")); stage.add_child(floor)
	var policy = Lods.new()
	for id: String in VehicleCatalog.IDS:
		if not only.is_empty() and only!=id: continue
		for variant: Dictionary in [{"simple":false,"fitted":false},{"simple":false,"fitted":true}]:
			var fitted: bool=variant.fitted
			simple_case=variant.simple
			var parts: Dictionary=VehicleCustomisation.defaults()
			if fitted:
				for category: String in VehicleCustomisation.CATEGORIES: parts[category]=VehicleCustomisation.options(category,id)[-1][0]
			var car: CarVisual=make_car(id,parts,true,true)
			while not car.model_ready: await process_frame
			var condition:=VehicleWeathering.new(); condition.configure(car,"winter",VehicleCatalog.config(id))
			condition.restore({"dirt":0.22,"slow_dirt":0.08,"color":"b9a788","snow":0.16,"slow_snow":0.04})
			var glass=preload("res://race/electric_glass_lighting.gd").new()
			var meshes: Array=[]; var full: Array=[]
			for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false): meshes.append({"node":node,"original":node.mesh})
			old_policy.prepare_vehicle(car,id,2.0)
			for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
				full.append(node.mesh)
			if accepted_control:
				for index: int in range(meshes.size()):meshes[index].original=full[index]
			for item: Dictionary in meshes: item.node.mesh=item.original
			for night: bool in [false,true]:
				car.set_night_headlights(night)
				condition.configure(car,"night_city" if night else "winter",VehicleCatalog.config(id))
				glass.configure(car,"night_city" if night else "winter")
				environment.ambient_light_energy=0.18 if night else 0.5
				light.light_energy=0.25 if night else 1.0
				for view: String in ["overhead","close","rear","macro"]:
					camera.size=35.0/1.15 if view=="overhead" else (3.4 if view=="macro" else 5.8)
					camera.position=Vector3(8,32,20) if view=="overhead" else Vector3(5.4,3.8,-7.1 if view=="close" else 7.1)
					camera.look_at(Vector3(0,0.65,0))
					await native_case(car,id+("-simple" if simple_case else "")+("-fitted" if fitted else "-stock")+("-night-" if night else "-day-")+view,meshes,full)
			glass.reset(); condition.reset()
			await ghost_pictures(car,id+("-fitted" if fitted else "-stock"))
			car.free(); await process_frame
	viewport.free(); await process_frame

func run() -> void:
	load_controls()
	output="res://../docs/evidence/vehicle-simplification-pass2-2026-11-07/structural"
	var only: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		if argument.begins_with("--vehicle="):only=argument.trim_prefix("--vehicle=")
		if argument=="--accepted-control":accepted_control=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if DisplayServer.get_name()=="headless":
		asset_audit()
		audit_triangle_order()
		for id: String in VehicleCatalog.IDS:
			for fitted: bool in [false,true]:
				var car:=CarVisual.new();car.vehicle_id=id;car.customisation=VehicleCustomisation.defaults()
				if fitted:
					for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
				root.add_child(car)
				while not car.model_ready:await process_frame
				var pair: Array=ghost_pair(car)
				for ghost: Node in pair:ghost.free()
				car.free();await process_frame
	else: await native_review(only)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"rows":rows},"\t"))
	print("VEHICLE_SECOND_PASS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
