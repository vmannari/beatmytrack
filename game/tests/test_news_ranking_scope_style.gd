extends SceneTree

const Fixture = preload("res://tests/test_garage_news.gd")
const RankingFixture = preload("res://tests/test_ranking_newspaper.gd")
const News = preload("res://backend/news_client.gd")
const Menu = preload("res://ui/garage_news_menu.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle(count: int = 15) -> void:
	for tick: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func watch(node: Node) -> void:
	if node is Window: preload("res://ui/popup_style.gd").watch(node)

func run() -> void:
	root.size = Vector2i(1280,720)
	node_added.connect(watch)
	var backend := RankingFixture.Backend.new()
	backend.hold_page = true
	root.add_child(backend)
	var service := News.new()
	service.client = backend
	service.read_state_path = "user://ranking-scope-test.cfg"
	root.add_child(service)
	var pane := Fixture.Pane.new()
	pane.theme = MenuStyle.theme()
	root.add_child(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu := Menu.new()
	menu.page = pane
	menu.service = service
	pane.tools.add_child(menu)
	await settle()
	menu._select_tab("ranking")
	var ranking: Node = menu._ranking
	var choice: OptionButton = ranking.selector
	var popup: PopupMenu = choice.get_popup()
	check(choice.get_theme_stylebox("normal").bg_color == Color("e3dbc6") and choice.get_theme_stylebox("disabled").bg_color == Color("e3dbc6"),"paper styles exist before the first frame")
	check(popup.has_meta("menu_popup_custom") and popup.get_theme_stylebox("panel").bg_color == Color("eee7d4"),"popup style exists before the first frame")
	await settle()
	check(choice.disabled,"scope selector is disabled during the initial ranking request")
	check(choice.get_theme_stylebox("disabled").bg_color == Color("e3dbc6"),"loading state has the paper background immediately")
	check(choice.get_theme_color("font_disabled_color") == Menu.INK,"loading state has readable ink immediately")
	check(popup.has_meta("menu_popup_custom") and not popup.has_meta("menu_popup_style"),"newspaper popup bypasses the shared dark chrome on entry")
	check(popup.get_theme_stylebox("panel").bg_color == Color("eee7d4"),"popup uses paper")
	check(popup.get_theme_color("font_color") == Menu.INK and popup.get_theme_color("font_hover_color") == Menu.INK,"popup choices use newspaper ink")
	check(popup.item_count == 4 and choice.selected == 0,"scope options and default selection remain intact")
	var output: String = ProjectSettings.globalize_path("res://../build/news-ranking-style")
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join("loading-"+RenderingServer.get_current_rendering_method()+".png")) == OK,"capture the loading state")
	backend.hold_page = false
	backend.reply.emit()
	await settle(30)
	check(not choice.disabled,"scope selector enables when the ranking arrives")
	check(choice.get_theme_stylebox("normal").bg_color == choice.get_theme_stylebox("disabled").bg_color,"selected control does not change paper style after loading")
	choice.show_popup()
	await settle()
	check(popup.visible,"scope popup opens")
	check(popup.position.y >= 0 and popup.position.y+popup.size.y <= root.size.y,"the complete popup fits in the window")
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join("open-"+RenderingServer.get_current_rendering_method()+".png")) == OK,"capture the open popup")
	var item_height: float = (popup.size.y-popup.get_theme_stylebox("panel").get_minimum_size().y)/4.0
	var point: Vector2 = Vector2(popup.position)+Vector2(popup.size.x*0.5,10+item_height*1.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move,true)
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click,true)
	await settle(30)
	check(choice.selected == 1 and backend.paths.back() == "/ranking?scope=country","clicking a popup item selects and loads that scope")
	if popup.visible: popup.hide()
	choice.select(2)
	choice.item_selected.emit(2)
	await settle(30)
	check(choice.selected == 2 and backend.paths.back() == "/ranking?scope=friends","selecting a scope keeps the existing ranking behavior")
	check(choice.get_theme_stylebox("normal").bg_color == Color("e3dbc6"),"selected scope retains paper style")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1600,900)]:
		root.size = dimensions
		await settle()
		choice.show_popup()
		await settle()
		check(popup.visible and popup.position.y >= 0 and popup.position.y+popup.size.y <= root.size.y,"popup fits "+str(dimensions))
		popup.hide()
	pane.queue_free()
	service.queue_free()
	backend.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ranking-scope-test.cfg"))
	print("NEWS RANKING SCOPE STYLE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
