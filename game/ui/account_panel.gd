extends PanelContainer
## Both sign-in paths share the same account/session UI.
var account: Node
var username: LineEdit
var status_label: Label
var google_button: Button
var development_button: Button
var logout_button: Button
var cancel_button: Button
var refresh_button: Button
var username_label: Label

func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	column.add_child(MenuStyle.label("YOUR ACCOUNT", 32))
	status_label = MenuStyle.label("", 20, true)
	status_label.custom_minimum_size.y = 58
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	username_label = MenuStyle.label("Choose your player name", 18)
	column.add_child(username_label)
	username = LineEdit.new()
	username.name = "PlayerUsername"
	username.placeholder_text = "Your username"
	username.max_length = 40
	username.custom_minimum_size.y = 54
	column.add_child(username)
	google_button = MenuStyle.button("Continue with Google", func() -> void: account.sign_in_google(username.text), true)
	google_button.name = "GoogleSignIn"
	column.add_child(google_button)
	development_button = MenuStyle.button("Development · developer", account.sign_in_developer)
	development_button.name = "DevelopmentSignIn"
	column.add_child(development_button)
	logout_button = MenuStyle.button("Sign out", account.sign_out)
	column.add_child(logout_button)
	cancel_button = MenuStyle.button("Cancel sign-in", account.cancel_google)
	column.add_child(cancel_button)
	refresh_button = MenuStyle.button("Retry connection", account.refresh_options)
	column.add_child(refresh_button)
	account.changed.connect(_update)
	_update()

func _update() -> void:
	var signed_in: bool = account.client.signed_in()
	status_label.text = account.message
	username.visible = not signed_in
	username_label.visible = not signed_in
	username.editable = not account.busy
	google_button.visible = not signed_in
	google_button.disabled = account.busy or not account.configured
	development_button.visible = not signed_in and account.show_development()
	development_button.disabled = account.busy or not account.configured
	logout_button.visible = signed_in
	logout_button.disabled = account.busy
	cancel_button.visible = account.waiting_for_google
	cancel_button.disabled = account._cancelled
	refresh_button.visible = not signed_in and not account.busy
