extends SceneTree
## Real purchase dialog builder with an in-memory economy; no account or save writes.
const Chrome = preload("res://ui/popup_style.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/customisation-purchase-no-car-2026-10-27/native"
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
	for frame: int in range(14): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func open_purchase(title: String = "Twin intakes", id: String = "kit/compact/hood/twin_scoop") -> ConfirmationDialog:
	check(not page._require_owned(id,title,func() -> void: applications += 1),"locked item waits for confirmation")
	await settle()
	return page._purchase_dialog

func dismiss(dialog: ConfirmationDialog) -> void:
	dialog.cancel_button.pressed.emit()
	await settle()
	check(page._purchase_dialog == null and not is_instance_valid(dialog),"Not now releases the owned popup")

func inspect(dialog: ConfirmationDialog, label: String, overflow: bool = false) -> void:
	var view: Node = dialog
	var bounds := Rect2(Vector2.ZERO,Vector2(dialog.size))
	var body: Rect2 = view.copy_scroll.get_global_rect()
	check(dialog.has_meta("menu_popup_custom") and not dialog.has_node("PopupStyle"),label+": dedicated purchase presentation")
	check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),label+": popup fits viewport")
	check(dialog.find_children("*","SubViewport",true,false).is_empty(),label+": no 3D preview viewport")
	check(not dialog.has_node("PurchaseVehicle") and dialog.find_child("PurchaseRotateHint",true,false) == null,label+": no car or rotation instruction")
	check(view.details.get_global_rect().encloses(view.heading.get_global_rect()),label+": heading fits content")
	check(view.heading.get_global_rect().end.y+8 <= view.description.get_global_rect().position.y,label+": description clears heading")
	check(not view.heading.get_global_rect().intersects(view.close_button.get_global_rect()),label+": heading clears Close")
	check(not view.eyebrow.get_global_rect().intersects(view.close_button.get_global_rect()),label+": category clears Close")
	check(body.size.y >= 64,label+": usable text area")
	check(body.end.y+8 <= view.status_label.position.y,label+": status is reserved outside scrolling details")
	check(view.status_label.get_global_rect().end.y+8 <= view.confirm_button.position.y,label+": status clears primary action")
	check(view.status_label.get_minimum_size().y <= view.status_label.size.y+1,label+": complete availability message fits")
	check(view.confirm_button.get_global_rect().end.y <= view.cancel_button.position.y,label+": actions are separate")
	check(view.confirm_button.disabled == dialog.get_ok_button().disabled,label+": native purchase availability retained")
	check(view.price_label.text == "750",label+": real price")
	check(view.balance_label.text == "2,150" if economy.coins == 2150 else view.balance_label.text == "100" if economy.coins == 100 else view.balance_label.text == "0",label+": real balance")
	check(view.remaining_label.text == "1,400" if economy.coins == 2150 else view.remaining_label.text == "650" if economy.coins == 100 else view.remaining_label.text == "750",label+": factual remaining balance or shortfall")
	check(not view.copy_scroll.get_h_scroll_bar().visible,label+": no horizontal scroll")
	if not overflow:
		check(not view.copy_scroll.get_v_scroll_bar().visible,label+": normal purchase needs no scrolling")
		check(view.copy_scroll.get_global_rect().encloses(view.details.get_global_rect()),label+": full normal details are visible")
	for button: Button in [view.confirm_button,view.cancel_button,view.close_button]:
		check(bounds.encloses(button.get_global_rect()),label+": button fits "+button.name)
		check(button.size.y >= 48,label+": touch height "+button.name)
	print("PURCHASE_RECT: ",label," panel=",dialog.size," content=",view.details.size," scroll=",view.copy_scroll.size," status=",view.status_label.get_global_rect())

func localized(view: Node, locale: String, state: String) -> void:
	var source: String = "Permanent unlock for every car." if state == "paint" else "Permanent unlock for this car."
	check(view.description.text == str(TranslationServer.translate(source)),locale+"/"+state+": localized permanent unlock")
	check(view.close_button.tooltip_text == str(TranslationServer.translate("Close")),locale+"/"+state+": localized Close tooltip")
	for message: String in [source,"Your balance","After purchase","Still needed","Not now","Unlock for {price}","Exterior","Paint","Coins","Close","Sign in","Not enough coins. Complete more races.","Sign in to earn coins and unlock this item."]:
		var catalog: Translation = TranslationServer.get_translation_object(locale)
		check(catalog != null and not str(catalog.get_message(message)).is_empty(),locale+": packaged purchase translation "+message)
		# Exterior is also the authored Spanish and Portuguese word, not fallback.
		if locale != "en" and not (message == "Exterior" and locale in ["es","pt_BR"]): check(str(TranslationServer.translate(message)) != message,locale+": no English fallback for "+message)
	if state in ["zero","unaffordable"]:
		check(view.status_label.text == str(TranslationServer.translate("Not enough coins. Complete more races.")),locale+": localized insufficient-coins message")
	if state == "guest":
		check(view.status_label.text == str(TranslationServer.translate("Sign in to earn coins and unlock this item.")),locale+": localized sign-in message")

func run() -> void:
	OS.set_environment("BMT_API_URL","")
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
	page.kit_draft = VehicleCustomisation.defaults()
	page.account_requested.connect(func() -> void: accounts += 1)
	root.size = Vector2i(1280,720)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/languages.json"))
	for locale: String in manifest.languages:
		TranslationServer.set_locale(locale)
		GameFonts.configure(locale)
		var paid_size := Vector2i.ZERO
		for state: String in ["affordable","zero","unaffordable","busy","pending","guest","paint"]:
			economy.coins = 0 if state == "zero" else 100 if state == "unaffordable" else 2150
			economy.busy = state == "busy"
			economy.pending = {"item_id":"fixture"} if state == "pending" else {}
			economy.signed_in = state != "guest"
			var dialog: ConfirmationDialog = await open_purchase("Checker fade" if state == "paint" else "Twin intakes","livery/checker_fade" if state == "paint" else "kit/compact/hood/twin_scoop")
			inspect(dialog,locale+"/"+state)
			localized(dialog,locale,state)
			check(dialog.get_ok_button().disabled == (state in ["zero","unaffordable","busy","pending"]),locale+"/"+state+": affordability guard")
			if state == "affordable": paid_size = dialog.size
			if state in ["zero","unaffordable"]: check(dialog.size == paid_size,locale+"/"+state+": no-money state preserves the layout dimensions")
			if state in ["affordable","zero","guest"] or locale in ["en","fi"]: await capture(locale+"-"+state)
			await dismiss(dialog)
	TranslationServer.set_locale("en")
	GameFonts.configure("en")
	economy.signed_in = true
	economy.coins = 2150
	economy.busy = false
	economy.pending = {}
	for dimensions: Vector2i in [Vector2i(1138,535),Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,960),Vector2i(540,960),Vector2i(640,360)]:
		root.size = dimensions
		await settle()
		var dialog: ConfirmationDialog = await open_purchase()
		var name: String = "%dx%d" % [dimensions.x,dimensions.y]
		inspect(dialog,name)
		await capture(name)
		await dismiss(dialog)
	root.size = Vector2i(1280,720)
	var current: ConfirmationDialog = await open_purchase()
	TranslationServer.set_locale("fi")
	GameFonts.configure("fi")
	GameText.refresh(self)
	await settle()
	inspect(current,"live-language-change")
	localized(current,"fi","affordable")
	TranslationServer.set_locale("en")
	GameFonts.configure("en")
	GameText.refresh(self)
	await settle()
	current.close_button.pressed.emit()
	await settle()
	check(page._purchase_dialog == null and economy.calls == 0,"Close cancels without a purchase")
	current = await open_purchase()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	current.push_input(escape,true)
	await settle()
	check(page._purchase_dialog == null and economy.calls == 0,"Escape cancels without a purchase")
	current = await open_purchase()
	page._preview_serial += 1
	current.confirm_button.pressed.emit()
	await settle()
	check(page._purchase_dialog == null and economy.calls == 0,"stale context cannot confirm")
	economy.signed_in = false
	current = await open_purchase()
	current.confirm_button.pressed.emit()
	await settle()
	check(accounts == 1 and economy.calls == 0,"guest confirmation requests account without spending")
	economy.signed_in = true
	current = await open_purchase()
	current.confirm_button.pressed.emit()
	current.confirm_button.pressed.emit()
	await settle()
	check(economy.calls == 1 and applications == 1,"confirmation purchases/applies once")
	# Real overflow remains accessible only when the viewport or copy requires it.
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(640,360)
	await settle()
	current = await open_purchase("Twin intakes with a longer translated customisation name")
	current.description.text += "\n"+"More detailed unlock information. ".repeat(80)
	await settle()
	inspect(current,"short-overflow",true)
	check(current.copy_scroll.get_v_scroll_bar().visible,"genuine overflow remains scrollable")
	current.copy_scroll.scroll_vertical = ceili(current.copy_scroll.get_v_scroll_bar().max_value)
	await settle()
	check(current.details.get_global_rect().end.y <= current.copy_scroll.get_global_rect().end.y+1,"scroll reaches final line")
	await capture("short-overflow")
	root.size = Vector2i(540,960)
	await settle()
	inspect(current,"portrait-overflow",true)
	await dismiss(current)
	root.size = Vector2i(540,960)
	await settle()
	economy.coins = 0
	current = await open_purchase()
	inspect(current,"portrait-zero")
	await capture("portrait-zero")
	await dismiss(current)
	page.queue_free()
	economy.queue_free()
	await process_frame
	print("CUSTOMISATION_PURCHASE_LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
