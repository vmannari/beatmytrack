extends AcceptDialog
## Paginated server standings for one immutable version and vehicle.
var client: Node
var version: String
var vehicle: String
var offset: int = 0
var next_offset: Variant
var next_cursor: String = ""
var page_cursors: Array[String] = [""]
var page_index: int = 0
var board_id: String = ""
var showing_nearby: bool = false
var retry_button: Button
var body: VBoxContainer
var rows: RichTextLabel
var previous: Button
var next: Button
var around: Button
var busy: bool = false

func _ready() -> void:
	preload("res://ui/popup_style.gd").watch(self)
	title = "Verified high scores · "+VehicleCatalog.title(vehicle)
	size = Vector2i(620,540)
	body = VBoxContainer.new()
	add_child(body)
	rows = RichTextLabel.new()
	rows.custom_minimum_size = Vector2(580,380)
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(rows)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	previous = MenuStyle.button("Previous",func() -> void:
		if not showing_nearby and page_index > 0: page_index -= 1
		load_page())
	next = MenuStyle.button("Next",func() -> void:
		if next_cursor.is_empty(): return
		page_cursors.resize(page_index+1)
		page_cursors.append(next_cursor)
		page_index += 1
		load_page())
	around = MenuStyle.button("Around me",func() -> void: load_page(true))
	retry_button = MenuStyle.button("Retry",func() -> void: load_page(showing_nearby))
	retry_button.visible = false
	for button: Button in [previous,next,around,retry_button]: actions.add_child(button)
	load_page()

func load_page(nearby: bool = false) -> void:
	if busy: return
	busy = true
	showing_nearby = nearby
	for button: Button in [previous,next,around]: button.disabled = true
	if is_instance_valid(retry_button): retry_button.disabled = true
	rows.text = "Loading verified scores…"
	var response: Dictionary
	if nearby and not board_id.is_empty():
		response = await client.request_api("/boards/"+board_id+"/around-me",HTTPClient.METHOD_GET,{},"",true)
	else:
		var cursor: String = "" if nearby else page_cursors[page_index]
		response = await client.request_api("/track-versions/"+version.uri_encode()+"/leaderboard?vehicle_id="+vehicle.uri_encode()+("&cursor="+cursor.uri_encode() if not cursor.is_empty() else ""))
		if response.ok: board_id = str(response.data.board_id)
		if nearby and response.ok and int(response.data.population) > 0:
			response = await client.request_api("/boards/"+board_id+"/around-me",HTTPClient.METHOD_GET,{},"",true)
	if not is_inside_tree(): return
	if response.ok:
		rows.clear()
		rows.add_text("%d verified racers\n\n" % int(response.data.population))
		for item: Dictionary in response.data.items:
			rows.add_image(PlayerCountry.texture(str(item.get("country_code",""))),28,21)
			rows.add_text("  %d.  %s    %s\n" % [int(item.rank),str(item.display_name),MenuStyle.time_text(float(item.time_ticks)/120.0)])
		if response.data.items.is_empty(): rows.add_text("Complete a verified race to appear here." if nearby else "No verified times yet.")
		if not nearby:
			next_offset = response.data.get("next_offset")
			next_cursor = str(response.data.next_cursor) if response.data.get("next_cursor") != null else ""
	else:
		rows.text = "Could not load scores: "+str(response.error)+"\nUse Retry to try again."
		if not nearby: next_cursor = ""
	busy = false
	previous.disabled = page_index == 0 and not nearby
	next.disabled = nearby or next_cursor.is_empty()
	around.disabled = not client.signed_in()
	if is_instance_valid(retry_button):
		retry_button.visible = not response.ok
		retry_button.disabled = false
