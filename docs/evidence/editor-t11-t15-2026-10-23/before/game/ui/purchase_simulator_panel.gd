extends VBoxContainer
## Explicit testing controls; never a shipping checkout.
var client: Node
var adapter: Node
var message: Label
var summary: Label
var rows: VBoxContainer
var outcome: OptionButton
var working: bool = false

func _ready() -> void:
	name = "PurchaseSimulator"
	add_theme_constant_override("separation",8)
	if not OS.is_debug_build(): hide(); return
	adapter = preload("res://platform/purchase_simulator.gd").new()
	adapter.client = client
	add_child(adapter)
	add_child(MenuStyle.label("Purchase simulator — no payment",24))
	var explanation: Label = MenuStyle.label("Test publishing slots and ad-free access with Development sign-in. Changes persist on the test backend.",16)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(explanation)
	summary = MenuStyle.label("",18)
	summary.name = "PurchaseEntitlements"
	add_child(summary)
	var controls := HBoxContainer.new()
	add_child(controls)
	outcome = OptionButton.new()
	outcome.name = "PurchaseOutcome"
	for caption: String in ["Approved","Pending","Declined","Cancelled"]: outcome.add_item(caption)
	outcome.custom_minimum_size = Vector2(180,48)
	controls.add_child(outcome)
	controls.add_child(MenuStyle.button("Refresh / recover",_refresh))
	controls.add_child(MenuStyle.button("Expire month",_adjust.bind("expire_month")))
	controls.add_child(MenuStyle.button("Reset ad-free",_adjust.bind("reset_ad_free")))
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation",8)
	add_child(rows)
	message = MenuStyle.label("",16)
	message.name = "PurchaseSimulatorStatus"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)
	_refresh()

func _refresh() -> void:
	if working: return
	working = true
	message.text = "Checking test purchases…"
	var result: Dictionary = await adapter.catalog()
	working = false
	_render(result)

func _render(result: Dictionary) -> void:
	for child: Node in rows.get_children(): rows.remove_child(child); child.queue_free()
	if not result.ok:
		message.text = "Start the purchase-test backend and sign in with Development. " + str(result.get("error","Unavailable."))
		return
	var data: Dictionary = result.data
	var entitlements: Dictionary = data.entitlements
	summary.text = "%d publishing slots · %s" % [int(entitlements.publishing_slots),"Forever ad-free" if entitlements.ad_free_forever else ("Ad-free until " + Time.get_datetime_string_from_unix_time(int(entitlements.ad_free_until)).replace("T"," ") + " UTC" if entitlements.ad_free else "Ads enabled")]
	message.text = "Simulation only. Published slots stay consumed; ad-free access includes up to three rewinds per race."
	if adapter.has_pending_request():
		var retry: Button = MenuStyle.button("Retry saved purchase",_retry,true)
		retry.name = "RetrySimulatedPurchase"
		rows.add_child(retry)
	for product: Dictionary in data.products:
		var button: Button = MenuStyle.button("Simulate %s · €%s" % [product.title,product.price_eur],_purchase.bind(str(product.id)),true)
		button.name = "Simulate_"+str(product.id)
		button.disabled = not bool(product.get("enabled",true)) or adapter.has_pending_request() or (bool(entitlements.ad_free_forever) and str(product.id).begins_with("ad_free"))
		rows.add_child(button)
	for order: Dictionary in data.purchases:
		if order.state != "pending": continue
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label: Label = MenuStyle.label("Pending: "+str(order.product_id),16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		for action: String in ["approved","declined","cancelled"]:
			row.add_child(MenuStyle.button(action.capitalize(),_resolve.bind(str(order.id),action)))

func _purchase(product_id: String) -> void:
	if working: return
	working = true
	message.text = "Simulating purchase…"
	var result: Dictionary = await adapter.purchase(product_id,["approved","pending","declined","cancelled"][outcome.selected])
	working = false
	await _after(result)

func _retry() -> void:
	if working: return
	working = true
	var result: Dictionary = await adapter.retry()
	working = false
	await _after(result)

func _resolve(id: String, action: String) -> void:
	if working: return
	working = true
	var result: Dictionary = await adapter.resolve(id,action)
	working = false
	await _after(result)

func _after(result: Dictionary) -> void:
	await _refresh()
	message.text = "Simulated purchase: "+str(result.data.purchase.state)+". No payment taken." if result.ok else str(result.get("error","Request failed. Use Refresh / recover."))

func _adjust(action: String) -> void:
	if working: return
	working = true
	var result: Dictionary = await adapter.adjust(action)
	working = false
	await _refresh()
	message.text = "Simulated ad-free state updated. Purchase history and publishing slots retained." if result.ok else str(result.get("error","Test adjustment failed."))
