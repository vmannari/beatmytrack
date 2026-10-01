extends SceneTree
## Offline data bake of the original procedural lens; no runtime bake.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var viewport := SubViewport.new()
 viewport.size = Vector2i(1536,768)
 viewport.disable_3d = true
 viewport.transparent_bg = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var rect := ColorRect.new()
 rect.size = Vector2(viewport.size)
 var material := ShaderMaterial.new()
 material.shader = load("res://tests/bake_storm_glass.gdshader")
 rect.material = material
 viewport.add_child(rect)
 for frame: int in range(4): await RenderingServer.frame_post_draw
 var result: Image = viewport.get_texture().get_image()
 var alpha_min: float = 1.0
 var alpha_max: float = 0.0
 for y: int in range(0,result.get_height(),7):
  for x: int in range(0,result.get_width(),7):
   var value: float = result.get_pixel(x,y).a
   alpha_min = minf(alpha_min,value)
   alpha_max = maxf(alpha_max,value)
 if alpha_min > 0.01 or alpha_max < 0.2:
  push_error("Bake must preserve rim data in alpha, not an opaque viewport alpha")
  quit(1)
  return
 var destination: String = "res://assets/textures/storm_glass_data.png"
 var error: Error = result.save_png(destination)
 print("STORM_GLASS_BAKE: ",error," size=",result.get_size())
 viewport.queue_free()
 await process_frame
 quit(0 if error == OK else 1)
