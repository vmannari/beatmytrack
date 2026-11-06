extends Node
## Creator landing UI; the native editor loads only when a document opens.

func run_new_document(app: Node) -> void:
	if app.screen == "create" and app._editor_has_unsaved_changes():
		app._confirm_editor_departure(app._start_new_document)
		return
	app._start_new_document()

func run_start_new_document(app: Node) -> void:
	app._flush_editor_writes()
	app._finish_preview_thread()
	app.editor_view.clear()
	app.object_browser_state.clear()
	app.canvas = null
	app.document = TrackDocument.create_blank()
	app.document.id = TrackLibrary.unique_id()
	app.editor_saved_snapshot = {}
	app._stamp_creator()
	app.history.clear()
	app.redo_history.clear()
	app._navigate_menu_page("biome")
	app.object_browser = null
	app.object_browser_state.clear()

func run_choose_biome(app: Node, parent: VBoxContainer = null, preview: bool = false) -> void:
	if parent == null: parent = app.content
	if not preview and app.screen != "biome": return
	if app.document.is_empty() and not preview:
		app.document = TrackDocument.create_blank()
		app.document.id = TrackLibrary.unique_id()
		app._stamp_creator()
	var heading_row = HBoxContainer.new()
	heading_row.add_theme_constant_override("separation",20)
	parent.add_child(heading_row)
	var heading_copy = VBoxContainer.new()
	heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_copy.add_theme_constant_override("separation",2)
	heading_row.add_child(heading_copy)
	app._heading("NEW TRACK", "Select biome",heading_copy)
	var load_track = MenuStyle.button("LOAD TRACK",app._open_drafts)
	load_track.name = "LoadTrack"
	load_track.icon = MenuIcon.texture("folder")
	load_track.custom_minimum_size = Vector2(190,58)
	load_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading_row.add_child(load_track)
	var selected_biome: String = str(app.document.get("theme",TrackDocument.THEMES[0]))
	if selected_biome not in TrackDocument.THEMES: selected_biome = TrackDocument.THEMES[0]
	parent.set_meta("biome_theme",selected_biome)
	var cards = HBoxContainer.new()
	cards.name = "BiomePicker"
	cards.add_theme_constant_override("separation",16)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(cards)
	for biome: String in TrackDocument.THEMES:
		var card = Button.new()
		card.name = "Biome_"+biome
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(180,260)
		card.clip_contents = true
		card.text = ""
		var selected: bool = biome == selected_biome
		var card_style = MenuStyle.box(Color.TRANSPARENT,0)
		card_style.set_corner_radius_all(0)
		card_style.border_color = MenuStyle.BORDER
		card_style.set_border_width_all(1)
		for state: String in ["normal","hover","pressed","focus"]:
			card.add_theme_stylebox_override(state,card_style)
		var picture = TextureRect.new()
		picture.name = "BiomePicture"
		picture.texture = TrackTile.scenery_texture(biome)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.modulate = Color.WHITE if selected else Color(0.62,0.68,0.72)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyle.fill(picture)
		card.add_child(picture)
		var label_panel = PanelContainer.new()
		label_panel.name = "BiomeLabelOverlay"
		label_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_panel.anchor_left = 0.0
		label_panel.anchor_top = 1.0
		label_panel.anchor_right = 1.0
		label_panel.anchor_bottom = 1.0
		label_panel.offset_top = -72
		label_panel.offset_bottom = -8
		var label_style = MenuStyle.box(MenuStyle.ACCENT if selected else Color("091720f2"),0)
		label_style.set_corner_radius_all(0)
		label_panel.add_theme_stylebox_override("panel",label_style)
		var label_center = CenterContainer.new()
		label_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_panel.add_child(label_center)
		var label_row = HBoxContainer.new()
		label_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_row.add_theme_constant_override("separation",10)
		label_center.add_child(label_row)
		var icon = TextureRect.new()
		icon.name = "BiomeIcon"
		icon.modulate = MenuStyle.INK if selected else (Color("c7dfff") if biome != "night_city" else Color("f1f4f3"))
		icon.texture = MenuIcon.texture({"pine":"leaf","desert":"cactus","night_city":"night","winter":"snowflake","storm":"storm"}.get(biome,"biomes"))
		icon.custom_minimum_size = Vector2(30,30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_row.add_child(icon)
		var label = MenuStyle.label("",26)
		GameText.bind_upper(label,TrackTheme.title(biome))
		label.name = "BiomeTitle"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if selected: label.add_theme_color_override("font_color",MenuStyle.INK)
		label_row.add_child(label)
		card.add_child(label_panel)
		card.pressed.connect(app._preview_creation_biome.bind(biome))
		cards.add_child(card)
	var summary_panel = PanelContainer.new()
	summary_panel.name = "BiomeSummary"
	summary_panel.custom_minimum_size.y = 118
	summary_panel.add_theme_stylebox_override("panel",MenuStyle.card(16))
	parent.add_child(summary_panel)
	var summary_row = HBoxContainer.new()
	summary_row.add_theme_constant_override("separation",20)
	summary_panel.add_child(summary_row)
	var copy = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation",4)
	summary_row.add_child(copy)
	var summary_title = HBoxContainer.new()
	summary_title.add_theme_constant_override("separation",10)
	copy.add_child(summary_title)
	var summary_icon = TextureRect.new()
	summary_icon.name = "BiomeSummaryIcon"
	summary_icon.modulate = Color("c7dfff") if selected_biome != "night_city" else Color("f1f4f3")
	summary_icon.texture = MenuIcon.texture({"pine":"leaf","desert":"cactus","night_city":"night","winter":"snowflake","storm":"storm"}.get(selected_biome,"biomes"))
	summary_icon.custom_minimum_size = Vector2(34,34)
	summary_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	summary_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	summary_title.add_child(summary_icon)
	var title = MenuStyle.label("",28)
	GameText.bind_upper(title,TrackTheme.title(selected_biome))
	title.name = "BiomeSummaryTitle"
	summary_title.add_child(title)
	var description = MenuStyle.label(str(app.CREATION_BIOME_DESCRIPTIONS[selected_biome]),18,true)
	description.name = "BiomeDescription"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(description)
	description.resized.connect(app._size_creation_biome_description.bind(description))
	description.minimum_size_changed.connect(app._size_creation_biome_description.bind(description))
	summary_row.add_child(VSeparator.new())
	var create = MenuStyle.button("CREATE TRACK",func() -> void: app._select_creation_biome(str(parent.get_meta("biome_theme"))),true)
	create.name = "CreateTrack"
	create.icon = MenuIcon.texture("create")
	create.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	create.add_theme_color_override("icon_hover_color",MenuStyle.INK)
	create.add_theme_color_override("icon_pressed_color",MenuStyle.INK)
	create.custom_minimum_size = Vector2(250,70)
	create.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	create.add_theme_font_size_override("font_size",26)
	summary_row.add_child(create)

func run_size_creation_biome_description(app: Node, description: Label) -> void:
	if description.size.x <= 0: return
	var font: Font = description.get_theme_font("font")
	var font_size: int = description.get_theme_font_size("font_size")
	var spacing: int = description.get_theme_constant("line_spacing")
	var line_height: float = font.get_height(font_size)
	var metrics: Array = [description.size.x,TranslationServer.get_locale(),font,font_size,spacing,line_height]
	if description.get_meta("biome_description_metrics",[]) == metrics: return
	description.set_meta("biome_description_metrics",metrics)
	# Reserve the tallest localized description at this width, regardless of
	# selection. Recalculate on width/font/locale changes, never on a biome tap.
	var height: float = 0.0
	for source: String in app.CREATION_BIOME_DESCRIPTIONS.values():
		var paragraph = TextParagraph.new()
		paragraph.width = description.size.x
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		paragraph.add_string(GameText.message(source),font,font_size,TranslationServer.get_locale())
		var lines: int = paragraph.get_line_count()
		height = maxf(height,maxf(paragraph.get_size().y,line_height*lines)+maxi(0,lines-1)*spacing)
	description.custom_minimum_size.y = ceilf(height)

func run_preview_creation_biome(app: Node, biome: String) -> void:
	if app.screen != "biome" or biome not in TrackDocument.THEMES: return
	app.document.theme = biome
	app._update_creation_biome(app.content,biome)

func run_update_creation_biome(app: Node, parent: VBoxContainer, biome: String) -> void:
	var previous: String = str(parent.get_meta("biome_theme",""))
	if previous == biome or biome not in TrackDocument.THEMES: return
	# Selection owns only these existing controls. Keep the shell, focus and
	# prepared swipe pages alive; no navigation or page warming runs on a tap.
	var cards: HBoxContainer = parent.find_child("BiomePicker",true,false)
	for id: String in [previous,biome]:
		var card: Button = cards.get_node_or_null("Biome_"+id)
		if card == null: continue
		var selected: bool = id == biome
		var picture: TextureRect = card.get_node("BiomePicture")
		picture.modulate = Color.WHITE if selected else Color(0.62,0.68,0.72)
		var band: PanelContainer = card.get_node("BiomeLabelOverlay")
		var style: StyleBoxFlat = band.get_theme_stylebox("panel")
		style.bg_color = MenuStyle.ACCENT if selected else Color("091720f2")
		var icon: TextureRect = card.find_child("BiomeIcon",true,false)
		icon.modulate = MenuStyle.INK if selected else (Color("c7dfff") if id != "night_city" else Color("f1f4f3"))
		var label: Label = card.find_child("BiomeTitle",true,false)
		label.add_theme_color_override("font_color",MenuStyle.INK if selected else MenuStyle.TEXT)
	var summary: PanelContainer = parent.find_child("BiomeSummary",true,false)
	var summary_icon: TextureRect = summary.find_child("BiomeSummaryIcon",true,false)
	var chosen_icon: TextureRect = cards.get_node("Biome_"+biome).find_child("BiomeIcon",true,false)
	summary_icon.texture = chosen_icon.texture
	summary_icon.modulate = Color("c7dfff") if biome != "night_city" else Color("f1f4f3")
	var title: Label = summary.find_child("BiomeSummaryTitle",true,false)
	GameText.bind_upper(title,TrackTheme.title(biome))
	var description: Label = summary.find_child("BiomeDescription",true,false)
	description.text = str(app.CREATION_BIOME_DESCRIPTIONS[biome])
	parent.set_meta("biome_theme",biome)

func run_select_creation_biome(app: Node, biome: String) -> void:
	if app.screen != "biome" or biome not in TrackDocument.THEMES: return
	app.document.theme = biome
	app.history.clear()
	app.redo_history.clear()
	app._show_screen("create")
	app._notify_creation_slots(str(app.document.id))

func run_notify_creation_slots(app: Node, id: String) -> void:
	if app.lifecycle == null or app.online == null or not app.online.client.signed_in(): return
	var owner_scope: String = app.lifecycle.scope()
	await app.lifecycle.refresh_publishing_slots(true)
	if app.screen == "create" and str(app.document.get("id","")) == id and app.lifecycle.scope() == owner_scope and app.lifecycle.no_publishing_slots():
		app._notice(TrackLifecycle.NO_SLOTS)

