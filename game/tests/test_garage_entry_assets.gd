extends SceneTree
## The warm queue follows actual restore paths and observes finish edits.
const Assets=preload("res://ui/garage_studio_assets.gd")
const Graphics=preload("res://rendering/graphics_preparation.gd")
var checks: int=0
var failures: int=0

func _initialize() -> void: run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("GARAGE_ENTRY_FAIL ",label)

func run() -> void:
	for id: String in VehicleCatalog.IDS:
		for simple: bool in [true,false]:
			var car:=CarVisual.new()
			car.vehicle_id=id
			car.simple_model=simple
			car.editable_kits=VehicleCustomisation.supported(id)
			var parts: Dictionary=VehicleCustomisation.defaults()
			var stock: Array[String]=Assets.paths(id,simple,parts)
			check(stock[0]==preload("res://vehicle/modular_car_base.gd").path_for(car) if simple else stock[0]==preload("res://ui/garage_car_cache.gd").DIRECTORY+car.model_id+".scn","stock restoration path "+id+str(simple))
			for category: String in VehicleCustomisation.CATEGORIES:
				parts[category]=VehicleCustomisation.options(category,id)[1][0]
			var fitted: Array[String]=Assets.paths(id,simple,parts)
			check(fitted[0]==preload("res://vehicle/modular_car_base.gd").path_for(car),"fitted base path "+id+str(simple))
			for category: String in VehicleCustomisation.CATEGORIES:
				check(preload("res://vehicle/modular_car_kits.gd").path_for(car,category,parts[category]) in fitted,"fitted module path "+id+category+str(simple))
			check(fitted.size()==6 and fitted[-1]==GarageEnvironment.PREPARED_ARCHITECTURE,"four fitted modules and the original workshop "+id+str(simple))
			car.free()
	for mode: String in ["before","during","pending","context"]:
		await mutated_batch(mode)
	print("GARAGE_ENTRY_ASSETS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

class Host extends Node3D:
	var camera: Camera3D
	var showroom_viewport: SubViewport

func mutated_batch(mode: String) -> void:
	Graphics.invalidate("test fixture")
	var host:=Host.new()
	root.add_child(host)
	host.camera=Camera3D.new()
	host.add_child(host.camera)
	host.showroom_viewport=SubViewport.new()
	host.add_child(host.showroom_viewport)
	var queue: Node=preload("res://ui/garage_first_draw.gd").new()
	host.add_child(queue)
	var changed:=StandardMaterial3D.new()
	var meshes: Array[MeshInstance3D]=[]
	for index: int in range(12 if mode=="pending" else 1):
		var mesh:=MeshInstance3D.new()
		mesh.mesh=BoxMesh.new()
		mesh.material_override=changed if index==0 else StandardMaterial3D.new()
		host.add_child(mesh)
		meshes.append(mesh)
	queue.hold(host)
	if mode=="before": changed.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var calls: Dictionary={"count":0,"changed_drawn":false}
	var draw: Callable=func() -> bool:
		calls.count+=1
		for copy: GeometryInstance3D in queue._copies:
			if copy.material_override==changed and changed.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED: calls.changed_drawn=true
		if calls.count==1:
			if mode in ["during","pending"]: changed.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			if mode=="context": Graphics.invalidate("changed while drawing")
		await process_frame
		return true
	var current: Callable=func() -> bool: return calls.count<8
	check(await queue.prepare(draw,current),"queue completes with "+mode+" mutation")
	check(queue.pending.is_empty(),"every pending program is accounted for after "+mode)
	check(calls.count==(1 if mode=="before" else 2),"changed programs require a fresh draw after "+mode)
	if mode!="context": check(calls.changed_drawn,"changed finish actually draws after "+mode)
	check(Graphics.warmed.is_empty(),"proxy draws do not publish full-view receipts after "+mode)
	queue.release()
	check(queue.held.is_empty() and queue._copies.is_empty(),"release retires owned preparation state after "+mode)
	for mesh: MeshInstance3D in meshes: check(mesh.visible,"release restores held geometry after "+mode)
	host.queue_free()
	await process_frame
