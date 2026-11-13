extends "res://../docs/evidence/challenger-panels-2026-11-12/panel_geometry.gd"
func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	var folder: String = "res://../docs/evidence/challenger-surface-joins-2026-11-12/"
	var base: String = folder+"before/" if before else "res://assets/vehicles/challenger_hellcat_v1/"
	var metrics: Array = []
	for tier: String in ["simple","full"]:
		var body: Mesh = load(base+tier+"_body_paint.res")
		var collider: StaticBody3D = collision(body,1)
		await physics_frame; await physics_frame
		var arrays: Array = body.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for side: float in [-1.0,1.0]:
			var edges: Dictionary = {}
			for i: int in range(0,indices.size(),3):
				for pair: Vector2i in [Vector2i(0,1),Vector2i(1,2),Vector2i(2,0)]:
					var a: Vector3 = vertices[indices[i+pair.x]];var b: Vector3 = vertices[indices[i+pair.y]]
					var midpoint: Vector3 = (a+b)*0.5
					var angle: float = atan2(absf(midpoint.x-0.005052)-0.35,midpoint.y-0.40)
					if midpoint.x*side<0 or angle<=0.57 or angle>=0.91 or midpoint.z<=0.84 or midpoint.z>=1.60:continue
					var ka: String = str(Vector3i((a*1000000).round()));var kb: String = str(Vector3i((b*1000000).round()))
					var key: String = ka+"/"+kb if ka<kb else kb+"/"+ka
					edges[key] = int(edges.get(key,0))+1
			check(not edges.is_empty(),tier+" upper shoulder has measured mesh edges")
			check(edges.values().all(func(n: int) -> bool:return n==2),tier+" shoulder skin has no open or multiple interior edges")
		for profile: Array in [["front-corner",0.84,-1.85,-1.53],["front-door",0.91,-0.82,-0.40],["rear-shoulder",0.97,0.65,1.52],["rear-corner",0.85,1.94,2.04],["rear-shoulder-upper",0.56,0.84,1.50,"radial"],["rear-shoulder-crown",0.63,0.72,1.50,"radial"]]:
			for side: float in [-1.0,1.0]:
				var positions: Array[Vector3] = []; var normals: Array[Vector3] = []
				var count: int = roundi((profile[3]-profile[2])/0.005)+1
				for i: int in range(count):
					var z: float = lerpf(profile[2],profile[3],i/float(count-1))
					var hit: Dictionary
					if profile.size()>4:
						var origin := Vector3(0.005052+side*0.35,0.40,z)
						var direction := Vector3(side*sin(profile[1]),cos(profile[1]),0)
						hit = cast(origin+direction*2,origin,1)
						# Resolve exact triangle-edge numerical misses with a 10 um
						# longitudinal probe; the strict edge-pairing audit above
						# separately rejects real openings in the shoulder sheet.
						if hit.is_empty():hit = cast(origin+direction*2+Vector3(0,0,0.00001),origin+Vector3(0,0,0.00001),1)
					else:hit = cast(Vector3(side*2,profile[1],warp(z)),Vector3(0,profile[1],warp(z)),1)
					check(not hit.is_empty(),tier+" "+str(profile[0])+" continuous skin at "+str(z))
					if not hit.is_empty():positions.append(hit.position);normals.append(shade(body,hit))
				var angle: float = 0; var bend: float = 0; var wobble: float = 0
				for i: int in range(1,normals.size()):
					angle = maxf(angle,rad_to_deg(normals[i-1].angle_to(normals[i])))
				for i: int in range(1,normals.size()-1):
					bend = maxf(bend,absf(positions[i-1].x-2*positions[i].x+positions[i+1].x))
					wobble = maxf(wobble,(normals[i-1]-2*normals[i]+normals[i+1]).length())
				check(angle<4.0,tier+" "+str(profile[0])+" no abrupt reflection jump "+str(angle))
				check(bend<0.002,tier+" "+str(profile[0])+" no abrupt geometry step "+str(bend))
				check(wobble<0.045,tier+" "+str(profile[0])+" no reflection ripple "+str(wobble))
				var samples: Array = []
				for i: int in range(positions.size()):samples.append([positions[i].x,positions[i].y,positions[i].z,normals[i].x,normals[i].y,normals[i].z])
				metrics.append({"tier":tier,"area":profile[0],"side":side,"max_normal_jump_degrees":angle,"max_geometry_second_difference_m":bend,"max_normal_second_difference":wobble,"samples":samples})
		collider.free();await physics_frame
	var file := FileAccess.open(folder+("before" if before else "after")+"-joins.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"));file.close()
	print("CHALLENGER_JOINS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
