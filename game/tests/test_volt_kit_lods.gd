extends SceneTree
const Kits = preload("res://vehicle/modular_car_kits.gd")
const OUT = "res://../docs/evidence/volt-kit-review-2026-11-17"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var rows: Array = []
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.editable_kits = true
		for category: String in ["hood","body"]:
			for option: Array in VehicleCustomisation.options(category,"electric").slice(1):
				var holder: Node = load(Kits.path_for(car,category,str(option[0]))).instantiate()
				var backings: int = 0
				var protected_parts: int = 0
				for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
					if not part.mesh.get_meta("car_keep_master",false): continue
					protected_parts += 1
					if part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: backings += 1
					for surface: int in range(part.mesh.get_surface_count()):
						checks += 1
						if not RenderingServer.mesh_get_surface(part.mesh.get_rid(),surface).get("lods",[]).is_empty():
							failures += 1
							printerr("VKR_LOD_FAIL protected surface has distance replacements ",category,"/",option[0])
				checks += 1
				if backings == 0:
					failures += 1
					printerr("VKR_LOD_FAIL fitted trim lacks protected metal backing ",category,"/",option[0]," simple=",simple)
				rows.append({"category":category,"option":option[0],"simple":simple,"protected_parts":protected_parts,"protected_backings":backings})
				holder.free()
		car.free()
	var suffix: String = "-before" if "--before" in OS.get_cmdline_user_args() else ""
	FileAccess.open(OUT.path_join("distance-policy"+suffix+".json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("VKR_KIT_LODS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
