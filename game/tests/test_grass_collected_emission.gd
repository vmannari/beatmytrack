extends SceneTree

const Grass = preload("res://track/grass_road_verge.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func run() -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i: int in range(180):
		var x: float = float(i % 20)*1.5
		var y: float = float(i / 20)*1.5
		# Include rejected slivers alongside normal and sloping triangles.
		var height: float = 0.000001 if i % 7 == 0 else 1.2
		points.append_array(PackedVector2Array([Vector2(x,y),Vector2(x+1.2,y),Vector2(x+0.3,y+height)]))
		uvs.append_array(PackedVector2Array([Vector2(0.027,0.0),Vector2(-0.038,0.7),Vector2(-0.01,0.4)]))
	for details: bool in [false,true]:
		for cancel_after: int in [-1,2]:
			var old = Grass.new(); old.details_enabled = details
			var new = Grass.new(); new.details_enabled = details
			var original := SurfaceTool.new(); original.begin(Mesh.PRIMITIVE_TRIANGLES)
			var updated := SurfaceTool.new(); updated.begin(Mesh.PRIMITIVE_TRIANGLES)
			var old_calls: Array = [0]; var new_calls: Array = [0]
			var old_cancel := func() -> bool: old_calls[0] += 1; return cancel_after > 0 and old_calls[0] >= cancel_after
			var new_cancel := func() -> bool: new_calls[0] += 1; return cancel_after > 0 and new_calls[0] >= cancel_after
			for i: int in range(points.size()):
				if i % 128 == 0 and old_cancel.call(): break
				old._emit_vertex(original,points[i],uvs[i])
			var count: int = new.emit_collected(updated,points,uvs,new_cancel)
			var label: String = "details="+str(details)+" cancel="+str(cancel_after)
			check(original.commit_to_arrays() == updated.commit_to_arrays(),label+" exact mesh arrays")
			check(old._points == new._points and old._across == new._across and old._heights == new._heights,label+" pending triangle")
			check(old.detail_count == new.detail_count and old._cells_emitted == new._cells_emitted,label+" details")
			check(old_calls == new_calls and count == (0 if cancel_after > 0 else points.size()/3),label+" cancellation checks and count")
	for pending: int in [1,2]:
		for details: bool in [false,true]:
			for cancel_after: int in [-1,2]:
				var old = Grass.new(); old.details_enabled = details
				var new = Grass.new(); new.details_enabled = details
				var original := SurfaceTool.new(); original.begin(Mesh.PRIMITIVE_TRIANGLES)
				var updated := SurfaceTool.new(); updated.begin(Mesh.PRIMITIVE_TRIANGLES)
				for i: int in range(pending):
					old._emit_vertex(original,points[i],uvs[i])
					new._emit_vertex(updated,points[i],uvs[i])
				var old_calls: Array = [0]; var new_calls: Array = [0]
				var old_cancel := func() -> bool: old_calls[0] += 1; return cancel_after > 0 and old_calls[0] >= cancel_after
				var new_cancel := func() -> bool: new_calls[0] += 1; return cancel_after > 0 and new_calls[0] >= cancel_after
				for i: int in range(points.size()):
					if i % 128 == 0 and old_cancel.call(): break
					old._emit_vertex(original,points[i],uvs[i])
				var count: int = new.emit_collected(updated,points,uvs,new_cancel)
				var label: String = "pending="+str(pending)+" details="+str(details)+" cancel="+str(cancel_after)
				check(original.commit_to_arrays() == updated.commit_to_arrays(),label+" exact mesh arrays")
				check(old._points == new._points and old._across == new._across and old._heights == new._heights,label+" pending triangle")
				check(old.detail_count == new.detail_count and old._cells_emitted == new._cells_emitted,label+" details")
				check(old_calls == new_calls and count == (0 if cancel_after > 0 else points.size()/3),label+" cancellation checks and count")
	var many_points := PackedVector2Array(); var many_uvs := PackedVector2Array()
	for i: int in range(12): many_points.append_array(points); many_uvs.append_array(uvs)
	var timings: Dictionary = {"per_vertex":[],"batched":[]}
	for trial: int in range(4):
		for batched: bool in ([false,true] if trial % 2 == 0 else [true,false]):
			var grass = Grass.new(); grass.details_enabled = false
			var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var start: int = Time.get_ticks_usec()
			if batched: grass.emit_collected(tool,many_points,many_uvs,Callable())
			else:
				var no_cancel := Callable()
				for i: int in range(many_points.size()):
					if i % 128 == 0 and no_cancel.is_valid() and no_cancel.call(): break
					grass._emit_vertex(tool,many_points[i],many_uvs[i])
			timings["batched" if batched else "per_vertex"].append((Time.get_ticks_usec()-start)/1000.0)
	print("GRASS_COLLECTED_TIMING ms=",JSON.stringify(timings))
	print("GRASS_COLLECTED_EMISSION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
