class_name TrackRating
extends HBoxContainer
## Personal track identity, independent of car, physics version and race records.
signal rated
signal save_failed
signal eligibility_changed
signal selected
var records: LocalRecords
var track_id: String
var stars: Array[Button] = []
var caption: Label
var locked: bool = false
var cloud_client: Node
var cloud_version: String = ""
var cloud_score: int = 0
var cloud_sync: Node
var last_sync_status: String = ""
var vote_loading: bool = false
var vote_saving: bool = false
var vote_key: String = ""
var pending_score: int = 0
var vote_reload_pending: bool = false
var cloud_scope: String = ""
var finish_vote: Node
var instant_finish: bool = false

func _scope() -> String:
	if cloud_client == null or not cloud_client.signed_in(): return ""
	if not cloud_client.has_method("base_url"): return str(cloud_client.get_instance_id())
	return str(cloud_client.base_url())+"|"+str(cloud_client.player.get("id",""))

func value() -> int:
	if is_instance_valid(finish_vote): return int(finish_vote.score)
	if not cloud_version.is_empty(): return cloud_score
	return int(records.settings.get("track_ratings",{}).get(track_id,0))

func _ready() -> void:
	name = "TrackRating"
	add_theme_constant_override("separation",6)
	caption = MenuStyle.label("Rate the track",15,true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(caption)
	for score: int in range(1,6):
		var button := MenuStyle.button("",choose.bind(score))
		button.name = "Rate%d" % score
		button.tooltip_text = "Rate track %d out of 5" % score
		button.custom_minimum_size = Vector2(44,44)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width",22)
		add_child(button)
		stars.append(button)
	refresh()
	if not cloud_version.is_empty():
		cloud_scope = _scope()
		if cloud_sync != null: cloud_sync.changed.connect(_sync_changed)
		_load_cloud_vote()

func _exit_tree() -> void:
	if is_instance_valid(cloud_sync) and cloud_sync.changed.is_connected(_sync_changed):
		cloud_sync.changed.disconnect(_sync_changed)

func _sync_changed() -> void:
	last_sync_status = str(cloud_sync.status)
	if locked and not vote_saving and last_sync_status.begins_with("Race verified"):
		if vote_loading: vote_reload_pending = true
		else: _load_cloud_vote()

func _load_cloud_vote() -> void:
	if vote_loading or vote_saving: return
	if _scope() != cloud_scope: return
	locked = true
	refresh()
	if cloud_client == null or not cloud_client.signed_in():
		caption.text = "Sign in to rate"
		return
	vote_loading = true
	var response: Dictionary = await cloud_client.request_api("/track-versions/"+cloud_version+"/rating",HTTPClient.METHOD_GET,{},"",true)
	if not is_inside_tree() or _scope() != cloud_scope: return
	vote_loading = false
	if response.ok:
		cloud_score = int(response.data.score)
		locked = not bool(response.data.eligible)
		caption.text = "Rate the track" if not locked else "Verified race required · no self-rating"
	else:
		caption.text = "Rating unavailable · reopen to retry"
	refresh()
	eligibility_changed.emit()
	if vote_reload_pending:
		vote_reload_pending = false
		call_deferred("_load_cloud_vote")

func refresh() -> void:
	if is_instance_valid(caption): caption.tooltip_text = caption.text
	for i: int in range(stars.size()):
		if not cloud_version.is_empty(): stars[i].disabled = locked
		stars[i].icon = MenuIcon.texture("star_filled" if i < value() else "star")
		stars[i].add_theme_color_override("icon_normal_color",MenuStyle.ACCENT if i < value() else MenuStyle.MUTED)
		stars[i].add_theme_color_override("icon_disabled_color",MenuStyle.ACCENT if i < value() else MenuStyle.MUTED)

func choose(score: int) -> void:
	if locked or score < 1 or score > 5: return
	if is_instance_valid(finish_vote):
		locked = true
		finish_vote.choose(score)
		selected.emit()
		return
	if not cloud_version.is_empty() and _scope() != cloud_scope: return
	if not cloud_version.is_empty():
		vote_saving = true
		locked = true
		refresh()
		if vote_key.is_empty() or pending_score != score:
			pending_score = score
			vote_key = preload("res://backend/backend_client.gd").new_idempotency_key()
		var response: Dictionary = await cloud_client.rate_track(cloud_version,score,vote_key)
		if not is_inside_tree() or _scope() != cloud_scope: return
		vote_saving = false
		locked = false
		if response.ok:
			vote_key = ""
			cloud_score = int(response.data.score)
			caption.text = "Rate the track"
			rated.emit()
		else:
			caption.text = "Rate the track"
			save_failed.emit()
		refresh()
		return
	var previous_ratings: Dictionary = records.settings.get("track_ratings",{}).duplicate()
	var ratings: Dictionary = previous_ratings.duplicate()
	ratings[track_id] = score
	records.settings["track_ratings"] = ratings
	if records.save_records() != OK:
		records.settings["track_ratings"] = previous_ratings
		caption.text = "Rate the track"
		refresh()
		save_failed.emit()
		if instant_finish:
			locked = true
			selected.emit()
		return
	caption.text = "Rate the track"
	refresh()
	rated.emit()
	if instant_finish:
		locked = true
		selected.emit()
