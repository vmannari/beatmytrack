extends "res://tests/probe_electric_power_increment.gd"
func run() -> void:
	var results: Dictionary={}
	for scale: float in [0.25,0.245,0.24,0.235,0.23,0.22]:
		var config: HandlingConfig=VehicleCatalog.config("electric").duplicate()
		config.power_lateral_response_scale=scale
		var peak: float=0
		var recovery: float=0
		var representative: Dictionary={}
		for kph: float in [0.0,30.0,50.0,80.0,120.0,170.0]:
			for steering: float in [0.35,0.65,1.0]:
				for pedal: float in [0.55,0.65,1.0]:
					var value: Dictionary=slide_sample(config,kph,steering,pedal)
					peak=maxf(peak,value.peak)
					recovery=maxf(recovery,value.recovery_ms)
					if kph==50 and steering==1.0 and pedal==0.65: representative=value
		results[str(scale)]={"peak":peak,"recovery_ms":recovery,"representative":representative}
	FileAccess.open("res://../docs/evidence/electric-stronger-powered-drift-2026-10-29/candidates.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t")+"\n")
	print("STRONGER_POWER_DRIFT_PROBE: ",JSON.stringify(results))
	quit()
