extends SceneTree
## Offline trailer capture. Uses real runtime scenes and quantized driving input.
## All storage is redirected by the launcher; no account or service is used.

const FPS: int = 30
const SIZE := Vector2i(1920, 1080)
const DISPLAY_FONT = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const TEXT_FONT = preload("res://assets/fonts/Barlow-Regular.ttf")
var output: String
var mode: String = "smoke"
var shot: String = ""
var frame_index: int = 0
var evidence: Array[Dictionary] = []
var overlay: TrailerOverlay
var app: Node
var trailer_document: Dictionary = {}

class TrailerOverlay extends Control:
	var heading: String = ""
	var subtitle: String = ""
	var tag: String = ""
	var elapsed: float = 0.0
	var end_card: bool = false
	var editor_caption: bool = false
	var challenge_caption: bool = false
	var cursor := Vector2.INF
	func _draw() -> void:
		var s: Vector2 = size / Vector2(1920,1080)
		draw_set_transform(Vector2.ZERO,0.0,s)
		if end_card:
			draw_rect(Rect2(0,0,1920,1080),Color(0.025,0.045,0.055,0.82))
			draw_rect(Rect2(880,285,160,5),Color("dbb36d"))
			_center("BEAT MY TRACK",560,150,DISPLAY_FONT,Color("f5f0e6"))
			_center("BUILD IT.  MAKE IT YOURS.  SET THE CHALLENGE.",650,30,TEXT_FONT,Color("dfc28b"))
			_center("Can they beat your track?",800,42,DISPLAY_FONT,Color("f5f0e6"))
			return
		if challenge_caption:
			draw_style_box(_tag_box(),Rect2(48,822,1150,84))
			draw_rect(Rect2(69,836,4,54),Color("dbb36d"))
			draw_string(DISPLAY_FONT,Vector2(92,858),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color("f5f0e6"))
			draw_string(TEXT_FONT,Vector2(94,892),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("dedfd9"))
		elif editor_caption:
			draw_style_box(_tag_box(),Rect2(455,126,1110,115))
			draw_rect(Rect2(478,151,4,63),Color("dbb36d"))
			draw_string(DISPLAY_FONT,Vector2(505,184),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,42,Color("f5f0e6"))
			draw_string(TEXT_FONT,Vector2(507,220),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("dedfd9"))
		elif not heading.is_empty():
			for i: int in range(140):
				var a: float = 0.74 * pow(float(i)/140.0,1.4)
				draw_rect(Rect2(0,940+i,1920,1),Color(0.025,0.045,0.055,a))
			draw_rect(Rect2(72,968,5,65),Color("dbb36d"))
			draw_string(DISPLAY_FONT,Vector2(96,1010),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,54,Color("f5f0e6"))
			draw_string(TEXT_FONT,Vector2(98,1046),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("dedfd9"))
		if not tag.is_empty():
			var w: float = TEXT_FONT.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x+40
			draw_style_box(_tag_box(),Rect2(1848-w,48,w,42))
			draw_string(TEXT_FONT,Vector2(1868-w,77),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("f5f0e6"))
		if cursor.is_finite():
			draw_circle(cursor,15,Color(0.86,0.70,0.42,0.20))
			draw_arc(cursor,15,0,TAU,48,Color("f4deb2"),2,true)
	func _tag_box() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color=Color(0.025,0.045,0.055,0.82)
		box.set_corner_radius_all(4)
		return box
	func _center(text: String,y: float,font_size: int,font: Font,color: Color) -> void:
		var w: float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,Vector2((1920-w)*0.5,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
	assert(output.is_absolute_path(),"Explicit workspace output required")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=SIZE
	root.content_scale_size=Vector2i(1280,720)
	var layer := CanvasLayer.new()
	layer.layer=100
	root.add_child(layer)
	overlay=TrailerOverlay.new()
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if mode == "smoke":
		await _gameplay("smoke","pine",15,"YOUR TRACK. YOUR RULES.","Create it. Customise it. Challenge them.",0)
	elif mode == "gameplay":
		await _gameplay("01-hook","pine",120,"YOUR TRACK. YOUR RULES.","Create it. Customise it. Challenge them.",0)
		for biome: String in TrackTheme.IDS:
			await _gameplay("03-biome-"+biome,biome,42,"ONE TRACK. FIVE WORLDS.","Grass / Desert / Night / Winter / Storm",TrackTheme.IDS.find(biome)%4)
		await _gameplay("06-finale","desert",150,"SET THE CHALLENGE.","Build a circuit worth beating.",2)
		await _gameplay("07-end","pine",120,"","",2,true)
	elif mode == "garage":
		await _garage()
	elif mode == "editor":
		await _editor()
	elif mode == "challenge":
		await _challenges()
	var file := FileAccess.open(output.path_join(mode+"-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":mode,"fps":FPS,"size":[1920,1080],"shots":evidence},"\t"))
	file.close()
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	GameSoundtrack.instance().output_enabled=false
	print("TRAILER_CAPTURE_COMPLETE ",mode," shots=",evidence.size())
	quit(0)

func _begin_shot(identity: String,heading: String,subtitle: String,tag: String="",end: bool=false) -> void:
	shot=identity
	frame_index=0
	DirAccess.make_dir_recursive_absolute(output.path_join(shot))
	overlay.heading=heading
	overlay.subtitle=subtitle
	overlay.tag=tag
	overlay.end_card=end
	overlay.editor_caption=identity=="02-editor"
	overlay.challenge_caption=identity=="05-challenges"
	overlay.cursor=Vector2.INF
	overlay.queue_redraw()
	print("TRAILER_SHOT ",shot)

func _save_frame() -> void:
	overlay.elapsed=float(frame_index)/FPS
	overlay.queue_redraw()
	await RenderingServer.frame_post_draw
	var error: Error=root.get_texture().get_image().save_jpg(output.path_join(shot).path_join("%05d.jpg"%frame_index),0.94)
	assert(error == OK,"Trailer frame write failed")
	frame_index+=1

func _finish_shot(extra: Dictionary={}) -> void:
	var item: Dictionary={"id":shot,"frames":frame_index,"seconds":float(frame_index)/FPS}
	item.merge(extra)
	evidence.append(item)

func _paint(index: int) -> Dictionary:
	var value: Dictionary=VehicleLivery.defaults("compact")
	var palettes: Array=[{"body":"294e68","accent":"ece2ce","detail":"d8a35b"},{"body":"ac4935","accent":"f0ddad","detail":"26383f"},{"body":"d6b45c","accent":"233b45","detail":"d9e1d6"},{"body":"507a70","accent":"e5dfca","detail":"c97343"}]
	value.colors=palettes[index%4].duplicate()
	value.pattern=["apex_twin","offset_gt","apex_twin","offset_gt"][index%4]
	assert(VehicleLivery.valid(value))
	return value

func _parts(index: int) -> Dictionary:
	var value: Dictionary=VehicleCustomisation.defaults()
	if index%4==1: value.merge({"hood":"scoop","aero":"rallywing","rims":"rallydisc","body":"rally"},true)
	if index%4==2: value.merge({"hood":"extractor","aero":"swan","rims":"split","body":"wide"},true)
	if index%4==3: value.merge({"hood":"louvres","aero":"ducktail","rims":"mesh","body":"street"},true)
	assert(VehicleCustomisation.valid(value))
	return value

func _document(theme: String="pine") -> Dictionary:
	var doc: Dictionary=TrackDocument.create_default()
	doc.id="trailer_circuit"
	doc.name="Beat My Track"
	doc["creator"]="Beat My Track"
	doc.theme=theme
	return doc

func _gameplay(identity: String,theme: String,count: int,heading: String,subtitle: String,style: int,end: bool=false) -> void:
	var doc: Dictionary=_document(theme)
	print("TRAILER_DOCUMENT_VALIDATION ",TrackDocument.validate(doc))
	var track: NativeTrack=TrackCompiler.compile(doc)
	assert(track != null)
	var race: Node=load("res://core/game.tscn").instantiate()
	race.initial_track=track
	race.production_mode=true
	race.cooperative_preparation=true
	race.ai_enabled=true
	race.hitch_diagnostics_enabled=false
	root.add_child(race)
	while not race.preparation_complete: await process_frame
	race.set_physics_process(false)
	race.set_process(false)
	race.paused=false
	race.countdown_ticks=0
	race.car.apply_livery(_paint(style))
	# Install real cosmetic geometry before the captured simulation begins.
	if style>0:
		var previous: CarVisual=race.car
		var model := CarVisual.new()
		model.vehicle_id="compact"
		model.livery=_paint(style)
		model.customisation=_parts(style)
		previous.get_parent().add_child(model)
		race.car=model
		previous.get_parent().remove_child(previous)
		previous.queue_free()
		race.car_weathering=VehicleWeathering.new()
		race.car_weathering.configure(model,theme,race.handling)
		race.car.set_night_headlights(theme=="night_city")
		if race.winter_snow_wind != null: race.winter_snow_wind.car_visual=model
	race.hud.hide()
	race.race_cues.hide()
	race.countdown_label.hide()
	# Warm-up is real canonical driving, excluded from the edit.
	for i: int in range(240): race._physics_process(1.0/120.0)
	race.previous_position=race.sim.state.position
	race.previous_heading=race.sim.state.heading
	race._process(1.0/FPS)
	race.camera.follow(race.sim.state.position,race.sim.state.velocity,race.sim.state.heading,0.0,true)
	await process_frame
	_begin_shot(identity,heading,subtitle,TrackTheme.title(theme) if not end else "",end)
	var from: Vector2=race.sim.state.position
	var start_tick: int=race.sim.state.tick
	var max_speed: float=0
	for i: int in range(count):
		race.paused=false
		for step: int in range(4): race._physics_process(1.0/120.0)
		race.previous_position=race.sim.state.position
		race.previous_heading=race.sim.state.heading
		race._process(1.0/FPS)
		max_speed=maxf(max_speed,race.sim.state.velocity.length())
		await _save_frame()
	_finish_shot({"theme":theme,"car":"compact","paint":_paint(style),"parts":_parts(style),"start_tick":start_tick,"end_tick":race.sim.state.tick,"start_position":[from.x,from.y],"end_position":[race.sim.state.position.x,race.sim.state.position.y],"max_speed_mps":max_speed,"source":"actual Game scene; ordinary RouteDriver quantized inputs; canonical 120 Hz simulation; HUD hidden for editorial capture"})
	assert(race.sim.state.tick-start_tick==count*4)
	assert(from.distance_to(race.sim.state.position)>1.0)
	race.queue_free()
	await process_frame

func _garage() -> void:
	var showroom := CarShowroom.new()
	showroom.garage_mode=true
	showroom.vehicle_id="compact"
	showroom.livery=_paint(0)
	showroom.customisation=_parts(0)
	root.add_child(showroom)
	showroom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i: int in range(12): await process_frame
	showroom.set_zoom(0.80)
	showroom.elevation=0.34
	_begin_shot("04-garage","MAKE IT YOURS.","Liveries. Body kits. Aero. Wheels.")
	var variants: Array[Dictionary]=[]
	for i: int in range(240):
		var variant: int=i/60
		if i%60==0:
			showroom.apply_livery(_paint(variant))
			showroom.apply_customisation(_parts(variant))
			variants.append({"at_frame":i,"paint":_paint(variant),"parts":_parts(variant)})
		showroom.yaw=-0.70+float(i)*0.005
		showroom._orbit()
		showroom.invalidate_render()
		await _save_frame()
	_finish_shot({"source":"actual Garage environment, CarShowroom, liveries and cosmetic kit geometry","variants":variants})
	showroom.queue_free()
	await process_frame

func _new_app() -> void:
	var directory: String=output.path_join("isolated-profile")
	DirAccess.make_dir_recursive_absolute(directory)
	app=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(directory.path_join("records.json"))
	app.library=TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override=directory.path_join("cloud")
	root.add_child(app)
	var deadline: int=Time.get_ticks_msec()+60000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	assert(app.startup_complete,"Isolated app startup timed out")

func _wait_editor() -> void:
	var deadline: int=Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		if app.canvas.native_preview != null and app.editor_preview_thread == null and not app.editor_world._building and not app.editor_commits.unsettled(): break
		await process_frame
	assert(app.canvas.native_preview != null and not app.editor_world._building,"Editor preview timed out")
	for i: int in range(3): await process_frame

func _editor() -> void:
	await _new_app()
	var doc: Dictionary=TrackDocument.create_blank()
	doc.id="trailer_build"
	doc.name="Your next challenge"
	doc["creator"]="Beat My Track"
	app.document=doc
	app.canvas=null
	app.editor_view={}
	app._show_screen("create")
	await _wait_editor()
	var canvas: EditorCanvas=app.canvas
	canvas.zoom=0.72
	canvas.pan=Vector2(55,-12)
	canvas.queue_redraw()
	_begin_shot("02-editor","BUILD YOUR NEXT CHALLENGE.","Connect the road. Shape the circuit. Make it your own.")
	for index: int in range(8):
		canvas.choose_piece("straight" if index%2==0 else "curve")
		if index==0:
			canvas.ghost.position=[-20.0,-35.0]
			canvas.ghost.heading=0.0
		canvas.ghost.length=40.0 if index%2==0 else 0.0
		canvas.ghost.radius=15.0
		canvas.queue_redraw()
		app._build_editor_tools()
		for i: int in range(12): await _save_frame()
		canvas.confirm_piece()
		await _wait_editor()
		for i: int in range(12): await _save_frame()
	# End on the actual completed native preview with editing handles visible.
	for i: int in range(18): await _save_frame()
	assert(doc.pieces.size()==8)
	_finish_shot({"source":"actual App track editor; choose_piece and confirm_piece; native previews; eight committed modular sections","pieces":doc.pieces,"document":doc})

func _challenges() -> void:
	await _new_app()
	app._show_screen("challenge_create")
	var page := ChallengeCreate.new()
	page.adapter=app.challenges
	page.library=app.library
	page.records=app.records
	page.selected_track=app.selected_track
	page.initial_vehicle="compact"
	app.content.add_child(page)
	for i: int in range(30): await process_frame
	_begin_shot("05-challenges","CHALLENGE THEM.","One-to-one. Group races. 3×3.")
	for i: int in range(150):
		if i==50: page._choose_format("group")
		if i==100: page._choose_format("three")
		await _save_frame()
	_finish_shot({"source":"actual ChallengeCreate format picker, offline isolated profile; no challenge submission or synthetic win/result"})
