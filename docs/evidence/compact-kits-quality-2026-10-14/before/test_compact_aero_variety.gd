extends SceneTree
## Actual lower/aft silhouette, hatch-mount fit, roll clearance and retained editing.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/compact-aero-variety-2026-10-14"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	var rows: Array[Dictionary] = []
	check(VehicleCustomisation.OPTIONS.aero.size()==13,"thirteen independently selectable aero choices")
	for kind: String in ["pedestal","biwing","endurance"]:
		var center: Vector3 = CompactAero.PROFILES[kind].center
		check(center.y<=1.52 and center.z>=2.20,"large wing is lower and farther aft: "+kind)
	for simple: bool in [false,true]:
		for option: Array in VehicleCustomisation.OPTIONS.aero:
			var kind: String = option[0]
			var car := CarVisual.new()
			car.editable_kits = true
			car.simple_model = simple
			car.customisation = VehicleCustomisation.defaults()
			car.customisation.aero = kind
			root.add_child(car)
			var points := PackedVector3Array()
			var bounds := AABB()
			var initial: bool = true
			var triangles: int = 0
			for frame: Node3D in car.kit_frames.aero:
				for mesh: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
					var transform: Transform3D = car.global_transform.affine_inverse()*mesh.global_transform
					for surface: int in range(mesh.mesh.get_surface_count()):
						var arrays: Array = mesh.mesh.surface_get_arrays(surface)
						triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
						for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
							var p: Vector3 = transform*point
							points.append(p)
							bounds = AABB(p,Vector3.ZERO) if initial else bounds.expand(p)
							initial = false
			if kind!="stock":
				check(not points.is_empty() and triangles>0,"real fitted aero geometry "+kind)
				check(bounds.end.z<2.66 and bounds.end.y<2.02 and bounds.size.x<2.02,"bounded aero silhouette "+kind)
			if CompactAero.PROFILES.has(kind):
				var profile: Dictionary = CompactAero.PROFILES[kind]
				if profile.mount=="rear":
					check(bounds.position.z>1.80,"whole low rear assembly stays behind the cabin "+kind)
					for side: float in [-1,1]:
						var mount: Vector3 = CompactAero.mount_point(kind,side)
						check(mount.y<1.01 and is_equal_approx(mount.z,CompactCoachwork.rear_skin(mount.x,mount.y)),"rear metal mount follows actual hatch "+kind)
				var clear: bool = true
				for p: Vector3 in points:
					if p.y>=1.065 and p.y<=1.46 and absf(p.x)<0.61:
						if p.z<CompactCoachwork.rear_skin(p.x,p.y)+0.02: clear = false
				check(clear,"aero clears original hatch glass "+kind)
			if kind=="splitwing":
				var empty_center: bool = true
				for p: Vector3 in points:
					if p.y>1.20 and absf(p.x)<0.12: empty_center = false
				check(empty_center,"split blade retains its visible center opening")
			for index: int in range(24):
				var state := VehicleState.new()
				state.roll_ticks = maxi(1,VehicleSimulation.ROLL_DURATION_TICKS-index*VehicleSimulation.ROLL_DURATION_TICKS/24)
				state.roll_direction = 1
				var snapshot: Array = state.snapshot()
				car.position = Vector3.ZERO
				car.rotation = Vector3.ZERO
				car.present_roll(state)
				var low: float = INF
				for p: Vector3 in points: low = minf(low,(car.transform*p).y)
				check(low>=-0.003 and state.snapshot()==snapshot,"actual aero clears floor during visual roll "+kind)
			rows.append({"option":kind,"simple":simple,"triangles":triangles,"bounds_position":[bounds.position.x,bounds.position.y,bounds.position.z],"bounds_size":[bounds.size.x,bounds.size.y,bounds.size.z]})
			car.queue_free()
			await process_frame
	for key: String in CompactKits.meshes:
		if not key.begins_with("aero4/") or key.trim_suffix("/simple").get_file() not in ["seal","plate"]: continue
		var kind: String = key.split("/")[1]
		if CompactAero.PROFILES[kind].mount!="rear": continue
		var arrays: Array = (CompactKits.meshes[key] as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var volume: float = 0.0
		var edges: Dictionary = {}
		for index: int in range(0,indices.size(),3):
			volume += vertices[indices[index]].cross(vertices[indices[index+1]]).dot(vertices[indices[index+2]])/6.0
			for edge: int in range(3):
				var a: String = str(Vector3i((vertices[indices[index+edge]]*100000.0).round()))
				var b: String = str(Vector3i((vertices[indices[index+(edge+1)%3]]*100000.0).round()))
				var label: String = a+"/"+b if a<b else b+"/"+a
				edges[label] = int(edges.get(label,0))+1
		check(absf(volume)>0.000005,"hatch saddle is a closed solid "+key)
		var closed: bool = true
		for count: int in edges.values():
			if count!=2: closed = false
		check(closed,"hatch saddle has paired watertight edges "+key)
	var host := Control.new()
	root.add_child(host)
	var view := CarShowroom.new()
	view.garage_mode = true
	host.add_child(view)
	var actual: CarVisual = view.car
	var body: Node3D = actual.body
	var wheels: Array[Node3D] = actual.rolling_wheels.duplicate()
	var camera: Transform3D = view.camera.transform
	view.weathering.dirt_amount = 0.52
	view.weathering._update_finish()
	var condition: Dictionary = view.weathering.snapshot()
	for option: Array in VehicleCustomisation.OPTIONS.aero:
		var next: Dictionary = actual.customisation.duplicate(true)
		next.aero = option[0]
		view.apply_customisation(next)
		check(view.car==actual and actual.body==body and actual.rolling_wheels==wheels,"wing edit retains actual car/body/wheels")
		check(view.camera.transform==camera and view.weathering.snapshot()==condition,"wing edit retains camera and exact condition")
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("aero-fit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"aero":rows},"\t"))
	file.close()
	host.queue_free()
	await process_frame
	print("COMPACT_AERO_VARIETY: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
