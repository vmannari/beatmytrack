extends SceneTree
## Inspect actual opaque kit solids: welded closure, consistent edges and exterior winding.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-kit-surface-fix-2026-10-29/final"
var measurements: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func surface(mesh: Mesh) -> Dictionary:
	var edges: Dictionary = {}
	var volume: float = 0.0
	# Audit the actual native arrays; the triangle-mesh convenience path rounds
	# fine bevel coordinates and can make its otherwise valid cap edges collinear.
	var faces := PackedVector3Array()
	for surface_index: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty(): faces.append_array(vertices)
		else:
			for index: int in indices: faces.append(vertices[index])
	for face: int in range(faces.size()/3):
		var points: Array[Vector3] = [faces[face*3],faces[face*3+1],faces[face*3+2]]
		if (points[1]-points[0]).cross(points[2]-points[0]).length_squared()<1e-22: continue
		volume += points[0].dot(points[1].cross(points[2]))/6.0
		for corner: int in range(3):
			# Vector3's display string rounds away tiny bevels. Integer grid keys
			# retain the full one-micrometre weld precision without such collisions.
			var a: Vector3i = Vector3i((points[corner]*1000000).round())
			var b: Vector3i = Vector3i((points[(corner+1)%3]*1000000).round())
			if a==b: continue
			var forward: bool = a<b
			var key: String = str(a)+":"+str(b) if forward else str(b)+":"+str(a)
			var entry: Vector2i = edges.get(key,Vector2i.ZERO)
			entry.x += 1
			entry.y += 1 if forward else -1
			edges[key] = entry
	var boundary: int = 0
	var inconsistent: int = 0
	var examples: Array[String] = []
	for key: String in edges:
		var entry: Vector2i = edges[key]
		if entry.x!=2: boundary += 1
		elif entry.y!=0: inconsistent += 1
		if entry.x!=2 and examples.size()<12: examples.append(key)
	return {"boundary_edges":boundary,"inconsistent_edges":inconsistent,"boundary_examples":examples,"signed_volume":volume,"triangles":faces.size()/3}

func overlay(name: String) -> bool:
	for prefix: String in ["NoseInlayKeyline","NoseCenterInlay","FairingInlayKeyline","FairingCenterInlay","PodInsetStripe"]:
		if name.begins_with(prefix): return true
	return false

func triangles(car: CarVisual) -> int:
	var total: int = 0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: total += part.mesh.get_faces().size()/3
	return total

func lamps_exposed(car: CarVisual) -> bool:
	var parts: Array[MeshInstance3D] = []
	for frame: Node3D in car.kit_frames.hood:
		for part: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
			if not overlay(str(part.name)): parts.append(part)
	var found: int = 0
	for lamp: MeshInstance3D in parts:
		if lamp.name!="FrontLampGlass": continue
		found += 1
		var direction: Vector3 = lamp.global_basis.z.normalized()
		var origin: Vector3 = lamp.global_position-direction*0.25
		var nearest: MeshInstance3D
		var distance: float = INF
		for part: MeshInstance3D in parts:
			var inverse: Transform3D = part.global_transform.affine_inverse()
			var hit: Dictionary = part.mesh.generate_triangle_mesh().intersect_ray(inverse*origin,inverse.basis*direction)
			if hit.is_empty(): continue
			var depth: float = origin.distance_to(part.global_transform*hit.position)
			if depth<distance: nearest = part; distance = depth
		if nearest!=lamp: return false
	return found==2

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if "--historical" in OS.get_cmdline_user_args():
		historical()
		return
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.editable_kits = true
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for category: String in VehicleCustomisation.CATEGORIES:
			for option: Array in VehicleCustomisation.options(category,"kart"):
				if option[0]=="stock": continue
				car.graphics.restore_originals()
				var value: Dictionary = VehicleCustomisation.defaults()
				value[category] = option[0]
				car.change_kit_parts(value)
				var seen: Array[Mesh] = []
				var problems: Array[Dictionary] = []
				var count: int = 0
				for frame: Node3D in car.kit_frames[category]:
					for part: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
						if overlay(str(part.name)) or part.mesh in seen: continue
						seen.append(part.mesh)
						count += 1
						var info: Dictionary = surface(part.mesh)
						if info.boundary_edges>0 or info.inconsistent_edges>0 or info.signed_volume>=-1e-12:
							info["part"] = str(part.name)
							problems.append(info)
				check(problems.is_empty(),"closed exterior solids "+category+"/"+str(option[0])+" simple="+str(simple)+" defects="+str(problems.size()))
				if category=="hood": check(lamps_exposed(car),"both lamps remain outside the sealed nose "+str(option[0]))
				var assembled := CarVisual.new()
				assembled.vehicle_id = "kart"
				assembled.simple_model = simple
				assembled.editable_kits = true
				assembled.customisation = value
				root.add_child(assembled)
				while not assembled.model_ready: await process_frame
				check(triangles(assembled)==triangles(car),"production batches retain all solid/cap triangles "+category+"/"+str(option[0]))
				assembled.free()
				measurements.append({"category":category,"option":option[0],"simple":simple,"unique_solids":count,"defects":problems})
		car.free()
		await process_frame
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("KART_KIT_SURFACES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func historical() -> void:
	# These immutable resources predate the fix. Inspect their raw arrays with
	# exactly the final audit, without replacing another process's live sources.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/kart-kit-surface-fix/before/game/assets/vehicles/kart_refined_v1/manifest.json"))
	var panels: int = 0
	var open_panels: int = 0
	var inward_wheels: int = 0
	for entry: Dictionary in manifest.meshes:
		var panel: bool = "|kit-section-v1|" in str(entry.key)
		var wheel: bool = str(entry.key).begins_with("RecessedDiscWheel|") or str(entry.key).begins_with("DeepBowlWheel|")
		if not panel and not wheel: continue
		var info: Dictionary = surface(load("res://assets/vehicles/kart_refined_v1/"+str(entry.file)))
		info["key"] = entry.key
		measurements.append(info)
		if panel:
			panels += 1
			if info.boundary_edges>0: open_panels += 1
		if wheel and info.signed_volume>0: inward_wheels += 1
	check(panels==42 and open_panels==42,"final audit rejects all 42 historical uncapped panels")
	check(inward_wheels==4,"final audit rejects both mirrored wheel designs at both detail levels")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"historical_open_panels":open_panels,"historical_inward_wheels":inward_wheels,"measurements":measurements},"\t"))
	print("KART_KIT_SURFACE_CONTROL: %d checks, %d failures; %d open panels, %d inward wheels" % [checks,failures,open_panels,inward_wheels])
	quit(1 if failures else 0)
