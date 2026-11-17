extends SceneTree
## Cache-free preparation costs; script loading is outside kernel timers.
var checks: int = 0
var failures: int = 0
var timings: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("KERNEL_FAIL ",label)

func instrument(path: String, methods: Array) -> GDScript:
	var script: GDScript = load(path)
	var source: String = script.source_code.replace("\r\n","\n")
	for entry: Array in methods:
		var name: String = entry[0]
		var start: int = source.find("func "+name+"(")
		check(start >= 0,"profile method exists "+path+":"+name)
		var end: int = source.find("\n",start)
		var signature: String = source.substr(start,end-start)
		var static_method: bool = start >= 7 and source.substr(start-7,7) == "static "
		source = source.substr(0,start)+source.substr(start,end-start).replace("func "+name+"(","func _profile_original_"+name+"(")+source.substr(end)
		var returns: String = signature.get_slice(" -> ",1).trim_suffix(":")
		var args: String = "session,path,gate_bins" if name == "_crossings" and signature.contains("gate_bins") else str(entry[1])
		if name == "_projection" and signature.contains("native:"): args = "track,point,bins,native"
		var call: String = ("await " if entry.size() > 2 and entry[2] else "")+"_profile_original_"+name+"("+args+")"
		var wrapper: String = "\n"+("static " if static_method else "")+signature+"\n\tvar began: int = Time.get_ticks_usec()\n"
		if returns == "void": wrapper += "\t"+call+"\n"
		else: wrapper += "\tvar result: "+returns+" = "+call+"\n"
		wrapper += '\t_profile_cost("'+path+":"+name+'",Time.get_ticks_usec()-began)\n'
		if returns != "void": wrapper += "\treturn result\n"
		source += wrapper
	source += '''
static var _profile_costs: Dictionary = {}
static func _profile_cost(key: String, elapsed: int) -> void:
	var row: Dictionary = _profile_costs.get(key,{"calls":0,"us":0})
	row.calls += 1; row.us += elapsed; _profile_costs[key] = row
'''
	script.source_code = source
	check(script.reload() == OK,"diagnostic timers reload "+path)
	return script

func run() -> void:
	var corridor: Script = instrument("res://race/spline_gate_corridor.gd",[
		["select","session,track"],["lane","track,fraction,constant_width,rejoin_start,recovery_m,basis"],
		["_crossings","session,path"],["_projection","track,point,bins"]])
	var coverage: Script = instrument("res://race/road_gate_coverage.gd",[["spans","center,direction,raster,elevated"]])
	var surface: Script = load("res://track/road_surface_height.gd")
	var roads: Script = load("res://editor/road_preparation.gd")
	var visual: Script = instrument("res://track/native_track_visual.gd",[
		["_prepare_road_piece","track,index,ctx",true],["_creator_overlay_mask","track,paint"],["_creator_road_mask","track"],
		["_asphalt_edge_faces","tool,support"],["_build_kerbs","track",true],
		["_commit_creator_road","tool,color,mask,road_mask,extent,gravel,grass,kerb,asphalt_surface,edge_fringe,road_marking,prepared_arrays,prepared_relief",true]])
	var union: Script = instrument("res://track/desert_road_union.gd",[["emit","visual,tool,height",true]])
	var shoulder: Script = instrument("res://track/shoulder_mesh.gd",[["emit","tool,yield_budget,cancelled",true]])
	var verge: Script = instrument("res://track/grass_road_verge.gd",[["emit_collected","tool,points,uvs,cancelled"]])
	var track: Resource = load("res://editor/track_compiler.gd").compile(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json")))
	check(track != null,"Star compiles")
	var disk: Script = load("res://track/road_mesh_disk_cache.gd"); disk.directory = ""
	load("res://race/checkpoint_layout_disk_cache.gd").directory = ""
	roads.trim_retained()
	load("res://race/checkpoint_layout_cache.gd").trim_to()
	load("res://track/road_support_cache.gd").trim()
	var began: int = Time.get_ticks_usec()
	var packet: Dictionary = roads.prepare(track,true)
	var road_us: int = Time.get_ticks_usec()-began
	check(not packet.get("parts",[]).is_empty(),"fresh road packet generated")
	var session: RefCounted = load("res://race/track_session.gd").new()
	track._race_gates = {}
	began = Time.get_ticks_usec()
	session._configure(track)
	var checkpoint_us: int = Time.get_ticks_usec()-began
	check(session.initialized,"fresh checkpoint layout generated")
	var parts: Dictionary = {}
	for helper: Script in [corridor,coverage,visual,union,shoulder,verge]: parts.merge(helper._profile_costs)
	var result: Dictionary = {"road_us":road_us,"checkpoint_us":checkpoint_us,"route_points":track.route.size(),
		"parts":packet.parts.size(),"gates":session.checkpoint_count(),"stages":parts,"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("KERNEL_PROFILE ",JSON.stringify(result))
	load("res://soundtrack/audio_world.gd").instance().queue_free()
	for frame: int in range(14): await process_frame
	quit(1 if failures else 0)
