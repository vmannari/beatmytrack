extends "res://../docs/evidence/challenger-reference-repair-2026-11-14/coarse_verify.gd"

func _initialize() -> void: diagnose.call_deferred()

func diagnose() -> void:
	var detail: bool=not "--disable-detail" in OS.get_cmdline_user_args()
	preload("res://vehicle/car_detail_reduction.gd").enabled=detail
	Base.enabled=false
	Kits.enabled=false
	Cache.enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	Coarse.offline=verify_coarse
	var result: Dictionary={}
	for editable: bool in [false,true]:
		var car: CarVisual=await make_coarse_car("super_rally",true,editable)
		result[str(editable)]=inventory(car,false)
		car.free()
		await process_frame
	FileAccess.open("res://../build/challenger-reference-repair-2026-11-14/coarse-parts"+("" if detail else "-without-detail")+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit()
