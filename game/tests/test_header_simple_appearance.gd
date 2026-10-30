extends SceneTree
const Profile = preload("res://ui/profile_car.gd")
const Cache = preload("res://ui/header_simple_cache.gd")
var failures = 0
var checks = 0
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
 checks += 1
 if not ok: failures += 1; print("FAIL ",label)
func render(paint: Dictionary, parts: Dictionary, use_template: bool) -> Dictionary:
 var viewport := SubViewport.new()
 viewport.size = Vector2i(176,112); viewport.disable_3d = true; viewport.transparent_bg = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var view: Control = Profile.make_preview("compact",paint,parts)
 view.size = Vector2(176,112)
 view.header_template = use_template
 view.cooperative_build = true
 view.cache_rest_pose = false
 var hits_before: int = Cache.hits
 var started: int = Time.get_ticks_usec()
 viewport.add_child(view)
 while not view.presentation_ready: await process_frame
 var ready_ms: float = (Time.get_ticks_usec()-started)/1000.0
 Profile.apply_presentation(view)
 for frame in range(12): await RenderingServer.frame_post_draw
 var image: Image = viewport.get_texture().get_image()
 var pixels: PackedByteArray = image.get_data()
 var nonzero: int = 0
 for pixel in range(3,pixels.size(),4):
  if pixels[pixel] > 0: nonzero += 1
 var result = {"pixels":pixels,"nonzero":nonzero,"hits":Cache.hits-hits_before,"ready_ms":ready_ms}
 viewport.queue_free()
 await process_frame
 return result
func compare(paint: Dictionary,parts: Dictionary,label: String,expected_hits: int):
 var a = await render(paint,parts,false)
 var b = await render(paint,parts,true)
 var changed: int = 0; var max_diff: int = 0; var total: int = 0
 for i in range(a.pixels.size()):
  var delta = absi(int(a.pixels[i])-int(b.pixels[i]))
  total += delta
  if delta != 0: changed += 1; max_diff=maxi(max_diff,delta)
 var mean: float = float(total)/float(a.pixels.size())/255.0
 print("COMPARE ",label," reference_ms=",a.ready_ms," template_ms=",b.ready_ms," hits=",b.hits," nonzero=",a.nonzero," differing_bytes=",changed," max_difference=",max_diff," mean=",mean)
 check(a.nonzero>0,"nonempty reference "+label)
 check(b.hits==expected_hits,"expected cache hit "+label)
 # Same strict mean absolute RGBA threshold as the retained header appearance fixture.
 check(mean<0.02,"appearance matches reference "+label)
func run():
 root.size = Vector2i(1280,720)
 for pattern in ["plain","offset_gt"]:
  var paint: Dictionary = VehicleLivery.defaults("compact")
  paint.colors.body = "cc2244"; paint.colors.accent = "32b5d7"; paint.pattern = pattern
  await compare(paint,VehicleCustomisation.defaults(),pattern,1)
 var custom = VehicleCustomisation.defaults(); custom.hood = "cowl"
 await compare(VehicleLivery.defaults("compact"),custom,"custom-kit",0)
 print("HEADER_TEMPLATE_COMPARISON checks=",checks," failures=",failures)
 quit(1 if failures else 0)
