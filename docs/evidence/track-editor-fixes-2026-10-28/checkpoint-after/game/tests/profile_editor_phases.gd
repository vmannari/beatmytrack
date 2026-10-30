extends "res://tests/test_editor_t01_t04.gd"
class TimedVisual extends NativeTrackVisual:
	var phases: Dictionary = {}
	func _prepare_road_piece(track: NativeTrack, index: int, ctx: Dictionary) -> Dictionary:
		var began: int = Time.get_ticks_usec(); var result: Dictionary = await super._prepare_road_piece(track,index,ctx)
		phases["piece_us"] = int(phases.get("piece_us",0))+Time.get_ticks_usec()-began
		return result
	func _build_kerbs(track: NativeTrack, arrays: Array = []) -> void:
		var began: int = Time.get_ticks_usec(); await super._build_kerbs(track,arrays)
		phases["kerbs_us"] = int(phases.get("kerbs_us",0))+Time.get_ticks_usec()-began
	func _commit_creator_road(tool: SurfaceTool, color: Color, mask: Texture2D, road_mask: Texture2D, extent: Vector2, gravel: bool = false, grass: bool = false, kerb: bool = false, asphalt_surface: bool = false, edge_fringe: bool = false, road_marking: bool = false, arrays: Array = [], relief: String = "") -> void:
		var began: int = Time.get_ticks_usec()
		await super._commit_creator_road(tool,color,mask,road_mask,extent,gravel,grass,kerb,asphalt_surface,edge_fringe,road_marking,arrays,relief)
		phases["commit_inclusive_us"] = int(phases.get("commit_inclusive_us",0))+Time.get_ticks_usec()-began
func run() -> void:
	var doc: Dictionary = circuit(96)
	var track: NativeTrack = TrackCompiler.compile(doc)
	var began: int = Time.get_ticks_usec()
	var ground: Dictionary = preload("res://race/race_ground_preparation.gd").run(func() -> bool: return false,track)
	print("EDITOR_PHASE ground_cpu_ms=",(Time.get_ticks_usec()-began)/1000.0)
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://editor/road_preparation.gd").replace("var builder := NativeTrackVisual.new()","var builder := preload(\"res://tests/profile_editor_phases.gd\").TimedVisual.new()")
	script.source_code = script.source_code.replace("var size: int = 0\n\tfor part: Dictionary in packet.parts:","print(\"EDITOR_PHASE road_stages \",JSON.stringify(builder.phases))\n\tvar size: int = 0\n\tfor part: Dictionary in packet.parts:")
	check(script.reload() == OK,"timed CPU builder loads")
	for planning: bool in [true,false]:
		began = Time.get_ticks_usec()
		var result: Dictionary = script.prepare(track,true,false,Callable(),planning)
		print("EDITOR_PHASE planning=",planning," ms=",(Time.get_ticks_usec()-began)/1000.0," parts=",result.get("parts",[]).size())
	print("EDITOR_PHASE_COMPLETE")
	quit(1 if failures else 0)
