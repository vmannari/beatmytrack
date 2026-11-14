extends SceneTree
const OUT = "res://../docs/evidence/visual-fixes-2026-11-13/contours"
const CONTOUR_SHADER = preload("res://vehicle/panel_contour.gdshader")
func _initialize() -> void: run.call_deferred()
func capture(view: CarShowroom,name_value: String) -> void:
	view.invalidate_render()
	for frame: int in range(12): await process_frame
	await RenderingServer.frame_post_draw
	assert(view.showroom_viewport.get_texture().get_image().save_png(OUT+"/"+name_value+".png")==OK)
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	for id: String in ["electric","super_rally"]:
		var view:=CarShowroom.new()
		view.vehicle_id=id;view.simple_model=true;view.read_only=true
		view.livery=VehicleLivery.defaults(id);view.customisation=VehicleCustomisation.defaults()
		view.size=Vector2(1000,760)
		root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready:await process_frame
		var contour_nodes: Array=[]
		for n: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
			var m: Material=n.material_override
			if m is ShaderMaterial and m.shader==CONTOUR_SHADER:
				var control:=StandardMaterial3D.new()
				control.albedo_color=m.get_shader_parameter("contour_color")
				control.roughness=0.9;control.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
				control.cull_mode=BaseMaterial3D.CULL_DISABLED
				contour_nodes.append([n,m,control])
		assert(not contour_nodes.is_empty())
		for shot: Array in [["side",-PI/2,0.15],["front",-0.70,0.31]]:
			view.yaw=shot[1];view.elevation=shot[2]
			view.zoom=0.85 if id=="electric" else 1.05
			view._orbit()
			for enabled: bool in [false,true]:
				for row: Array in contour_nodes:row[0].material_override=row[1] if enabled else row[2]
				await capture(view,RenderingServer.get_current_rendering_method()+"-"+id+"-"+shot[0]+("-integrated" if enabled else "-sampled"))
		view.free();await process_frame
	print("CONTOUR_NATIVE_COMPARE: two cars, two views, paired physical-width sampling")
	quit()
