extends PanelContainer
## Provider choice first; only authenticated new players see name selection.
signal continue_requested
var account: Node
var username: LineEdit
var title: Label
var subtitle: Label
var status_label: Label
var google_button: Button
var development_button: Button
var logout_button: Button
var cancel_button: Button
var refresh_button: Button
var save_button: Button
var guest_button: Button
var footer: Label
var divider: HBoxContainer
var google_status: Label

func centered_label(text: String, font_size: int, muted: bool = false) -> Label:
	var label: Label = MenuStyle.label(text, font_size, muted)
	label.add_theme_font_override("font", MenuStyle.BODY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _ready() -> void:
	var style := MenuStyle.box(Color(0.045, 0.078, 0.12, 0.91), 28)
	style.set_corner_radius_all(22)
	style.border_color = Color(0.68, 0.77, 0.83, 0.40)
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 16
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	title = centered_label("Sign in", 42)
	column.add_child(title)
	subtitle = centered_label("Your racing profile. Your next personal best.", 20, true)
	column.add_child(subtitle)
	var space := Control.new()
	space.custom_minimum_size.y = 6
	column.add_child(space)
	google_button = preload("res://ui/google_sign_in_button.gd").new()
	google_button.pressed.connect(account.sign_in_google)
	google_button.name = "GoogleSignIn"
	column.add_child(google_button)
	google_button.custom_minimum_size.y = 80
	google_status = centered_label("Google sign-in is awaiting setup.", 16, true)
	column.add_child(google_status)
	development_button = MenuStyle.button("Development · developer", account.sign_in_developer)
	development_button.name = "DevelopmentSignIn"
	development_button.custom_minimum_size = Vector2(360, 60)
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
	save_button = MenuStyle.button("Save name & continue", _save_name, true)
	save_button.name = "SavePlayerName"
	column.add_child(save_button)
	status_label = centered_label("", 18, true)
	column.add_child(status_label)
	cancel_button = MenuStyle.button("Cancel sign-in", account.cancel_google)
	column.add_child(cancel_button)
	refresh_button = MenuStyle.button("Retry connection", account.refresh_options)
	column.add_child(refresh_button)
	divider = HBoxContainer.new()
	for index: int in range(3):
		if index == 1:
			var or_label := centered_label("OR", 16, true)
			or_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			or_label.custom_minimum_size.x = 48
			divider.add_child(or_label)
		else:
			var line := HSeparator.new()
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			divider.add_child(line)
	column.add_child(divider)
	guest_button = MenuStyle.button("Play as guest  ›", func() -> void: continue_requested.emit())
	guest_button.name = "ContinueWithoutSignIn"
	guest_button.add_theme_font_override("font", MenuStyle.BODY)
	guest_button.add_theme_color_override("font_color", Color("90d4ff"))
	guest_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	column.add_child(guest_button)
	footer = centered_label("You can sign in whenever you're ready.", 16, true)
	column.add_child(footer)
	logout_button = MenuStyle.button("Sign out", account.sign_out)
	column.add_child(logout_button)
	account.changed.connect(_update)
	_update()

func _save_name() -> void:
	await account.save_username(username.text)
	if account.client.signed_in() and not account.needs_username():
		continue_requested.emit()

func _update() -> void:
	var signed_in: bool = account.client.signed_in()
	var onboarding: bool = account.needs_username()
	var waiting: bool = account.waiting_for_google
	title.text = "Choose your name" if onboarding else ("You're signed in" if signed_in else "Sign in")
	subtitle.text = "This is the name other racers will see." if onboarding else (account.player_name() if signed_in else "Your racing profile. Your next personal best.")
	username.visible = onboarding
	username.editable = not account.busy
	save_button.visible = onboarding
	save_button.disabled = account.busy
	google_button.visible = not signed_in and not waiting
	google_button.disabled = account.busy or not account.configured
	google_status.visible = not signed_in and not waiting and not account.capabilities.is_empty() and not account.google_available()
	development_button.visible = not signed_in and not waiting and account.show_development()
	development_button.disabled = account.busy or not account.configured
	logout_button.visible = signed_in
	logout_button.disabled = account.busy
	cancel_button.visible = waiting
	cancel_button.disabled = account._cancelled
	refresh_button.visible = account.retry_available and not account.busy
	status_label.text = account.message
	status_label.visible = not account.message.is_empty() and account.message not in ["Choose how to sign in.", "Signed in as " + account.player_name() + ".", "Choose the name other racers will see."]
	divider.visible = not signed_in
	guest_button.visible = not onboarding
	guest_button.disabled = waiting
	guest_button.text = "Continue racing  ›" if signed_in else "Play as guest  ›"
	footer.visible = not signed_in and not waiting
