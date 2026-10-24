extends SceneTree
const LightBudget = preload("res://track/night_light_budget.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func triangles(nodes: Array[MeshInstance3D]) -> Array[String]:
	var result: Array[String] = []
	for node: MeshInstance3D in nodes:
		var data: Array = node.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var count: int = indices.size() if not indices.is_empty() else data[Mesh.ARRAY_VERTEX].size()
		for start: int in range(0,count,3):
			var row: Array = []
			for corner: int in range(3):
				var index: int = indices[start+corner] if not indices.is_empty() else start+corner
				for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
					if data[attribute]!=null: row.append(data[attribute][index])
			result.append(var_to_bytes(row).hex_encode())
	result.sort(); return result
func partition(kind: String,family: String,theme: String) -> void:
	var visual := NativeTrackVisual.new(); visual.theme_id = theme; visual.colors = TrackTheme.palette(theme); root.add_child(visual)
	var objects: Array = []
	for index: int in range(12): objects.append({"kind":kind,"position":[-80+(index%6)*32,-32+(index/6)*64],"rotation":index*15,"scale":0.75+(index%3)*0.25})
	var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":objects}}
	await visual._build_placed_objects(track)
	var original: MeshInstance3D = visual.get_node(family)
	var expected: Array[String] = triangles([original]); var material: Material = original.material_override
	await visual._partition_bank_meshes()
	var parts: Array[MeshInstance3D] = []
	for node: Node in visual.get_children():
		if node is MeshInstance3D and node.has_meta("spatial_mesh_tile") and str(node.name).begins_with(family): parts.append(node)
	check(parts.size()>1,family+" receives independent spatial culling")
	var actual: Array[String] = triangles(parts)
	if actual!=expected:
		print("SPATIAL_TRIANGLE_COUNTS ",family," ",expected.size(),"/",actual.size())
		for index: int in range(mini(actual.size(),expected.size())):
			if actual[index]!=expected[index]:
				var a: Array = bytes_to_var(expected[index].hex_decode()); var b: Array = bytes_to_var(actual[index].hex_decode())
				for field: int in range(a.size()):
					if var_to_bytes(a[field])!=var_to_bytes(b[field]): print("SPATIAL_FIELD_DIFF ",field," equal=",a[field]==b[field]," ",var_to_bytes(a[field]).hex_encode(),"/",var_to_bytes(b[field]).hex_encode())
				break
	check(actual==expected,family+" retains every exact triangle/normal/colour/UV")
	check(parts.all(func(node: MeshInstance3D) -> bool: return node.material_override==material and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON),family+" retains original opaque material and shadows")
	check(not is_instance_valid(original),family+" releases the complete aggregate instead of doubling retained geometry")
	print("PROP_SPATIAL_ENVELOPE ",family," triangles=",expected.size()," chunks=",parts.size())
	visual.free(); await process_frame
func lights() -> void:
	var world := Node3D.new(); root.add_child(world)
	for index: int in range(96):
		var lamp := OmniLight3D.new(); lamp.position = Vector3((index%12)*8-44,4,(index/12)*8-28); lamp.omni_range = 15; lamp.light_energy = 5
		world.add_child(lamp)
	var camera := Camera3D.new(); world.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 35
	camera.look_at_from_position(Vector3(0,35,35),Vector3.ZERO)
	var budget: Node3D = LightBudget.new(); budget.name = "NightLightBudget"; world.add_child(budget); budget.set_process(false); budget.update_camera(camera)
	check(budget.sources.size()==96 and budget.selected.size()==8,"all authored lamps remain represented; eight are active")
	check(budget.sources.filter(func(node: OmniLight3D) -> bool: return node.visible).size()==8,"global selection cannot exceed the per-mesh omni envelope")
	var stable: Array = budget.selected.duplicate()
	for index: int in range(20): camera.position.x += 0.001; budget.update_camera(camera)
	check(budget.selected.size()==stable.size() and budget.selected.all(func(node: OmniLight3D) -> bool: return node in stable),"small camera motion retains stable membership")
	camera.position.x += 65; budget.update_camera(camera)
	check(budget.selected!=stable and budget.selected.size()==8,"distant motion selects nearby lamps within the same bound")
	check(budget.sources.all(func(node: OmniLight3D) -> bool: return node.light_energy==5 and node.omni_range==15),"selection preserves authored intensities/ranges")
	if DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="gl_compatibility":
		var box := MeshInstance3D.new(); box.mesh = BoxMesh.new(); world.add_child(box)
		var visibility: Array[bool] = []
		for source: OmniLight3D in budget.sources: visibility.append(source.visible)
		var prepared: Dictionary = NightRenderPreparation.begin(world,camera)
		check(not prepared.light_limit and prepared.lights.size()==96 and prepared.nodes.size()==2,"covered warmup supports all legal authored lamps above the former 64-light limit")
		NightRenderPreparation.set_context(prepared,3); NightRenderPreparation.end(prepared)
		var restored: Array[bool] = []
		for source: OmniLight3D in budget.sources: restored.append(source.visible)
		check(restored==visibility,"covered shader preparation restores the exact selected light set")
	var copy: Node3D = world.duplicate(); root.add_child(copy)
	var copied: Node3D = copy.get_node(str(budget.name))
	check(copied.sources.size()==96 and copied.selected.size()==8,"copied worlds recover authored visibility instead of freezing a prior selection")
	budget.sources[0].free(); budget.update_camera(camera)
	check(budget.sources.size()==95 and budget.selected.size()==8,"removed lamps refresh safely within the same bound")
	copy.free(); world.free(); await process_frame
func fire_bound() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 73019
	var skipped: int = 0; var errors: int = 0
	for index: int in range(12000):
		var p := Vector3(rng.randf_range(-0.5,0.5),rng.randf_range(-0.5,0.5),rng.randf_range(-0.5,0.5)); var h: float = p.y+0.5
		var coarse := Vector3(rng.randf(),rng.randf(),rng.randf()); var fine: float = rng.randf(); var spill: float = rng.randf()
		var centre := Vector2(coarse.y-0.5,coarse.z-0.5)*(0.17+0.25*h); var radius: float = (Vector2(p.x,p.z)-centre).length()*2
		var envelope: float = 0.84*pow(maxf(0,1-h),0.8)+0.025
		var maximum: float = lerpf(envelope*lerpf(1,0.60+coarse.y*0.72,spill)-radius+(coarse.x-0.5)*0.72+0.26,minf(0.9-radius,(coarse.x-0.30)*1.7+0.24-h*0.70),spill)
		var body: float = lerpf(envelope*lerpf(1,0.42+coarse.y*0.72+fine*0.18,spill)-radius+(coarse.x-0.5)*0.72+(fine-0.5)*0.52,minf(0.9-radius,(coarse.x-0.30)*1.7+(fine-0.5)*0.48-h*0.70),spill)
		if maximum<=0.025:
			skipped += 1
			if body>0.02500001: errors += 1
	check(skipped>0 and errors==0,"coarse-noise bound never skips positive fire density")
	print("FIRE_EMPTY_BOUND samples=12000 skipped=",skipped," false_empty=",errors)
func run() -> void:
	await partition("snow_castle","WinterCraft","winter")
	await partition("egypt_obelisk","EgyptianStonework","desert")
	await partition("abandoned_warehouse","NightFurniture","night_city")
	await lights(); fire_bound()
	print("GAMEPLAY_RENDER_ENVELOPE: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
