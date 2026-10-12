extends SceneTree
## Frozen actual world: baseline, strong flash and restored overcast; camera/state stable.
const OUT: String = "res://../docs/evidence/storm-flash-rumble-2026-10-10"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	game.initial_track.metadata.theme = "storm"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var weather: StormWeather = game.storm_weather
	weather.until_lightning = 9999
	weather.until_thunder = -1
	for tick: int in range(8):
		await process_frame
		weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		game.paused = false
		game._process(.016)
	var state: Array = game.sim.state.snapshot()
	var camera: Camera3D = root.get_camera_3d()
	var pose: Transform3D = camera.global_transform
	var size: float = camera.size
	weather.flash_age = weather.FLASH_DURATION
	weather.advance(0,false)
	await RenderingServer.frame_post_draw
	var before: Image = root.get_texture().get_image()
	check(before.save_png(OUT.path_join("overcast.png"))==OK,"captured overcast world")
	weather.rng.seed = 317
	weather._build_flash_profile()
	var strongest: Vector2 = Vector2.ZERO
	for knot: Vector2 in weather.flash_profile:
		if knot.y>strongest.y: strongest = knot
	weather.flash_age = strongest.x
	weather.advance(0,false)
	await RenderingServer.frame_post_draw
	var flash: Image = root.get_texture().get_image()
	check(flash.save_png(OUT.path_join("strong-flash.png"))==OK,"captured strong lightning world")
	check(strongest.y>=.72 and strongest.y<=weather.FLASH_PEAK_MAX,"strong flash envelope reaches new amplitude")
	check(game.biome_light.light_energy>weather.base_light_energy+14,"world light rises strongly")
	var before_luma: float = 0
	var flash_luma: float = 0
	var samples: int = 0
	for y: int in range(150,650,20):
		for x: int in range(260,1050,20):
			var a: Color = before.get_pixel(x,y)
			var b: Color = flash.get_pixel(x,y)
			before_luma += a.r*.2126+a.g*.7152+a.b*.0722
			flash_luma += b.r*.2126+b.g*.7152+b.b*.0722
			samples += 1
	check(flash_luma>before_luma*1.8,"rendered world is substantially brighter at the flash")
	weather.advance(0,true)
	check(is_equal_approx(weather.flash_strength(),strongest.y),"pause freezes flash level")
	weather.flash_age = weather.FLASH_DURATION
	weather.advance(0,false)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT.path_join("restored.png"))==OK,"captured restored overcast")
	check(is_equal_approx(game.biome_light.light_energy,weather.base_light_energy),"flash restores base world light")
	check(game.sim.state.snapshot()==state and camera.global_transform==pose and camera.size==size,"flash does not alter simulation or camera")
	var file := FileAccess.open(OUT.path_join("flash-check.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"peak":strongest.y,"world_light_boost":strongest.y*weather.FLASH_LIGHT_ENERGY,"overlay_alpha":strongest.y*weather.FLASH_OVERLAY_ALPHA,"mean_before":before_luma/samples,"mean_flash":flash_luma/samples,"brightness_ratio":flash_luma/before_luma},"\t")+"\n")
	file.close()
	game.free()
	GameSoundtrack.instance().menu_player.stop()
	await create_timer(.15).timeout
	print("STRONG_STORM_FLASH: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
