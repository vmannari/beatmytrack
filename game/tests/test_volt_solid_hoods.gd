extends SceneTree
## The removed hood vents stay absent, including when restoring prepared parts.
const Kits=preload("res://vehicle/modular_car_kits.gd")
const CHANGED: Array[String]=["volt_vent","volt_triple","volt_track","volt_race"]
var checks:=0
var failures:=0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)

func run() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	var legacy: Script=load("res://../docs/evidence/volt-solid-hoods-2026-11-03/before/game/vehicle/electric_kits.gd")
	Kits.enabled=prepared
	preload("res://vehicle/modular_car_base.gd").enabled=prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=prepared
	for option: Array in VehicleCustomisation.options("hood","electric"):
		check(not (str(option[1])+VehicleCustomisation.description("hood",str(option[0]),"electric")).to_lower().contains("vent"),"no vent wording "+str(option[0]))
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.editable_kits=true
		car.batch_parts=prepared
		car.cache_rest_pose=prepared
		root.add_child(car)
		while not car.model_ready: await process_frame
		for option: Array in VehicleCustomisation.options("hood","electric").slice(1):
			var parts: Dictionary=VehicleCustomisation.defaults()
			parts.hood=option[0]
			var hits: int=Kits.hits
			car.change_kit_parts(parts)
			if prepared: check(Kits.hits==hits+1,"actual prepared module used "+str(option[0]))
			var frame: Node3D=car.kit_frames.hood[0]
			check(frame.find_children("*Vent*","MeshInstance3D",true,false).is_empty(),"no vent floors or louvres "+str(option[0]))
			if str(option[0]) in CHANGED:
				var painted:=false
				var trim_only:=true
				for node: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
					for surface: int in range(node.mesh.get_surface_count()):
						var material: Material=node.get_active_material(surface)
						if material==car.paint_materials.body: painted=true
						elif not prepared: trim_only=trim_only and str(node.name).begins_with("VoltHoodShutLineV5_")
				check(painted and trim_only,"solid painted skin plus perimeter seam "+str(option[0]))
				if not prepared: check(frame.find_children("*","MeshInstance3D",true,false).size()==2,"no extra insert geometry "+str(option[0]))
			elif not prepared:
				var old:=Node3D.new()
				car.body.add_child(old)
				legacy.hood(car,old,str(option[0]))
				var current_skin: MeshInstance3D=frame.find_child("VoltHoodSkinV5_*",true,false)
				var original_skin: MeshInstance3D=old.find_child("VoltHoodSkinV4_*",true,false)
				check(current_skin!=null and original_skin!=null and var_to_bytes(current_skin.mesh.surface_get_arrays(0))==var_to_bytes(original_skin.mesh.surface_get_arrays(0)),"other hood skin arrays exact "+str(option[0]))
				old.free()
		car.free()
		await process_frame
	print("VOLT_SOLID_HOODS: ",checks," checks, ",failures," failures; prepared=",prepared)
	quit(1 if failures else 0)
