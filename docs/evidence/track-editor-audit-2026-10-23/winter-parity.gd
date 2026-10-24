extends "res://tests/test_editor_incremental_objects.gd"
## Diagnostic only: isolate the existing Winter rendering assertion by asset.
func run() -> void:
	var source: NativeTrack = props_fixture("winter")
	var mismatches: Array = []
	for object: Dictionary in source.metadata.creator_document.objects:
		var track := NativeTrack.new(); track.metadata = {"theme":"winter","creator_document":{"objects":[object]},"scenery_objects":[]}; track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
		var old := NativeTrackVisual.new(); old.theme_id = "winter"; old.colors = TrackTheme.palette("winter")
		var fresh := NativeTrackVisual.new(); fresh.theme_id = "winter"; fresh.colors = old.colors
		await old._build_placed_objects(track); await fresh.refresh_editor_objects(track,false)
		var a: Dictionary = triangles(old); var b: Dictionary = triangles(fresh)
		if not same_triangles(a,b):
			var row: Dictionary = {"object":object,"available_in_winter":CreatorCatalog.available(object.kind,"winter"),"original_triangle_keys":a.size(),"incremental_triangle_keys":b.size()}
			mismatches.append(row); print("WINTER_PARITY ",JSON.stringify(row))
		old.free(); fresh.free()
	var groups: Array = []
	for available_only: bool in [false,true]:
		var track := NativeTrack.new(); track.metadata = source.metadata.duplicate(true)
		if available_only: track.metadata.creator_document.objects = track.metadata.creator_document.objects.filter(func(object: Dictionary) -> bool: return CreatorCatalog.available(object.kind,"winter"))
		track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
		var old := NativeTrackVisual.new(); old.theme_id = "winter"; old.colors = TrackTheme.palette("winter")
		var fresh := NativeTrackVisual.new(); fresh.theme_id = "winter"; fresh.colors = old.colors
		await old._build_placed_objects(track); await fresh.refresh_editor_objects(track,false)
		var equal: bool = same_triangles(triangles(old),triangles(fresh))
		groups.append({"available_only":available_only,"objects":track.metadata.creator_document.objects.size(),"exact":equal})
		old.free(); fresh.free()
	var path: String = ProjectSettings.globalize_path("res://../docs/evidence/track-editor-audit-2026-10-23/winter-parity.json")
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"single_asset_mismatches":mismatches,"objects":source.metadata.creator_document.objects.size(),"groups":groups},"\t")); file.close()
	print("WINTER_PARITY_DONE mismatches=",mismatches.size()); quit()
