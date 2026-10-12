extends Control
## Non-interactive developer graph. F8 never steals steering/touch input.
var controller: DynamicMusicController
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var c: DynamicMusicController = controller
	var stages: Dictionary = {1:"Solo",3:"Harmony",7:"Bass",15:"Rhythm",31:"Guitar",63:"Full ensemble"}
	var stage: String = str(stages.get(c.telemetry.get("layers",1),"Transition"))
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(12,65,390,535),Color(0.025,0.04,0.07,0.94))
	var lines: Array[String] = ["MUSIC  /  Grass MVP  /  F8", "%.1f m   %.1f m/s   ahead %.1f m" % [c.distance,c.speed,c.lookahead_distance],
		"%s  >  %s" % [c.analyzer.feature(c.distance),c.analyzer.feature(c.distance+c.lookahead_distance)],
		"Energy %.2f   Tension %.2f   Hook %.2f" % [c.state.x,c.state.y,c.state.z],
		"Risk %.2f  Off %.2f  Over %.2f  Slip %.2f" % [c.trajectory.driving_risk,c.trajectory.off_track_risk,c.trajectory.overspeed_risk,c.trajectory.slip_risk],
		"Avg %.1f km/h  build %.0f%%  wait %.1fs" % [c.progression.average_speed*3.6,c.progression.intensity*100,c.progression.recovery_seconds],
		"Clean qualifying %.1fs / %s" % [c.progression.qualifying_seconds,"recovery" if c.progression.melancholy else "building" if c.progression.fast else "below pace"],
		"Beat %.2f   Bar %d   Phrase %d" % [c.clock.beat_position,c.clock.current_bar+1,c.clock.current_phrase+1],
		"%s / drum %s / riff %s" % [stage,c.telemetry.get("drum_pattern","-"),c.telemetry.get("hook_pattern","-")],
		"Voices %s / peak %s / 32" % [c.telemetry.get("active_voices",0),c.telemetry.get("peak_voices",0)],
		"Mix %s us (%.1f%%)  control %d us" % [c.telemetry.get("mix_us",0),float(c.telemetry.get("mix_us",0))*float(c.telemetry.get("sample_rate",48000))/maxf(1.0,float(c.telemetry.get("buffer_frames",512)))/10000.0,c.controller_us],
		"Buffer %s   render overruns %s" % [c.telemetry.get("buffer_frames",0),c.telemetry.get("render_budget_overruns",0)],
		"Native DSP unavailable" if not c.available else "Seed %d / engine v%d" % [c.analyzer.seed_value,TrackMusicAnalyzer.MUSIC_ENGINE_VERSION]]
	for i: int in range(lines.size()): draw_string(font,Vector2(24,90+i*23),lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	var colors: Array[Color] = [Color("f5ce53"),Color("ef786d"),Color("72d2ac")]
	for component: int in range(3):
		var graph := PackedVector2Array()
		for i: int in range(c.analyzer.states.size()): graph.append(Vector2(25+360.0*i/maxi(1,c.analyzer.states.size()-1),545-c.analyzer.states[i][component]*120))
		if graph.size()>1: draw_polyline(graph,colors[component],2.0,true)
	if c.analyzer.length > 0:
		var x: float = 25+360*fposmod(c.distance,c.analyzer.length)/c.analyzer.length
		draw_line(Vector2(x,420),Vector2(x,550),Color.WHITE)
	draw_string(font,Vector2(24,580),"Route: yellow energy / red tension / green hook",HORIZONTAL_ALIGNMENT_LEFT,-1,14)
