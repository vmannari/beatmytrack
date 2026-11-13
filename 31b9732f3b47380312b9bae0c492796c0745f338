extends "res://tests/review_compact_kits.gd"
## Actual prepared/source attachment rays, both sides and detail levels.
var checks: int = 0
var failures: int = 0
var attachments: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func prepared(key: String, simple: bool) -> ArrayMesh:
	var cache: String = key+("/simple" if simple else "")
	return CompactKits.meshes.get(cache) as ArrayMesh

func shell(car: CarVisual) -> Array[TriangleMesh]:
	var result: Array[TriangleMesh] = []
	for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if part.get_parent()!=car.body: continue
		if part.mesh is ArrayMesh and part.transform == Transform3D.IDENTITY:
			result.append(part.mesh.generate_triangle_mesh())
	return result

func verify_solid(mesh: ArrayMesh, label: String) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var edges: Dictionary = {}
	var volume: float = 0
	for index: int in range(0,indices.size(),3):
		volume += points[indices[index]].cross(points[indices[index+1]]).dot(points[indices[index+2]])/6.0
		for edge: int in range(3):
			var a: Vector3i = Vector3i((points[indices[index+edge]]*100000).round())
			var b: Vector3i = Vector3i((points[indices[index+(edge+1)%3]]*100000).round())
			if a == b: continue
			var p: String = str(a)
			var q: String = str(b)
			var key: String = p+"/"+q if p<q else q+"/"+p
			edges[key] = int(edges.get(key,0))+1
	var closed: bool = true
	var unexpected: Array[String] = []
	for key: String in edges:
		if edges[key] != 2:
			closed = false
			if unexpected.size()<6: unexpected.append(key+" count="+str(edges[key]))
	if not closed: print("UNPAIRED_EDGES ",label," ",unexpected)
	check(closed,label+" is a watertight fabricated solid")
	check(absf(volume)>0.00000002,label+" has real thickness")

func interval(meshes: Array[TriangleMesh], at: Vector3, axis: Vector3) -> Vector2:
	var low: float = INF
	var high: float = -INF
	for mesh: TriangleMesh in meshes:
		for side: float in [-1,1]:
			var hit: Dictionary = mesh.intersect_ray(at+axis*side*3.0,-axis*side)
			if hit.is_empty(): continue
			var point: Vector3 = hit.position
			var value: float = point.dot(axis)
			low = minf(low,value)
			high = maxf(high,value)
	return Vector2(low,high)

func verify_lip(stock: Array[TriangleMesh], simple: bool) -> void:
	var mount: ArrayMesh = prepared("aero6/liproot",simple)
	check(mount != null,"roof lip has a complete fitted root, simple="+str(simple))
	if mount == null: return
	verify_solid(mount,"lip root "+str(simple))
	var root_mesh: Array[TriangleMesh] = [mount.generate_triangle_mesh()]
	var lip_mesh: Array[TriangleMesh] = [prepared("aero6/lip",simple).generate_triangle_mesh()]
	var deepest: float = INF
	var weakest: float = INF
	for column: int in range(13):
		var x: float = lerpf(-0.55,0.55,column/12.0)
		var base: Vector3 = CompactCoachwork.roof_point(x/0.63,0.94)
		for offset: float in [0.02,0.05]:
			var at := Vector3(x,0,base.z+offset)
			var original: Vector2 = interval(stock,at,Vector3.UP)
			var root_range: Vector2 = interval(root_mesh,at,Vector3.UP)
			var blade: Vector2 = interval(lip_mesh,at,Vector3.UP)
			var label: String = "roof root "+str(simple)+"/"+str(column)+"/"+str(offset)
			check(root_range.is_finite() and original.is_finite() and blade.is_finite(),label+" real ray hits")
			check(root_range.x <= original.y+0.0001,label+" reaches original roof")
			check(root_range.y >= blade.x+0.0003,label+" overlaps existing lip underside")
			deepest = minf(deepest,original.y-root_range.x)
			weakest = minf(weakest,root_range.y-blade.x)
	attachments.append({"part":"liproot","simple":simple,"minimum_roof_embed_m":deepest,"minimum_lip_overlap_m":weakest})

func verify_arches(stock: Array[TriangleMesh], kind: String, simple: bool) -> void:
	for side: float in [-1,1]:
		for axle: float in [-1.28,1.28]:
			var suffix: String = str(side)+"/"+str(axle)
			var backing: ArrayMesh = prepared("body6/"+kind+"/fendermount"+suffix,simple)
			check(backing != null,"fitted arch backing "+kind+"/"+suffix+"/"+str(simple))
			if backing == null: continue
			verify_solid(backing,kind+" backing "+suffix+"/"+str(simple))
			var clear: bool = true
			for point: Vector3 in backing.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if absf(point.x)>0.69 and absf(point.x)<0.98 and Vector2(point.y-0.37,point.z-axle).length()<0.382: clear = false
			check(clear,"mounting return retains the unchanged tyre envelope "+kind+"/"+suffix+"/"+str(simple))
			var back_mesh: Array[TriangleMesh] = [backing.generate_triangle_mesh()]
			var arch_mesh: Array[TriangleMesh] = [prepared("body6/"+kind+"/arch"+suffix,simple).generate_triangle_mesh()]
			var deepest: float = INF
			var weakest: float = INF
			var outer: float = 0.461 if kind=="heritage" else 0.492
			for station: int in range(11):
				var angle: float = lerpf(0.30,PI-0.30,station/10.0)
				for radius: float in [0.430,0.450,outer-0.004]:
					var at := Vector3(0,0.37+sin(angle)*radius,axle+cos(angle)*radius)
					var axis := Vector3(side,0,0)
					var original: Vector2 = interval(stock,at,axis)
					var back: Vector2 = interval(back_mesh,at,axis)
					var arch: Vector2 = interval(arch_mesh,at,axis)
					var label: String = kind+"/"+suffix+"/"+str(simple)+"/"+str(station)+"/"+str(radius)
					check(original.is_finite() and back.is_finite() and arch.is_finite(),label+" actual attachment ray hits")
					check(back.x <= original.y+0.0001,label+" backing reaches original metal")
					check(back.y >= arch.x+0.0003,label+" backing overlaps flare return")
					deepest = minf(deepest,original.y-back.x)
					weakest = minf(weakest,back.y-arch.x)
			attachments.append({"part":"fendermount","kind":kind,"simple":simple,"side":side,"axle":axle,"minimum_stock_embed_m":deepest,"minimum_flare_overlap_m":weakest})

func make_car(profile: Dictionary, simple: bool) -> CarVisual:
	var car := CarVisual.new()
	car.simple_model = simple
	car.batch_parts = false
	car.editable_kits = true
	car.customisation = profile
	root.add_child(car)
	return car

func run() -> void:
	output = "res://../docs/evidence/compact-kit-fixes-2026-10-25/attachments"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	if "--source" in OS.get_cmdline_user_args(): CompactKits.use_baked = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for simple: bool in [false,true]:
		var stock: CarVisual = make_car(VehicleCustomisation.defaults(),simple)
		var surfaces: Array[TriangleMesh] = shell(stock)
		for kind: String in ["dome","vented"]:
			var profile: Dictionary = VehicleCustomisation.defaults()
			profile.hood = kind
			profile.aero = "lip"
			var car: CarVisual = make_car(profile,simple)
			if kind == "dome": verify_lip(surfaces,simple)
			car.queue_free()
			await process_frame
		inspect_inserts(simple)
		for row: Dictionary in measurements.insert_clearance:
			if row.simple != simple: continue
			check(row.samples>4000,"dense matching insert/sheet rays "+row.kind+"/"+str(simple))
			check(row.below_sheet==0 and row.min_clearance_model_m>=0.0010,"actual insert triangles remain above hood "+row.kind+"/"+str(simple))
		for kind: String in ["rally","club","heritage","wide","endurance","gravel"]:
			var profile: Dictionary = VehicleCustomisation.defaults()
			profile.body = kind
			var car: CarVisual = make_car(profile,simple)
			verify_arches(surfaces,kind,simple)
			car.queue_free()
			await process_frame
		stock.queue_free()
		await process_frame
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		var host := Control.new()
		root.add_child(host)
		MenuStyle.fill(host)
		var view := CarShowroom.new()
		view.garage_mode = true
		host.add_child(view)
		MenuStyle.fill(view)
		await settle()
		var profile: Dictionary = VehicleCustomisation.defaults()
		profile.aero = "lip"
		view.apply_customisation(profile)
		await capture(view,"roof-lip-side",Vector3(0.1,1.50,1.15),Vector3(1.65,0.06,0.35))
		for kind: String in ["rally","heritage","wide"]:
			profile = VehicleCustomisation.defaults()
			profile.body = kind
			view.apply_customisation(profile)
			await capture(view,kind+"-arch",Vector3(0.925,0.73,-1.28),Vector3(0.60,0.04,-0.53))
		for simple: bool in [false,true]:
			for hood: String in ["dome","vented"]:
				var current: CarVisual = view.car
				view.car = CarVisual.new()
				view.car.simple_model = simple
				view.car.customisation = {"version":1,"hood":hood,"aero":"lip","rims":"mesh","body":"wide"}
				view.car.livery = VehicleLivery.defaults("compact")
				current.get_parent().add_child(view.car)
				view.car.transform = current.transform
				current.get_parent().remove_child(current)
				current.queue_free()
				var prefix: String = ("simple" if simple else "full")+"-"+hood
				await capture(view,prefix+"-insert",Vector3(0,1.03,-1.4),Vector3(0.8,1.1,-0.9))
				await capture(view,prefix+"-front",Vector3(0,0.72,0),Vector3(3.5,2.5,-4.8))
			host.queue_redraw()
			await capture(view,("simple" if simple else "full")+"-roof-lip",Vector3(0.1,1.50,1.15),Vector3(1.65,0.06,0.35))
			await capture(view,("simple" if simple else "full")+"-arch",Vector3(0.925,0.73,-1.28),Vector3(0.60,0.04,-0.53))
		host.queue_free()
		await process_frame
	measurements.attachments = attachments
	measurements.checks = checks
	measurements.failures = failures
	var file := FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t"))
	file.close()
	print("COMPACT_KIT_ATTACHMENTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
