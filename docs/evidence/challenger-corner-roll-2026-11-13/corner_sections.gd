extends "res://../docs/evidence/challenger-panels-2026-11-12/panel_geometry.gd"
func run() -> void:
	var folder: String="res://../docs/evidence/challenger-corner-roll-2026-11-13/"
	var all_rows: Array=[]
	for stage: String in ["before","candidate"]:
		var base: String=folder+"before/" if stage=="before" else "res://../build/challenger-corner-roll-2026-11-13/native/"
		for tier: String in ["simple","full"]:
			var mesh: Mesh=ResourceLoader.load(base+tier+"_body_paint.res","",ResourceLoader.CACHE_MODE_IGNORE)
			var body: StaticBody3D=collision(mesh,1);await physics_frame;await physics_frame
			for side: float in [-1,1]:
				for z: float in [-2.03,-2.10,-2.15]:
					var samples: Array=[]
					for i: int in range(241):
						var y: float=.70+i*.0005
						var hit: Dictionary=cast(Vector3(side*2,y,z),Vector3(0,y,z),1)
						if hit.is_empty():continue
						var n: Vector3=shade(mesh,hit)
						samples.append({"y":y,"x":hit.position.x,"angle":rad_to_deg(atan2(n.y,absf(n.x)))})
					all_rows.append({"stage":stage,"tier":tier,"side":side,"z":z,"samples":samples})
			body.free();await physics_frame
	var file:=FileAccess.open(folder+"corner-sections.json",FileAccess.WRITE);file.store_string(JSON.stringify(all_rows));file.close()
	print("CORNER_SECTIONS: ",all_rows.size()," native section profiles");quit()
