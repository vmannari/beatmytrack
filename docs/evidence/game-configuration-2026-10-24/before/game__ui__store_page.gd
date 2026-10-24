extends VBoxContainer
## Entitlements and checkout live outside canonical racing. No store SDK yet.
signal sign_in_requested
signal purchase_requested(product_id: String)
var client: Node
var adapter: Node
var summary: Label
var status: Label
var grid: GridContainer
var pending_rows: VBoxContainer
var outcome: OptionButton
var controls: BoxContainer
var working: bool = false
var eligible: bool = false
var entitlements: Dictionary = {}
var products: Array = []
var page_preview: bool = false
var _pending_revision: int = -1
var _presented_revision: int = -1
var _presented_scope: String = ""
var _header: BoxContainer
var _headline: Label
var _ad_offers: BoxContainer
var _slots_heading: VBoxContainer
var _footer: BoxContainer
var _restore: Button
var _body: VBoxContainer
var _cards: Array[Control] = []
var _compact: bool = false
const ACCESS = preload("res://backend/store_access_cache.gd")

const COPY: Dictionary = {
	"creator_slot_1":"Publish one additional track.",
	"creator_slots_5":"Publish five additional tracks.",
	"creator_slots_10":"Publish ten additional tracks.",
	"ad_free_month":"No automatic renewal",
	"ad_free_forever":"No interruption ads",
}
const TITLES: Dictionary = {
	"creator_slot_1":"1 SLOT", "creator_slots_5":"5 SLOTS", "creator_slots_10":"10 SLOTS",
	"ad_free_month":"1 MONTH AD-FREE", "ad_free_forever":"FOREVER AD-FREE",
}
const ACTIONS: Dictionary = {
	"creator_slot_1":"Add 1 slot", "creator_slots_5":"Add 5 slots", "creator_slots_10":"Add 10 slots",
	"ad_free_month":"Try 1 month", "ad_free_forever":"Go ad-free forever",
}
const SLOT_COUNTS: Dictionary = {"creator_slot_1":1,"creator_slots_5":5,"creator_slots_10":10}

func _ready() -> void:
	name = "StorePage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	theme = MenuStyle.theme()
	add_theme_constant_override("separation",8)
	adapter = preload("res://platform/purchase_simulator.gd").new()
	adapter.client = client
	add_child(adapter)
	controls = BoxContainer.new()
	controls.add_theme_constant_override("separation",12)
	add_child(controls)
	outcome = OptionButton.new()
	outcome.name = "StoreTestOutcome"
	for caption: String in ["Approved","Pending","Declined","Cancelled"]: outcome.add_item(caption)
	outcome.custom_minimum_size = Vector2(180,52)
	controls.add_child(outcome)
	controls.add_child(_label("SIMULATION · NO PAYMENT",18))
	controls.hide()
	var scroll := ScrollContainer.new()
	scroll.name = "StoreScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",12)
	scroll.add_child(_body)
	_header = BoxContainer.new()
	_header.add_theme_constant_override("separation",20)
	_body.add_child(_header)
	var intro := VBoxContainer.new()
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.size_flags_stretch_ratio = 1.8
	intro.add_theme_constant_override("separation",2)
	_header.add_child(intro)
	_headline = _label("MORE TRACKS. MORE FREEDOM.",44)
	_headline.name = "StoreHeadline"
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_child(_headline)
	var subtitle: Label = _label("Publish your best creations and race without interruptions.",19)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_child(subtitle)
	var account := PanelContainer.new()
	account.name = "StoreAccountStatus"
	account.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	account.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	account.add_theme_stylebox_override("panel",_panel_style(false,14))
	_header.add_child(account)
	var account_row := HBoxContainer.new()
	account.add_child(account_row)
	var avatar := TextureRect.new()
	avatar.texture = MenuIcon.texture("avatar")
	avatar.custom_minimum_size = Vector2(40,40)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.modulate = MenuStyle.MUTED
	account_row.add_child(avatar)
	var account_copy := VBoxContainer.new()
	account_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	account_copy.add_theme_constant_override("separation",2)
	account_row.add_child(account_copy)
	account_copy.add_child(MenuStyle.label("ACCOUNT STATUS",16,true))
	summary = _label("Checking your access…",19)
	summary.name = "StoreEntitlements"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_copy.add_child(summary)
	_ad_offers = BoxContainer.new()
	_ad_offers.name = "StoreAdOffers"
	_ad_offers.add_theme_constant_override("separation",12)
	_body.add_child(_ad_offers)
	_slots_heading = VBoxContainer.new()
	_slots_heading.add_theme_constant_override("separation",0)
	_body.add_child(_slots_heading)
	_slots_heading.add_child(_label("PUBLISH MORE TRACKS",28))
	var slot_copy: Label = _label("Slots stay used after publication. Anyone can race your tracks for free.",18)
	slot_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slots_heading.add_child(slot_copy)
	grid = GridContainer.new()
	grid.name = "StoreProducts"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	_body.add_child(grid)
	pending_rows = VBoxContainer.new()
	_body.add_child(pending_rows)
	_footer = BoxContainer.new()
	add_child(_footer)
	var footer_copy := VBoxContainer.new()
	footer_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer_copy.add_theme_constant_override("separation",2)
	_footer.add_child(footer_copy)
	var free_note: Label = _label("Racing and local drafts stay free.",16)
	free_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer_copy.add_child(free_note)
	_restore = MenuStyle.button("Refresh / recover",refresh)
	_restore.name = "StoreRecover"
	_restore.tooltip_text = "Refresh your access and recover saved checkout requests."
	_restore.add_theme_font_size_override("font_size",18)
	_restore.add_theme_color_override("font_color",MenuStyle.MUTED)
	_restore.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,8))
	_footer.add_child(_restore)
	status = _label("",14)
	status.name = "StoreStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color",MenuStyle.MUTED)
	footer_copy.add_child(status)
	resized.connect(_columns)
	_columns()
	if not page_preview: activate()
	elif is_instance_valid(client):
		var access: RefCounted = ACCESS.for_service(client)
		if access.refreshed >= 0 and Time.get_ticks_msec()-access.refreshed < ACCESS.TTL_MS and access.value.get("ok",false): _present_access(access.value,ACCESS.identity(client))

func activate() -> void:
	page_preview = false
	refresh(false)

func _columns() -> void:
	if not is_instance_valid(grid): return
	grid.columns = 3 if size.x >= 900 else 2 if size.x >= 650 else 1
	_header.vertical = size.x < 1000
	_ad_offers.vertical = size.x < 900
	_footer.vertical = size.x < 650
	controls.vertical = size.x < 450
	for row: Node in pending_rows.get_children():
		if row is BoxContainer: row.vertical = size.x < 650
	_headline.add_theme_font_size_override("font_size",44 if size.x >= 1000 else 36 if size.x >= 650 else 30)
	_compact = size.x < 1100
	for card: Control in _cards:
		var content: BoxContainer = card.find_child("StoreOfferContent",true,false) as BoxContainer
		if content == null: continue
		content.vertical = _compact
		var checkout: Control = content.get_node("StoreCheckout")
		checkout.custom_minimum_size.x = 0 if _compact else 170

static func valid_catalog(data: Variant) -> bool:
	return ACCESS.valid_catalog(data)

func refresh(force: bool = true) -> void:
	if working: return
	if not force and is_instance_valid(client):
		var access: RefCounted = ACCESS.for_service(client)
		if _presented_scope == ACCESS.identity(client) and _presented_revision == access.refreshed and access.refreshed >= 0 and Time.get_ticks_msec()-access.refreshed < ACCESS.TTL_MS:
			if eligible and _pending_revision != _presented_revision:
				working = true
				_pending_revision = _presented_revision
				await _pending()
				working = false
			return
	working = true
	status.text = "Loading store…"
	eligible = false
	entitlements = {}
	controls.hide()
	var result: Dictionary = {"ok":false,"error":"Online services are not configured."}
	var scope: String = ACCESS.identity(client)
	if is_instance_valid(client): result = await ACCESS.for_service(client).fetch(client,force)
	if not is_inside_tree() or scope != ACCESS.identity(client):
		working = false
		return
	if not result.ok or not valid_catalog(result.get("data")):
		working = false
		summary.text = "Access unavailable until reconnected."
		_draw_products()
		status.text = "Store unavailable. Reconnect and Refresh."
		return
	_present_access(result,scope)
	if eligible and (force or _pending_revision != _presented_revision):
		_pending_revision = int(result.revision)
		await _pending()
	working = false

func _present_access(result: Dictionary, scope: String) -> void:
	products = result.data.products
	entitlements = result.get("entitlements",{})
	eligible = OS.is_debug_build() and bool(entitlements.get("purchase_simulation",false))
	controls.visible = eligible
	if entitlements.is_empty():
		summary.text = "Sign in to view your publishing slots and ad-free access."
	else:
		summary.text = "%d publishing slots · %s" % [int(entitlements.publishing_slots),"Forever ad-free" if entitlements.ad_free_forever else ("Ad-free until "+Time.get_date_string_from_unix_time(int(entitlements.ad_free_until))+" UTC" if entitlements.ad_free else "Ads enabled")]
	_draw_products()
	status.text = "SIMULATION · No payment is taken." if eligible else "Store billing is not connected yet. Purchases are unavailable."
	_presented_scope = scope
	_presented_revision = int(result.get("revision",-1))

func _draw_products() -> void:
	_cards.clear()
	for container: Node in [grid,_ad_offers]:
		for child: Node in container.get_children(): container.remove_child(child); child.queue_free()
	for child: Node in pending_rows.get_children(): pending_rows.remove_child(child); child.queue_free()
	if not is_instance_valid(client) or not client.signed_in(): pending_rows.add_child(MenuStyle.button("Sign in",sign_in_requested.emit))
	for id: String in ["ad_free_forever","ad_free_month","creator_slot_1","creator_slots_5","creator_slots_10"]:
		for product: Dictionary in products:
			if str(product.id) != id: continue
			var card: PanelContainer = _product_card(product)
			if id.begins_with("ad_free"): _ad_offers.add_child(card)
			else: grid.add_child(card)
	_ad_offers.visible = _ad_offers.get_child_count() > 0
	_slots_heading.visible = grid.get_child_count() > 0

func _panel_style(highlight: bool, padding: int = 14) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.card(padding)
	style.bg_color = Color(0.025,0.065,0.085,0.96)
	style.border_color = MenuStyle.ACCENT if highlight else Color("305565")
	style.set_border_width_all(2 if highlight else 1)
	style.set_corner_radius_all(7)
	if highlight:
		style.shadow_color = Color(1,0.77,0.12,0.10)
		style.shadow_size = 6
	return style

func _badge(caption: String) -> Label:
	var badge: Label = MenuStyle.label(caption,14)
	badge.add_theme_font_override("font",MenuStyle.DISPLAY)
	badge.add_theme_color_override("font_color",MenuStyle.INK)
	badge.add_theme_stylebox_override("normal",MenuStyle.box(MenuStyle.ACCENT,4))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return badge

func _benefit(caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	var tick: Label = MenuStyle.label("✓",18)
	tick.add_theme_color_override("font_color",MenuStyle.ACCENT)
	row.add_child(tick)
	var copy: Label = _label(caption,17)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(copy)
	return row

func _best_slot_value(product: Dictionary) -> bool:
	var count: int = int(SLOT_COUNTS.get(str(product.id),0))
	var price: String = str(product.price_eur)
	if count < 2 or not bool(product.enabled) or not price.is_valid_float() or float(price) <= 0.0: return false
	var compared: bool = false
	for other: Dictionary in products:
		var other_count: int = int(SLOT_COUNTS.get(str(other.id),0))
		var other_price: String = str(other.price_eur)
		if other_count == 0 or other.id == product.id or not bool(other.enabled): continue
		if not other_price.is_valid_float() or float(other_price) <= 0.0: return false
		compared = true
		if float(price)/count >= float(other_price)/other_count: return false
	return compared

func _product_card(product: Dictionary) -> PanelContainer:
	var id: String = str(product.id)
	var ad: bool = id.begins_with("ad_free")
	var forever: bool = id == "ad_free_forever"
	var best: bool = _best_slot_value(product)
	var highlight: bool = forever or best
	var card := PanelContainer.new()
	card.name = "StoreCard_"+id
	card.set_meta("telemetry_product_id",id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.6 if forever else 1.0
	card.add_theme_stylebox_override("panel",_panel_style(highlight))
	_cards.append(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	card.add_child(column)
	if not ad:
		_slot_content(column,product,best)
		return card
	if forever: column.add_child(_badge("ONE-TIME PURCHASE"))
	var content := BoxContainer.new()
	content.name = "StoreOfferContent"
	content.vertical = _compact
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",14 if not content.vertical else 6)
	column.add_child(content)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation",4)
	content.add_child(copy)
	var title_row := HBoxContainer.new()
	copy.add_child(title_row)
	var title: Label = _label(str(TITLES.get(id,product.title)),34 if forever else 28)
	title.name = "StoreTitle_"+id
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(title)
	copy.add_child(_benefit(str(COPY[id])))
	copy.add_child(_benefit("Up to 3 free resumes per race"))
	var checkout := VBoxContainer.new()
	checkout.name = "StoreCheckout"
	checkout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	checkout.add_theme_constant_override("separation",6)
	if not _compact:
		checkout.custom_minimum_size.x = 170
		checkout.size_flags_stretch_ratio = 0.75
	content.add_child(checkout)
	var price: Label = _label("€"+str(product.price_eur),40)
	price.name = "StorePrice_"+id
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	checkout.add_child(price)
	checkout.add_child(_buy_button(product,highlight))
	return card

func _slot_content(column: VBoxContainer, product: Dictionary, best: bool) -> void:
	var id: String = str(product.id)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title: Label = _label(str(TITLES[id]),28)
	title.name = "StoreTitle_"+id
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(title)
	var price_group := VBoxContainer.new()
	price_group.add_theme_constant_override("separation",0)
	heading.add_child(price_group)
	if best:
		var badge: Label = _badge("BEST VALUE")
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heading.add_child(badge)
		heading.move_child(price_group,-1)
	var price: Label = MenuStyle.label("€"+str(product.price_eur),34)
	price.name = "StorePrice_"+id
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_group.add_child(price)
	var description: Label = _label(str(COPY[id]),18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(description)
	column.add_child(HSeparator.new())
	var amount: String = str(product.price_eur)
	if amount.is_valid_float() and float(amount) > 0.0:
		column.add_child(MenuStyle.label("€%.2f per slot" % (float(amount)/int(SLOT_COUNTS[id])),16,true))
	column.add_child(_buy_button(product,best))

func _buy_button(product: Dictionary, highlight: bool) -> Button:
	var id: String = str(product.id)
	var owned_forever: bool = bool(entitlements.get("ad_free_forever",false)) and id.begins_with("ad_free")
	var available: bool = eligible and bool(product.enabled) and not owned_forever and not adapter.has_pending_request()
	var caption: String = str(ACTIONS[id])
	if available: caption = "Simulate · "+caption
	elif owned_forever: caption = "Already ad-free forever"
	elif not bool(product.enabled): caption = "Unavailable"
	var button: Button = MenuStyle.button(caption,_purchase.bind(id),highlight)
	button.name = "StoreBuy_"+id
	button.disabled = not available
	if not available and not owned_forever: button.tooltip_text = "Purchases are unavailable. Refresh your access to try again."
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size",22)
	if not highlight:
		var outline: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,8)
		outline.border_color = MenuStyle.TEXT
		outline.set_border_width_all(1)
		button.add_theme_stylebox_override("normal",outline)
	return button

func _pending() -> void:
	var result: Dictionary = await adapter.catalog()
	if not is_inside_tree() or not result.ok: return
	if adapter.has_pending_request():
		var retry: Button = MenuStyle.button("Retry saved checkout",_retry)
		retry.name = "StoreRetry"
		pending_rows.add_child(retry)
	for order: Dictionary in result.data.purchases:
		if order.state != "pending": continue
		var row := BoxContainer.new()
		row.vertical = size.x < 650
		pending_rows.add_child(row)
		row.add_child(_label("Pending test payment: "+str(order.product_id),16))
		for state: String in ["approved","declined","cancelled"]:
			row.add_child(MenuStyle.button(state.capitalize(),_resolve.bind(str(order.id),state)))

func _purchase(product_id: String) -> void:
	if working or not eligible: return
	if product_id in COPY: purchase_requested.emit(product_id)
	working = true
	status.text = "Processing simulated checkout…"
	var result: Dictionary = await adapter.purchase(product_id,["approved","pending","declined","cancelled"][outcome.selected])
	working = false
	await _after(result)

func _retry() -> void:
	if working: return
	working = true
	var result: Dictionary = await adapter.retry()
	working = false
	await _after(result)

func _resolve(id: String, state: String) -> void:
	if working: return
	working = true
	var result: Dictionary = await adapter.resolve(id,state)
	working = false
	await _after(result)

func _after(result: Dictionary) -> void:
	await refresh()
	if not is_inside_tree(): return
	status.text = "Simulated payment "+str(result.data.purchase.state)+". No payment taken." if result.ok else ("This item is unavailable right now." if result.get("error") == "PRODUCT_DISABLED" else str(result.get("error","Checkout failed. Refresh to recover.")))

func _label(text: String, font_size: int) -> Label:
	var label: Label = MenuStyle.label(text,font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func telemetry_exposures() -> Array[String]:
	var result: Array[String] = []
	if not is_visible_in_tree() or not is_instance_valid(grid): return result
	var scroll: Control = get_node_or_null("StoreScroll") as Control
	if scroll == null: return result
	var visible: Rect2 = scroll.get_global_rect().intersection(get_viewport().get_visible_rect())
	for card: Control in _cards:
		var product: String = str(card.get_meta("telemetry_product_id",""))
		if product not in COPY or not card.is_visible_in_tree(): continue
		var bounds: Rect2 = card.get_global_rect()
		if bounds.get_area() > 0 and visible.intersection(bounds).get_area() >= bounds.get_area()*0.5: result.append(product)
	return result
