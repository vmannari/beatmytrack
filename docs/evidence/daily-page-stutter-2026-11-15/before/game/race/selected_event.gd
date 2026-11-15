extends RefCounted
## Bind the existing single CPU worker to one visible, exact Daily/Rivalry event.
const SETTLE_MS: int = 250

static func identity(entry: Dictionary) -> Array:
	var manifest: Variant=entry.get("manifest",{})
	return [entry.get("id",""),entry.get("version_id",""),entry.get("content_hash",""),entry.get("canonical_track_hash",""),entry.get("redacted_track_hash",""),manifest.get("track_content_hash","") if manifest is Dictionary else ""]

static func matches(track: NativeTrack, entry: Dictionary) -> bool:
	return track != null and identity(track.metadata.get("cloud_entry",{})) == identity(entry)

static func pin(app: Node, kind: String, page: Control) -> Array:
	if kind == "daily": return [page._server_now/86400,page._ends_at,identity(page.entry)]
	return rivalry_pin(app,app.rivalry_track) if kind == "rivalry" else []

static func rivalry_pin(app: Node, index: int) -> Array:
	if index < 0 or index >= app.rivalry.model.tracks.size(): return []
	var model: RefCounted = app.rivalry.model
	return [app.lifecycle.scope(),VehicleCatalog.selected,app.rivalry.scope(),app.rivalry.snapshot_scope,app.rivalry.cached_snapshot,model.group_id,model.week,index,model.vehicle_id,model.world_circuit,identity(app.cloud.entry_from_metadata(model.tracks[index].entry)),model.status,model.completed,bool(model.tracks[index].get("available",true))]

static func current(app: Node) -> bool:
	var event: Dictionary = app._selected_preparation_event
	var page: Object = event.page.get_ref()
	if not is_instance_valid(page) or not page.is_inside_tree() or not page.is_visible_in_tree() or app.screen != event.kind: return false
	if event.kind == "daily":
		if page.page_preview or Time.get_ticks_msec() >= int(event.expires): return false
		# A race tap revalidates the same event. Keep its worker during that
		# request, but never past expiry or a different returned day/version.
		if page._busy: return identity(page.entry) == event.pin[2]
		return pin(app,"daily",page) == event.pin
	var model: RefCounted = app.rivalry.model
	return not model.sample and not model.completed and model.status == "active" and not app.rivalry.cached_snapshot and app.rivalry.snapshot_scope == app.rivalry.scope() and app.rivalry_section == "detail" and page.section == "detail" and page.selected == app.rivalry_track and pin(app,"rivalry",page) == event.pin and bool(model.tracks[app.rivalry_track].get("available",true))

static func prepare(app: Node, kind: String, page: Control, entry: Dictionary, source: Dictionary) -> void:
	if app.screen != kind or not page.is_inside_tree() or is_instance_valid(app.game) or not app.cloud._allowed(entry): return
	if kind == "daily" and page.page_preview: return
	var event_pin: Array = pin(app,kind,page)
	if event_pin.is_empty(): return
	var actual: Dictionary = page.entry if kind == "daily" else app.cloud.entry_from_metadata(app.rivalry.model.tracks[app.rivalry_track].entry)
	if identity(actual) != identity(entry): return
	var old: Dictionary = app._selected_preparation_event
	if not old.is_empty() and old.kind == kind and old.page.get_ref() == page and old.pin == event_pin and matches(app.selected_track,entry) and app._selected_preparation_vehicle == VehicleCatalog.selected and app._selected_preparation_scope == app.lifecycle.scope() and app._selected_preparation_navigation == app._navigation_generation:
		if app._selected_preparation_pending or not app.selected_track.metadata.get("metadata_only",false): return
	if app.cloud_starting: return
	app._cancel_selected_preparation()
	app._selected_preparation_event = {"kind":kind,"page":weakref(page),"pin":event_pin,"due":Time.get_ticks_msec()+SETTLE_MS,"started":false,"expires":Time.get_ticks_msec()+maxi(0,page._ends_at-page._server_now)*1000-(Time.get_ticks_msec()-page._sample_msec) if kind == "daily" else 0}
	app.selected_track = app._selected_event_track(entry)
	app._selected_preparation_track = app.selected_track
	app._selected_preparation_browser = weakref(page)
	app._selected_preparation_scope = app.lifecycle.scope()
	app._selected_preparation_navigation = app._navigation_generation
	app._selected_preparation_vehicle = VehicleCatalog.selected
	app._selected_preparation_entry = entry.duplicate(true)
	app._selected_preparation_pin = [app.selected_track.identity,app.selected_track.content_hash,app.selected_track.metadata.get("cloud_version",""),entry.get("content_hash","")]
	app._selected_preparation_source = source
	app._selected_preparation_pending = true
	if not current(app): app._cancel_selected_preparation()
