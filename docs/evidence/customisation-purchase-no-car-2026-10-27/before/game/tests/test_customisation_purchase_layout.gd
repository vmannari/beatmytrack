extends SceneTree
## Real purchase dialog builder with an in-memory economy; no account or save writes.
const Chrome = preload("res://ui/popup_style.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/customisation-purchase-reference-2026-10-26/native"
var page: GaragePage
var economy: FixtureEconomy
var applications: int = 0
var accounts: int = 0

class FixturePage extends GaragePage:
	func _ready() -> void: set_process(false)
	func _notification(_what: int) -> void: pass
	func _exit_tree() -> void: pass

class FixtureEconomy extends Node:
	var scope: String = "isolated-purchase-layout"
	var busy: bool = false
	var pending: Dictionary = {}
	var coins: int = 2150
	var signed_in: bool = true
	var calls: int = 0
	func authenticated() -> bool: return signed_in
	func owns(_id: String) -> bool: return false
	func balance() -> int: return coins
	func price(_id: String) -> int: return 750
	func purchase(_id: String) -> bool:
		calls += 1
		await get_tree().process_frame
		return true

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while is_instance_valid(page) and is_instance_valid(page._purchase_dialog) and not page._purchase_dialog.vehicle_preview.presentation_ready and Time.get_ticks_msec()<deadline: await process_frame
	for frame: int in range(12): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func open_purchase(title: String = "Twin intakes", id: String = "kit/compact/hood/twin_scoop") -> ConfirmationDialog:
	check(not page._require_owned(id,title,func() -> void: applications += 1),"locked item waits for confirmation")
	await settle()
	return page._purchase_dialog

func inspect(dialog: ConfirmationDialog, label: String) -> void:
	var view: Node = dialog
	var bounds := Rect2(Vector2.ZERO,Vector2(dialog.size))
	var message_rect: Rect2 = view.description.get_global_rect()
	var visible_body: Rect2 = view.copy_scroll.get_global_rect()
	var actions: Control = view.confirm_button
	check(dialog.has_meta("menu_popup_custom") and not dialog.has_node("PopupStyle"),label+": dedicated purchase presentation has no generic chrome")
	check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),label+": popup fits viewport")
	check(view.details.get_global_rect().encloses(view.heading.get_global_rect()),label+": heading fits its scrollable content")
	check(view.heading.get_global_rect().end.y+8 <= message_rect.position.y,label+": body clears heading")
	check(visible_body.end.y+12 <= actions.position.y,label+": body clears actions")
	check(visible_body.size.y >= 64,label+": message keeps a usable visible area")
	check(message_rect.size.y+1 >= view.description.get_minimum_size().y,label+": full message has its natural height")
	check(not visible_body.intersects(view.close_button.get_global_rect()),label+": details clear Close")
	check(view.vehicle_preview.presentation_ready,label+": actual native car is ready")
	inspect_camera(view.vehicle_preview,label)
	check(not view.preview_area.get_global_rect().intersects(visible_body),label+": car and purchase details occupy separate areas")
	check(view.confirm_button.disabled == dialog.get_ok_button().disabled,label+": custom action retains native availability")
	check(view.price_label.text == "750",label+": price uses actual data")
	check(view.balance_label.text == "2,150" if economy.coins == 2150 else view.balance_label.text == "100",label+": current balance uses actual data")
	check(view.remaining_label.text == "1,400" if economy.coins == 2150 else view.remaining_label.text == "—",label+": remaining balance is factual")
	for button: Button in [view.confirm_button,view.cancel_button,view.close_button]:
		check(bounds.encloses(button.get_global_rect()),label+": button fits panel "+button.text)
		check(button.size.y >= 48,label+": touch height "+button.text)
	print("PURCHASE_RECT: ",label," viewport=",root.get_visible_rect()," panel=",dialog.size," message=",message_rect," visible=",visible_body," actions=",actions.get_global_rect())

func inspect_camera(preview: Node, label: String) -> void:
	var camera: Camera3D = preview.camera
	check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE,label+": preview uses natural perspective")
	check(camera.fov >= 30 and camera.fov <= 42,label+": moderate lens avoids wide-angle exaggeration")
	var elevation: float = rad_to_deg(asin(camera.global_basis.z.y))
	check(elevation >= 8 and elevation <= 16,label+": parked-car view avoids the old roof-heavy angle")
	var near_a: Vector2 = camera.unproject_position(camera.to_global(Vector3(-0.15,0,-5)))
	var near_b: Vector2 = camera.unproject_position(camera.to_global(Vector3(0.15,0,-5)))
	var far_a: Vector2 = camera.unproject_position(camera.to_global(Vector3(-0.15,0,-9)))
	var far_b: Vector2 = camera.unproject_position(camera.to_global(Vector3(0.15,0,-9)))
	check(near_a.distance_to(near_b) > far_a.distance_to(far_b)*1.5,label+": equal features become smaller with depth")
	var safe := Rect2(Vector2(preview.viewport.size)*0.025,Vector2(preview.viewport.size)*0.95)
	var enclosed: bool = not preview.points.is_empty()
	for point: Vector3 in preview.points:
		if camera.is_position_behind(point) or not safe.has_point(camera.unproject_position(point)): enclosed = false
	check(enclosed,label+": every visible-mesh corner keeps framing clearance")

func dismiss(dialog: ConfirmationDialog) -> void:
	dialog.cancel_button.pressed.emit()
	await settle()
	check(page._purchase_dialog == null and not is_instance_valid(dialog),"Cancel releases the owned purchase popup")

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameFonts.configure("en")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): output = argument.trim_prefix("--evidence=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.gui_embed_subwindows = true
	node_added.connect(func(node: Node) -> void:
		if node is Window: Chrome.watch(node))
	var background := ColorRect.new()
	background.color = Color("101a26")
	root.add_child(background)
	MenuStyle.fill(background)
	page = FixturePage.new()
	root.add_child(page)
	MenuStyle.fill(page)
	economy = FixtureEconomy.new()
	root.add_child(economy)
	page.economy = economy
	page.vehicle_id = "compact"
	page.draft = VehicleLivery.defaults("compact")
	page.draft.colors.body = "266ec6"
	page.kit_draft = VehicleCustomisation.defaults()
	page.kit_draft.hood = "twin_scoop"
	var source := CarShowroom.new()
	source.read_only = true
	source.livery = page.draft.duplicate(true)
	source.customisation = page.kit_draft.duplicate(true)
	source.size = Vector2(640,360)
	source.position = Vector2(-2000,-2000)
	root.add_child(source)
	while not source.showroom_ready: await process_frame
	page.showroom = source
	page.account_requested.connect(func() -> void: accounts += 1)
	for dimensions: Vector2i in [Vector2i(1138,535),Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,960),Vector2i(540,960),Vector2i(640,360)]:
		root.size = dimensions
		await settle()
		var dialog: ConfirmationDialog = await open_purchase()
		var label: String = "%dx%d" % [dimensions.x,dimensions.y]
		inspect(dialog,label)
		check(dialog.dialog_text.contains("750") and dialog.dialog_text.contains("2150"),"actual price/balance are retained")
		check(not dialog.get_ok_button().disabled,"affordable item can be bought")
		await capture(label)
		await dismiss(dialog)
	root.size = Vector2i(1280,720)
	await settle()
	var interactive: ConfirmationDialog = await open_purchase()
	var native: Node = interactive.vehicle_preview
	check(native.reused_meshes,"purchase preview shares existing Garage meshes")
	check(native.model.get_child_count() == source.car.find_children("*","MeshInstance3D",true,false).filter(func(mesh: MeshInstance3D) -> bool: return mesh.mesh != null and mesh.is_visible_in_tree()).size(),"snapshot contains every visible Garage mesh")
	var original_yaw: float = source.yaw
	var original_camera: Transform3D = source.camera.transform
	var original_livery: Dictionary = source.livery.duplicate(true)
	var first_yaw: float = native.yaw
	var at: Vector2 = native.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = at if pressed else at+Vector2(70,0)
		mouse.pressed = pressed
		interactive.push_input(mouse,true)
		if pressed:
			var motion := InputEventMouseMotion.new()
			motion.position = at+Vector2(70,0)
			motion.relative = Vector2(70,0)
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			interactive.push_input(motion,true)
	await settle()
	check(not is_equal_approx(native.yaw,first_yaw),"native mouse drag rotates the preview")
	var mouse_yaw: float = native.yaw
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.position = at
	touch.pressed = true
	interactive.push_input(touch,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = at+Vector2(-90,0)
	drag.relative = Vector2(-90,0)
	interactive.push_input(drag,true)
	touch = touch.duplicate()
	touch.position = drag.position
	touch.pressed = false
	interactive.push_input(touch,true)
	await settle()
	check(not is_equal_approx(native.yaw,mouse_yaw),"native touch drag rotates the preview")
	check(source.yaw == original_yaw and source.camera.transform == original_camera and source.livery == original_livery,"purchase rotation leaves the original Garage view and cosmetics exact")
	var idle_requests: int = native.render_requests
	await settle()
	check(native.render_requests == idle_requests and native.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS,"idle preview does not repeat render requests")
	await capture("rotated-preview")
	interactive.close_button.pressed.emit()
	await settle()
	check(page._purchase_dialog == null and economy.calls == 0,"Close cancels without a purchase")
	check(not is_instance_valid(native),"closing releases the temporary preview")
	interactive = await open_purchase()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	interactive.push_input(escape,true)
	await settle()
	check(page._purchase_dialog == null and economy.calls == 0,"Escape cancels without a purchase")
	interactive = await open_purchase()
	page._preview_serial += 1
	interactive.confirm_button.pressed.emit()
	await settle()
	check(page._purchase_dialog == null and economy.calls == 0,"stale preview cannot confirm a purchase")
	var rear: ConfirmationDialog = await open_purchase("GT wing","kit/compact/aero/wing")
	inspect(rear,"rear-aero")
	check(not rear.vehicle_preview.reused_meshes,"direct unpreviewed request builds its requested native appearance")
	check(rear.vehicle_preview.model.customisation.aero == "wing" and source.customisation.aero == "stock","direct request shows the requested wing without changing the Garage")
	check(cos(rear.vehicle_preview.yaw)<0,"rear aero opens from behind to show the selected part")
	await capture("rear-aero")
	await dismiss(rear)
	root.size = Vector2i(960,540)
	for state: String in ["unaffordable","busy","pending","guest","paint"]:
		economy.coins = 100 if state == "unaffordable" else 2150
		economy.busy = state == "busy"
		economy.pending = {"item_id":"fixture"} if state == "pending" else {}
		economy.signed_in = state != "guest"
		var dialog: ConfirmationDialog = await open_purchase("Twin intakes" if state != "paint" else "Checker fade","livery/checker_fade" if state == "paint" else "kit/compact/hood/twin_scoop")
		inspect(dialog,state)
		check(dialog.get_ok_button().disabled == (state in ["unaffordable","busy","pending"]),state+": purchase availability is preserved")
		await capture(state)
		if state == "guest":
			dialog.confirm_button.pressed.emit()
			await settle()
			check(accounts == 1 and economy.calls == 0,"guest confirmation requests account without a purchase")
		elif state == "paint":
			dialog.confirm_button.pressed.emit()
			dialog.confirm_button.pressed.emit()
			await settle()
			check(economy.calls == 1 and applications == 1,"confirmation buys and applies once through the original callback")
		else: await dismiss(dialog)
	economy.signed_in = true
	for locale: String in ["en","de","fr","fi","pt_BR","ja","ko"]:
		TranslationServer.set_locale(locale)
		GameFonts.configure(locale)
		var dialog: ConfirmationDialog = await open_purchase()
		inspect(dialog,"locale-"+locale)
		await capture("locale-"+locale)
		await dismiss(dialog)
	TranslationServer.set_locale("en")
	GameFonts.configure("en")
	# Exercise small logical viewports independently of the production canvas stretch.
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(640,360)
	await settle()
	var long_dialog: ConfirmationDialog = await open_purchase("Twin intakes with a longer translated customisation name")
	long_dialog.description.text += "\n"+"More detailed unlock information. ".repeat(80)
	await settle()
	inspect(long_dialog,"short-overflow")
	var chrome: Node = long_dialog
	check(chrome.copy_scroll.get_v_scroll_bar().visible,"overflow has a vertical scrollbar above the actions")
	chrome.copy_scroll.scroll_vertical = ceili(chrome.copy_scroll.get_v_scroll_bar().max_value)
	await settle()
	check(chrome.details.get_global_rect().end.y <= chrome.copy_scroll.get_global_rect().end.y+1,"scroll reaches the final message line")
	await capture("short-overflow")
	root.size = Vector2i(540,960)
	await settle()
	inspect(long_dialog,"portrait-resize")
	await capture("portrait-resize")
	await dismiss(long_dialog)
	page.queue_free()
	economy.queue_free()
	source.queue_free()
	await process_frame
	print("CUSTOMISATION_PURCHASE_LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
