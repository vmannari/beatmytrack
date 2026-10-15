extends SceneTree
## Independent part fit, normal winding, 256 combinations and bounded caches.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/compact-kits-2026-10-13"
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)
func _run() -> void:
	var parts_only: bool = "--parts-only" in OS.get_cmdline_user_args()
	var stock := CarVisual.new()
	root.add_child(stock)
	var stock_wear := VehicleWeathering.new()
	stock_wear.configure(stock,"pine",VehicleCatalog.config("compact"))
	print("STOCK_WASH_BOUNDS ",stock_wear.bounds)
	var stock_bounds: AABB = stock_wear.bounds
	stock.queue_free()
	await process_frame
	var maximum: int = 0
	var cache_full: int = 0
	for simple: bool in [false,true]:
		for hood: Array in VehicleCustomisation.OPTIONS.hood:
			for aero: Array in VehicleCustomisation.OPTIONS.aero:
				for rims: Array in VehicleCustomisation.OPTIONS.rims:
					for body: Array in VehicleCustomisation.OPTIONS.body:
						if parts_only:
							var selected: int = 0
							for id: String in [str(hood[0]),str(aero[0]),str(rims[0]),str(body[0])]:
								if id!="stock": selected += 1
							if selected>1: continue
						var car := CarVisual.new()
						car.simple_model = simple
						car.customisation = {"version":1,"hood":hood[0],"aero":aero[0],"rims":rims[0],"body":body[0]}
						root.add_child(car)
						var label: String = str(car.customisation)+"/"+str(simple)
						check(car.front_wheels.size()==2 and car.rolling_wheels.size()==4,label+" articulation")
						var triangles: int = 0
						for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
							var arrays: Array = mesh.mesh.surface_get_arrays(0)
							triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
						maximum = maxi(maximum,triangles)
						check(triangles<170000,label+" budget")
						if hood[0]=="dome" and aero[0]=="wing" and rims[0]=="turbine" and body[0]=="club":
							var wear := VehicleWeathering.new()
							wear.configure(car,"pine",VehicleCatalog.config("compact"))
							print("TUNED_WASH_BOUNDS ",wear.bounds," simple=",simple)
							check(wear.bounds.is_equal_approx(stock_bounds),"saved wash mapping retained")
							var model_points := PackedVector3Array()
							for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
								if part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
								var transform: Transform3D = car.global_transform.affine_inverse()*part.global_transform
								for p: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: model_points.append(transform*p)
							for step: int in range(24):
								var state := VehicleState.new()
								state.roll_ticks = maxi(1,VehicleSimulation.ROLL_DURATION_TICKS-step*VehicleSimulation.ROLL_DURATION_TICKS/24)
								state.roll_direction = 1
								var before: Array = state.snapshot()
								car.position = Vector3.ZERO
								car.rotation = Vector3.ZERO
								car.present_roll(state)
								var low: float = INF
								for p: Vector3 in model_points: low = minf(low,(car.transform*p).y)
								check(low>=-0.003,"fitted wing/body clear floor during roll")
								check(state.snapshot()==before,"visual roll preserves canonical state")
						car.queue_free()
						await process_frame
		if not simple: cache_full = CompactKits.meshes.size()
	check(CompactKits.meshes.size()<=cache_full*2,"part cache bounded by catalog/quality, not combinations")
	for key: String in CompactKits.meshes:
		var arrays: Array = (CompactKits.meshes[key] as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var finite: bool = true
		var wrong: int = 0
		var volume: float = 0.0
		for index: int in range(vertices.size()):
			if not vertices[index].is_finite() or not normals[index].is_finite() or normals[index].length_squared()<0.5: finite = false
		for index: int in range(0,indices.size(),3):
			var a: int = indices[index]
			var b: int = indices[index+1]
			var c: int = indices[index+2]
			var face: Vector3 = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
			volume += vertices[a].cross(vertices[b]).dot(vertices[c])/6.0
			if face.length_squared()>1e-16 and face.normalized().dot((normals[a]+normals[b]+normals[c]).normalized())>0.02:
				wrong += 1
				if key=="hood/scoop/side1.0": print("BAD_SCOOP ",[vertices[a],vertices[b],vertices[c]],[normals[a],normals[b],normals[c]])
		check(finite,"finite unit normals "+key)
		check(wrong==0,"clockwise shaded triangles "+key+" wrong="+str(wrong))
		if key=="aero/wing/airfoil": check(absf(volume)>0.004,"GT blade has solid airfoil volume")
	for kind: String in ["louvres","scoop","dome"]:
		for edge: float in [0.0,1.0]:
			for index: int in range(89):
				var t: float = index/88.0
				check(CompactKits.hood_sample(kind,t,edge).is_equal_approx(CompactCoachwork.hood_point(lerpf(-1,1,t),edge)),"hood front/cowl fits "+kind)
			for index: int in range(33):
				var t: float = index/32.0
				check(CompactKits.hood_sample(kind,edge,t).is_equal_approx(CompactCoachwork.hood_point(lerpf(-1,1,edge),t)),"hood fender fits "+kind)
	print("KIT_GEOMETRY: %d checks, %d failures; max=%d triangles; cached=%d"%[checks,failures,maximum,CompactKits.meshes.size()])
	quit(1 if failures else 0)
