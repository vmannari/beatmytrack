extends RefCounted
## Fixed numeric schema: no Variant, object, string or recursive decoder.
## Count checks precede every allocation; dictionary insertion order is retained.
const MAX_BYTES: int = 512 * 1024
const MAX_GATES: int = 4096
const MAX_ITEMS: int = 65536
const MAX_COORD: float = 1000000.0
var stream := StreamPeerBuffer.new()
var valid: bool = true
var _reserved: int = 768

static func encode(layout: Dictionary, track: NativeTrack, versions: Array) -> PackedByteArray:
	if not validate(layout,track,versions): return PackedByteArray()
	var output := StreamPeerBuffer.new()
	output.put_double(layout._start_progress)
	output.put_u8(int(layout._finish_elevated)); output.put_u8(int(layout._spline_corridor))
	for value: Vector2 in [layout._finish_road_widths,layout._finish_widths]:
		output.put_double(value.x); output.put_double(value.y)
	output.put_u32(layout._centers.size())
	for i: int in range(layout._centers.size()):
		for value: Vector2 in [layout._centers[i],layout._directions[i],layout._widths[i],layout._road_widths[i]]:
			output.put_double(value.x); output.put_double(value.y)
		output.put_float(layout._progress[i]); output.put_float(layout._notice_reach[i])
		output.put_u32(layout._route_hints[i]); output.put_u8(int(layout._layers[i]))
	output.put_u32(layout._notice_route_bins.size())
	for cell: Vector2i in layout._notice_route_bins:
		output.put_32(cell.x); output.put_32(cell.y)
		var indices: PackedInt32Array = layout._notice_route_bins[cell]
		output.put_u32(indices.size())
		for index: int in indices: output.put_u32(index)
	output.put_u32(layout._notice_approaches.size())
	for cells: Dictionary in layout._notice_approaches:
		output.put_u32(cells.size())
		for cell: Vector2i in cells: output.put_32(cell.x); output.put_32(cell.y)
	output.put_u32(layout._notice_route_layers.size())
	output.put_data(layout._notice_route_layers)
	output.put_u32(layout._notice_layer_offsets.size())
	for offset: int in layout._notice_layer_offsets: output.put_u32(offset)
	return output.data_array if output.get_size() <= MAX_BYTES else PackedByteArray()

func decode(bytes: PackedByteArray, track: NativeTrack, versions: Array) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_BYTES or versions.size() != 3: return {}
	stream.data_array = bytes
	var layout := {"rules_key":versions[0],"notice_version":versions[1],"checkpoint_layout_version":versions[2]}
	layout._start_progress = _number()
	layout._finish_elevated = _flag()
	var spline: bool = _flag()
	layout._finish_road_widths = _vector()
	layout._finish_widths = _vector()
	layout._spline_corridor = spline
	var centers := PackedVector2Array()
	var directions := PackedVector2Array()
	var progress := PackedFloat32Array()
	var widths: Array[Vector2] = []
	var road_widths: Array[Vector2] = []
	var reach := PackedFloat32Array()
	var hints := PackedInt32Array()
	var layers: Array[bool] = []
	for i: int in range(_count(MAX_GATES,77)):
		centers.append(_vector()); directions.append(_vector())
		widths.append(_vector()); road_widths.append(_vector())
		progress.append(_number(false)); reach.append(_number(false))
		hints.append(_integer()); layers.append(_flag())
	layout._centers = centers; layout._directions = directions; layout._progress = progress
	layout._widths = widths; layout._road_widths = road_widths; layout._notice_reach = reach
	layout._route_hints = hints; layout._layers = layers
	var bins: Dictionary = {}
	for i: int in range(_count(MAX_ITEMS,16)):
		var cell := Vector2i(_integer(true),_integer(true))
		if bins.has(cell): return {}
		var indices := PackedInt32Array()
		for j: int in range(_count(mini(MAX_ITEMS,track.route.size()),4)): indices.append(_integer())
		bins[cell] = indices
	layout._notice_route_bins = bins
	var approaches: Array[Dictionary] = []
	for i: int in range(_count(MAX_GATES,4)):
		var cells: Dictionary = {}
		for j: int in range(_count(MAX_ITEMS,8)):
			var cell := Vector2i(_integer(true),_integer(true))
			if cells.has(cell): return {}
			cells[cell] = true
		approaches.append(cells)
	layout._notice_approaches = approaches
	var route_layers := PackedByteArray()
	var layer_count: int = _count(MAX_BYTES,1)
	if layer_count > 0: route_layers = stream.get_data(layer_count)[1]
	layout._notice_route_layers = route_layers
	var offsets := PackedInt32Array()
	for i: int in range(_count(MAX_ITEMS*2,4)): offsets.append(_integer())
	layout._notice_layer_offsets = offsets
	if not valid or stream.get_available_bytes() != 0 or not validate(layout,track,versions): return {}
	# Dot assignment uses StringName keys; TrackSession's prepared-field loop
	# uses String keys. Preserve even this distinction in the exact receipt.
	var exact: Dictionary = {}
	for key: Variant in layout: exact[String(key)] = layout[key]
	return exact

func _take(bytes: int) -> bool:
	if not valid or stream.get_available_bytes() < bytes: valid = false; return false
	return true

func _integer(signed_value: bool = false) -> int:
	if not _take(4): return 0
	return stream.get_32() if signed_value else stream.get_u32()

func _count(maximum: int, stride: int) -> int:
	var count: int = _integer()
	if not valid or count > maximum or count > stream.get_available_bytes()/stride:
		valid = false; return 0
	# Reserve conservative container headroom before nested arrays/dictionaries
	# are created, not only after validating the completed layout.
	_reserved += count*stride*12
	if _reserved > 2*1024*1024: valid = false; return 0
	return count

func _number(double_value: bool = true) -> float:
	if not _take(8 if double_value else 4): return 0.0
	var value: float = stream.get_double() if double_value else stream.get_float()
	if not is_finite(value): valid = false
	return value

func _flag() -> bool:
	if not _take(1): return false
	var value: int = stream.get_u8()
	if value > 1: valid = false
	return value == 1

func _vector() -> Vector2: return Vector2(_number(),_number())

static func validate(layout: Dictionary, track: NativeTrack, versions: Array) -> bool:
	if versions.size() != 3 or layout.size() != 20: return false
	if layout.get("rules_key") != versions[0] or layout.get("notice_version") != versions[1] or layout.get("checkpoint_layout_version") != versions[2]: return false
	# Projecting the finish can exceed route_length by packed cumulative rounding
	# at the closing segment (Dust cloud). Require the exact builder projection.
	if not layout.get("_start_progress") is float or not is_finite(layout._start_progress) or layout._start_progress != track.route_progress(track.finish_center): return false
	if not layout.get("_finish_elevated") is bool or not layout.get("_spline_corridor") is bool: return false
	for field: String in ["_finish_road_widths","_finish_widths"]:
		if not _width(layout.get(field)): return false
	if layout._finish_widths != layout._finish_road_widths+Vector2.ONE*1.5: return false
	for field: String in ["_centers","_directions"]:
		if not layout.get(field) is PackedVector2Array: return false
	for field: String in ["_progress","_notice_reach"]:
		if not layout.get(field) is PackedFloat32Array: return false
	for field: String in ["_widths","_road_widths","_layers","_notice_approaches"]:
		if not layout.get(field) is Array: return false
	if not layout.get("_route_hints") is PackedInt32Array or not layout.get("_notice_route_bins") is Dictionary or not layout.get("_notice_route_layers") is PackedByteArray or not layout.get("_notice_layer_offsets") is PackedInt32Array: return false
	var count: int = layout._centers.size()
	if count > MAX_GATES or track.route.size() < 2 or track.route.size() > MAX_ITEMS or not is_finite(track.route_length) or track.route_length <= 0.0: return false
	for field: String in ["_directions","_progress","_notice_reach","_widths","_road_widths","_layers","_route_hints"]:
		if layout[field].size() != count: return false
	for i: int in range(count):
		if not _point(layout._centers[i]) or not _point(layout._directions[i]): return false
		if absf(layout._directions[i].length_squared()-1.0) > 0.001: return false
		if not _width(layout._widths[i]) or not _width(layout._road_widths[i]) or not layout._layers[i] is bool: return false
		if layout._widths[i].x < layout._road_widths[i].x or layout._widths[i].y < layout._road_widths[i].y: return false
		if not _bounded(layout._progress[i],track.route_length+0.01) or (i > 0 and layout._progress[i] < layout._progress[i-1]): return false
		if not _bounded(layout._notice_reach[i],track.route_length+MAX_COORD) or layout._route_hints[i] < 0 or layout._route_hints[i] >= track.route.size(): return false
	var items: int = 0
	if layout._notice_route_bins.size() > MAX_ITEMS: return false
	for cell: Variant in layout._notice_route_bins:
		if not _cell(cell) or not layout._notice_route_bins[cell] is PackedInt32Array: return false
		var indices: PackedInt32Array = layout._notice_route_bins[cell]
		items += indices.size()
		if indices.is_empty() or items > MAX_ITEMS: return false
		var last: int = -1
		for index: int in indices:
			if index <= last or index >= track.route.size(): return false
			last = index
	if layout._notice_approaches.size() != (count if layout._spline_corridor else 0): return false
	items = 0
	for cells: Variant in layout._notice_approaches:
		if not cells is Dictionary: return false
		items += cells.size()
		if items > MAX_ITEMS: return false
		for cell: Variant in cells:
			if not _cell(cell) or not cells[cell] is bool or not cells[cell]: return false
	if track.creator_bridges.is_empty():
		if not layout._notice_route_layers.is_empty() or not layout._notice_layer_offsets.is_empty(): return false
	else:
		if layout._notice_layer_offsets.size() != track.route.size()*2 or layout._notice_route_layers.size() > MAX_BYTES: return false
		var segments: Array[Vector2i] = []
		for i: int in range(track.route.size()):
			var offset: int = layout._notice_layer_offsets[i*2]
			var steps: int = layout._notice_layer_offsets[i*2+1]
			if offset < 0 or steps != maxi(1,ceili(track.route[i].distance_to(track.route[(i+1)%track.route.size()])/0.25)) or offset+steps >= layout._notice_route_layers.size(): return false
			segments.append(Vector2i(offset,steps+1))
		segments.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.x < b.x)
		var offset: int = 0
		for segment: Vector2i in segments:
			if segment.x != offset: return false
			offset += segment.y
		if offset != layout._notice_route_layers.size(): return false
		for layer: int in layout._notice_route_layers:
			if layer > 1: return false
	# Match the existing shared RAM allowance before a decoded layout is admitted.
	return var_to_bytes(layout).size()*4+768 <= 2*1024*1024

static func _bounded(value: float, maximum: float) -> bool: return is_finite(value) and value >= 0.0 and value <= maximum
static func _point(value: Vector2) -> bool: return value.is_finite() and absf(value.x) <= MAX_COORD and absf(value.y) <= MAX_COORD
static func _width(value: Variant) -> bool: return value is Vector2 and _point(value) and value.x >= 0.0 and value.y >= 0.0
static func _cell(value: Variant) -> bool: return value is Vector2i and absi(value.x) <= int(MAX_COORD) and absi(value.y) <= int(MAX_COORD)
