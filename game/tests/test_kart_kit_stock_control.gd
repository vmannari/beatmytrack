extends SceneTree
## Compare actual stock meshes with the frozen task-start authors.
var checks: int = 0
var failures: int = 0
class FixtureCar extends CarVisual:
	func _ready() -> void: pass
func _initialize() -> void: run.call_deferred()

func snapshot(car: CarVisual) -> Array[String]:
	var result: Array[String] = []
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		for surface: int in range(part.mesh.get_surface_count()):
			result.append(str(inverse*part.global_transform)+str(hash(part.mesh.surface_get_arrays(surface))))
	result.sort()
	return result

func run() -> void:
	var stock: Dictionary = {}
	for simple: bool in [false,true]:
		var car := FixtureCar.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		car.customisation = VehicleCustomisation.defaults()
		car.scale = Vector3.ONE*HandlingConfig.BODY_SCALE
		car.body = Node3D.new()
		car.add_child(car.body)
		car.brake_material = VisualGeometry.material(Color("802d2b"))
		root.add_child(car)
		preload("res://tests/fixtures/kart_kit_stock_model.gd").build(car)
		if simple: RacingCarModels.prepare(car)
		stock[simple] = snapshot(car)
		car.free()
	for simple: bool in [false,true]:
		for editable: bool in [false,true]:
			var car := CarVisual.new()
			car.vehicle_id = "kart"
			car.simple_model = simple
			car.batch_parts = false
			car.editable_kits = editable
			root.add_child(car)
			checks += 1
			if snapshot(car)!=stock[simple]:
				failures += 1
				print("FAIL: stock arrays/transforms simple=",simple," editable=",editable)
			car.free()
	print("KART_KIT_STOCK_CONTROL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
