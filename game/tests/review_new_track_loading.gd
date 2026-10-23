extends SceneTree
## NTL01-NTL03: attribute new-track work without changing the shipping loader.
## Disposable local artifacts only; no network, player records or device access.
const ROADS = preload("res://editor/road_preparation.gd")
const WORLDS = preload("res://track/prepared_world_cache.gd")
var folder: String
var visual_script: GDScript
var checks: int = 0
var failures: int = 0
var report: Dictionary = {"samples":[]}

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func instrument() -> void:
	var source: String = FileAccess.get_file_as_string("res://track/native_track_visual.gd").replace("\r\n","\n")
	var begin: int = source.find("func build(")
	var end: int = source.find("\nfunc ",begin+1)
	var body: String = source.substr(begin,end-begin)
	body = body.replace("\tground_support = bridge.road_surface","\tstarted = Time.get_ticks_usec()\n\tground_support = bridge.road_surface")
	for stage: Array in [
		["\tawait _build_terrain(track)","terrain"],
		["\tawait _build_creator_roads(track)","road_install_or_disk"],
		["\tawait _build_barriers(track)","barriers"],
		["\t\tawait _build_low_cover(track)","cover"],
		["\t\tawait _build_placed_objects(track)","objects"],
		["\tbridge.build(self)","bridges"],
		["\t_build_finish(track)","finish"],
		["\t_build_snow_banks(track)","snow"],
		["\tif desert_relief != null: await desert_relief.apply(self,_menu_slices)","desert_deformation"],
		["\t_partition_bank_meshes()","partition"]]:
		assert(body.count(stage[0]) == 1,"Attribution marker changed: "+stage[1])
		var indent: String = "\t\t" if stage[1] in ["cover","objects"] else "\t"
		body = body.replace(stage[0],stage[0]+"\n"+indent+"mark(\""+stage[1]+"\")")
	visual_script = GDScript.new()
	visual_script.source_code = "extends NativeTrackVisual\nvar started: int = 0\nvar marks: Dictionary = {}\nfunc mark(label: String) -> void:\n\tmarks[label] = Time.get_ticks_usec()-started\n"+body
	assert(visual_script.reload() == OK)

func clear_idle() -> void:
	NativeTrackVisual._road_mesh_cache.clear()
	WORLDS.entries.clear()
	ROADS.entries.clear()
	ROADS.bytes = 0
	ROADS.account_gpu([])

func signature(root_node: Node) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	append_signature(root_node,hash)
	return hash.finish().hex_encode()

func append_signature(node: Node, hash: HashingContext) -> void:
	# Resource instance IDs and diagnostic timing fields are intentionally absent.
	var state: Array = [node.get_class(),node.get_groups()]
	if node is Node3D: state.append(node.transform)
	if node is GeometryInstance3D: state.append([node.layers,node.cast_shadow])
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		for surface: int in range(node.mesh.get_surface_count()):
			hash.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
	if node is MultiMeshInstance3D and node.multimesh != null:
		state.append([node.multimesh.instance_count,node.multimesh.visible_instance_count,node.multimesh.buffer])
	hash.update(var_to_bytes(state))
	for child: Node in node.get_children(): append_signature(child,hash)

func bake_world(visual: NativeTrackVisual, theme: String, track: NativeTrack) -> Dictionary:
	# Local-only proof of the work that a finished-geometry pack can avoid.
	# This engine scene is NOT a proposed format for downloaded content.
	var began: int = Time.get_ticks_usec()
	var holder := Node3D.new()
	var seen: Dictionary = {}
	var bytes: int = track.cells.size()*(20 if theme == "desert" else 16)
	for child: Node in visual.get_children():
		bytes += WORLDS._resource_bytes(child,seen)
		var copy: Node = child.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
		holder.add_child(copy)
		WORLDS._own(copy,holder)
		WORLDS._isolate_instances(copy)
	check(signature(holder) == signature(visual),theme+" local baked holder preserves geometry")
	var packed := PackedScene.new()
	check(packed.pack(holder) == OK,theme+" finished world packs locally")
	var path: String = folder.path_join(theme+".world.scn")
	check(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS) == OK,theme+" finished world saves locally")
	holder.free()
	var file := FileAccess.open(path,FileAccess.READ)
	var result: Dictionary = {"prepare_and_write_ms":(Time.get_ticks_usec()-began)/1000.0,"file_bytes":file.get_length() if file != null else 0,"resident_estimate_bytes":bytes,"fits_existing_world_lru":bytes <= WORLDS.MAX_BYTES}
	if file != null: file.close()
	return result

func read_world_packs(expected: Dictionary) -> void:
	for theme: String in ["pine","desert","winter"]:
		var began: int = Time.get_ticks_usec()
		var packed: PackedScene = ResourceLoader.load(folder.path_join(theme+".world.scn"),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		var read_ms: float = (Time.get_ticks_usec()-began)/1000.0
		check(packed != null,theme+" finished local pack loads")
		if packed == null: continue
		began = Time.get_ticks_usec()
		var holder: Node = packed.instantiate()
		root.add_child(holder)
		var instantiate_ms: float = (Time.get_ticks_usec()-began)/1000.0
		check(signature(holder) == expected.get(theme,""),theme+" fresh-process finished pack preserves world geometry")
		var row: Dictionary = {"theme":theme,"read_ms":read_ms,"instantiate_ms":instantiate_ms}
		report.samples.append(row)
		print("FINISHED_WORLD_PACK ",JSON.stringify(row))
		holder.free()

func run() -> void:
	var cached_only: bool = "--cached-only" in OS.get_cmdline_user_args() or "--cached-bake" in OS.get_cmdline_user_args()
	folder = ProjectSettings.globalize_path("res://../build/new-track-loading-review")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): folder = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
	DirAccess.make_dir_recursive_absolute(folder)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = folder.path_join("roads")
	instrument()
	report.engine = Engine.get_version_info().string
	report.visual_version = NativeTrackVisual.VERSION
	report.renderer = RenderingServer.get_current_rendering_method()
	report.headless = DisplayServer.get_name() == "headless"
	report.cached_only = cached_only
	var expected: Dictionary = {}
	var pack_only: bool = "--pack-only" in OS.get_cmdline_user_args()
	if cached_only or pack_only: expected = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("expected.json")))
	if pack_only:
		read_world_packs(expected)
		report.checks = checks; report.failures = failures
		var pack_report := FileAccess.open(folder.path_join("finished-packs.json"),FileAccess.WRITE)
		pack_report.store_string(JSON.stringify(report,"\t")); pack_report.close()
		print("FINISHED_WORLD_PACK_REVIEW: ",checks," checks, ",failures," failures")
		quit(1 if failures else 0)
		return
	for theme: String in ["pine","desert","winter"]:
		clear_idle()
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
		document.theme = theme
		var began: int = Time.get_ticks_usec()
		var track: NativeTrack = TrackCompiler.compile(document)
		var compile_ms: float = (Time.get_ticks_usec()-began)/1000.0
		check(track != null,theme+" fixture compiles")
		if track == null: continue
		var packet: Dictionary = {}
		var road_cpu_ms: float = 0.0
		if not cached_only:
			began = Time.get_ticks_usec()
			# Same job and packet consumed by App._start_race, with loading frames.
			var job: RefCounted = preload("res://editor/road_preparation_job.gd").start(track,self)
			while not job.done: await process_frame
			road_cpu_ms = (Time.get_ticks_usec()-began)/1000.0
			packet = job.result if job.result is Dictionary else {}
			check(not packet.get("parts",[]).is_empty(),theme+" cold CPU job produced geometry")
		else:
			check(not NativeTrackVisual.race_roads_need_preparation(track),theme+" saved roads bypass CPU preparation")
		began = Time.get_ticks_usec()
		var bridge := BridgePresentation.new(track)
		var support_ms: float = (Time.get_ticks_usec()-began)/1000.0
		var visual: NativeTrackVisual = visual_script.new()
		visual.race_road_packet = packet
		root.add_child(visual)
		began = Time.get_ticks_usec()
		await visual.build(track,bridge)
		var world_ms: float = (Time.get_ticks_usec()-began)/1000.0
		check(visual.world_built,theme+" world completed")
		var stages: Dictionary = {}
		var previous: int = 0
		for label: String in visual.get("marks"):
			var time: int = visual.get("marks")[label]
			stages[label] = (time-previous)/1000.0
			previous = time
		var digest: String = signature(visual)
		if cached_only: check(digest == expected.get(theme,""),theme+" fresh-process saved roads preserve complete world geometry")
		else: expected[theme] = digest
		var key: Array = [track.content_hash,NativeTrackVisual.VERSION,theme,TrackTheme.palette(theme),true]
		var path: String = NativeTrackVisual.ROAD_DISK_CACHE.directory.path_join(NativeTrackVisual.ROAD_DISK_CACHE.identity(key)+".res")
		var artifact := FileAccess.open(path,FileAccess.READ)
		check(artifact != null,theme+" local artifact saved")
		var artifact_bytes: int = artifact.get_length() if artifact != null else 0
		if artifact != null: artifact.close()
		var row: Dictionary = {"theme":theme,"compile_ms":compile_ms,"road_cpu_ms":road_cpu_ms,"support_ms":support_ms,"world_ms":world_ms,"stages_ms":stages,"artifact_bytes":artifact_bytes,"geometry_sha256":digest,"pieces":document.pieces.size()}
		if "--bake-world" in OS.get_cmdline_user_args() or "--cached-bake" in OS.get_cmdline_user_args(): row.finished_world_pack = bake_world(visual,theme,track)
		report.samples.append(row)
		print("NEW_TRACK_REVIEW ",JSON.stringify(row))
		visual.free()
		await process_frame
	if not cached_only:
		var file := FileAccess.open(folder.path_join("expected.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(expected,"\t")); file.close()
	report.checks = checks; report.failures = failures
	var output := FileAccess.open(folder.path_join("cached.json" if cached_only else "cold.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")); output.close()
	clear_idle()
	print("NEW_TRACK_LOADING_REVIEW: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
