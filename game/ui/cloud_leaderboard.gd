extends AcceptDialog
## Paginated server standings for one immutable version and vehicle.
var client: Node
var version: String
var vehicle: String
var offset: int = 0
var next_offset: Variant
var body: VBoxContainer
var rows: RichTextLabel
var previous: Button
var next: Button
var around: Button
var busy: bool = false

func _ready() -> void:
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
		offset = maxi(0,offset-20)
		load_page())
	next = MenuStyle.button("Next",func() -> void:
		if next_offset != null: offset = int(next_offset)
		load_page())
	around = MenuStyle.button("Around me",func() -> void: load_page(true))
	for button: Button in [previous,next,around]: actions.add_child(button)
	load_page()

func load_page(nearby: bool = false) -> void:
	if busy: return
	busy = true
	for button: Button in [previous,next,around]: button.disabled = true
	rows.text = "Loading verified scores…"
	var response: Dictionary = await client.request_api("/track-versions/"+version+"/leaderboard?vehicle_id="+vehicle.uri_encode()+"&offset=%d" % offset)
	if not is_inside_tree(): return
	if nearby and response.ok and int(response.data.population) > 0:
		response = await client.request_api("/boards/"+str(response.data.board_id)+"/around-me",HTTPClient.METHOD_GET,{},"",true)
		if not is_inside_tree(): return
	if response.ok:
		rows.text = "%d verified racers\n\n" % int(response.data.population)
		for item: Dictionary in response.data.items:
			rows.text += "%d.  %s    %s\n" % [int(item.rank),str(item.display_name),MenuStyle.time_text(float(item.time_ticks)/120.0)]
		if response.data.items.is_empty(): rows.text += "Complete a verified race to appear here." if nearby else "No verified times yet."
		next_offset = response.data.get("next_offset")
	else:
		rows.text = "Could not load scores: "+str(response.error)+"\nClose and reopen to retry."
		next_offset = null
	busy = false
	previous.disabled = offset == 0
	next.disabled = next_offset == null
	around.disabled = not client.signed_in()
