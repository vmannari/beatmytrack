extends SceneTree
## Exact geometry, lifetime, mutation, pose and budget controls for audio hulls.
const Contact = preload("res://vehicle/visible_contact_audio.gd")
var checks: int = 0
var failures: int = 0
var samples: Array[Dictionary] = []
var baseline_script: Script

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("CONTACT_CACHE_FAIL ",label)

func mesh(points: PackedVector3Array) -> ArrayMesh:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func fixture() -> Node3D:
	var car := Node3D.new(); root.add_child(car)
	car.scale = Vector3(0.25,0.25,0.25)
	var part := MeshInstance3D.new(); part.name = "Wheel"
	part.mesh = mesh(PackedVector3Array([Vector3(-1,0,-2),Vector3(1,0,-2),Vector3(0,0,2)]))
	car.add_child(part)
	return car

func oracle(car: Node3D) -> PackedVector2Array:
	var points := PackedVector2Array()
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null: continue
		var transform: Transform3D = inverse*part.global_transform
		for surface: int in range(part.mesh.get_surface_count()):
			var vertices: PackedVector3Array = part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var local: Vector3 = transform*vertex
				points.append(Vector2(local.x*car.scale.x,-local.z*car.scale.z))
	return Geometry2D.convex_hull(points) if points.size()>2 else PackedVector2Array()

func controls() -> void:
	Contact.trim_cache()
	var car: Node3D = fixture()
	var observer := Contact.new()
	var expected: PackedVector2Array = oracle(car)
	observer.configure(car,true)
	check(observer.outline==expected,"first exact hull")
	check(Contact.bytes_used()>0,"admitted mesh and outline bytes")
	var reads: int = Contact.surface_reads
	var hits: int = Contact.cache_hits
	observer.touching = true; observer.sounded = true; observer.cue_requested = true
	observer.configure(car,true)
	check(Contact.cache_hits==hits+1 and Contact.surface_reads==reads,"same geometry hit performs no surface read")
	check(not observer.touching and not observer.sounded and not observer.cue_requested,"cache hit resets contact episode")
	car.get_child(0).position.x = 3.0
	observer.configure(car,true)
	check(observer.outline==oracle(car) and observer.outline!=expected,"moved part requires exact new hull")
	car.scale = Vector3(0.5,0.25,0.5)
	observer.configure(car,true)
	check(observer.outline==oracle(car),"scale change requires exact new hull")
	var old_mesh: ArrayMesh = car.get_child(0).mesh
	old_mesh.clear_surfaces()
	observer.configure(car,true)
	check(observer.outline.is_empty(),"surface removal cannot reuse old hull")
	old_mesh.emit_changed()
	check(Contact.prepared_outlines.is_empty(),"same mesh geometry edit invalidates all dependent poses")
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-4,0,-2),Vector3(4,0,-2),Vector3(0,0,4)])
	old_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	observer.configure(car,true)
	check(observer.outline==oracle(car),"same-resource replacement rebuilds exact hull")
	var previous: PackedVector2Array = observer.outline
	var bounds: AABB = old_mesh.get_aabb()
	old_mesh.clear_surfaces()
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-4,0,4),Vector3(4,0,4),Vector3(0,0,-2)])
	old_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	old_mesh.emit_changed()
	check(old_mesh.get_aabb()==bounds,"mutation fixture preserves bounding box")
	observer.configure(car,true)
	check(observer.outline==oracle(car) and observer.outline!=previous,"changed signal rejects stale geometry with unchanged identity, pose and bounds")
	car.get_child(0).mesh = mesh(PackedVector3Array([Vector3(-2,0,-5),Vector3(2,0,-5),Vector3(0,0,5)]))
	reads = Contact.surface_reads
	observer.configure(car,true)
	check(Contact.surface_reads>reads and observer.outline==oracle(car),"new mesh identity misses even at unchanged pose")
	for index: int in range(12):
		car.get_child(0).position.x = index
		observer.configure(car,true)
	check(Contact.prepared_outlines.size()<=Contact.MAX_ENTRIES and Contact.bytes_used()<=Contact.RETAINED_BYTES,"bounded pose entries and retained bytes")
	var before: int = Contact.bytes_used()
	Contact.trim_cache(before/2)
	check(Contact.bytes_used()<=before/2,"partial pressure trim respects allowance")
	Contact.trim_cache()
	check(Contact.prepared_outlines.is_empty() and Contact.bytes_used()==0,"full pressure trim releases entries")
	var reference: WeakRef = weakref(car.get_child(0).mesh)
	car.free(); old_mesh = null
	check(reference.get_ref()==null,"trim retains no mesh after owner is freed")
	var empty := Node3D.new(); root.add_child(empty)
	observer.configure(empty,true)
	check(observer.outline.is_empty(),"empty car remains silent")
	empty.free(); Contact.trim_cache()

func oversized() -> void:
	var car := Node3D.new(); root.add_child(car)
	var part := MeshInstance3D.new(); car.add_child(part)
	var vertices := PackedVector3Array(); vertices.resize(400002)
	var normals := PackedVector3Array(); normals.resize(vertices.size()); normals.fill(Vector3.UP)
	for index: int in range(vertices.size()): vertices[index]=Vector3(-1 if index%3==0 else 1 if index%3==1 else 0,0,-2 if index%3<2 else 2)
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	var large := ArrayMesh.new(); large.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	part.mesh = large
	var observer := Contact.new(); observer.configure(car,true)
	check(observer.outline==oracle(car),"over-budget model keeps exact uncached hull")
	check(Contact.prepared_outlines.is_empty() and Contact.bytes_used()==0,"over-budget model retains no mesh")
	car.free()

func asset_sample(id: String, prepared: bool, source: Script = Contact) -> Dictionary:
	var path: String = "res://assets/vehicles/modular_car_bases_v1/"+id+"_simple_fixed.scn"
	var packed: PackedScene = load(path)
	var car: Node3D = packed.instantiate()
	root.add_child(car)
	car.scale = Vector3.ONE*HandlingConfig.BODY_SCALE
	var observer: Variant = source.new()
	var start: int = Time.get_ticks_usec()
	observer.configure(car,prepared)
	var elapsed: int = Time.get_ticks_usec()-start
	var result: Dictionary = {"id":id,"prepared":prepared,"usec":elapsed,"outline":observer.outline,"bytes":Contact.bytes_used(),"parts":car.find_children("*","MeshInstance3D",true,false).size()}
	car.free()
	return result

func assets() -> void:
	for id: String in ["compact","electric","kart","forklift","hovercraft","super_rally"]:
		Contact.trim_cache()
		var baseline: Dictionary = asset_sample(id,false)
		var old_repeat: Dictionary = {}
		if baseline_script != null:
			asset_sample(id,true,baseline_script)
			old_repeat = asset_sample(id,true,baseline_script)
			check(old_repeat.outline==baseline.outline,id+" retained original cache hull matches oracle")
		var first: Dictionary = asset_sample(id,true)
		check(first.outline==baseline.outline,id+" first hull exact to uncached vertices")
		check(Contact.bytes_used()>0,id+" eligible for bounded mesh retention")
		await process_frame
		var reads: int = Contact.surface_reads
		var hits: int = Contact.cache_hits
		var repeated: Dictionary = asset_sample(id,true)
		check(repeated.outline==baseline.outline,id+" recreated owner hull exact")
		check(Contact.cache_hits==hits+1 and Contact.surface_reads==reads,id+" recreated owner reuses hull without GPU readback")
		samples.append({"id":id,"uncached_us":baseline.usec,"original_repeat_us":old_repeat.get("usec",-1),"first_us":first.usec,"repeat_us":repeated.usec,"retained_bytes":repeated.bytes,"parts":repeated.parts,"hull_points":repeated.outline.size()})
	Contact.trim_cache()

func fitted() -> void:
	# A fitted part and articulated wheel retain their own nodes and transforms;
	# only their immutable meshes are shared by the outline cache.
	var car: Node3D = fixture()
	var fitted_part := MeshInstance3D.new(); car.add_child(fitted_part)
	fitted_part.mesh = mesh(PackedVector3Array([Vector3(-2,1,1),Vector3(2,1,1),Vector3(0,1,3)]))
	var observer := Contact.new(); observer.configure(car,true)
	var neutral: PackedVector2Array = observer.outline
	car.get_child(0).rotation.y = 0.7; fitted_part.rotation.y = -0.3
	observer.configure(car,true)
	check(observer.outline==oracle(car) and observer.outline!=neutral,"fitted and moving nodes use current transforms")
	car.get_child(0).rotation.y = 0; fitted_part.rotation.y = 0
	var reads: int = Contact.surface_reads
	observer.configure(car,true)
	check(observer.outline==neutral and Contact.surface_reads==reads,"returning to exact original pose reuses original hull")
	car.free(); Contact.trim_cache()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline="):
			var previous := GDScript.new()
			previous.source_code = FileAccess.get_file_as_string(argument.trim_prefix("--baseline=")).replace("\r\n","\n").replace("class_name VisibleContactAudio\n","")
			check(previous.reload()==OK,"original source fixture loads independently")
			baseline_script = previous
	controls()
	oversized()
	fitted()
	await assets()
	print("CONTACT_CACHE_SAMPLES ",JSON.stringify(samples))
	print("CONTACT_OUTLINE_RETENTION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
