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
var controls: HBoxContainer
var working: bool = false
var eligible: bool = false
var entitlements: Dictionary = {}
var products: Array = []
var page_preview: bool = false
var _pending_revision: int = -1
var _presented_revision: int = -1
var _presented_scope: String = ""
const ACCESS = preload("res://backend/store_access_cache.gd")

const COPY: Dictionary = {
	"creator_slot_1":"Publish one additional track. A slot stays used after publication.",
	"creator_slots_5":"Five additional publications. Local drafts and export stay free.",
	"creator_slots_10":"Ten additional publications. Everyone can race shared tracks free.",
	"ad_free_month":"One calendar month, with free rewinds. No automatic renewal.",
	"ad_free_forever":"Permanent ad-free access, with free rewinds. Three per race maximum.",
}

func _ready() -> void:
	name = "StorePage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	adapter = preload("res://platform/purchase_simulator.gd").new()
	adapter.client = client
	add_child(adapter)
	add_child(MenuStyle.label("STORE",36))
	add_child(_label("More room to publish. Racing stays unlimited and free.",18))
	var row := HBoxContainer.new()
	add_child(row)
	summary = _label("Checking your access…",18)
	summary.name = "StoreEntitlements"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(summary)
	row.add_child(MenuStyle.button("Refresh / recover",refresh))
	controls = HBoxContainer.new()
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
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	grid = GridContainer.new()
	grid.name = "StoreProducts"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	body.add_child(grid)
	pending_rows = VBoxContainer.new()
	body.add_child(pending_rows)
	status = _label("",16)
	status.name = "StoreStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	resized.connect(_columns)
	_columns()
	if not page_preview: activate()

func activate() -> void:
	page_preview = false
	refresh(false)

func _columns() -> void:
	if is_instance_valid(grid): grid.columns = 3 if size.x >= 1050 else 2 if size.x >= 650 else 1

static func valid_catalog(data: Variant) -> bool:
	return ACCESS.valid_catalog(data)

func refresh(force: bool = true) -> void:
	if working: return
	if not force and is_instance_valid(client):
		var access: RefCounted = ACCESS.for_service(client)
		if _presented_scope == ACCESS.identity(client) and _presented_revision == access.refreshed and access.refreshed >= 0 and Time.get_ticks_msec()-access.refreshed < ACCESS.TTL_MS: return
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
	products = result.data.products
	entitlements = result.get("entitlements",{})
	eligible = OS.is_debug_build() and bool(entitlements.get("purchase_simulation",false))
	controls.visible = eligible
	if entitlements.is_empty():
		summary.text = "Sign in to view your publishing slots and ad-free access."
	else:
		summary.text = "%d publishing slots · %s" % [int(entitlements.publishing_slots),"Forever ad-free" if entitlements.ad_free_forever else ("Ad-free until "+Time.get_date_string_from_unix_time(int(entitlements.ad_free_until))+" UTC" if entitlements.ad_free else "Ads enabled")]
	_draw_products()
	status.text = "Simulated checkout only. No payment is taken. Free rewinds remain limited to three per race." if eligible else "Store billing is not connected yet. Purchases are unavailable."
	_presented_scope = scope
	_presented_revision = int(result.get("revision",-1))
	if eligible and (force or _pending_revision != _presented_revision):
		_pending_revision = int(result.revision)
		await _pending()
	working = false

func _draw_products() -> void:
	for child: Node in grid.get_children(): grid.remove_child(child); child.queue_free()
	for child: Node in pending_rows.get_children(): pending_rows.remove_child(child); child.queue_free()
	if not is_instance_valid(client) or not client.signed_in(): pending_rows.add_child(MenuStyle.button("Sign in",sign_in_requested.emit))
	for product: Dictionary in products:
		var card := PanelContainer.new()
		card.name = "StoreCard_"+str(product.id)
		card.set_meta("telemetry_product_id",str(product.id))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 165
		card.add_theme_stylebox_override("panel",MenuStyle.card(16))
		grid.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",8)
		card.add_child(column)
		var title: Label = _label(str(product.title),25)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(title)
		var description: Label = _label(str(COPY.get(product.id,"")),16)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(description)
		var owned_forever: bool = bool(entitlements.get("ad_free_forever",false)) and str(product.id).begins_with("ad_free")
		var available: bool = eligible and bool(product.enabled) and not owned_forever and not adapter.has_pending_request()
		var button: Button = MenuStyle.button(("Simulate · €" if available else "Unavailable · €")+str(product.price_eur),_purchase.bind(str(product.id)),true)
		button.name = "StoreBuy_"+str(product.id)
		button.disabled = not available
		button.custom_minimum_size.y = 52
		if owned_forever: button.text = "Already ad-free forever"
		column.add_child(button)

func _pending() -> void:
	var result: Dictionary = await adapter.catalog()
	if not is_inside_tree() or not result.ok: return
	if adapter.has_pending_request():
		var retry: Button = MenuStyle.button("Retry saved checkout",_retry)
		retry.name = "StoreRetry"
		pending_rows.add_child(retry)
	for order: Dictionary in result.data.purchases:
		if order.state != "pending": continue
		var row := HBoxContainer.new()
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
	for card: Control in grid.get_children():
		var product: String = str(card.get_meta("telemetry_product_id",""))
		if product not in COPY or not card.is_visible_in_tree(): continue
		var bounds: Rect2 = card.get_global_rect()
		if bounds.get_area() > 0 and visible.intersection(bounds).get_area() >= bounds.get_area()*0.5: result.append(product)
	return result
