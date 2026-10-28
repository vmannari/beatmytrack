extends "res://tests/probe_electric_slide_access.gd"

const INCREMENT_OUTPUT: String = "res://../docs/evidence/electric-power-drift-2026-10-28"

func run() -> void:
	var old: HandlingConfig = load(INCREMENT_OUTPUT+"/before/game__resources__cars__electric.tres") as HandlingConfig
	var results: Dictionary = {}
	for scale: float in [0.28,0.27,0.26,0.25]:
		var config: HandlingConfig = old.duplicate() as HandlingConfig
		config.power_lateral_response_scale = scale
		var turns: Dictionary = {}
		for kph: float in [0.0,30.0,50.0,80.0,120.0,170.0]:
			for steering: float in [0.35,0.65,1.0]:
				for pedal: float in [0.55,0.65,1.0]:
					turns[str(kph)+"/"+str(steering)+"/"+str(pedal)] = slide_sample(config,kph,steering,pedal)
		results[str(scale)] = turns
	var file := FileAccess.open(INCREMENT_OUTPUT+"/candidates.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	print("ELECTRIC_POWER_INCREMENT_PROBE: four candidates")
	quit.call_deferred()
