extends SceneTree
## Exact per-cell reconstruction implies exact bilinear/nine-tap mask filtering.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	for theme: String in ["winter","desert","pine","storm","night_city"]:
		for kinds: Array in [[0,1,2,4],[0,1,3,7],[0,1,2,3,4,5,6,7]]:
			var track := NativeTrack.new()
			track.metadata = {"theme":theme}
			track.grid_width = 16
			track.grid_height = 16
			track.half_extent = Vector2(8,8)
			track.cells.resize(256)
			for index: int in range(256): track.cells[index] = int(kinds[index % kinds.size()])
			var before: PackedInt32Array = track.cells.duplicate()
			var visual := NativeTrackVisual.new()
			visual.theme_id = theme
			visual.colors = TrackTheme.palette(theme)
			root.add_child(visual)
			await visual._build_terrain(track)
			var material: ShaderMaterial = visual.get_child(0).material_override
			var packed: bool = material.get_shader_parameter("terrain_packed")
			check(packed == (theme in ["winter","desert"] and kinds.size() <= 4),theme + " packs only eligible four-channel maps")
			var low: Image = (material.get_shader_parameter("surface_low") as Texture2D).get_image()
			var high: Image = (material.get_shader_parameter("surface_high") as Texture2D).get_image()
			var slots: Vector4i = material.get_shader_parameter("terrain_slots")
			for y: int in range(16):
				for x: int in range(16):
					var weights: Array[float] = [0,0,0,0,0,0,0,0]
					var a: Color = low.get_pixel(x,y)
					var b: Color = high.get_pixel(x,y)
					for channel: int in range(4):
						if packed:
							if slots[channel] >= 0: weights[slots[channel]] = a[channel]
						else:
							weights[channel] = a[channel]
							weights[channel+4] = b[channel]
					var expected: Array[float] = [0,0,0,0,0,0,0,0]
					expected[track.cells[y*16+x]] = 1.0
					check(weights == expected,theme + " preserves every source-channel byte")
			check(track.cells == before,theme + " leaves canonical cells unchanged")
			check(material.render_priority == (1 if theme in ["winter","desert"] else 0),theme + " opaque terrain order is scoped")
			visual.free()
	print("BIOME_TERRAIN_PACKING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
