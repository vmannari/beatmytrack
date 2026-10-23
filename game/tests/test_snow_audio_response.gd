extends "res://tests/test_snow_bank_audio.gd"
## Reproduces panel-first contact/slow attack and verifies the real output route.
const OUT: String = "res://../docs/evidence/snow-audio-response-2026-10-22"

class OldBackend extends RefCounted:
	var calls: int = 0
	func stats() -> Dictionary: return {"clip_count":4,"ready":true}
	func set_output(_a: float,_b: float,_mute: bool,_pause: bool) -> void: pass
	func play(_index: int,_gain: float,_pitch: float,_slot: int) -> bool:
		calls += 1
		return true

func run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	var audio: Node
	if baseline:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(OUT.path_join("before/game/vehicle/vehicle_audio.gd")).replace("class_name VehicleAudio\n","").replace("class_name VehicleAudio\r\n","")
		check(script.reload()==OK,"preserved previous snow mixer compiles")
		audio = script.new()
	else: audio = VehicleAudio.new()
	root.add_child(audio)
	var track: NativeTrack = make_track()
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		audio.configure(id,config)
		var state := VehicleState.new()
		# The existing visible snow spray uses an ellipse 12 cm wider than
		# the tyre contacts. Only the side panel touches this actual bank.
		state.position = Vector2(5.06-(config.track_width*.5+.12*HandlingConfig.BODY_SCALE),0)
		state.velocity = Vector2(10,0)
		var saved: Array = state.snapshot()
		audio.begin_physics_feedback()
		audio.resolved_contact(state,track,state.velocity)
		check(audio.surface_model.snow_bank==0 and audio.surface_model.snow_body>.08,"fixture touches visible side panel before any physical sample: "+id)
		check(audio.snow_count==1 and audio.levels.snow>.02,"snow entry starts on the first visible-panel contact: "+id)
		check(state.snapshot()==saved,"visible snow feedback leaves driving exact: "+id)
		audio.present(state,DriveFrame.new(),track,.016,false)
		check(audio.levels.snow>.02,"presentation keeps panel-only plough contact: "+id)
		state.position.x -= .25
		audio.resolved_contact(state,track,state.velocity)
		check(audio.levels.snow==0,"nearby panel pass cannot play snow: "+id)
		await process_frame
	verify_attack()
	if not baseline:
		verify_shared(track)
		verify_native(audio)
		var legacy := WindowsImpactAudio.new()
		var fake := OldBackend.new()
		legacy.backend = fake
		legacy.loaded_samples = 4
		check(not legacy.play(4,.5,1.0) and fake.calls==0,"older loaded DLL rejects only the unsupported snow clip")
		if AudioServer.get_driver_name()=="WASAPI": check(legacy.play(0,.5,1.0) and fake.calls==1,"older DLL keeps its original crash route during reload")
	audio.free()
	await process_frame
	print("SNOW_AUDIO_RESPONSE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify_attack() -> void:
	var path: String = OUT.path_join("before/game/assets/audio/vehicles/snow_hit.wav") if baseline else VehicleAudio.BANK+"snow_hit.wav"
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var position: int = 12
	var pcm := PackedByteArray()
	while position+8<=bytes.size():
		var length: int = bytes.decode_u32(position+4)
		if bytes.slice(position,position+4).get_string_from_ascii()=="data":
			pcm = bytes.slice(position+8,position+8+length)
			break
		position += 8+length+(length%2)
	var peak: int = 0
	for offset: int in range(0,pcm.size(),2): peak = maxi(peak,absi(pcm.decode_s16(offset)))
	var strong: int = -1
	for offset: int in range(0,pcm.size(),2):
		if absi(pcm.decode_s16(offset))>=peak*.5:
			strong = offset/2
			break
	var milliseconds: float = float(strong)/44100.0*1000.0
	print("SNOW_COMPRESSION_ATTACK_MS: ",milliseconds)
	check(strong>=0 and milliseconds<=5.0,"strong recorded compression starts within 5 ms of the cue")

func verify_shared(track: NativeTrack) -> void:
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var first := SurfaceAudioModel.new()
	var second := SurfaceAudioModel.new()
	first.configure(config)
	second.configure(config)
	var state := VehicleState.new()
	state.position = Vector2(5.06-(config.track_width*.5+.12*HandlingConfig.BODY_SCALE),0)
	state.velocity = Vector2(10,0)
	first.sample_contacts(state,track,true)
	second.sample(state,DriveFrame.new(),track,.016,true,first)
	check(second.snow_body==first.snow_body and second.snow_body>0,"same-frame shared contacts retain the visible panel contact")

func verify_native(audio: Node) -> void:
	if AudioServer.get_driver_name()!="WASAPI":
		check(audio.windows_impacts.backend==null,"other platforms keep the ordinary audio path")
		return
	audio.reset()
	var backend: RefCounted = audio.windows_impacts.backend
	check(backend!=null and audio.windows_impacts.loaded_samples==5,"all five contact clips warm before the first bank hit")
	if backend==null: return
	var before: int = int(backend.call("stats").submitted)
	audio._event("snow_hit",.5)
	check(int(backend.call("stats").submitted)==before+1 and not audio.events[0].playing,"snow takes the native route without a delayed Godot duplicate")
	check(audio.events[0].bus=="Vehicle","snow keeps Vehicle volume/mute routing")
	check(int(backend.call("stats").voice_limit)==4,"five sample choices retain only four simultaneous event voices")
	audio.reset()
	check(int(backend.call("stats").active_voices)==0,"reset/rewind clears the native snow tail")
	audio.windows_impacts.close()
	audio._event("snow_hit",.5)
	check(audio.events[0].playing,"unavailable native output falls back to the current snow sample")
