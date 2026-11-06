extends Node
## Settings composition; state and callbacks remain owned by App.

func run_settings(app: Node) -> void:
	var page = SettingsPage.new()
	page.records = app.records
	page.purchase_client = app.online.client
	page.signed_in = app.online.client.signed_in()
	page.player_name = app.online.player_name() if page.signed_in else "Guest"
	page.country_code = str(app.online.client.player.get("country_code","")) if page.signed_in else ""
	page.customize_requested.connect(app._customize_controls)
	page.account_requested.connect(app._open_account)
	page.privacy_changed.connect(app._apply_privacy_choice)
	page.tutorial_requested.connect(func() -> void:
		if app.tutorial != null: app.tutorial.replay())
	page.help_requested.connect(func(topic: String) -> void:
		if app.tutorial != null: app.tutorial.show_help(topic))
	app.content.add_child(page)

func run_customize_controls(app: Node) -> void:
	var editor = ControlLayoutEditor.new()
	editor.records = app.records
	app.root_ui.visible = false
	app.add_child(editor)
	editor.closed.connect(func() -> void: app._show_screen("settings"))

