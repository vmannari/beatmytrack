extends SceneTree
## Releases consumed by carousel input must still reach every preview worker.
const Cache = preload("res://ui/garage_preview_cache.gd")
const Preloader = preload("res://ui/garage_preloader.gd")
const Carousel = preload("res://ui/track_carousel.gd")
const Swipe = preload("res://ui/menu_page_swipe.gd")
var checks: int = 0
var failures: int = 0

class App extends Node:
	var _publishing_slots_foreground: bool=true

func _initialize() -> void:
	if "--old-relay" in OS.get_cmdline_user_args():
		var relay: Script=load("res://ui/preview_touch_input.gd")
		relay.source_code=FileAccess.get_file_as_string("res://../build/carousel-preview-20261107/before/preview_touch_input.gd")
		assert(relay.reload(true)==OK)
	if "--old-thumbnail" in OS.get_cmdline_user_args():
		var thumbnail: Script=load("res://ui/garage_cached_thumbnail.gd")
		thumbnail.source_code=FileAccess.get_file_as_string("res://../build/carousel-preview-20261107/before/garage_cached_thumbnail.gd")
		assert(thumbnail.reload(true)==OK)
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",label)

func touch(at: Vector2, index: int, pressed: bool, canceled: bool=false) -> void:
	var event := InputEventScreenTouch.new()
	event.position=at; event.index=index; event.pressed=pressed; event.canceled=canceled
	root.push_input(event,true)

func drag(at: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position=at; event.relative=Vector2(10,0); event.index=index
	root.push_input(event,true)

func run() -> void:
	root.size=Vector2i(960,540)
	var host := Control.new()
	host.size=Vector2(960,540)
	root.add_child(host)
	var cache: Node=Cache.new()
	host.add_child(cache)
	cache.set_process(false)
	cache.idle_ms=0
	var app := App.new()
	host.add_child(app)
	var preloader: Node=Preloader.new()
	preloader.app=app
	host.add_child(preloader)
	preloader.set_process(false)
	var gallery: ScrollContainer=Carousel.new()
	gallery.position=Vector2(100,300); gallery.size=Vector2(700,140)
	host.add_child(gallery)
	var content := Control.new()
	content.custom_minimum_size=Vector2(1400,140)
	gallery.add_child(content)
	var swipe: Node=Swipe.new()
	swipe.menu=host; swipe.modal_root=host
	host.add_child(swipe)
	for tick: int in range(4): await process_frame
	# A release in a gesture owner can be swallowed before earlier siblings.
	touch(Vector2(50,50),4,true)
	check(cache._touches.has(4) and preloader._touches.has(4),"press reaches both preview workers")
	touch(Vector2(180,350),4,false)
	check(cache._touches.is_empty() and preloader._touches.is_empty(),"carousel-area release clears earlier press")
	# Hold one finger outside the carousel while another owns its swipe.
	touch(Vector2(50,50),5,true)
	touch(Vector2(180,350),6,true)
	touch(Vector2(200,350),5,false)
	check(not cache._touches.has(5) and not preloader._touches.has(5),"consumed release cannot strand another finger")
	touch(Vector2(200,350),6,false)
	check(cache._touches.is_empty() and preloader._touches.is_empty(),"carousel swipe finishes without retained touches")
	# A short page swipe starts over static content: DOWN passes through, but
	# horizontal intent consumes UP without navigating away from this page.
	touch(Vector2(50,50),7,true)
	check(cache._touches.has(7) and preloader._touches.has(7),"page-swipe press is observed by preview workers")
	drag(Vector2(60,50),7)
	touch(Vector2(60,50),7,false)
	check(cache._touches.is_empty() and preloader._touches.is_empty(),"handled page-swipe release clears all workers")
	# Keep the cancellation case independent when running the old control.
	cache._touches.erase(7); preloader._touches.erase(7)
	touch(Vector2(50,50),8,true)
	drag(Vector2(60,50),8)
	touch(Vector2(50,50),9,true)
	touch(Vector2(60,50),8,false,true)
	check(not cache._touches.has(8) and cache._touches.has(9) and not preloader._touches.has(8) and preloader._touches.has(9),"handled cancellation clears only its finger")
	check(not cache._render_allowed(),"a remaining held finger continues to block rendering")
	touch(Vector2(50,50),9,false)
	check(cache._touches.is_empty() and preloader._touches.is_empty(),"remaining real release restores idle rendering")
	check(cache._render_allowed(),"preview render gate reopens after consumed input")
	root.gui_embed_subwindows=true
	var popup:=PopupPanel.new()
	host.add_child(popup)
	for tick: int in range(2): await process_frame
	touch(Vector2(50,50),10,true)
	touch(Vector2(50,50),11,true)
	popup.popup_centered(Vector2i(200,100))
	for tick: int in range(2): await process_frame
	var release:=InputEventScreenTouch.new()
	release.index=10
	popup.push_input(release,true)
	check(not cache._touches.has(10) and cache._touches.has(11) and not preloader._touches.has(10) and preloader._touches.has(11),"popup release preserves another held finger")
	release.index=11; release.pressed=true; release.canceled=true
	popup.push_input(release,true)
	check(cache._touches.is_empty() and preloader._touches.is_empty(),"popup cancellation still reaches both workers")
	popup.hide()
	popup.queue_free()
	cache.directory="user://preview-touch-"+TrackLibrary.unique_id()
	cache.remember_pictures=true
	var card: Control=preload("res://ui/garage_cached_thumbnail.gd").new()
	card.vehicle_id="compact"
	card.livery=VehicleLivery.for_car({},"compact")
	card.livery.colors.body="ac5732"
	card.customisation=VehicleCustomisation.defaults()
	card.preview_service=cache
	host.add_child(card)
	check(cache.queued.size()==1,"missing custom picture queues its first request")
	card.refresh_thumbnail()
	check(cache.queued.size()==1,"refresh coalesces the existing request")
	var job: Dictionary=cache.queued.pop_front()
	cache.active=job
	card.refresh_thumbnail()
	check(cache.queued.is_empty(),"refresh coalesces an active native capture")
	cache.active={}
	cache.io=job
	card.refresh_thumbnail()
	check(cache.queued.is_empty(),"refresh coalesces an active image read")
	cache.io={}
	cache.queued.clear()
	card.refresh_thumbnail()
	check(cache.queued.size()==1 and card._placeholder.visible,"same-identity refresh resubmits missing work")
	var image:=Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var texture:=ImageTexture.create_from_image(image)
	cache.ready_pictures[card.vehicle_id]={"key":card.preview_key,"texture":texture}
	cache.queued.clear()
	card.refresh_thumbnail()
	check(card.displayed_key==card.preview_key and card._image.texture==texture and not card._placeholder.visible,"exact remembered picture replaces the placeholder on refresh")
	check(cache.queued.is_empty(),"completed picture refresh queues no work")
	var old_key: String=card.preview_key
	var paint: Dictionary=card.livery.duplicate(true)
	paint.colors.body="372dbe"
	card.apply_livery(paint)
	card.publish_preview(old_key,texture)
	check(card.displayed_key.is_empty() and card._image.texture==null and card._placeholder.visible,"late old paint cannot replace a new requested appearance")
	host.queue_free()
	for tick: int in range(4): await process_frame
	print("PREVIEW_TOUCH_CONSUMPTION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
