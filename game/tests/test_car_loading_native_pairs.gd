extends SceneTree
## Isolate this pass under the current finish, including concurrent art edits.
const OUT: String="res://../docs/evidence/car-loading-improvements-2026-11-13/paired/"
var checks: int=0
var failures: int=0
var rows: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("CAR_LOADING_NATIVE_FAIL ",message)
func settle(view: CarShowroom) -> void:
	view.invalidate_render()
	for frame: int in range(16): await process_frame;await RenderingServer.frame_post_draw
func difference(a: Image,b: Image) -> Dictionary:
	a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
	var x: PackedByteArray=a.get_data()
	var y: PackedByteArray=b.get_data()
	var changed: int=0
	var significant: int=0
	var total: int=0
	var peak: int=0
	if x!=y:
		for at: int in range(0,x.size(),4):
			var delta: int=0
			for channel: int in range(3):
				var value: int=absi(int(x[at+channel])-int(y[at+channel]))
				total+=value;delta=maxi(delta,value)
			if delta>0: changed+=1
			if delta>8: significant+=1
			peak=maxi(peak,delta)
	return {"exact":x==y,"changed_pixels":changed,"significant_pixels":significant,"max_delta":peak,"mean_255":float(total)/(a.get_width()*a.get_height()*3)}
func switch_meshes(changes: Dictionary, on: bool, car: CarVisual, input: float) -> void:
	for node: MeshInstance3D in changes:
		node.mesh=changes[node][1 if on else 0]
		for surface: int in range(node.mesh.get_surface_count()): node.set_surface_override_material(surface,changes[node][2][surface])
	var fixed: MeshInstance3D=car.find_child("DriverStaticSuit",true,false)
	if fixed!=null: fixed.visible=not on
	if car.vehicle_id=="kart":
		preload("res://vehicle/kart_steering.gd").present(car.find_child("SteeringAssembly",true,false),car.find_child("TomkartDriver",true,false),input)
func pair(view: CarShowroom,changes: Dictionary,label: String,input: float) -> void:
	switch_meshes(changes,true,view.car,input)
	var reference: Image
	var stable: bool=false
	# First-use Vulkan lighting can finish after the model-ready notification.
	# Require repeated real draws to converge; retain a bounded failure path.
	for attempt: int in range(8):
		await settle(view)
		var candidate: Image=view.showroom_viewport.get_texture().get_image()
		if reference!=null and reference.get_data()==candidate.get_data(): stable=true;reference=candidate;break
		reference=candidate
	check(stable,"stable reference "+label)
	switch_meshes(changes,false,view.car,input)
	await settle(view)
	var result: Image=view.showroom_viewport.get_texture().get_image()
	var delta: Dictionary=difference(reference,result)
	delta["view"]=label
	rows.append(delta)
	# Keep exactness as a diagnostic. Morph/static GPU paths can round an
	# otherwise encoded-identical point differently. Use the existing vehicle
	# appearance bounds from test_vehicle_mesh_simplification.gd unchanged.
	check(delta.mean_255<0.25,"retained appearance energy "+label)
	check(float(delta.significant_pixels)/(reference.get_width()*reference.get_height())<0.005,"retained visible-pixel bound "+label)
	switch_meshes(changes,true,view.car,input)
	await settle(view)
	var restored: Dictionary=difference(reference,view.showroom_viewport.get_texture().get_image())
	check(restored.max_delta<=1,"reference restored "+label)
	delta["restoration"]=restored
	reference.save_png(OUT+RenderingServer.get_current_rendering_method()+"/"+label+"-reference.png")
	result.save_png(OUT+RenderingServer.get_current_rendering_method()+"/"+label+"-optimised.png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+RenderingServer.get_current_rendering_method()))
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		var view := CarShowroom.new()
		view.vehicle_id=id;view.simple_model=true;view.read_only=true
		view.livery=VehicleLivery.defaults(id);view.customisation=VehicleCustomisation.defaults()
		view.size=Vector2(1000,760)
		var prior_hits: int=preload("res://vehicle/modular_car_base.gd").hits
		root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready: await process_frame
		check(preload("res://vehicle/modular_car_base.gd").hits==prior_hits+1,"actual current prepared base "+id)
		var changes: Dictionary={}
		for node: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
			var materials: Array=[]
			for surface: int in range(node.mesh.get_surface_count()): materials.append(node.get_active_material(surface))
			var reference: Mesh=node.mesh.duplicate()
			if str(node.name)=="TomkartDriver": reference=load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
			changes[node]=[node.mesh,reference,materials]
		for shot: Array in [["front",-0.70,0.31],["rear",2.45,0.31],["side",-PI/2,0.15],["overhead",-0.4,1.02]]:
			view.yaw=shot[1];view.elevation=shot[2];view.zoom=1.05 if id in ["compact","forklift"] else 0.85
			view._orbit()
			await pair(view,changes,id+"-"+shot[0],0.0)
		if id=="kart":
			for input: float in [-1.0,-0.5,0.0,0.5,1.0]:
				for shot: Array in [["cockpit",-0.7,0.5],["overhead",-0.4,1.02]]:
					view.yaw=shot[1];view.elevation=shot[2];view.zoom=0.66
					view._orbit()
					await pair(view,changes,"kart-steer-"+shot[0]+"-"+str(input),input)
		view.free()
		await process_frame
	FileAccess.open(OUT+RenderingServer.get_current_rendering_method()+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))
	print("CAR_LOADING_NATIVE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
