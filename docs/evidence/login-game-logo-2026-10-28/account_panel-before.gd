extends PanelContainer
## Provider choice first; only authenticated new players see name selection.
signal continue_requested
var account: Node
var username: LineEdit
var country_picker: Button
var country_save: Button
var country_group: VBoxContainer
var country_player_id: String = ""
var title: Label
var subtitle: Label
var status_label: Label
var google_button: Button
var development_button: Button
var logout_button: Button
var delete_button: Button
var cancel_button: Button
var refresh_button: Button
var save_button: Button
var guest_button: BaseButton
var footer: Label
var divider: HBoxContainer
var google_status: Label
var column: VBoxContainer
var accent: ColorRect
var privacy_note: Label
var terms_row: HBoxContainer
var terms_check: CheckBox
var terms_copy: RichTextLabel
var terms_divider: HSeparator

func centered_label(text: String, font_size: int, muted: bool = false) -> Label:
	var label: Label = MenuStyle.label(text, font_size, muted)
	label.add_theme_font_override("font", MenuStyle.BODY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _ready() -> void:
	name = "AccountCard"
	var style := MenuStyle.box(Color(0.035, 0.078, 0.095, 0.97), 28)
	style.set_corner_radius_all(18)
	style.border_color = Color("d4e0e5")
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 16
	add_theme_stylebox_override("panel", style)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var mark := TextureRect.new()
	mark.texture = preload("res://assets/menu/sign_in_mark.svg")
	mark.custom_minimum_size = Vector2(36, 40)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(mark)
	var wordmark := MenuStyle.label("BEAT MY TRACK", 22)
	wordmark.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	wordmark.add_theme_color_override("font_color", Color("ffbf16"))
	var italic := FontVariation.new()
	italic.base_font = MenuStyle.DISPLAY
	italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.16, 1), Vector2.ZERO)
	italic.spacing_glyph = 3
	wordmark.add_theme_font_override("font", italic)
	wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wordmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(wordmark)
	var language := preload("res://ui/language_picker.gd").new()
	language.show_label = false
	language.compact = true
	header.add_child(language)
	title = MenuStyle.label("Ready to race?", 70)
	title.name = "SignInHeading"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	subtitle = MenuStyle.label("Sign in to save results online, join events and race friends.", 26, true)
	subtitle.add_theme_font_override("font", MenuStyle.BODY)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	var accent_space := MarginContainer.new()
	accent_space.add_theme_constant_override("margin_top", 8)
	accent_space.add_theme_constant_override("margin_bottom", 8)
	accent = ColorRect.new()
	accent.color = Color("ffbf16")
	accent.custom_minimum_size = Vector2(58, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_space.add_child(accent)
	column.add_child(accent_space)
	google_button = preload("res://ui/google_sign_in_button.gd").new()
	google_button.prominent = true
	google_button.pressed.connect(account.sign_in_google)
	google_button.name = "GoogleSignIn"
	column.add_child(google_button)
	google_button.custom_minimum_size.y = 68
	google_status = centered_label("Google sign-in is awaiting setup.", 16, true)
	column.add_child(google_status)
	development_button = MenuStyle.button("Development · Beat My Track", account.sign_in_developer)
	development_button.name = "DevelopmentSignIn"
	development_button.custom_minimum_size = Vector2(0, 48)
	development_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	development_button.add_theme_font_override("font", MenuStyle.BODY)
	var dev_style := MenuStyle.box(Color(0.25, 0.30, 0.38, 0.68), 12)
	dev_style.set_corner_radius_all(12)
	dev_style.set_border_width_all(1)
	dev_style.border_color = Color(0.58, 0.66, 0.75, 0.55)
	development_button.add_theme_stylebox_override("normal", dev_style)
	column.add_child(development_button)
	username = LineEdit.new()
	username.name = "PlayerUsername"
	username.placeholder_text = "Your racing name"
	username.max_length = 40
	username.custom_minimum_size.y = 54
	username.text_submitted.connect(func(_value: String) -> void: _save_name())
	column.add_child(username)
	country_group = VBoxContainer.new()
	country_group.add_theme_constant_override("separation",8)
	column.add_child(country_group)
	country_group.add_child(centered_label("Your flag appears beside you in standings.",16,true))
	country_picker = preload("res://ui/country_picker.gd").new()
	country_picker.country_selected.connect(func(_code: String) -> void: _country_changed())
	country_group.add_child(country_picker)
	country_save = MenuStyle.button("Save country",_save_country,true)
	country_save.name = "SavePlayerCountry"
	country_group.add_child(country_save)
	save_button = MenuStyle.button("Save name & continue", _save_name, true)
	save_button.name = "SavePlayerName"
	column.add_child(save_button)
	status_label = centered_label("", 18, true)
	column.add_child(status_label)
	cancel_button = MenuStyle.button("Cancel sign-in", account.cancel_google)
	column.add_child(cancel_button)
	refresh_button = MenuStyle.button("Retry connection", account.refresh_options)
	column.add_child(refresh_button)
	guest_button = LinkButton.new()
	guest_button.text = "Play as guest"
	guest_button.pressed.connect(func() -> void: continue_requested.emit())
	guest_button.name = "ContinueWithoutSignIn"
	guest_button.custom_minimum_size.y = 48
	guest_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	guest_button.add_theme_font_override("font", MenuStyle.BODY)
	guest_button.add_theme_font_size_override("font_size", 22)
	guest_button.add_theme_color_override("font_color", MenuStyle.TEXT)
	guest_button.add_theme_color_override("font_disabled_color", MenuStyle.MUTED)
	guest_button.add_theme_color_override("font_hover_color", MenuStyle.ACCENT)
	column.add_child(guest_button)
	footer = centered_label("Local progress stays on this device. Events require sign-in.", 17, true)
	column.add_child(footer)
	logout_button = MenuStyle.button("Sign out", account.sign_out)
	logout_button.name = "SignOut"
	column.add_child(logout_button)
	delete_button = MenuStyle.button("Delete account",_confirm_deletion)
	delete_button.name = "DeleteAccount"
	column.add_child(delete_button)
	divider = HBoxContainer.new()
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.add_child(line)
	column.add_child(divider)
	terms_row = HBoxContainer.new()
	terms_row.name = "DraftTermsAgreement"
	terms_row.add_theme_constant_override("separation", 10)
	column.add_child(terms_row)
	terms_check = CheckBox.new()
	terms_check.name = "AgreeToDraftTerms"
	terms_check.custom_minimum_size = Vector2(44, 48)
	terms_check.add_theme_icon_override("unchecked", preload("res://assets/menu/sign_in_checkbox.svg"))
	terms_check.add_theme_icon_override("checked", preload("res://assets/menu/sign_in_checkbox_checked.svg"))
	var check_style := StyleBoxEmpty.new()
	check_style.set_content_margin_all(8)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		terms_check.add_theme_stylebox_override(state, check_style)
	terms_check.add_theme_stylebox_override("focus", MenuStyle.theme().get_stylebox("focus", "Button"))
	terms_check.accessibility_name = tr("I agree to the draft Terms of Service")
	terms_check.toggled.connect(func(_checked: bool) -> void: _update())
	terms_row.add_child(terms_check)
	terms_copy = RichTextLabel.new()
	terms_copy.name = "DraftTermsLink"
	terms_copy.bbcode_enabled = true
	terms_copy.fit_content = true
	terms_copy.scroll_active = false
	terms_copy.custom_minimum_size.y = 48
	terms_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terms_copy.add_theme_font_override("normal_font", MenuStyle.BODY)
	terms_copy.add_theme_font_size_override("normal_font_size", 19)
	var terms_inset := StyleBoxEmpty.new()
	terms_inset.content_margin_top = 10
	terms_copy.add_theme_stylebox_override("normal", terms_inset)
	terms_copy.meta_clicked.connect(func(_meta: Variant) -> void: _open_terms())
	terms_row.add_child(terms_copy)
	terms_divider = HSeparator.new()
	column.add_child(terms_divider)
	var privacy := LinkButton.new()
	privacy.text = "Privacy policy"
	privacy.pressed.connect(func() -> void:
		if not account.client.base_url().is_empty(): account.open_browser.call(account.client.base_url()+"/privacy"))
	privacy.name = "AccountPrivacyPolicy"
	privacy.custom_minimum_size.y = 44
	privacy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	privacy.add_theme_font_override("font", MenuStyle.BODY)
	privacy.add_theme_font_size_override("font_size", 17)
	privacy.add_theme_color_override("font_color", MenuStyle.MUTED)
	privacy.add_theme_color_override("font_disabled_color", MenuStyle.MUTED.darkened(0.2))
	privacy.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	privacy.disabled = account.client.base_url().is_empty()
	column.add_child(privacy)
	privacy_note = centered_label("Optional usage and performance sharing is off until you enable it in Settings → Privacy. Online racing sends the evidence needed to verify your results.", 15, true)
	column.add_child(privacy_note)
	account.changed.connect(_update)
	resized.connect(_fit_typography)
	_update()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(title):
		_fit_typography.call_deferred()
		_update_terms_copy.call_deferred()

func _update_terms_copy() -> void:
	terms_check.accessibility_name = tr("I agree to the draft Terms of Service")
	terms_copy.text = "[center]" + GameText.message("I agree to the {terms}", {"terms":"[url=terms][color=#ffbf16]" + tr("Terms of Service (draft)") + "[/color][/url]"}) + "[/center]"

func _open_terms() -> void:
	if has_node("DraftTermsDialog"): return
	var dialog := preload("res://ui/draft_terms_dialog.gd").new()
	add_child(dialog)
	dialog.popup_centered()

func _fit_typography() -> void:
	if not is_instance_valid(title): return
	var compact: bool = account.client.signed_in() or account.waiting_for_google or account.retry_available or not account.configured or account.show_development()
	var long_copy: bool = not compact and tr(subtitle.text).length() > 70
	var font_size: int = 36 if account.client.signed_in() else 40 if compact else 60 if long_copy else 70
	var font: Font = title.get_theme_font("font")
	var available: float = maxf(1, size.x - (40 if compact else 56))
	while font_size > 32 and font.get_string_size(tr(title.text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 1
	title.add_theme_font_size_override("font_size", font_size)
	if not compact:
		subtitle.add_theme_font_size_override("font_size", 22 if long_copy else 26)
		column.add_theme_constant_override("separation", 6 if long_copy else 8)
		var style: StyleBoxFlat = get_theme_stylebox("panel")
		style.set_content_margin_all(24 if long_copy else 28)

func fit_width() -> void:
	if not is_inside_tree(): return
	var compact: bool = account.client.signed_in() or account.waiting_for_google or account.retry_available or not account.configured or account.show_development()
	custom_minimum_size.x = clampf(get_viewport_rect().size.x * 0.405, 600 if compact else 516, 620)

func _save_name() -> void:
	if country_picker.country_code.is_empty():
		account.message = "Choose your country before continuing."
		account.changed.emit()
		return
	await account.save_username(username.text,country_picker.country_code)

func _confirm_deletion() -> void:
	if account.busy or not account.client.signed_in(): return
	var dialog := preload("res://ui/account_deletion_dialog.gd").new()
	add_child(dialog)
	dialog.open_for(account)

func _country_changed() -> void:
	country_save.disabled = account.busy or country_picker.country_code == str(account.client.player.get("country_code",""))

func _save_country() -> void:
	await account.save_country(country_picker.country_code)

func _update() -> void:
	var signed_in: bool = account.client.signed_in()
	var onboarding: bool = account.needs_username()
	var waiting: bool = account.waiting_for_google
	terms_row.visible = not signed_in and not waiting and OS.is_debug_build()
	terms_divider.visible = terms_row.visible
	var agreed: bool = not terms_row.visible or terms_check.button_pressed
	_update_terms_copy()
	title.text = "Ready to race?" if not signed_in else "Choose your name" if onboarding else "Choose your country" if account.needs_country() else "Your account"
	subtitle.text = "This is the name other racers will see." if onboarding else (account.player_name() if signed_in else "Sign in to save results online, join events and race friends.")
	subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED if signed_in and not onboarding else Node.AUTO_TRANSLATE_MODE_INHERIT
	username.visible = onboarding
	username.editable = not account.busy
	save_button.visible = onboarding
	save_button.disabled = account.busy
	country_group.visible = signed_in
	country_picker.disabled = account.busy
	var player_id: String = str(account.client.player.get("id",""))
	if player_id != country_player_id:
		country_player_id = player_id
		country_picker.set_country(str(account.client.player.get("country_code","")))
	if country_picker.country_code.is_empty(): country_picker.set_country(str(account.client.player.get("country_code","")))
	if account.message == "Country saved.": country_picker.set_country(str(account.client.player.get("country_code","")))
	country_save.visible = signed_in and not onboarding
	_country_changed()
	google_button.visible = not signed_in and not waiting
	google_button.disabled = account.busy or not account.configured or not agreed
	google_status.visible = not signed_in and not waiting and not account.capabilities.is_empty() and not account.google_available()
	development_button.visible = not signed_in and not waiting and account.show_development()
	development_button.disabled = account.busy or not account.configured or not agreed
	logout_button.visible = signed_in
	logout_button.disabled = account.busy
	delete_button.visible = signed_in
	delete_button.disabled = account.busy or not account.client.deletion_supported()
	cancel_button.visible = waiting
	cancel_button.disabled = account._cancelled
	refresh_button.visible = account.retry_available and not account.busy
	status_label.text = account.message
	status_label.visible = not account.message.is_empty() and account.message not in ["Choose how to sign in.", "Signed in as " + account.player_name() + ".", "Choose the name other racers will see."]
	divider.visible = not signed_in
	guest_button.visible = not onboarding
	guest_button.disabled = waiting or not agreed
	guest_button.text = "Continue racing  ›" if signed_in else "Play as guest"
	footer.visible = not signed_in and not waiting
	privacy_note.visible = signed_in
	var compact: bool = signed_in or waiting or account.retry_available or not account.configured or account.show_development()
	accent.get_parent().visible = not compact
	# Additional provider/profile controls keep the previous 600-unit width.
	fit_width()
	subtitle.add_theme_font_size_override("font_size", 20 if compact else 26)
	column.add_theme_constant_override("separation", 4 if compact else 8)
	var style: StyleBoxFlat = get_theme_stylebox("panel")
	style.set_content_margin_all(16 if compact else 28)
	google_button.custom_minimum_size.y = 60 if compact else 68
	custom_minimum_size.y = 0 if compact else 532
	_fit_typography.call_deferred()
