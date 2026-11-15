extends SceneTree
const WORLDS = preload("res://track/prepared_world_cache.gd")
const DISK = preload("res://track/prepared_world_disk_cache.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var mode: String = "write"
var themes: Array[String] = ["pine","desert","winter","storm"]
var star: bool = false
class FrozenOwner extends Node3D:
	var preparation_complete: bool = true

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ",label)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
		if argument.begins_with("--theme="): themes.assign([argument.trim_prefix("--theme=")])
		if argument == "--star": star = true; themes.assign(["pine"])
		if argument == "--qualify-unsupported": DISK.allow_unqualified_renderer = true
		if argument == "--qualify-night": DISK.allow_unqualified_theme = true
	if not DISK._enabled() and DisplayServer.get_name() != "headless":
		await unsupported_renderer()
		print("PREPARED_WORLD_DISK: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0); return
	DISK.directory = "user://world-disk-test/"+("star" if star else "all")
	if DisplayServer.get_name() == "headless":
		DISK.allow_headless = true
		# Dummy rendering cannot preserve Texture3D's native image payload. All
		# five real biomes, including Night volumes, are qualified natively.
		if themes.size() > 1: themes.assign(["pine"])
	NativeTrackVisual.ROAD_DISK_CACHE.directory = "user://world-disk-test/roads"
	var identity_started: int = Time.get_ticks_usec()
	DISK.source_key = DISK.source_identity()
	print("WORLD_SOURCE_MS ",(Time.get_ticks_usec()-identity_started)/1000.0)
	for theme: String in themes:
		await exercise(theme)
	if not DISK.allow_unqualified_theme and mode != "baseline": await unsupported_renderer("night_city")
	await retention_controls()
	WORLDS.trim_cache()
	for frame: int in range(3): await process_frame
	var output: String = OS.get_environment("BMT_LOADING_FIX_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("world-disk.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"mode":mode,"checks":checks,"failures":failures,"source":DISK.source_key,"rows":rows},"\t")); file.close()
	print("PREPARED_WORLD_DISK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func exercise(theme: String) -> void:
	if theme == "night_city" and not DISK.allow_unqualified_theme:
		await unsupported_renderer(theme); return
	WORLDS.trim_cache()
	var document: Dictionary = TrackDocument.create_default()
	if star:
		document = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
		if document.has("document"): document = document.document
	document.theme = theme
	for kind: String in ["tyre_stack","cone","barrel","flowers"]:
		document.objects.append({"kind":kind,"position":[18.0+document.objects.size()*3,18.0],"rotation":30.0})
	if theme == "night_city":
		document.objects.append({"kind":"light","position":[25.0,20.0],"rotation":0.0})
		document.objects.append({"kind":"burning_barrel","position":[24.0,25.0],"rotation":0.0})
	var track: NativeTrack = TrackCompiler.compile(document)
	check(track != null,theme+" fixture compiles")
	if track == null: return
	var bridge := BridgePresentation.new(track)
	var visual := NativeTrackVisual.new()
	visual.cache_race_world = true; visual.profile_build = true; visual.preserve_relief_surfaces = true
	if mode == "baseline": visual.persist_race_world = false
	root.add_child(visual)
	var began: int = Time.get_ticks_usec()
	await visual.build(track,bridge,true)
	var wall: float = (Time.get_ticks_usec()-began)/1000.0
	var io_began: int = Time.get_ticks_usec()
	while not DISK.pending_writes.is_empty() and Time.get_ticks_usec()-io_began < 10000000: await process_frame
	check(DISK.pending_writes.is_empty(),theme+" optional file verification settles without blocking construction")
	var io_wait: float = (Time.get_ticks_usec()-io_began)/1000.0
	check(visual.world_built,theme+" world completes")
	if mode == "baseline":
		check(visual._world_disk_id.is_empty() and DISK.pending_writes.is_empty(),theme+" baseline performs no persistent world work")
		rows.append({"theme":theme,"mode":mode,"star":star,"wall_ms":wall,"costs":visual.build_costs.duplicate()})
		print("WORLD_DISK_ROW ",JSON.stringify(rows[-1])); visual.free(); await process_frame; return
	check(not WORLDS.entries.is_empty(),theme+" world admitted within RAM allowance")
	if WORLDS.entries.is_empty(): visual.free(); return
	var entry: Dictionary = WORLDS.entries[-1]
	var original_scene: PackedScene = entry.scene
	var id: String = visual._world_disk_id
	var holder: Node3D = entry.scene.instantiate()
	var original: Variant = node_signature(holder)
	holder.free()
	var signature: String = hash_value(original)
	var baseline_path: String = DISK.directory.path_join(theme+"-expected.txt")
	var expectation: Dictionary = DISK._manifest(id)
	if mode == "write":
		check(visual.build_costs.get("world_disk_written",false),theme+" first build writes complete artifact")
		if not visual.build_costs.get("world_disk_written",false):
			var state: SceneState = entry.scene.get_state()
			for index: int in range(state.get_node_count()):
				print("WORLD_NODE ",index," ",state.get_node_type(index)," parent=",state.get_node_path(index,true)," instance=",state.get_node_instance(index))
				for property: int in range(state.get_node_property_count(index)):
					if state.get_node_property_name(index,property) == &"script": print("WORLD_SCRIPT ",state.get_node_property_value(index,property))
		var file := FileAccess.open(baseline_path,FileAccess.WRITE); file.store_string(signature); file.close()
	else:
		check(visual.build_costs.get("world_disk_hit",false),theme+" fresh process restores disk artifact")
		check(FileAccess.get_file_as_string(baseline_path) == signature,theme+" fresh process scene has exact encoded geometry/materials/transforms/groups")
	check(not expectation.is_empty(),theme+" committed manifest exists")
	rows.append({"theme":theme,"mode":mode,"star":star,"wall_ms":wall,"optional_io_wait_ms":io_wait,"costs":visual.build_costs.duplicate(),"nodes":holder_count(entry.scene),"estimated_bytes":entry.bytes,"file_bytes":expectation.get("bytes",0),"signature":signature})
	print("WORLD_DISK_ROW ",JSON.stringify(rows[-1]))
	# Re-admission exercises serialized resources even in the writing process.
	visual.free(); await process_frame; WORLDS.trim_cache()
	var restored: Node3D = preload("res://track/prepared_race_world.gd").new(); restored.cache_race_world = true; restored.profile_build = true; restored.preserve_relief_surfaces = true
	root.add_child(restored)
	began = Time.get_ticks_usec(); await restored.restore(track,bridge,true)
	check(restored.world_built and restored.build_costs.get("world_disk_hit",false),theme+" serialized world installs")
	holder = WORLDS.entries[-1].scene.instantiate()
	var serialized: Variant = node_signature(holder); holder.free()
	if hash_value(serialized) != signature:
		printerr("WORLD_DIFF ",theme," ",first_difference(original,serialized,"world"))
	check(hash_value(serialized) == signature,theme+" serialized snapshot matches exact fresh scene")
	if DisplayServer.get_name() != "headless": await compare_views(original_scene,WORLDS.entries[-1].scene,theme)
	var again: Node3D = preload("res://track/prepared_race_world.gd").new(); again.cache_race_world = true; again.preserve_relief_surfaces = true
	root.add_child(again); await again.restore(track,bridge,true)
	var first_multi: Array[Node] = restored.find_children("*","MultiMeshInstance3D",true,false)
	var second_multi: Array[Node] = again.find_children("*","MultiMeshInstance3D",true,false)
	check(first_multi.size() == second_multi.size(),theme+" all mutable instance groups restored")
	for index: int in range(first_multi.size()):
		check(first_multi[index].multimesh != second_multi[index].multimesh,theme+" mutable instance buffer independently owned")
		check(first_multi[index].multimesh.mesh == second_multi[index].multimesh.mesh,theme+" immutable mesh shared within process")
	check(WORLDS.entries.size() <= WORLDS.MAX_ENTRIES and WORLDS.bytes_used() <= WORLDS.MAX_BYTES,theme+" RAM budgets unchanged")
	if theme == "night_city":
		var first_clock: Node = restored.get_node_or_null("NightPropEffects")
		var second_clock: Node = again.get_node_or_null("NightPropEffects")
		check(first_clock != null and second_clock != null,"Night clocks reconstructed")
		if first_clock != null and second_clock != null:
			first_clock.externally_ticked = true; second_clock.externally_ticked = true
			var other_elapsed: float = second_clock.elapsed
			first_clock.advance(0.1,false)
			check(second_clock.elapsed == other_elapsed,"Night clocks independently advance")
			for index: int in range(first_clock.surfaces.size()): check(first_clock.surfaces[index] != second_clock.surfaces[index],"Night clock materials are independently owned")
	if theme == "winter": winter_leases(restored,again)
	var before_writes: int = DISK.writes
	check(not DISK.write_entry(id,WORLDS.entries[-1],func() -> bool: return true) and DISK.writes == before_writes,theme+" existing artifact is not rewritten")
	if theme == themes[-1]:
		controls(id,WORLDS.entries[-1])
		await asynchronous_guards(WORLDS.entries[-1])
		await option_guard(track,bridge)
	if is_instance_valid(restored): restored.free()
	again.free(); await process_frame

func controls(id: String, entry: Dictionary) -> void:
	check(DISK.read_entry("0".repeat(64)).is_empty(),"unknown/stale identity misses")
	var previous_source: String = DISK.source_key
	var options: Array = [true,false,true,false,VisualGeometry.optimize_model_geometry]
	check(DISK.identity(entry.key,options) == id,"same actual key and options reproduce artifact identity")
	DISK.source_key = "f".repeat(64)
	check(DISK.identity(entry.key,options) != id,"changed source invalidates artifact identity")
	DISK.source_key = previous_source
	var changed_key: Array = entry.key.duplicate(true); changed_key[0] = str(changed_key[0])+"changed"
	check(DISK.identity(changed_key,options) != id,"changed track content invalidates artifact identity")
	check(DISK.identity(entry.key,[false,false,true,false]) != id,"changed geometry detail invalidates artifact identity")
	check(not DISK.write_entry("1".repeat(64),entry,func() -> bool: return false),"cancelled construction cannot publish")
	var manifest: Dictionary = DISK._manifest(id)
	if manifest.is_empty(): return
	var path: String = DISK.directory.path_join(manifest.file)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_buffer(original.slice(0,32)); file.close()
	check(DISK.read_entry(id).is_empty(),"truncated payload rejected before ResourceLoader")
	file = FileAccess.open(path,FileAccess.WRITE); file.store_buffer(original); file.close()
	check(not DISK.read_entry(id).is_empty(),"restored exact payload accepted")
	file = FileAccess.open(path,FileAccess.WRITE); file.store_buffer(original.slice(0,32)); file.close()
	check(DISK.read_entry(id).is_empty(),"repeat corrupt payload misses")
	check(DISK.write_entry(id,entry,func() -> bool: return true),"fresh construction repairs rejected payload despite old manifest")
	check(not DISK.read_entry(id).is_empty(),"repaired artifact can be reused immediately and next process")
	manifest = DISK._manifest(id)
	for dependency: String in ResourceLoader.get_dependencies(DISK.directory.path_join(manifest.file)):
		check(not "user://" in dependency,"repaired artifact cannot depend on older disposable payloads")
	var manifest_path: String = DISK.directory.path_join(id+".json")
	var manifest_bytes: PackedByteArray = FileAccess.get_file_as_bytes(manifest_path)
	manifest.file = "../escape.res"
	file = FileAccess.open(manifest_path,FileAccess.WRITE); file.store_string(JSON.stringify(manifest)); file.close()
	check(DISK.read_entry(id).is_empty(),"manifest cannot name arbitrary paths")
	file = FileAccess.open(manifest_path,FileAccess.WRITE); file.store_buffer(manifest_bytes); file.close()
	var calls: Array[int] = [0]
	var cancel_after_save: Callable = func() -> bool: calls[0] += 1; return calls[0] == 1
	check(not DISK.write_entry("2".repeat(64),entry,cancel_after_save),"cancellation after serialization rejects publication")
	check(DISK._manifest("2".repeat(64)).is_empty(),"cancelled serialization has no manifest")

func retention_controls() -> void:
	var original_directory: String = DISK.directory
	DISK.directory = original_directory.path_join("retention")
	DirAccess.make_dir_recursive_absolute(DISK.directory)
	var data: PackedByteArray = "local-test".to_utf8_buffer()
	var digest: String = DISK._digest(data)
	for index: int in range(7):
		var id: String = str(index).repeat(64)
		var name: String = id+"-"+digest+"-2147483647.res"
		var file := FileAccess.open(DISK.directory.path_join(name),FileAccess.WRITE); file.store_buffer(data); file.close()
		file = FileAccess.open(DISK.directory.path_join(id+".json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"format":DISK.FORMAT,"id":id,"file":name,"sha256":digest,"bytes":data.size()})); file.close()
	var abandoned: String = "a".repeat(64)+".pending-2147483647-1.res"
	check(not OS.is_process_running(2147483647),"abandoned fixture PID is not live")
	var live: String = "b".repeat(64)+".pending-"+str(OS.get_process_id())+"-1.res"
	for name: String in [abandoned,live,"unrelated.keep"]:
		var file := FileAccess.open(DISK.directory.path_join(name),FileAccess.WRITE); file.store_buffer(data); file.close()
	DISK._prune("6".repeat(64))
	var count: int = 0
	for name: String in DirAccess.get_files_at(DISK.directory):
		if name.ends_with(".json"): count += 1
	check(count == DISK.MAX_FILES and not DISK._manifest("6".repeat(64)).is_empty(),"disk entry count is bounded and preserves newest publication")
	check(not FileAccess.file_exists(DISK.directory.path_join(abandoned)),"interrupted dead-process payload is removed")
	check(FileAccess.file_exists(DISK.directory.path_join(live)),"live process pending write is preserved")
	check(FileAccess.file_exists(DISK.directory.path_join("unrelated.keep")),"cleanup owns only cache artifacts")
	DirAccess.remove_absolute(DISK.directory.path_join(live))
	var lock: String = DISK._acquire_lock()
	check(not lock.is_empty(),"publication lock acquired without waiting")
	check(DISK._acquire_lock().is_empty(),"second live publisher cannot enter locked publication")
	DISK._release_lock("wrong-token")
	check(DISK._acquire_lock().is_empty(),"wrong token cannot release live lock")
	DISK._release_lock(lock)
	var lock_path: String = DISK.directory.path_join(".publication-lock")
	DirAccess.make_dir_absolute(lock_path)
	var stale := FileAccess.open(lock_path.path_join("owner-2147483647-1"),FileAccess.WRITE); stale.store_string("2147483647-1"); stale.close()
	lock = DISK._acquire_lock()
	check(not lock.is_empty(),"dead immutable owner token recovers without stealing live lock")
	DISK._release_lock(lock)
	DirAccess.make_dir_absolute(lock_path)
	lock = DISK._acquire_lock()
	if lock.is_empty():
		print("WORLD_LOCK_RETRY ownerless recovery returned an optional filesystem miss")
		check(not DirAccess.dir_exists_absolute(lock_path) or DirAccess.get_files_at(lock_path).is_empty(),"optional recovery miss leaves no foreign or live owner")
		var own_prefix: String = ".publication-lock.pending-"+str(OS.get_process_id())+"-"
		check(not Array(DirAccess.get_directories_at(DISK.directory)).any(func(name: String) -> bool: return name.begins_with(own_prefix)),"optional recovery miss cleans its own unpublished candidate")
		for attempt: int in range(10):
			await process_frame
			lock = DISK._acquire_lock()
			if not lock.is_empty(): break
	check(not lock.is_empty(),"interrupted ownerless fixed lock recovers through populated-directory publication")
	check(not lock.is_empty() and DirAccess.get_files_at(lock_path).size() == 1,"published lock always contains its immutable owner marker")
	DISK._release_lock(lock)
	var orphan: String = "a".repeat(64)+"-"+digest+"-"+str(OS.get_process_id())+".res"
	var orphan_file := FileAccess.open(DISK.directory.path_join(orphan),FileAccess.WRITE); orphan_file.store_buffer(data); orphan_file.close()
	DISK._prune("6".repeat(64))
	check(not FileAccess.file_exists(DISK.directory.path_join(orphan)),"locked pruning removes unreferenced finalized payload even from a live PID")
	check(DISK._owned_bytes() <= DISK.MAX_TOTAL_BYTES,"physical owned payloads remain bounded")
	DISK.directory = original_directory

func option_guard(track: NativeTrack, bridge: BridgePresentation) -> void:
	var visual := NativeTrackVisual.new(); visual.cache_race_world = true; visual.persist_race_world = false; visual.profile_build = true
	visual.preserve_relief_surfaces = true; visual.scenery_lods = false
	root.add_child(visual)
	await visual.build(track,bridge,true)
	check(visual.world_built and visual.get_meta("prepared_world_key")[7][0] == false,"actual live RAM restore respects changed scenery options")
	check(not visual.build_costs.has("cache_instantiate_us"),"changed scenery options build their own geometry rather than reusing another snapshot")
	check(visual._world_disk_id.is_empty(),"explicit no-persistence fixture stays disk-free")
	visual.free(); await process_frame

func asynchronous_guards(entry: Dictionary) -> void:
	var owner := FrozenOwner.new(); owner.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(owner)
	var visual := NativeTrackVisual.new(); owner.add_child(visual); visual.world_built = true
	var allowed: Array[bool] = [true]; visual.build_current = func() -> bool: return allowed[0]
	var id: String = "3".repeat(64)
	check(DISK.queue_entry(id,entry,visual,WORLDS.generation),"optional IO queues from a complete immutable snapshot")
	check(pure_values(DISK.pending_writes[-1].receipt),"worker receipt owns no Nodes, meshes, materials or scenes")
	allowed[0] = false
	while not DISK.pending_writes.is_empty(): await process_frame
	check(DISK._manifest(id).is_empty(),"cancelled frozen Game cannot publish merely because preparation_complete is true")
	allowed[0] = true; id = "4".repeat(64)
	check(DISK.queue_entry(id,entry,visual,WORLDS.generation),"second optional write queues before pressure")
	WORLDS.trim_cache()
	while not DISK.pending_writes.is_empty(): await process_frame
	check(DISK._manifest(id).is_empty(),"memory generation change cancels pending publication")
	WORLDS.entries.append(entry)
	id = "5".repeat(64)
	check(DISK.queue_entry(id,entry,visual,WORLDS.generation),"third optional write queues before teardown")
	owner.free()
	while not DISK.pending_writes.is_empty(): await process_frame
	check(DISK._manifest(id).is_empty(),"freed owner cannot publish or be retained by IO")
	check(not Array(DirAccess.get_files_at(DISK.directory)).any(func(name: String) -> bool: return name.contains(".pending-")),"cancelled optional jobs remove all owned temporary payloads")

func pure_values(value: Variant) -> bool:
	if value is Object: return false
	if value is Array:
		for child: Variant in value:
			if not pure_values(child): return false
	if value is Dictionary:
		for child: Variant in value.values():
			if not pure_values(child): return false
	return true

func unsupported_renderer(theme: String = "pine") -> void:
	var before_writes: int = DISK.writes; var before_hits: int = DISK.hits
	var previous_source: String = DISK.source_key; DISK.source_key = ""
	var document: Dictionary = TrackDocument.create_default()
	document.theme = theme
	var track: NativeTrack = TrackCompiler.compile(document)
	var bridge := BridgePresentation.new(track)
	var visual := NativeTrackVisual.new(); visual.cache_race_world = true; visual.profile_build = true; visual.preserve_relief_surfaces = true
	root.add_child(visual); await visual.build(track,bridge,true)
	check(visual.world_built and visual._world_disk_id.is_empty(),"unqualified path keeps original world construction")
	check(DISK.writes == before_writes and DISK.hits == before_hits and DISK.pending_writes.is_empty(),"unqualified path performs no persistent world IO")
	check(DISK.source_key.is_empty(),"unqualified path skips first source fingerprint")
	var source: PackedScene = WORLDS.entries[-1].scene
	var again: Node3D = preload("res://track/prepared_race_world.gd").new(); again.cache_race_world = true; again.preserve_relief_surfaces = true; root.add_child(again)
	await again.restore(track,bridge,true)
	check(again.world_built and WORLDS.entries[-1].scene == source,"unqualified path retains existing RAM reuse")
	if DisplayServer.get_name() != "headless": await compare_views(source,WORLDS.entries[-1].scene,"unsupported-"+theme)
	visual.free(); again.free(); WORLDS.trim_cache(); await process_frame
	DISK.source_key = previous_source

func holder_count(scene: PackedScene) -> int: return scene.get_state().get_node_count()

func winter_leases(first: Node3D, second: Node3D) -> void:
	var material: ShaderMaterial
	for node: Node in first.find_children("*","MeshInstance3D",true,false):
		if node.material_override is ShaderMaterial and node.material_override.shader.code.contains("wind_surface_strength"):
			material = node.material_override; break
	check(material != null,"Winter wind surface survives serialization")
	if material == null: return
	var a: Dictionary = WORLDS.acquire_surface(first,material,first)
	var b: Dictionary = WORLDS.acquire_surface(second,material,second)
	check(a.material != b.material,"two live Winter owners cannot share mutable wind")
	a.material.set_shader_parameter("wind_surface_strength",0.73)
	check(b.material.get_shader_parameter("wind_surface_strength") != 0.73,"Winter wind does not cross owners")
	WORLDS.release_surface(a,first); WORLDS.release_surface(b,second)
	check(a.material.get_shader_parameter("wind_surface_strength") == 0.0,"released Winter lease resets transient strength")

func compare_views(before: PackedScene, after: PackedScene, theme: String) -> void:
	var views: Array[SubViewport] = []
	for scene: PackedScene in [before,before,after]:
		var view := SubViewport.new(); view.size = Vector2i(640,480); view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var holder: Node3D = scene.instantiate(); holder.process_mode = Node.PROCESS_MODE_DISABLED; view.add_child(holder)
		var environment := WorldEnvironment.new(); environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color("425248")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color = Color.WHITE; environment.environment.ambient_light_energy = 0.6
		view.add_child(environment)
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-58,-35,0); light.shadow_enabled = true; view.add_child(light)
		var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 160.0; camera.far = 1000
		view.add_child(camera); camera.position = Vector3(0,140,105); camera.look_at(Vector3.ZERO); camera.current = true
		views.append(view)
	for frame: int in range(4): await process_frame; await RenderingServer.frame_post_draw
	var images: Array[Image] = [views[0].get_texture().get_image(),views[1].get_texture().get_image(),views[2].get_texture().get_image()]
	print("WORLD_PIXELS ",theme," control=",pixel_differences(images[0],images[1])," serialized=",pixel_differences(images[0],images[2]))
	check(images[0].get_data() == images[1].get_data(),theme+" independent native views of original scene are pixel-exact")
	check(images[0].get_data() == images[2].get_data(),theme+" serialized scene renders pixel-exact in simultaneous native views")
	var output: String = OS.get_environment("BMT_LOADING_FIX_OUTPUT")
	if not output.is_empty():
		images[0].save_png(output.path_join(theme+"-fresh.png")); images[1].save_png(output.path_join(theme+"-control.png")); images[2].save_png(output.path_join(theme+"-disk.png"))
	for view: SubViewport in views: view.free()
	await process_frame

func pixel_differences(a: Image, b: Image) -> Dictionary:
	var first: PackedByteArray = a.get_data(); var second: PackedByteArray = b.get_data()
	var pixels: int = 0; var maximum: int = 0; var total: int = 0
	var channels: int = first.size()/(a.get_width()*a.get_height())
	for offset: int in range(0,first.size(),channels):
		var changed: bool = false
		for channel: int in range(channels):
			var delta: int = absi(int(first[offset+channel])-int(second[offset+channel]))
			changed = changed or delta > 0; maximum = maxi(maximum,delta); total += delta
		if changed: pixels += 1
	return {"pixels":pixels,"maximum":maximum,"mean":float(total)/first.size()}
func hash_value(value: Variant) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(var_to_bytes(value)); return hash.finish().hex_encode()

func node_signature(node: Node) -> Array:
	var groups: Array[StringName] = node.get_groups(); groups.sort()
	var data: Array = [node.get_class(),groups]
	if node is Node3D: data.append(node.transform)
	if node is GeometryInstance3D: data.append([node.layers,node.cast_shadow,node.visibility_range_begin,node.visibility_range_end,normalise(node.material_override)])
	if node is MeshInstance3D:
		data.append(normalise(node.mesh))
		for surface: int in range(node.get_surface_override_material_count()): data.append(normalise(node.get_surface_override_material(surface)))
	if node is MultiMeshInstance3D: data.append([normalise(node.multimesh.mesh),node.multimesh.instance_count,node.multimesh.visible_instance_count,node.multimesh.buffer,node.multimesh.custom_aabb])
	if node is OmniLight3D: data.append([node.light_color,node.light_energy,node.omni_range,node.light_cull_mask,node.visible])
	if node.get_script() != null:
		data.append(node.get_script().resource_path)
		for property: Dictionary in node.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage)&PROPERTY_USAGE_STORAGE: data.append([property.name,normalise(node.get(property.name))])
	for child: Node in node.get_children(): data.append(node_signature(child))
	return data

func normalise(value: Variant) -> Variant:
	if value is Shader: return ["shader",value.code]
	if value is GDScript: return ["script",value.resource_path]
	if value is TextureLayered:
		var images: Array = []
		if DisplayServer.get_name() != "headless":
			for layer: int in range(value.get_layers()):
				var image: Image = value.get_layer_data(layer)
				images.append([image.get_width(),image.get_height(),image.get_format(),image.get_data()])
		return [value.get_class(),value.get_width(),value.get_height(),value.get_layers(),value.get_format(),images]
	if value is Texture2D:
		if value.resource_path.begins_with("res://") and not "::" in value.resource_path: return ["texture",value.resource_path]
		var image: Image = value.get_image()
		return ["image",image.get_width(),image.get_height(),image.get_format(),image.get_data()]
	if value is Resource:
		var data: Array = [value.get_class()]
		for property: Dictionary in value.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and property.name not in ["resource_name","resource_path","resource_local_to_scene","script"]: data.append([property.name,normalise(value.get(property.name))])
		return data
	if value is Array:
		var data: Array = []
		for element: Variant in value: data.append(normalise(element))
		return data
	if value is Dictionary:
		var data: Array = []
		var keys: Array = value.keys(); keys.sort_custom(func(a: Variant,b: Variant) -> bool: return str(a)<str(b))
		for key: Variant in keys: data.append([key,normalise(value[key])])
		return data
	return value

func first_difference(a: Variant,b: Variant,path: String) -> String:
	if a is Array and b is Array:
		if a.size()!=b.size(): return path+" size "+str(a.size())+"/"+str(b.size())
		for index: int in range(a.size()):
			if a[index]!=b[index]: return first_difference(a[index],b[index],path+"/"+str(index))
	return path+" "+str(a).left(250)+" -> "+str(b).left(250)
