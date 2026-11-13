extends "res://tests/capture_modular_car_ab.gd"
## VSP01-VSP04: exact original buffers, all-car coverage and native controls.
const Lods = preload("res://vehicle/car_mesh_lods.gd")
var before_root: String = "res://../docs/evidence/vehicle-simplification-2026-11-07/before/"
var checks: int = 0
var camera: Camera3D
var light: DirectionalLight3D
var environment: Environment
var simple_case: bool = false

func make_car(vehicle: String, parts: Dictionary, prepared: bool, decorated: bool = false) -> CarVisual:
	Cache.enabled=prepared; Base.enabled=prepared; Kits.enabled=prepared
	Cache.entries.clear()
	var car:=CarVisual.new()
	car.vehicle_id=vehicle; car.simple_model=simple_case
	car.customisation=parts.duplicate(true); car.livery=VehicleLivery.defaults(vehicle)
	if decorated:
		car.livery.colors.body="277ab1"; car.livery.colors.accent="f0d58b"
		car.livery.pattern=str(LiveryCatalog.patterns[0].id)
		car.livery.stickers.hood.id=str(LiveryCatalog.stickers[0].id)
		if LiveryCatalog.has_roof(vehicle): car.livery.stickers.roof.id=str(LiveryCatalog.stickers[0].id)
	stage.add_child(car)
	return car

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("VEHICLE_LOD_FAIL ",label)

func value_key(value: Variant) -> Variant:
	if value is Shader: return value.code
	if value is Texture2D: return value.resource_path if not value.resource_path.is_empty() else [value.get_image().get_format(),value.get_image().get_data()]
	if value is Material: return material_key(value)
	return value

func material_key(material: Material) -> Array:
	if material == null: return []
	var result: Array = [material.get_class()]
	if material is ShaderMaterial:
		result.append(material.shader.code)
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			var value: Variant = material.get_shader_parameter(uniform.name)
			if value == null: value = RenderingServer.shader_get_parameter_default(material.shader.get_rid(),uniform.name)
			result.append([uniform.name,value_key(value)])
	else:
		for property: Dictionary in material.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"): result.append([property.name,value_key(material.get(property.name))])
	return result

func has_lods(mesh: Mesh) -> bool:
	if not mesh is ArrayMesh: return false
	for surface: Dictionary in mesh.get("_surfaces"):
		if not surface.get("lods",[]).is_empty(): return true
	return false

func scene_paths(directory: String, paths: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(directory):
		if file.ends_with(".scn"): paths.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(directory): scene_paths(directory.path_join(child),paths)

func attachment(root_node: Node, part: Node) -> String:
	# Engine-assigned anonymous leaf suffixes depend on bake process history.
	# Their exact parent, sibling slot, transform, complete buffers and materials
	# remain checked. Authored node names (including articulation) remain exact.
	var name_text: String=str(part.name)
	if name_text.begins_with("_MeshInstance3D_") and name_text.trim_prefix("_MeshInstance3D_").is_valid_int():
		return str(root_node.get_path_to(part.get_parent()))+"/anonymous-mesh-slot-"+str(part.get_index())
	return str(root_node.get_path_to(part))

func asset_audit() -> void:
	var paths: Array[String] = []
	for directory: String in [Base.DIRECTORY,Kits.DIRECTORY,"res://assets/garage/cars_v1","res://assets/menu/header_car_templates_v1"]: scene_paths(directory,paths)
	paths.sort()
	var coverage: Dictionary = {}
	var policy = Lods.new()
	for path: String in paths:
		var vehicle: String = ""
		for id: String in VehicleCatalog.IDS:
			if path.contains("/"+id+"/") or path.get_file().begins_with(id): vehicle = id
		# Retired pickup/classic/formula resources are retained in the checkout;
		# this pass covers the same five-car library as the export preflight.
		if vehicle.is_empty(): continue
		var previous: String = before_root+"game/"+path.trim_prefix("res://")
		check(ResourceLoader.exists(previous),"archived asset "+path)
		if not ResourceLoader.exists(previous): continue
		var old_scene: PackedScene = load(previous)
		var new_scene: PackedScene = load(path)
		var before: Node = old_scene.instantiate()
		var after: Node = new_scene.instantiate()
		var old_frames: Array[Node]=before.find_children("*","Node3D",true,false)
		var new_frames: Array[Node]=after.find_children("*","Node3D",true,false)
		check(old_frames.size()==new_frames.size(),"same complete articulation tree "+path)
		for frame: int in range(mini(old_frames.size(),new_frames.size())):
			var old_frame: Node3D=old_frames[frame]
			var new_frame: Node3D=new_frames[frame]
			check(old_frame.get_class()==new_frame.get_class() and old_frame.transform==new_frame.transform and old_frame.visible==new_frame.visible and attachment(before,old_frame)==attachment(after,new_frame),"exact articulation frame "+path+":"+str(after.get_path_to(new_frame)))
		var left: Array[Node] = before.find_children("*","MeshInstance3D",true,false)
		var right: Array[Node] = after.find_children("*","MeshInstance3D",true,false)
		check(left.size()==right.size(),"same mesh count "+path)
		var with_lods: int = 0
		for index: int in range(mini(left.size(),right.size())):
			var a: MeshInstance3D = left[index]
			var b: MeshInstance3D = right[index]
			var label: String = path+":"+str(after.get_path_to(b))
			check(attachment(before,a)==attachment(after,b),"same attachment "+label)
			check(a.transform==b.transform and a.visible==b.visible and a.cast_shadow==b.cast_shadow and a.layers==b.layers,"same pose/visibility/shadows "+label)
			check(a.mesh.get_aabb()==b.mesh.get_aabb(),"same bounds "+label)
			check(a.mesh.get_surface_count()==b.mesh.get_surface_count(),"same surface count "+label)
			for surface: int in range(mini(a.mesh.get_surface_count(),b.mesh.get_surface_count())):
				check(a.mesh.surface_get_arrays(surface)==b.mesh.surface_get_arrays(surface),"all original attributes/indices exact "+label)
				check(material_key(a.get_active_material(surface))==material_key(b.get_active_material(surface)),"same complete material "+label)
				if a.mesh is ArrayMesh and b.mesh is ArrayMesh:
					var aa: Dictionary = a.mesh.get("_surfaces")[surface].duplicate()
					var bb: Dictionary = b.mesh.get("_surfaces")[surface].duplicate()
					for key: String in ["lods","material"]:
						aa.erase(key); bb.erase(key)
					check(aa==bb,"original GPU storage exact "+label)
			if has_lods(b.mesh):
				with_lods += 1
				check(policy.eligible(b,vehicle),"LOD restricted to eligible geometry "+label)
				check(b.lod_bias==(1.0 if path.begins_with("res://assets/garage/") else 2.0),"conservative per-car bias "+label)
			if not policy.eligible(b,vehicle): check(not has_lods(b.mesh),"glass/layered hull/proxies retain full detail "+label)
		if path.begins_with(Base.DIRECTORY) or path.begins_with("res://assets/garage/cars_v1"):
			check(with_lods>0,"every vehicle assembly has useful LODs "+path)
		coverage[vehicle] = int(coverage.get(vehicle,0))+with_lods
		rows.append({"path":path,"vehicle":vehicle,"meshes":right.size(),"meshes_with_lods":with_lods})
		before.free(); after.free()
	check(rows.size()==468,"complete 468-resource library")
	for id: String in VehicleCatalog.IDS: check(int(coverage.get(id,0))>0,"all five vehicles covered "+id)

func image_difference(a: Image,b: Image) -> Dictionary:
	var result: Dictionary = difference(a,b)
	var aa: PackedByteArray = a.get_data()
	var bb: PackedByteArray = b.get_data()
	var over: int = 0
	for pixel: int in range(aa.size()/4):
		var peak: int = 0
		for channel: int in range(3): peak=maxi(peak,absi(int(aa[pixel*4+channel])-int(bb[pixel*4+channel])))
		if peak>8: over+=1
	result.pixels_over_8_fraction = float(over)/(aa.size()/4)
	return result

func settle() -> void:
	for _frame: int in range(6): await RenderingServer.frame_post_draw

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
	if label.ends_with("stock-day-overhead"): check(after_primitives<before_primitives,"measured all-car race reduction "+label)
	for image_entry: Array in [[before,"full"],[after,"lod"],[control,"control"]]:
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
		for variant: Dictionary in [{"simple":false,"fitted":false},{"simple":false,"fitted":true},{"simple":true,"fitted":false}]:
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
			for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
				meshes.append({"node":node,"original":node.mesh}); full.append(policy.full_detail(node.mesh))
			for night: bool in [false,true]:
				car.set_night_headlights(night)
				condition.configure(car,"night_city" if night else "winter",VehicleCatalog.config(id))
				glass.configure(car,"night_city" if night else "winter")
				environment.ambient_light_energy=0.18 if night else 0.5
				light.light_energy=0.25 if night else 1.0
				for view: String in ["overhead","close","rear"]:
					camera.size=35.0/1.15 if view=="overhead" else 5.8
					camera.position=Vector3(8,32,20) if view=="overhead" else Vector3(5.4,3.8,-7.1 if view=="close" else 7.1)
					camera.look_at(Vector3(0,0.65,0))
					await native_case(car,id+("-simple" if simple_case else "")+("-fitted" if fitted else "-stock")+("-night-" if night else "-day-")+view,meshes,full)
			glass.reset(); condition.reset(); car.free(); await process_frame
	viewport.free(); await process_frame

func run() -> void:
	output="res://../docs/evidence/vehicle-simplification-2026-11-07/structural"
	var only: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument.begins_with("--vehicle="): only=argument.trim_prefix("--vehicle=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if DisplayServer.get_name()=="headless": asset_audit()
	else: await native_review(only)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"rows":rows},"\t"))
	print("VEHICLE_SIMPLIFICATION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
