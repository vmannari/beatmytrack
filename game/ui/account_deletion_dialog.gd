extends ConfirmationDialog
## Never turn missing/stale balances into a zero-value deletion disclosure.
const Benefits = preload("res://ui/account_deletion_benefits.gd")
var account: Node
var actor: String
var origin: String
var generation: int
var loaded: bool = false
var benefits: Label
var retry: Button
var scroll: ScrollContainer

func open_for(controller: Node) -> void:
	account = controller
	actor = str(account.client.player.get("id",""))
	origin = account.client.base_url()
	generation = account.client._session_generation
	name = "DeleteAccountConfirmation"
	title = "Delete account"
	dialog_text = ""
	ok_button_text = "Delete account permanently"
	cancel_button_text = "Keep account"
	get_ok_button().disabled = true
	scroll = ScrollContainer.new()
	scroll.name = "DeletionScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var extent: Vector2 = get_parent().get_viewport().get_visible_rect().size.min(Vector2(get_parent().get_window().size))
	scroll.custom_minimum_size = Vector2(minf(540,extent.x-112),clampf(extent.y-220,100,420))
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",16)
	scroll.add_child(body)
	var copy: Label = _label("Deleting your whole account permanently loses all remaining account benefits, including paid benefits. They cannot be restored or transferred to a new account.",19)
	copy.name = "DeleteAccountCopy"
	copy.add_theme_color_override("font_color",MenuStyle.TEXT)
	body.add_child(copy)
	benefits = _label("Loading your remaining benefits…",18)
	benefits.name = "DeletionBenefits"
	body.add_child(benefits)
	retry = MenuStyle.button("Retry loading benefits",_load_benefits)
	retry.hide()
	body.add_child(retry)
	body.add_child(_label("Your sign-in identity and private online data will also be removed. Reinstalling cannot recover a deleted account.\n\nPublished tracks and historical standings stay under Removed account. Local tracks, car condition and local cosmetics stay on this device. Mandatory consumer rights and outstanding purchase claims remain.",17))
	confirmed.connect(_confirm)
	canceled.connect(queue_free)
	preload("res://ui/popup_style.gd").watch(self)
	popup_centered(Vector2i(620,int(scroll.custom_minimum_size.y)+190))
	get_cancel_button().grab_focus()
	_load_benefits()

func _label(source: String, font_size: int) -> Label:
	var result: Label = MenuStyle.label(source,font_size,true)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

func _same_account() -> bool:
	return is_instance_valid(account) and account.client.signed_in() and actor == str(account.client.player.get("id","")) and origin == account.client.base_url() and generation == account.client._session_generation

func _process(_delta: float) -> void:
	if loaded and not _same_account():
		loaded = false
		get_ok_button().disabled = true
		benefits.text = tr("Your account changed. Close this window and review the current account before deleting it.")
		retry.hide()

func _load_benefits() -> void:
	loaded = false
	get_ok_button().disabled = true
	retry.hide()
	benefits.text = tr("Loading your remaining benefits…")
	if not _same_account(): return
	var response: Dictionary = await account.client.request_api("/privacy/deletion-preview",HTTPClient.METHOD_GET,{},"",true)
	if not is_inside_tree(): return
	var data: Variant = response.get("data")
	if not _same_account():
		benefits.text = tr("Your account changed. Close this window and review the current account before deleting it.")
		return
	if not response.get("ok",false) or not Benefits.valid(data) or data.player_id != actor:
		benefits.text = tr("Could not load your remaining benefits. Retry before deleting your account.")
		retry.show()
		return
	benefits.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	benefits.text = Benefits.describe(data)
	loaded = true
	get_ok_button().disabled = false

func _confirm() -> void:
	if loaded and _same_account(): account.delete_account(actor,origin)
	queue_free()
