extends "res://../docs/evidence/challenger-panels-2026-11-12/panel_geometry.gd"
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/challenger-panels-2026-11-12/source-panel-survey.json"))
	var errors: Dictionary = {}
	for tier: String in ["simple","full"]:
		var mesh: Mesh = load("res://assets/vehicles/challenger_hellcat_v1/"+tier+"_hood_paint.res")
		var collider: StaticBody3D = collision(mesh,2)
		await physics_frame;await physics_frame
		var maximum: float = 0
		for row: Dictionary in source.hood:
			for i: int in range(source.hood_x.size()):
				if row.samples[i]==null:continue
				var x: float = source.hood_x[i];var z: float = row.z
				var vent: bool = false
				for box: Array in source.source_vents:
					if x>float(box[0][0])-0.01 and x<float(box[1][0])+0.01 and z>float(box[0][2])-0.01 and z<float(box[1][2])+0.01:vent=true
				if vent:continue
				var world_z: float = SuperRallyModel._nose_z(z,x)
				var mapped_x: float = SuperRallyModel._nose_plan_x(x,world_z)
				var hit: Dictionary = cast(Vector3(mapped_x,2,world_z),Vector3(mapped_x,0.7,world_z),2)
				check(not hit.is_empty(),tier+" bonnet exists at transformed source station")
				if hit.is_empty():continue
				var error: float = absf(hit.position.y-float(row.samples[i]));maximum=maxf(maximum,error)
				check(error<0.004,tier+" bonnet retains measured source height within 4 mm")
		collider.free();await physics_frame;errors[tier]=maximum
	print("REFERENCE_HOOD: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(errors)])
	quit(1 if failures else 0)
