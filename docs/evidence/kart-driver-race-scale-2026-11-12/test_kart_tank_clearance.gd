extends SceneTree
## KTC01: inspect actual tank, cap and driver triangles in both quality tiers.
const OUT = "res://../docs/evidence/kart-driver-race-scale-2026-11-12"
const Crossing = preload("res://tests/test_kart_driver_cockpit.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var probe: SceneTree = Crossing.new()
	var rows: Array = []
	var checks: int = 0
	var failures: int = 0
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var driver: MeshInstance3D = car.body.find_child("TomkartDriver",true,false)
		var body: ArrayMesh = driver.mesh
		for node: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
			if str(node.name) not in ["FuelTank","FuelCap","FuelLine"]: continue
			var transform: Transform3D = car.body.global_transform.affine_inverse()*node.global_transform
			if "--before" in OS.get_cmdline_user_args():
				if str(node.get_parent().name)=="FuelAssembly": node.get_parent().position = Vector3.ZERO
				node.mesh = load(OUT+"/before-"+("simple-" if simple else "full-")+str(node.name)+".res")
				if str(node.name)=="FuelCap": node.position = Vector3(0,0.332,-0.26)
				transform = car.body.global_transform.affine_inverse()*node.global_transform
			var tree: TriangleMesh = node.mesh.generate_triangle_mesh()
			var bounds: AABB = transform*node.mesh.get_aabb()
			if str(node.name)=="FuelTank":
				checks += 1
				if bounds.end.x> -0.29 or bounds.position.z<0.50 or bounds.position.y<0.210: failures += 1
			if str(node.name)=="FuelCap":
				checks += 1
				if bounds.end.x> -0.30 or bounds.position.z<0.60: failures += 1
			var part_faces: PackedVector3Array = node.mesh.get_faces()
			for index: int in range(part_faces.size()): part_faces[index] = transform*part_faces[index]
			for pose: int in range(7):
				var posed := ArrayMesh.new()
				for surface: int in range(body.get_surface_count()):
					var arrays: Array = body.surface_get_arrays(surface)
					if pose>0:
						var shape: Array = body.surface_get_blend_shape_arrays(surface)[pose-1]
						arrays[Mesh.ARRAY_VERTEX] = shape[Mesh.ARRAY_VERTEX]
						arrays[Mesh.ARRAY_NORMAL] = shape[Mesh.ARRAY_NORMAL]
					posed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				var hit: Vector3 = probe.crossing(posed.get_faces(),tree,transform,bounds)
				var reverse: Vector3 = probe.crossing(part_faces,posed.generate_triangle_mesh(),Transform3D.IDENTITY,posed.get_aabb())
				var clear: bool = not hit.is_finite() and not reverse.is_finite()
				checks += 1
				if not clear: failures += 1
				rows.append({"simple":simple,"pose":pose,"part":str(node.name),"bounds":str(bounds),"clear":clear,"driver_crossing":str(hit),"part_crossing":str(reverse)})
				print("TANK_INSPECT ",rows[-1])
			if str(node.name) in ["FuelTank","FuelCap"]:
				for obstacle: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
					var label: String = str(obstacle.name)
					if label.begins_with("Fuel") or label in ["TomkartDriver","HelmetStatic"] or obstacle.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
					checks += 1
					var placement: Transform3D = car.body.global_transform.affine_inverse()*obstacle.global_transform
					var box: AABB = placement*obstacle.mesh.get_aabb()
					if not bounds.intersects(box): continue
					var obstacle_faces: PackedVector3Array = obstacle.mesh.get_faces()
					for index: int in range(obstacle_faces.size()): obstacle_faces[index] = placement*obstacle_faces[index]
					var hit: Vector3 = probe.crossing(part_faces,obstacle.mesh.generate_triangle_mesh(),placement,box)
					var reverse: Vector3 = probe.crossing(obstacle_faces,tree,transform,bounds)
					if hit.is_finite() or reverse.is_finite(): failures += 1; printerr("TANK_OBSTACLE ",node.name," / ",label," ",hit," ",reverse)
			if "--snapshot" in OS.get_cmdline_user_args(): ResourceSaver.save(node.mesh,OUT+"/before-"+("simple-" if simple else "full-")+str(node.name).split("@")[0]+".res")
		car.free()
	probe.free()
	FileAccess.open(OUT+("/inspection-before.json" if "--snapshot" in OS.get_cmdline_user_args() else "/inspection-rejected.json" if "--before" in OS.get_cmdline_user_args() else "/inspection-after.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print("KART_TANK_CLEARANCE ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
