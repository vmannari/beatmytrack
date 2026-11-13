extends SceneTree
## Real purchase dialog builder with an in-memory economy; no account or save writes.
const Chrome = preload("res://ui/popup_style.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/customisation-purchase-layout-2026-10-26/baseline"
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
	for frame: int in range(12): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func open_purchase(title: String = "Twin intakes", id: String = "compact/hood/twin_intakes") -> ConfirmationDialog:
	check(not page._require_owned(id,title,func() -> void: applications += 1),"locked item waits for confirmation")
	await settle()
	return page._purchase_dialog

func inspect(dialog: ConfirmationDialog, label: String) -> void:
	var chrome: Node = dialog.get_node("PopupStyle")
	var bounds := Rect2(Vector2.ZERO,Vector2(dialog.size))
	var actions: Control = dialog.get_ok_button().get_parent()
	var message_rect: Rect2 = chrome.message.get_global_rect()
	var body_rect: Rect2 = chrome.body.get_global_rect()
	var visible_body: Rect2 = chrome.message_scroll.get_global_rect() if chrome.get("message_scroll") != null else body_rect
	check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),label+": popup fits viewport")
	check(bounds.encloses(chrome.header.get_global_rect()),label+": heading fits panel")
	check(chrome.header.get_global_rect().end.y+12 <= visible_body.position.y,label+": body clears heading")
	check(visible_body.end.y+12 <= actions.position.y,label+": body clears actions")
	check(visible_body.size.y >= 64,label+": message keeps a usable visible area")
	check(message_rect.size.y+1 >= chrome.message.get_minimum_size().y,label+": full message has its natural height")
	check(not chrome.header.get_global_rect().intersects(chrome.close_button.get_global_rect()),label+": title clears Close")
	for button: Button in [dialog.get_ok_button(),dialog.get_cancel_button(),chrome.close_button]:
		check(bounds.encloses(button.get_global_rect()),label+": button fits panel "+button.text)
		check(button.size.y >= 48,label+": touch height "+button.text)
	print("PURCHASE_RECT: ",label," viewport=",root.get_visible_rect()," panel=",dialog.size," message=",message_rect," body=",body_rect," actions=",actions.get_global_rect())

func dismiss(dialog: ConfirmationDialog) -> void:
	dialog.get_cancel_button().pressed.emit()
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
	root.size = Vector2i(960,540)
	for state: String in ["unaffordable","busy","pending","guest","paint"]:
		economy.coins = 100 if state == "unaffordable" else 2150
		economy.busy = state == "busy"
		economy.pending = {"item_id":"fixture"} if state == "pending" else {}
		economy.signed_in = state != "guest"
		var dialog: ConfirmationDialog = await open_purchase("Twin intakes" if state != "paint" else "Checker fade","livery/checker_fade" if state == "paint" else "compact/hood/twin_intakes")
		inspect(dialog,state)
		check(dialog.get_ok_button().disabled == (state in ["unaffordable","busy","pending"]),state+": purchase availability is preserved")
		await capture(state)
		if state == "guest":
			dialog.get_ok_button().pressed.emit()
			await settle()
			check(accounts == 1 and economy.calls == 0,"guest confirmation requests account without a purchase")
		elif state == "paint":
			dialog.get_ok_button().pressed.emit()
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
	long_dialog.dialog_text += "\n"+"More detailed unlock information. ".repeat(80)
	await settle()
	inspect(long_dialog,"short-overflow")
	var chrome: Node = long_dialog.get_node("PopupStyle")
	check(chrome.message_scroll != null and chrome.message_scroll.get_v_scroll_bar().visible,"overflow has a vertical scrollbar above the actions")
	chrome.message_scroll.scroll_vertical = ceili(chrome.message_scroll.get_v_scroll_bar().max_value)
	await settle()
	check(chrome.message.get_global_rect().end.y <= chrome.message_scroll.get_global_rect().end.y+1,"scroll reaches the final message line")
	await capture("short-overflow")
	root.size = Vector2i(540,960)
	await settle()
	inspect(long_dialog,"portrait-resize")
	await capture("portrait-resize")
	await dismiss(long_dialog)
	page.queue_free()
	economy.queue_free()
	await process_frame
	print("CUSTOMISATION_PURCHASE_LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
