extends SceneTree
## CRV03: compare restored production models with their pre-10k snapshots.
const WORK: String="res://../build/car-pass10-2026-11-16"
const OUT: String="res://../docs/evidence/car-pass10-2026-11-16"
const Base=preload("res://vehicle/modular_car_base.gd")
const Kits=preload("res://vehicle/modular_car_kits.gd")
var checks: int=0
var failures: int=0
var pairs: Array=[]

func apply_candidates(car: CarVisual,holders: Variant) -> void:
	var detail=preload("res://vehicle/car_detail_reduction.gd")
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("selected-plan.json")))
	var parts: Array=car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders: parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		if car.vehicle_id=="kart" and str(part.name)=="TomkartDriver":
			part.mesh=load(WORK.path_join("candidates").path_join(plan.driver.file));continue
		var key: String=car.vehicle_id+"_"+detail.mesh_key(part.mesh)
		if not plan.parts.has(key):continue
		preload("res://vehicle/car_budget_reduction.gd").swap(part,load(WORK.path_join("candidates").path_join(plan.parts[key].file)))

func _initialize() -> void: capture.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("DETAIL_NATIVE_FAIL ",label)

func triangles(node: Node) -> int:
	var total: int=0
	if node is MeshInstance3D and node.is_visible_in_tree() and node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: total+=node.mesh.get_faces().size()/3
	for child: Node in node.get_children(): total+=triangles(child)
	return total

func settle(view: CarShowroom) -> void:
	# Read-only showrooms draw on demand: request each settling frame.
	for frame: int in range(8):
		view.invalidate_render()
		await process_frame;await RenderingServer.frame_post_draw

func crop(models: Array, camera: Camera3D, size: Vector2i) -> Array:
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
	for model: Node3D in models:
		var parts: Array=model.find_children("*","MeshInstance3D",true,false)
		if model is MeshInstance3D: parts.append(model)
		for part: MeshInstance3D in parts:
			if part.mesh==null or not part.visible or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
			for corner: int in range(8):
				var pixel: Vector2=camera.unproject_position(part.global_transform*part.mesh.get_aabb().get_endpoint(corner))
				low=low.min(pixel);high=high.max(pixel)
	var rectangle:=Rect2i(Vector2i(low.floor())-Vector2i(8,8),Vector2i((high-low).ceil())+Vector2i(17,17)).intersection(Rect2i(Vector2i.ZERO,size))
	return [rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y]

func pair(view: CarShowroom, before_model: Node3D, after_model: Node3D, label: String, directory: String) -> Dictionary:
	before_model.show();after_model.hide()
	await settle(view)
	var before: Image=view.showroom_viewport.get_texture().get_image()
	var stable: bool=false
	var repeated: Image=before
	for attempt: int in range(4):
		await settle(view)
		repeated=before
		var next: Image=view.showroom_viewport.get_texture().get_image()
		stable=before.get_data()==next.get_data();before=next
		if stable: break
	check(stable,"stable reference "+label)
	var prior: int=view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var prior_draws: int=view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	before_model.hide();after_model.show()
	await settle(view)
	var after: Image=view.showroom_viewport.get_texture().get_image()
	var current: int=view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var current_draws: int=view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	after_model.hide();before_model.show()
	await settle(view)
	var restored: Image=view.showroom_viewport.get_texture().get_image()
	for attempt: int in range(4):
		if before.get_data()==restored.get_data(): break
		await settle(view);restored=view.showroom_viewport.get_texture().get_image()
	var exact: bool=before.get_data()==restored.get_data()
	check(exact,"exact restoration "+label)
	check(before.save_png(directory.path_join(label+"-before.png"))==OK,"before image")
	check(after.save_png(directory.path_join(label+"-after.png"))==OK,"after image")
	if not stable: repeated.save_png(directory.path_join(label+"-repeat.png"))
	if not exact: restored.save_png(directory.path_join(label+"-restored.png"))
	before_model.show();after_model.show()
	var rectangle: Array=crop([before_model,after_model],view.camera,view.showroom_viewport.size)
	before_model.hide()
	return {"label":label,"crop":rectangle,"before_image":label+"-before.png","after_image":label+"-after.png","stable_reference":stable,"restored_exact":exact,"repeat_image":label+"-repeat.png" if not stable else "","restoration_image":label+"-restored.png" if not exact else "","visible_primitives_before":prior,"visible_primitives_after":current,"draw_calls_before":prior_draws,"draw_calls_after":current_draws}

func ghost_for(model: Node3D) -> MeshInstance3D:
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	PersonalGhost._append_meshes(model,model.global_transform.affine_inverse(),tool)
	tool.generate_normals();tool.index()
	var ghost:=MeshInstance3D.new()
	ghost.mesh=tool.commit();ghost.transform=model.transform
	ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new()
	material.shader=PersonalGhost.finish_shader();ghost.material_override=material
	return ghost

func capture() -> void:
	Engine.time_scale=0.0
	var source: bool="--source" in OS.get_cmdline_user_args()
	if "--reference" in OS.get_cmdline_user_args(): preload("res://vehicle/car_budget_reduction.gd").enabled=false
	if "--candidates" in OS.get_cmdline_user_args(): preload("res://tests/support/car_pass10_source.gd").observer=apply_candidates
	var rgb_probe: bool="--rgb-plate-probe" in OS.get_cmdline_user_args()
	Base.enabled=not source;Kits.enabled=not source
	preload("res://vehicle/prepared_car_cache.gd").enabled=not source
	preload("res://ui/garage_car_cache.gd").enabled=false
	var decorated: bool="--decorated" in OS.get_cmdline_user_args()
	var directory: String=OUT.path_join(("source-" if source else "prepared-")+RenderingServer.get_current_rendering_method()+("-decorated" if decorated else "")+("-rgb-probe" if rgb_probe else ""))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		if id=="super_rally": continue
		var only: String=""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--vehicle="): only=argument.trim_prefix("--vehicle=")
		if not only.is_empty() and only!=id: continue
		for mode: String in (["stock"] if "--stock-only" in OS.get_cmdline_user_args() else ["stock","fitted"]):
			var view: CarShowroom=preload("res://tests/support/car_pass10_showroom.gd").new() if "--candidates" in OS.get_cmdline_user_args() else CarShowroom.new()
			view.vehicle_id=id;view.simple_model=true;view.read_only=true;view.size=Vector2(1000,760)
			view.livery=VehicleLivery.defaults(id);view.customisation=VehicleCustomisation.defaults()
			if decorated:
				view.livery.pattern="apex_twin"
				view.livery.colors.body="708ae8";view.livery.colors.accent="7222dd";view.livery.colors.detail="f06484"
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES: view.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			var hits: int=Base.hits
			var kit_hits: int=Kits.hits
			root.add_child(view)
			while not view.showroom_ready or not view.car.model_ready: await process_frame
			if rgb_probe:
				for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
					for surface: int in range(part.mesh.get_surface_count()):
						var material: Material=part.get_active_material(surface)
						if not material is StandardMaterial3D or material.albedo_texture==null or "compact_plate_v1" not in material.albedo_texture.resource_path: continue
						var replacement: StandardMaterial3D=material.duplicate()
						var paper: Image=material.albedo_texture.get_image();paper.convert(Image.FORMAT_RGB8)
						var ink: Image=material.emission_texture.get_image();ink.convert(Image.FORMAT_RGB8)
						replacement.albedo_texture=ImageTexture.create_from_image(paper)
						replacement.emission_texture=ImageTexture.create_from_image(ink)
						part.set_surface_override_material(surface,replacement)
						part.material_override=null
						print("PLATE_RGB_PROBE ",part.name," ",part.get_active_material(surface)," uv_scale=",replacement.uv1_scale)
			if "--uv-plate-probe" in OS.get_cmdline_user_args():
				for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
					if str(part.name)!="RearPlateFace": continue
					print("PLATE_UV_PROBE material=",part.get_active_material(0))
					var material:=ShaderMaterial.new()
					var shader:=Shader.new()
					shader.code="shader_type spatial; render_mode unshaded; uniform sampler2D paper: filter_linear_mipmap; void fragment(){ ALBEDO=texture(paper,UV).rrr; }"
					material.shader=shader
					material.set_shader_parameter("paper",(part.get_active_material(0) as StandardMaterial3D).albedo_texture)
					part.material_override=material
			if not source:
				check(Base.hits==hits+1,"actual prepared base "+id+mode)
				if mode=="fitted": check(Kits.hits==kit_hits+4,"actual four fitted modules "+id)
			var old: Node3D=load(WORK.path_join(id+"-"+mode+"-before.scn")).instantiate()
			view.car.get_parent().add_child(old)
			# The detached baseline was captured outside a showroom. Give its
			# original glazing the same studio uniforms as the current car.
			ShowroomStudio._studio_glass(old,{})
			check(old.transform.is_equal_approx(view.car.transform),"matched root transform "+id+mode)
			old.show();view.car.show()
			var before_count: int=triangles(old);var after_count: int=triangles(view.car)
			var key: DirectionalLight3D=view.car.get_parent().find_child("StudioKey",true,false)
			key.shadow_enabled=true
			var soft_shadow: Node3D=view.car.get_parent().find_child("PreparedStudioShadow",true,false)
			soft_shadow.hide()
			var views: Array=[["front",-0.70,0.31,1.0],["rear",2.45,0.31,1.0],["left",PI*0.5,0.25,1.0],["right",-PI*0.5,0.25,1.0],["top",-0.4,1.20,1.2],["distance",-0.4,1.02,3.1]]
			if id=="forklift": views.append_array([["hardware-left",0.0,0.3,1.0],["hardware-rear",0.0,0.3,1.0],["roof-equipment",0.0,0.3,1.0]])
			if id=="kart": views.append_array([["helmet-side",0.0,0.3,1.0],["helmet-front",0.0,0.3,1.0],["helmet-rear",0.0,0.3,1.0]])
			if id=="compact": views.append_array([["windshield",0.0,0.3,1.0],["windshield-left",0.0,0.3,1.0]])
			if id=="electric": views.append_array([["doors-left",0.0,0.3,1.0],["doors-right",0.0,0.3,1.0],["handle-front",0.0,0.3,1.0],["handle-rear",0.0,0.3,1.0]]);views.append_array([["roof-left",0.0,0.3,1.0],["roof-right",0.0,0.3,1.0],["roof-top",0.0,0.3,1.0]])
			for shot: Array in views:
				view.yaw=shot[1];view.elevation=shot[2];view.zoom=shot[3];view._orbit()
				var camera_position: Vector3=Vector3.ZERO;var target: Vector3=Vector3.ZERO
				match str(shot[0]):
					"doors-left": camera_position=Vector3(3.5,1.22,0.1);target=Vector3(0,0.68,0.1)
					"doors-right": camera_position=Vector3(-3.5,1.22,0.1);target=Vector3(0,0.68,0.1)
					"handle-front": camera_position=Vector3(2.0,1.12,-0.16);target=Vector3(0,0.87,-0.16)
					"handle-rear": camera_position=Vector3(2.0,1.12,0.86);target=Vector3(0,0.87,0.86)
					"hardware-left": camera_position=Vector3(2.3,1.7,-2.5);target=Vector3(0,1.2,0)
					"hardware-rear": camera_position=Vector3(-2.4,2.3,2.8);target=Vector3(0,1.3,0.6)
					"roof-equipment": camera_position=Vector3(0.9,4.3,1.5);target=Vector3(0,1.6,0)
					"helmet-side": camera_position=Vector3(1.35,1.09,0.38);target=Vector3(0,1.02,0.37)
					"helmet-front": camera_position=Vector3(0.65,1.21,-1.10);target=Vector3(0,1.02,0.37)
					"helmet-rear": camera_position=Vector3(-0.90,1.20,1.70);target=Vector3(0,1.02,0.37)
					"windshield": camera_position=Vector3(1.20,2.70,-3.20);target=Vector3(0,1.25,-0.76)
					"windshield-left": camera_position=Vector3(-1.40,2.40,-3.40);target=Vector3(0,1.25,-0.76)
					"roof-left": camera_position=Vector3(3.5,2.1,0.3);target=Vector3(0,1.04,0.3)
					"roof-right": camera_position=Vector3(-3.5,2.1,0.3);target=Vector3(0,1.04,0.3)
					"roof-top": camera_position=Vector3(1.7,3.8,0.2);target=Vector3(0,1.04,0.3)
				if camera_position!=Vector3.ZERO:
					view.camera.position=camera_position*HandlingConfig.BODY_SCALE;view.camera.look_at(target*HandlingConfig.BODY_SCALE)
				var row: Dictionary=await pair(view,old,view.car,id+"-"+mode+"-"+shot[0],directory)
				row.merge({"vehicle":id,"mode":mode,"view":shot[0],"master_before":before_count,"master_after":after_count,"real_shadows":true})
				pairs.append(row)
			if false:
				old.show();view.car.show()
				var before_ghost: MeshInstance3D=ghost_for(old)
				var after_ghost: MeshInstance3D=ghost_for(view.car)
				view.car.get_parent().add_child(before_ghost);view.car.get_parent().add_child(after_ghost)
				old.hide();view.car.hide();key.shadow_enabled=false
				view.yaw=-0.4;view.elevation=1.02;view.zoom=3.1;view._orbit()
				var row: Dictionary=await pair(view,before_ghost,after_ghost,id+"-ghost-distance",directory)
				row.merge({"vehicle":id,"mode":"ghost","view":"distance","master_before":before_ghost.mesh.get_faces().size()/3,"master_after":after_ghost.mesh.get_faces().size()/3,"real_shadows":false})
				pairs.append(row)
				before_ghost.free();after_ghost.free()
			view.free();await process_frame
		print("DETAIL_NATIVE ",id," pairs=",pairs.size())
	FileAccess.open(directory.path_join("comparisons.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pairs":pairs},"\t"))
	print("DETAIL_NATIVE_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
