extends AcceptDialog
## Shared native safety sheets, available from tracks, players and Settings.
signal completed(accepted: bool)
var client: Node
var sheet_kind: String = "manage"
var target: Dictionary = {}
var body: VBoxContainer
var status: Label
var reasons: OptionButton
var details: TextEdit
var consent: CheckBox
var terms_version: String = ""
var busy: bool = false
var account_scope: String = ""
var popup_bounds := Vector2i(800,620)
const CODES: Array[String] = ["harassment","hate","sexual_content","child_safety","violence","privacy","spam","illegal_content","track_issue"]
const LABELS: Array[String] = ["Bullying or harassment","Hate or discrimination","Sexual content or nudity","Child safety","Threats or graphic violence","Personal information","Spam, scam or impersonation","Illegal content","Other track issue"]

static func track_target(track: NativeTrack) -> Dictionary:
	var metadata: Dictionary = track.metadata
	var entry: Dictionary = metadata.get("cloud_entry",{})
	return {"name":str(entry.get("name",metadata.get("title",track.identity))),
		"creator_name":str(entry.get("creator",metadata.get("cloud_creator","Player"))),
		"version_id":str(metadata.get("cloud_version",entry.get("version_id",""))),
		"track_id":str(metadata.get("cloud_track_id",entry.get("track_id",""))),
		"reported_player_id":str(metadata.get("cloud_creator_id",entry.get("creator_id","")))}

static func open(parent: Node, adapter: Node, kind: String = "manage", data: Dictionary = {}) -> Node:
	var sheet: Node = load("res://ui/community_safety_ui.gd").new()
	sheet.client = adapter
	sheet.sheet_kind = kind
	sheet.target = data.duplicate(true)
	var available: Vector2 = parent.get_viewport().get_visible_rect().size-Vector2(32,32)
	sheet.popup_bounds = Vector2i(minf(800,available.x),minf(620,available.y))
	parent.add_child(sheet)
	sheet.popup_centered(sheet.popup_bounds)
	return sheet

static func ensure_terms(parent: Node, adapter: Node) -> bool:
	var result: Dictionary = await adapter.safety.terms()
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion(): return false
	if not result.ok: return false
	if result.data.accepted: return true
	var sheet: Node = open(parent,adapter,"terms",result.data)
	return await sheet.completed

func _ready() -> void:
	theme = MenuStyle.theme()
	preload("res://ui/popup_style.gd").watch(self)
	dialog_hide_on_ok = false
	account_scope = client.base_url()+"/"+str(client.player.get("id",""))
	client.identity_changed.connect(_identity_changed)
	canceled.connect(func() -> void: completed.emit(false); queue_free())
	confirmed.connect(_submit)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := ScrollContainer.new()
	content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.custom_minimum_size = Vector2(mini(700,popup_bounds.x-64),mini(420,popup_bounds.y-200))
	content.add_child(body)
	add_child(content)
	status = MenuStyle.label("",17,true)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.hide()
	if not client.signed_in():
		title = "Community safety"
		body.add_child(MenuStyle.label("Sign in through Manage account to report or block players.",20,true))
		ok_button_text = "Close"
		body.add_child(status)
		return
	match sheet_kind:
		"terms": _terms()
		"report": _report()
		"track":
			title = str(target.get("name","Track"))
			body.add_child(MenuStyle.button("Report track",func() -> void: open(self,client,"report",target)))
			body.add_child(MenuStyle.button("Report / block creator",func() -> void: open(self,client,"player",target)))
			ok_button_text = "Done"
		"player": _player()
		"appeal":
			title = "Appeal report"
			details = TextEdit.new()
			details.placeholder_text = "Describe new evidence for the moderation owner."
			details.custom_minimum_size = Vector2(700,240)
			body.add_child(details)
			ok_button_text = "Send appeal"
			add_cancel_button("Cancel")
		_: _manage()
	body.add_child(status)

func _set_status(message: String) -> void:
	status.text = message
	status.visible = not message.is_empty()

func _identity_changed() -> void:
	if account_scope != client.base_url()+"/"+str(client.player.get("id","")):
		completed.emit(false)
		queue_free()

func _terms() -> void:
	title = "Public sharing rules"
	terms_version = str(target.version)
	var text := RichTextLabel.new()
	text.name = "CommunityTermsText"
	text.text = str(target.text)
	text.custom_minimum_size = Vector2(mini(700,popup_bounds.x-64),clampi(popup_bounds.y-290,100,330))
	body.add_child(text)
	consent = CheckBox.new()
	consent.name = "AcceptCommunityTerms"
	consent.text = "I accept these public sharing rules"
	consent.custom_minimum_size.y = 52
	consent.toggled.connect(func(value: bool) -> void: get_ok_button().disabled = not value)
	body.add_child(consent)
	get_ok_button().disabled = true
	ok_button_text = "Accept and continue"
	add_cancel_button("Cancel")

func _report() -> void:
	title = "Report player" if target.get("subject","") == "player" or not (target.has("version_id") or target.has("track_id")) else "Report track"
	body.add_child(MenuStyle.label(str(target.get("name","Player")),22,true))
	reasons = OptionButton.new()
	reasons.name = "ReportReason"
	for label: String in LABELS: reasons.add_item(label)
	reasons.custom_minimum_size.y = 50
	body.add_child(reasons)
	details = TextEdit.new()
	details.name = "ReportDetails"
	details.placeholder_text = "Describe what happened (no private information)."
	details.custom_minimum_size = Vector2(mini(700,popup_bounds.x-64),clampi(popup_bounds.y-430,80,180))
	details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	details.text_changed.connect(func() -> void:
		if is_instance_valid(status) and status.text.begins_with("Enter "): _set_status("")
	)
	body.add_child(details)
	var explanation := MenuStyle.label("Private report to the Beat my track moderation owner. Track progress in Community safety.",17,true)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(explanation)
	ok_button_text = "Send report"
	add_cancel_button("Cancel")

func _player() -> void:
	target.subject = "player"
	if target.has("creator_name"): target.name = target.creator_name
	title = str(target.get("name","Player"))
	if str(target.get("reported_player_id","")) == str(client.player.get("id","")):
		body.add_child(MenuStyle.label("This is your profile.",20))
		return
	body.add_child(MenuStyle.button("Report player",func() -> void: open(self,client,"report",target)))
	var explanation := MenuStyle.label("Blocking hides this player's tracks and public identity and stops new challenge interactions. Historical scores remain.",18,true)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(explanation)
	var id: String = str(target.get("reported_player_id",""))
	var button: Button = MenuStyle.button("Unblock player" if client.safety.is_blocked(id) else "Block player",func() -> void: _block(id,str(target.get("name","Player")),not client.safety.is_blocked(id)))
	button.name = "BlockPlayer"
	body.add_child(button)
	ok_button_text = "Done"

func _block(id: String, name_value: String, value: bool) -> void:
	if busy: return
	busy = true
	_set_status("Saving…")
	var response: Dictionary = await client.safety.set_block(id,name_value,value)
	if not is_inside_tree(): return
	busy = false
	_set_status(("Player blocked." if value else "Player unblocked.") if response.ok else "Hidden on this device. Connect and use Retry sync." if value and client.safety.is_blocked(id) else "Could not save: "+str(response.error))
	var button: Button = find_child("BlockPlayer",true,false)
	if button != null: button.text = "Unblock player" if client.safety.is_blocked(id) else "Block player"

func _manage() -> void:
	title = "Community safety"
	ok_button_text = "Done"
	body.add_child(MenuStyle.button("Read public sharing rules",func() -> void:
		var result: Dictionary = await client.safety.terms()
		if is_inside_tree() and result.ok: open(self,client,"terms",result.data)))
	body.add_child(MenuStyle.label("Blocked players",22))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(mini(700,popup_bounds.x-64),clampi(popup_bounds.y-450,50,150))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var players := VBoxContainer.new()
	players.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(players)
	for id: String in client.safety.blocked:
		var name_value: String = str(client.safety.blocked[id])
		var button: Button = MenuStyle.button("Unblock · "+name_value,func() -> void: _block(id,name_value,false))
		players.add_child(button)
	if client.safety.blocked.is_empty(): players.add_child(MenuStyle.label("No blocked players",18))
	body.add_child(MenuStyle.button("Retry sync / saved reports",func() -> void:
		_set_status("Syncing…")
		await client.safety.refresh()
		if is_inside_tree(): _set_status(GameText.message("Saved reports: %d · pending blocks: %d") % [client.safety.pending_reports.size(),client.safety.pending_blocks.size()])
	))
	body.add_child(MenuStyle.button("My reports",_my_reports))

func _my_reports() -> void:
	if busy: return
	busy = true
	var response: Dictionary = await client.request_api("/reports",HTTPClient.METHOD_GET,{},"",true)
	if not is_inside_tree(): return
	busy = false
	if not response.ok:
		_set_status("Could not load reports. Retry when connected.")
		return
	var dialog := AcceptDialog.new()
	dialog.title = "My reports"
	dialog.size = Vector2i(720,540)
	preload("res://ui/popup_style.gd").watch(dialog)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(650,340)
	dialog.add_child(scroll)
	var rows := VBoxContainer.new()
	scroll.add_child(rows)
	for item: Dictionary in response.data.items:
		rows.add_child(MenuStyle.label(str(item.title)+" · "+str(item.status),19))
		if item.status == "resolved": rows.add_child(MenuStyle.button("Appeal",func() -> void: open(self,client,"appeal",item)))
	if response.data.items.is_empty(): rows.add_child(MenuStyle.label("No submitted reports",19))
	if response.data.get("has_more",false): rows.add_child(MenuStyle.label("Showing your 50 most recently updated reports.",16))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _submit() -> void:
	if busy: return
	if sheet_kind not in ["terms","report","appeal"] or not client.signed_in():
		completed.emit(false)
		queue_free()
		return
	busy = true
	get_ok_button().disabled = true
	var response: Dictionary
	if sheet_kind == "terms":
		response = await client.request_api("/community/terms",HTTPClient.METHOD_POST,{"version":terms_version,"accepted":true},"",true)
	else:
		var text: String = details.text.strip_edges()
		if text.is_empty() or text.length() > 2000:
			_set_status("Enter 1–2000 characters.")
			busy = false
			get_ok_button().disabled = false
			return
		if sheet_kind == "appeal":
			if not target.has("command_id"): target.command_id = preload("res://backend/product_telemetry.gd").uuid()
			response = await client.request_api("/reports/"+str(target.id)+"/appeal",HTTPClient.METHOD_POST,{"command_id":target.command_id,"expected_revision":target.revision,"text":text},"",true)
		else:
			var payload: Dictionary = {"reason":CODES[reasons.selected],"text":text}
			for key: String in ["track_id","version_id","reported_player_id"]:
				if not str(target.get(key,"")).is_empty(): payload[key] = target[key]
			response = await client.safety.report(payload)
	if not is_inside_tree(): return
	busy = false
	if response.ok:
		completed.emit(true)
		if sheet_kind == "terms": queue_free()
		else:
			_set_status("Report sent. Reference: "+str(response.data.id))
			sheet_kind = "sent"
			details.editable = false
			if is_instance_valid(reasons): reasons.disabled = true
			ok_button_text = "Done"
			get_ok_button().disabled = false
	else:
		_set_status("Could not send: "+str(response.error))
		if sheet_kind == "report" and not client.safety.pending_reports.is_empty(): _set_status(status.text+" · Saved on this device. Retry from Community safety.")
		get_ok_button().disabled = false
