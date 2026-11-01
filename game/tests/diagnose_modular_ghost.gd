extends "res://tests/test_modular_car_assets.gd"

func compare(first: ArrayMesh, second: ArrayMesh, label: String) -> void:
	var a: PackedVector3Array = first.get_faces()
	var b: PackedVector3Array = second.get_faces()
	var unequal: int = 0
	var max_distance: float = 0.0
	var samples: Array = []
	for i: int in range(mini(a.size(),b.size())):
		var delta: float = a[i].distance_to(b[i])
		if delta > 0:
			unequal += 1
			max_distance = maxf(max_distance,delta)
			if samples.size() < 5: samples.append([i,a[i],b[i],delta])
	print("GHOST_DIAG ",label," counts=",a.size(),"/",b.size()," index_unequal=",unequal," max_distance=",max_distance," samples=",samples," hash=",mesh_geometry(first),"/",mesh_geometry(second))

func run() -> void:
	for id: String in ["kart","forklift"]:
		for simple: bool in [false,true]:
			var control: CarVisual = await make_car(id,simple,false,VehicleCustomisation.defaults(),false)
			var reference: ArrayMesh = PersonalGhost.mesh_for(control)
			var cached_holder: Node3D = Rest.rest_scene(control)
			var live: CarVisual = await make_car(id,simple,false,VehicleCustomisation.defaults(),true)
			var live_rest: ArrayMesh = PersonalGhost.mesh_for(live)
			compare(reference,live_rest,id+" simple="+str(simple)+" procedural_vs_modular_live")
			var detached: Node3D = PersonalGhost._modular_rest_scene(live)
			if detached != null:
				var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				var canonical:=Transform3D(Basis.from_scale(live.scale),Vector3.ZERO)
				PersonalGhost._append_local(detached,canonical,canonical.affine_inverse(),tool)
				tool.generate_normals()
				compare(reference,tool.commit(),id+" simple="+str(simple)+" canonical_scale")
				detached.free()
			live.position = Vector3(11,2,-3); live.rotation.y = 0.72
			live.body.rotation.z = 0.13
			if not live.rolling_wheels.is_empty(): live.rolling_wheels[0].rotation.x=0.7
			live.force_update_transform()
			for child: Node3D in live.find_children("*","Node3D",true,false): child.force_update_transform()
			PersonalGhost.prepared_meshes.clear()
			var ghost:=PersonalGhost.new(); ghost.configure(live)
			compare(reference,ghost.mesh,id+" simple="+str(simple)+" procedural_vs_detached")
			compare(live_rest,ghost.mesh,id+" simple="+str(simple)+" modular_live_vs_detached")
			if cached_holder != null: cached_holder.free()
			ghost.free(); control.free(); live.free(); await process_frame
	quit()
