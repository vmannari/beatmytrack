extends SceneTree
## Native proof of an actual reflected car, not merely a shiny deck material.
const Studio = preload("res://ui/garage_thumbnail_studio.gd")
var checks: int = 0
var failures: int = 0
var output: String
var rows: Array = []

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("THUMBNAIL_APPEARANCE_FAIL ",label)
func draw(view: CarShowroom) -> Image:
	for _frame: int in range(5):
		view._submit_render()
		await process_frame
		await RenderingServer.frame_post_draw
	return view.showroom_viewport.get_texture().get_image()
func difference(a: Image, b: Image) -> Dictionary:
	a.convert(Image.FORMAT_RGBA8); b.convert(Image.FORMAT_RGBA8)
	var aa: PackedByteArray = a.get_data()
	var bb: PackedByteArray = b.get_data()
	var changed: int = 0
	var total: int = 0
	for index: int in range(0,aa.size(),4):
		var delta: int = absi(aa[index]-bb[index])+absi(aa[index+1]-bb[index+1])+absi(aa[index+2]-bb[index+2])
		total += delta
		if delta>6: changed += 1
	return {"pixels":changed,"mean_rgb":float(total)/(a.get_width()*a.get_height()*3)}
func run() -> void:
	output = OS.get_environment("BMT_THUMBNAIL_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(180).timeout.connect(func() -> void: printerr("THUMBNAIL_APPEARANCE_TIMEOUT"); quit(1))
	var colors: Dictionary = {"compact":"587d2d","kart":"e5b633","forklift":"cf3b33","electric":"683ed4","hovercraft":"c85c42"}
	for id: String in VehicleCatalog.IDS:
		var view := Studio.new()
		view.vehicle_id = id
		view.framing_scale = 0.84
		view.size = Vector2(2048,512)
		view.livery = VehicleLivery.defaults(id)
		view.livery.colors.body = colors[id]
		view.livery.pattern = "offset_gt"
		view.customisation = VehicleCustomisation.defaults()
		root.add_child(view)
		while not view.showroom_ready: await process_frame
		var on: Image = await draw(view)
		var repeat: Image = await draw(view)
		var reflection: Image = view.reflections.views[0].get_texture().get_image()
		reflection.convert(Image.FORMAT_RGBA8)
		var data: PackedByteArray = reflection.get_data()
		var covered: int = 0
		var empty: int = 0
		for index: int in range(3,data.size(),4):
			if data[index]>16: covered += 1
			if data[index]==0: empty += 1
		check(covered>100 and empty>100,"reflection contains real car pixels and transparent surroundings "+id)
		check(view.reflections.views.size()==1 and view.reflections.views[0].size==Vector2i(768,192),"one bounded 768x192 reflection "+id)
		check(view.reflections.views[0].find_world_3d()==view.showroom_viewport.find_world_3d(),"reflection reuses the exact existing world "+id)
		check(view.reflections.cameras[0].transform.basis.determinant()>0.99,"reflection camera retains right-handed face winding "+id)
		check(view.reflections.cameras[0].cull_mask==GarageReflections.CAR_LAYER,"reflection draws car layer only "+id)
		check(view.find_children("*","CarVisual",true,false).size()==1,"no duplicate car model "+id)
		check(view.car.livery==view.livery and view.car.paint_materials.body.albedo_color.to_html(false)==colors[id],"exact saved body and pattern "+id)
		view.reflections.set_enabled(false)
		var off: Image = await draw(view)
		var control: Dictionary = difference(on,repeat)
		var reflected: Dictionary = difference(repeat,off)
		check(reflected.pixels>control.pixels+100 and reflected.mean_rgb>control.mean_rgb+0.01,"turntable reflection changes visible pixels beyond render variation "+id)
		check(on.save_png(output.path_join(id+"-reflection-on.png"))==OK,"capture final native studio "+id)
		check(off.save_png(output.path_join(id+"-reflection-off.png"))==OK,"capture reflection diagnostic "+id)
		check(reflection.save_png(output.path_join(id+"-reflection-map.png"))==OK,"capture actual car-only reflected image "+id)
		view.reflections.set_enabled(true)
		view.hide()
		check(view.reflections.views[0].render_target_update_mode==SubViewport.UPDATE_DISABLED,"hidden preview parks reflection drawing "+id)
		rows.append({"vehicle":id,"control":control,"reflection":reflected,"covered":covered,"transparent":empty})
		var released: WeakRef = weakref(view)
		var rig: GarageReflections = view.reflections
		view.queue_free()
		for _frame: int in range(6): await process_frame
		check(released.get_ref()==null and rig.views.is_empty(),"owner release retires reflection resources "+id)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"rows":rows},"  "))
	print("THUMBNAIL_APPEARANCE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
