extends CanvasLayer
## Optional post-finish prompt. Eligibility and the saved vote come from the server.
var cloud_client: Node
var cloud_sync: Node
var cloud_version: String
var row: TrackRating
var overlay: Control
var title: Label
var skip: Button
var offered: bool = false
var dismissed: bool = false
var scope: String
var reveal_at: int

func _ready() -> void:
	name = "TrackRatingPrompt"
	# CanvasLayer nesting does not inherit drawing order. Stay above the menu
	# canvas that owns this completed result, including its opaque backdrop.
	layer = 1
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is CanvasLayer: layer = maxi(layer,(ancestor as CanvasLayer).layer+1)
		ancestor = ancestor.get_parent()
	reveal_at = Time.get_ticks_msec()+750
	overlay = Control.new()
	MenuStyle.fill(overlay)
	overlay.theme = MenuStyle.theme()
	add_child(overlay)
	overlay.hide()
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.04,0.06,0.65)
	MenuStyle.fill(shade)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	MenuStyle.fill(center)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 380
	panel.add_theme_stylebox_override("panel",MenuStyle.box(MenuStyle.PANEL,24))
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",16)
	panel.add_child(body)
	title = MenuStyle.label("Rate the track",28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)
	row = TrackRating.new()
	row.cloud_client = cloud_client
	row.cloud_sync = cloud_sync
	row.cloud_version = cloud_version
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.eligibility_changed.connect(_eligibility_changed)
	row.rated.connect(_rated)
	row.save_failed.connect(func() -> void: row.caption.show())
	# Build actions before the request, which can complete synchronously from cache.
	skip = MenuStyle.button("Skip",_dismiss)
	skip.name = "SkipRating"
	body.add_child(skip)
	body.add_child(row)
	body.move_child(row,1)
	row.caption.hide()
	for star: Button in row.stars:
		star.custom_minimum_size = Vector2(64,56)
		star.add_theme_constant_override("icon_max_width",36)
	scope = row.cloud_scope
	if cloud_client.has_signal("identity_changed"):
		cloud_client.identity_changed.connect(_dismiss)

func _exit_tree() -> void:
	if is_instance_valid(cloud_client) and cloud_client.has_signal("identity_changed") and cloud_client.identity_changed.is_connected(_dismiss):
		cloud_client.identity_changed.disconnect(_dismiss)

func _eligibility_changed() -> void:
	if offered or dismissed or row.locked or row.value() != 0: return
	offered = true
	await get_tree().create_timer(maxf(0.0,(reveal_at-Time.get_ticks_msec())/1000.0)).timeout
	if not is_inside_tree() or dismissed or row._scope() != scope or row.locked or row.value() != 0: return
	overlay.show()

func _rated() -> void:
	row.caption.hide()
	title.text = "You rated this track %d / 5" % row.value()
	for star: Button in row.stars: star.disabled = true
	skip.disabled = true
	await get_tree().create_timer(0.7).timeout
	if is_inside_tree(): _dismiss()

func _dismiss() -> void:
	dismissed = true
	overlay.hide()
	queue_free()
