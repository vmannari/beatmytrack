extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1;print("FAIL: ",label)
func warp(z: float) -> float: return z-0.14*smoothstep(1.72,2.1171,-z)
func collision(mesh: Mesh,mask: int) -> StaticBody3D:
	var body := StaticBody3D.new();body.collision_layer = mask
	var shape := CollisionShape3D.new();shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape);root.add_child(body);return body
func cast(from: Vector3,to: Vector3,mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,mask)
	return root.world_3d.direct_space_state.intersect_ray(query)
func shade(mesh: Mesh,hit: Dictionary) -> Vector3:
	var arrays: Array = mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var i: int = int(hit.face_index)*3
	var a: int = indices[i];var b: int = indices[i+1];var c: int = indices[i+2]
	var v0: Vector3 = positions[b]-positions[a];var v1: Vector3 = positions[c]-positions[a]
	var v2: Vector3 = hit.position-positions[a]
	var d00: float = v0.dot(v0);var d01: float = v0.dot(v1);var d11: float = v1.dot(v1)
	var d20: float = v2.dot(v0);var d21: float = v2.dot(v1)
	var denominator: float = d00*d11-d01*d01
	var v: float = (d11*d20-d01*d21)/denominator
	var w: float = (d00*d21-d01*d20)/denominator
	return (normals[a]*(1-v-w)+normals[b]*v+normals[c]*w).normalized()
func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	var base: String = "res://../docs/evidence/challenger-panels-2026-11-12/before/game/assets/vehicles/challenger_hellcat_v1/" if before else "res://assets/vehicles/challenger_hellcat_v1/"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/challenger-panels-2026-11-12/source-panel-survey.json"))
	var metrics: Array = []
	for tier: String in ["simple","full"]:
		var hood: Mesh = load(base+tier+"_hood_paint.res")
		var body: Mesh = load(base+tier+"_body_paint.res")
		var colliders: Array[StaticBody3D] = [collision(body,1),collision(hood,2)]
		await physics_frame;await physics_frame
		var hood_error: float = 0;var side_error: float = 0;var seam_angle: float = 0
		for row: Dictionary in source.hood:
			for i: int in range(source.hood_x.size()):
				if row.samples[i] == null: continue
				var x: float = source.hood_x[i];var z: float = row.z
				# Vent apertures/returns are separate source features, not bonnet crown samples.
				var vent: bool = false
				for box: Array in source.source_vents:
					if x>float(box[0][0])-0.01 and x<float(box[1][0])+0.01 and z>float(box[0][2])-0.01 and z<float(box[1][2])+0.01:vent = true
				if vent:continue
				var hit: Dictionary = cast(Vector3(x,2,warp(z)),Vector3(x,0.7,warp(z)),2)
				check(not hit.is_empty(),tier+" hood exists at source sample "+str(Vector2(x,z)))
				if hit.is_empty():continue
				var error: float = absf(hit.position.y-float(row.samples[i]));hood_error = maxf(hood_error,error)
				check(error<0.004,tier+" hood follows factory profile within 4 mm "+str(Vector2(x,z))+" error="+str(error))
		for row: Dictionary in source.side:
			if row.z < -0.72 or row.z > 0.72:continue
			for i: int in range(source.side_y.size()):
				var y: float = source.side_y[i];var z: float = row.z
				if y<0.49 or y>0.94 or row.samples[i]==null:continue
				if y>0.855 and z>0.22 and z<0.55:continue
				var hit: Dictionary = cast(Vector3(-2,y,z),Vector3(0,y,z),1)
				check(not hit.is_empty(),tier+" side exists at measured station")
				if hit.is_empty():continue
				var error: float = absf(-hit.position.x-float(row.samples[i]));side_error = maxf(side_error,error)
				check(error<0.008,tier+" side retains source section within 8 mm "+str(Vector2(y,z))+" error="+str(error))
		for y: float in [0.45,0.65,0.82,0.91]:
			var crossings: Array[float] = []
			var outline: Array = source.door_outline
			for i: int in range(outline.size()):
				var a := Vector2(outline[i][0],outline[i][1]);var b := Vector2(outline[(i+1)%outline.size()][0],outline[(i+1)%outline.size()][1])
				if (a.x>y)!=(b.x>y):crossings.append(lerpf(a.y,b.y,(y-a.x)/(b.x-a.x)))
			for z: float in crossings:
				for side: float in [-1.0,1.0]:
					var a: Dictionary = cast(Vector3(side*2,y,z-0.018),Vector3(0,y,z-0.018),1)
					var b: Dictionary = cast(Vector3(side*2,y,z+0.018),Vector3(0,y,z+0.018),1)
					check(not a.is_empty() and not b.is_empty(),tier+" both sides of the door join have continuous outer skin")
					if a.is_empty() or b.is_empty():continue
					if y==0.82 and z<0:print("JOIN_NORMALS ",tier," side=",side," a=",shade(body,a)," b=",shade(body,b)," pa=",a.position," pb=",b.position)
					var angle: float = rad_to_deg(shade(body,a).angle_to(shade(body,b)));seam_angle = maxf(seam_angle,angle)
					check(angle<6.0,tier+" door join has no abrupt shading jump y="+str(y)+" z="+str(z)+" side="+str(side)+" angle="+str(angle))
		var fender_wobble: float = 0
		for side: float in [-1.0,1.0]:
			for y: float in [0.82,0.84]:
				var samples: Array[Vector3] = []
				for i: int in range(31):
					var z: float = -1.65+i*0.0225
					var hit: Dictionary = cast(Vector3(side*2,y,z),Vector3(0,y,z),1)
					check(not hit.is_empty(),tier+" front fender has continuous outer paint")
					if not hit.is_empty():samples.append(shade(body,hit))
				for i: int in range(1,samples.size()-1):
					var wobble: float = (samples[i-1]-samples[i]*2+samples[i+1]).length();fender_wobble = maxf(fender_wobble,wobble)
					check(wobble<0.06,tier+" front fender reflection has no local shading spike y="+str(y)+" z="+str(-1.65+i*0.0225)+" side="+str(side)+": "+str(wobble))
		metrics.append({"tier":tier,"hood_max_error_metres":hood_error,"side_max_error_metres":side_error,"door_join_max_degrees":seam_angle,"fender_normal_second_difference":fender_wobble})
		for collider: StaticBody3D in colliders:collider.free()
		await physics_frame
	var file := FileAccess.open("res://../docs/evidence/challenger-reference-body-2026-11-13/panel-"+("before" if before else "after")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"));file.close()
	print("CHALLENGER_PANELS: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(metrics)])
	quit(1 if failures else 0)
