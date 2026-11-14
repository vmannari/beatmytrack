extends SceneTree
## Returning hairpins must extrude away from each finite mouth, even when
## their two join planes coincide. Exercise actual accelerated dispatch too.
const ACCEL = preload("res://track/geometry_acceleration.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func run() -> void:
	var visual := NativeTrackVisual.new()
	if "--before" in OS.get_cmdline_user_args():
		var original := GDScript.new()
		var before: String = FileAccess.get_file_as_string("res://../build/visual-fixes-2026-11-13/median/before/game/track/native_track_visual.gd").replace("\r\n","\n")
		original.source_code = "extends NativeTrackVisual\n"
		for method: String in ["_road_border_samples", "_roadside_miter"]:
			var first: int = before.find("\nfunc "+method+"(")
			var last: int = before.find("\nfunc ",first+1)
			original.source_code += before.substr(first,last-first)+"\n"
		var loaded: bool = original.reload() == OK
		check(loaded,"task-start script loads")
		if not loaded: visual.free(); quit(1); return
		visual.set_script(original)
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
	var canonical: PackedByteArray = var_to_bytes([track.metadata,track.content_hash,track.cells,track.deck_cells,track.route,track.kerbs.triangles])
	var pieces: Array = track.metadata.creator_document.pieces
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	var outlines: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		var polygon: PackedVector2Array = RoadPieces.section_outline(pieces,index,0.0,topology)
		var bounds := Rect2(polygon[0],Vector2.ZERO)
		for point: Vector2 in polygon: bounds = bounds.expand(point)
		outlines.append({"index":index,"polygon":polygon,"bounds":bounds,"hole":false})
	check(ACCEL.roads() != null,"installed native road kernel available")
	for index: int in range(pieces.size()):
		var shape: Dictionary = VisualRoadJoin.build(pieces,index,-0.20,topology)
		check(NativeTrackVisual._coincident_join_planes(shape.cuts),"Ellipse finite-cap dispatch required "+str(index))
		ACCEL.roads_enabled = true
		var automatic: PackedVector2Array = await visual._road_border_samples(shape.contours,shape.cuts,shape.swept,pieces,index,outlines,topology)
		ACCEL.roads_enabled = false
		var scalar: PackedVector2Array = await visual._road_border_samples(shape.contours,shape.cuts,shape.swept,pieces,index,outlines,topology)
		check(automatic == scalar,"installed native dispatch uses finite-cap fallback "+str(index))
		for offset: int in range(0,automatic.size(),4):
			for endpoint: int in range(2):
				var point: Vector2 = automatic[offset+endpoint]
				if absf(point.x-14.5)>1.0 or point.y<4.0 or point.y>15.0: continue
				var normal: Vector2 = automatic[offset+endpoint+2]
				var toward_median := Vector2(0,1 if point.y<9.5 else -1)
				check(normal.dot(toward_median)>0.99,"continuous outward verge at "+str(point))
	ACCEL.roads_enabled = true
	# Parallel mouths at different positions remain on the native path.
	var straight_cuts: Array[Dictionary] = [{"point":Vector2(-10,0),"normal":Vector2.RIGHT,"span":10.0},{"point":Vector2(10,0),"normal":Vector2.LEFT,"span":10.0}]
	check(not NativeTrackVisual._coincident_join_planes(straight_cuts),"ordinary straight remains accelerated")
	check(canonical == var_to_bytes([track.metadata,track.content_hash,track.cells,track.deck_cells,track.route,track.kerbs.triangles]),"canonical track data stays byte exact")
	visual.free()
	print("JOIN_CAP_MITERS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
