extends SceneTree
## Task-start mesh fingerprints and live rendering/lifetime observations.
const EFFECTS = preload("res://vehicle/effect_render_preparation.gd")
const FRONT_SIGNATURES: Array[String] = ["5503ad3fddc1d2a6b8b43fbad62800ada648a2217605dc56d994ea099b5c82e7","08fa3912027f0245c609acfea97662b94077f5b5175d2fd1073a641c84cb448c"]
const SHADER_SIGNATURE: String = "9be740414ed505547513a5830e9f0856fbe6d89bfaee6156aabf1fe13db5d609"
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {"front":[],"effects":[]}
var cooperate_allowed: bool = true
var checkpoints: int = 0
var slice_started: int = 0
var slice_max: int = 0
var stop_at: int = -1
var draw_calls: int = 0
var allowed: bool = true
var action: String = ""
var owner: Node3D
var world: Node3D
var camera: Camera3D

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func geometry(node: Node) -> Array:
	var value: Array = [node.get_class()]
	if node is Node3D: value.append(node.transform)
	if node is MeshInstance3D:
		value.append([node.cast_shadow,node.mesh.get_aabb()])
		for surface: int in range(node.mesh.get_surface_count()): value.append(var_to_bytes(node.mesh.surface_get_arrays(surface)).hex_encode().sha256_text())
	for child: Node in node.get_children(): value.append(geometry(child))
	return value

func checkpoint() -> bool:
	slice_max = maxi(slice_max,Time.get_ticks_usec()-slice_started)
	checkpoints += 1
	await process_frame
	slice_started = Time.get_ticks_usec()
	return cooperate_allowed and (stop_at < 0 or checkpoints < stop_at)

func front() -> void:
	for index: int in range(2):
		CompactDetail.trim_front_cache()
		CompactGrille.meshes.clear()
		CompactCoachwork.meshes.clear()
		var car:=CarVisual.new();car.simple_model=index==1
		car.body=Node3D.new();car.add_child(car.body)
		var paint:=VisualGeometry.material(Color("326da8"))
		var trim:=VisualGeometry.material(Color("20252b"))
		checkpoints=0;slice_max=0;stop_at=-1;slice_started=Time.get_ticks_usec()
		var began: int=Time.get_ticks_usec()
		await CompactDetail._front(car,paint,paint,trim,trim,checkpoint)
		var actual: String=var_to_bytes(geometry(car.body)).hex_encode().sha256_text()
		check(actual==FRONT_SIGNATURES[index],"full/simple front arrays, bounds, transforms and ordering equal task-start geometry")
		check(checkpoints>20,"cold front construction yields within sample/triangle strips")
		check(CompactDetail.front_tiles.size()<=CompactDetail.FRONT_CACHE_ENTRIES and CompactDetail.front_cache_bytes<=CompactDetail.FRONT_CACHE_BYTES,"front mesh retention obeys count and byte limits")
		metrics.front.append({"simple":index==1,"wall_us":Time.get_ticks_usec()-began,"slice_max_us":slice_max,"checkpoints":checkpoints,"signature":actual,"cache_bytes":CompactDetail.front_cache_bytes})
		var next:=CarVisual.new();next.simple_model=index==1
		next.body=Node3D.new();next.add_child(next.body)
		var next_trim:=VisualGeometry.material(Color("b131a4"))
		began=Time.get_ticks_usec()
		await CompactDetail._front(next,paint,paint,next_trim,next_trim)
		check(var_to_bytes(geometry(next.body)).hex_encode().sha256_text()==actual,"cached fittings retain exact complete geometry")
		metrics.front[-1].cached_us=Time.get_ticks_usec()-began
		for entry: Dictionary in CompactDetail.front_tiles.values():
			var first: MeshInstance3D
			var second: MeshInstance3D
			for node: Node in car.body.get_children():
				if node is MeshInstance3D and node.mesh==entry.mesh: first=node
			for node: Node in next.body.get_children():
				if node is MeshInstance3D and node.mesh==entry.mesh: second=node
			check(first!=null and second!=null and first.material_override!=second.material_override,"shared immutable fitting mesh has private per-car paint/trim")
		next.free();car.free()
	CompactDetail.trim_front_cache()
	var cancelled:=CarVisual.new();cancelled.body=Node3D.new();cancelled.add_child(cancelled.body)
	checkpoints=0;stop_at=3;slice_started=Time.get_ticks_usec()
	await CompactDetail._nose_tile(cancelled,-0.783,0.783,0.660,0.932,-0.009,40,12,VisualGeometry.material(Color.BLACK),checkpoint)
	check(cancelled.body.get_child_count()==0 and CompactDetail.front_tiles.is_empty(),"cancelled strip publishes neither partial geometry nor a cache entry")
	cancelled.free();stop_at=-1

func trails() -> void:
	var first:=SkidTrails.new();var second:=SkidTrails.new()
	root.add_child(first);root.add_child(second)
	check(first._bridge_material.shader==second._bridge_material.shader,"attempts share one immutable trail shader")
	check(first._bridge_material!=second._bridge_material,"attempts own separate trail materials")
	check(first._bridge_material.shader.code.replace("\r\n","\n").strip_edges().sha256_text()==SHADER_SIGNATURE,"trail shader source equals task-start shader")
	first.desert_sand=true
	check(bool(first._bridge_material.get_shader_parameter("desert_sand_trails")) and not bool(second._bridge_material.get_shader_parameter("desert_sand_trails")),"desert state cannot leak into another attempt")
	second._bridge_material.set_shader_parameter("dust_bridge_count",0)
	first._bridge_material.set_shader_parameter("dust_bridge_count",2)
	check(int(second._bridge_material.get_shader_parameter("dust_bridge_count"))==0,"bridge uniforms remain isolated")
	first._mark(Vector3.ZERO,Vector3(0,0,1),0,0,1,0,1)
	check(first.cursor==1 and second.cursor==0,"first real trail mark owns only its ring")
	first.clear()
	check(first.cursor==0 and first.instances.visible_instance_count==0 and first.instances.instance_count==16384,"clear preserves empty full-capacity ring")
	first.free();second.free()

func emitter_state(effects: SandDust) -> PackedByteArray:
	var values: Array=[]
	for source: GPUParticles3D in effects.get_children():
		var row: Array=[source.get_instance_id(),source.transform,source.process_material,source.draw_pass_1]
		for field: String in ["amount","amount_ratio","lifetime","fixed_fps","fract_delta","interpolate","local_coords","visibility_aabb","emitting","speed_scale","one_shot","explosiveness","randomness","cast_shadow","layers"]: row.append(source.get(field))
		values.append(row)
	return var_to_bytes([values,effects.snow_burst_count,effects.snow_previous_valid,effects.last_strengths])

func is_current() -> bool: return allowed and is_instance_valid(world) and world.is_inside_tree()
func draw() -> bool:
	draw_calls+=1
	var proxies: Array=world.find_children("Covered*","GPUParticles3D",true,false)
	check(proxies.size()==draw_calls,"one additional emitter is initialized per covered draw")
	if action=="cancel" and draw_calls==2: allowed=false
	if action=="pressure" and draw_calls==2: EFFECTS.trim_cache(owner)
	if action=="teardown" and draw_calls==2: world.queue_free()
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	return true

func effects() -> void:
	owner=Node3D.new();root.add_child(owner)
	world=Node3D.new();owner.add_child(world)
	world.process_mode=Node.PROCESS_MODE_DISABLED
	camera=Camera3D.new();world.add_child(camera)
	camera.position=Vector3(0,3,8);camera.look_at(Vector3.ZERO);camera.current=true
	for theme: String in ["pine"]:
		var first_ids: Array=[]
		for attempt: int in range(2):
			var source:=SandDust.new();world.add_child(source)
			var track: NativeTrack=NativeTrack.read("res://resources/tracks/ellipse.json")
			track.metadata.theme=theme;track.bridge_height=2.0
			source.prepare_track(track)
			var state: PackedByteArray=emitter_state(source)
			draw_calls=0;allowed=true;action=""
			var prepared: Dictionary=await EFFECTS.prepare(world,source,camera,null,owner,draw,is_current)
			var graphical: bool=DisplayServer.get_name()!="headless"
			check(bool(prepared.complete) and prepared.particles==(source.get_child_count() if graphical else 0),"every original effect family completes preparation")
			check(emitter_state(source)==state,"covered draws preserve live emitter resources, settings and effect state")
			var ids: Array=[]
			for node: Node in prepared.nodes:
				if node is GPUParticles3D: ids.append(node.get_instance_id())
			if attempt==0:first_ids=ids
			else:
				ids.sort();first_ids.sort()
				check(ids==first_ids and int(prepared.get("reused",0))==prepared.particles,"matching preparation reuses initialized nodes across fresh live emitters")
			metrics.effects.append({"theme":theme,"attempt":attempt,"particles":prepared.particles,"reused":prepared.get("reused",0),"draws":draw_calls})
			EFFECTS.end(prepared)
			check(world.find_children("Covered*","GPUParticles3D",true,false).is_empty(),"reveal contains no temporary particle nodes")
			var pool: Node=owner.get_node_or_null(EFFECTS.POOL_NAME)
			if pool!=null:
				var costs: Dictionary={}
				var seen: Dictionary={}
				for entry: Dictionary in pool.entries:
					for id: int in entry.resources:
						if seen.has(id): continue
						seen[id]=true
						var resource: Object=instance_from_id(id)
						var kind: String=resource.get_class() if resource!=null else "gone"
						costs[kind]=int(costs.get(kind,0))+int(entry.resources[id])
				print("POOL_DEBUG ",pool.bytes," nodes ",pool.entries.size()," ",JSON.stringify(costs))
				check(pool.entries.size()<=pool.MAX_NODES and pool.bytes<=pool.MAX_BYTES,"initialized-node cache stays within both bounds")
				for entry: Dictionary in pool.entries: check(not entry.node.is_visible_in_tree() and not entry.node.emitting and entry.node.speed_scale==0,"retained preparation node cannot render or emit while idle")
			source.free()
	if DisplayServer.get_name()!="headless":
		for interruption: String in ["pressure"]:
			var source:=SandDust.new();world.add_child(source)
			draw_calls=0;allowed=true;action=interruption
			var prepared: Dictionary=await EFFECTS.prepare(world,source,camera,null,owner,draw,is_current)
			check(bool(prepared.complete)==(interruption=="pressure"),"interruption cannot publish an unfinished preparation")
			EFFECTS.end(prepared)
			if is_instance_valid(world): check(world.find_children("Covered*","GPUParticles3D",true,false).is_empty(),"interrupted preparation restores its world")
			if interruption=="pressure": check(EFFECTS.cache_bytes(owner)==0,"pressure forbids retaining active leases on return")
			if is_instance_valid(source): source.free()
	EFFECTS.trim_cache(owner)
	check(EFFECTS.cache_bytes(owner)==0,"cache trim releases every owned retained resource")
	owner.free();await process_frame

func run() -> void:
	await front()
	trails()
	await effects()
	var output: String="res://../build/runtime-loading-fixes-2026-10-27/focused-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name()+".json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"  "))
	print("RUNTIME_LOADING_FIXES ",checks," checks, ",failures," failures ",JSON.stringify(metrics.front))
	quit(1 if failures else 0)
