"""Exact preparation prototypes, confined to the private algorithm snapshot."""
import sys
from pathlib import Path
import road_checkpoint_efficiency_2026_11_17 as task

ROOT, PROJECT, OUT = task.base.ROOT, task.base.PROJECT, task.base.OUT

def edit(relative, transform):
    source=PROJECT/relative
    backup=OUT/'reference'/relative
    if not backup.exists():
        backup.parent.mkdir(parents=True,exist_ok=True); backup.write_bytes(source.read_bytes())
    task.base.replace_file(source,transform(backup.read_text(encoding='utf-8')))

def reverse_crossings(source):
    old='\tif not cache.has(key): cache[key] = _crossings(session,path)'
    assert source.count(old)==1
    source=source.replace(old,'\tif not cache.has("gate_bins"): cache["gate_bins"] = _gate_bins(session)\n\tif not cache.has(key): cache[key] = _crossings(session,path,cache.gate_bins)')
    start=source.index('static func _crossings('); end=source.index('\nstatic func _projection(',start)
    replacement='''static func _gate_bins(session: RefCounted) -> Dictionary:
	var bins: Dictionary = {}
	for gate: int in range(session._centers.size()):
		var center: Vector2 = session._centers[gate]
		var normal: Vector2 = session._directions[gate].orthogonal()
		var widths: Vector2 = session._widths[gate]
		var left: Vector2 = center-normal*widths.x
		var right: Vector2 = center+normal*widths.y
		var low := Vector2i(((left.min(right)-Vector2.ONE*0.001)/8.0).floor())
		var high := Vector2i(((left.max(right)+Vector2.ONE*0.001)/8.0).floor())
		for y: int in range(low.y,high.y+1):
			for x: int in range(low.x,high.x+1):
				var cell := Vector2i(x,y)
				if not bins.has(cell): bins[cell] = []
				bins[cell].append(gate)
	return bins

static func _crossings(session: RefCounted, path: PackedVector2Array, gate_bins: Dictionary = {}) -> PackedFloat64Array:
	if gate_bins.is_empty(): gate_bins = _gate_bins(session)
	var events := PackedFloat64Array(); events.resize(session._centers.size()); events.fill(-1.0)
	var nearest := PackedFloat64Array(); nearest.resize(events.size()); nearest.fill(INF)
	# The same shared-cell test, indexed from gates once for every lane. Each
	# gate still visits path segments in ascending order, preserving tie choices.
	for i: int in range(path.size()-1):
		var low := Vector2i((path[i].min(path[i+1])/8.0).floor())
		var high := Vector2i((path[i].max(path[i+1])/8.0).floor())
		var candidates: Dictionary = {}
		for y: int in range(low.y,high.y+1):
			for x: int in range(low.x,high.x+1):
				for gate: int in gate_bins.get(Vector2i(x,y),[]): candidates[gate] = true
		for gate: int in candidates:
			var center: Vector2 = session._centers[gate]
			var direction: Vector2 = session._directions[gate]
			var widths: Vector2 = session._widths[gate]
			var before: float = (path[i]-center).dot(direction)
			var after: float = (path[i+1]-center).dot(direction)
			var f: float = -before/(after-before) if before <= 0.0 and after > 0.0 else -1.0
			if f < 0.0: continue
			var p: Vector2 = path[i].lerp(path[i+1],f)
			var lateral: float = (p-center).dot(direction.orthogonal())
			if lateral < -widths.x or lateral > widths.y: continue
			if p.distance_squared_to(center) < nearest[gate]:
				nearest[gate] = p.distance_squared_to(center); events[gate] = i+f
	return events
'''
    return source[:start]+replacement+source[end:]

def skip_duplicate_cells(source):
    anchor='\t\tvar key := Vector2i(((center+normal*step*CELL_M*0.5)/CELL_M).floor())'
    assert source.count(anchor)==1
    source=source.replace('\tvar visited: Dictionary = {}','\tvar visited: Dictionary = {}\n\tvar visited_keys: Dictionary = {}')
    return source.replace(anchor,anchor+'\n\t\tif visited_keys.has(key): continue\n\t\tvisited_keys[key] = true')

def native_corridor(source):
    source=source.replace('\tif basis.is_empty(): basis = _lane_basis(track)', '''\tif basis.is_empty(): basis = _lane_basis(track)
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").checkpoints()
	if native != null:
		var prepared: PackedVector2Array = native.checkpoint_lane(track.route,basis,fraction,constant_width,rejoin_start,recovery_m,Geometry2D)
		if not prepared.is_empty(): return prepared''',1)
    anchor='\t# A recovery lane can erase the very hairpin it should recover around.'
    source=source.replace(anchor,'''\t# This job owns the native route index; it is released with preparation.
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").checkpoints() if track.get_script().resource_path == "res://track/native_track.gd" else null
	if native != null and not native.checkpoint_prepare(track.route,PackedFloat64Array(Array(track.route_cumulative))): native = null
'''+anchor,1)
    source=source.replace('_projection(track,point,route_bins)','_projection(track,point,route_bins,native)')
    source=source.replace('static func _crossings(session: RefCounted, path: PackedVector2Array) -> PackedFloat64Array:\n', '''static func _crossings(session: RefCounted, path: PackedVector2Array) -> PackedFloat64Array:
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").checkpoints()
	if native != null:
		var prepared: PackedFloat64Array = native.checkpoint_crossings(session._centers,session._directions,PackedVector2Array(session._widths),path)
		if prepared.size() == session._centers.size(): return prepared
''',1)
    source=source.replace('bins: Dictionary) -> float:\n\tvar key', '''bins: Dictionary, native: RefCounted = null) -> float:
	if native != null:
		var prepared: float = native.checkpoint_projection(point)
		if not is_nan(prepared): return prepared
	var key''',1)
    return source

def native_adapter(source):
    return source.replace('static var roads_enabled: bool = true','static var roads_enabled: bool = true\nstatic var checkpoints_enabled: bool = true',1).replace('static func winter()', '''static func checkpoints() -> RefCounted:
	return _feature("checkpoint_algorithm_version") if checkpoints_enabled else null

static func winter()''',1)

def edge_miters(source):
    start=source.index('static func _edge_miter('); end=source.index('\n\nstatic func _inner_bend_distance',start)
    old=source[start:end]
    old=old.replace('index: int) -> Vector2:','index: int, area: float = NAN) -> Vector2:',1)
    old=old.replace('\tvar area: float = 0.0\n\tfor i: int in range(polygon.size()): area += polygon[i].cross(polygon[(i+1)%polygon.size()])','\tif is_nan(area): area = _winding_area(polygon)',1)
    helpers='''static func _winding_area(polygon: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in range(polygon.size()): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
	return area

static func edge_miters(polygon: PackedVector2Array) -> PackedVector2Array:
	# The polygon is immutable during this build. Keep the original ordered
	# double sum, and each Vector2 calculation, while doing the sum once.
	var area: float = _winding_area(polygon)
	var miters := PackedVector2Array()
	for i: int in range(polygon.size()): miters.append(_edge_miter(polygon,i,area))
	return miters

'''
    return source[:start]+helpers+old+source[end:]

def reuse_miters(source):
    start=source.index('func _asphalt_edge_faces('); end=source.index('\n\nfunc _inner_bend_distance',start)
    old=source[start:end]
    old=old.replace('\t\tfor i: int in range(polygon.size()):','\t\tvar miters: PackedVector2Array = RoadEdges.edge_miters(polygon)\n\t\tfor i: int in range(polygon.size()):',1)
    old=old.replace('RoadEdges._edge_miter(polygon,i)','miters[i]').replace('RoadEdges._edge_miter(polygon,(i+1)%polygon.size())','miters[(i+1)%polygon.size()]')
    old=old.replace('\t# Close the raised asphalt', '''\tvar native: RefCounted = preload("res://track/geometry_acceleration.gd").roads()
	if native != null and not native.has_method("road_asphalt_sides"): native = null
	var ends := PackedVector3Array()
	var outwards := PackedVector3Array()
	# Close the raised asphalt''',1)
    old_call='''\t\t\t\tASPHALT_EDGE.append(tool,VisualGeometry.world(p)+Vector3.UP*top,VisualGeometry.world(q)+Vector3.UP*top,
					VisualGeometry.world(miter_a.lerp(miter_b,float(step)/steps)),VisualGeometry.world(miter_a.lerp(miter_b,float(step+1)/steps)),0.013,0.013)'''
    assert old_call in old
    old=old.replace(old_call,'''\t\t\t\tvar a3: Vector3 = VisualGeometry.world(p)+Vector3.UP*top
				var b3: Vector3 = VisualGeometry.world(q)+Vector3.UP*top
				var outward_a: Vector3 = VisualGeometry.world(miter_a.lerp(miter_b,float(step)/steps))
				var outward_b: Vector3 = VisualGeometry.world(miter_a.lerp(miter_b,float(step+1)/steps))
				if native == null: ASPHALT_EDGE.append(tool,a3,b3,outward_a,outward_b,0.013,0.013)
				else:
					ends.append(a3); ends.append(b3)
					outwards.append(outward_a); outwards.append(outward_b)
	if native != null and not native.road_asphalt_sides(tool,ends,outwards,0.013):
		# Unsupported input is rejected before native emission begins.
		for i: int in range(0,ends.size(),2):
			ASPHALT_EDGE.append(tool,ends[i],ends[i+1],outwards[i],outwards[i+1],0.013,0.013)''',1)
    return source[:start]+old+source[end:]

if sys.argv[1]=='reverse':
    edit('race/spline_gate_corridor.gd',reverse_crossings)
elif sys.argv[1]=='coverage':
    edit('race/road_gate_coverage.gd',skip_duplicate_cells)
elif sys.argv[1]=='native':
    edit('race/spline_gate_corridor.gd',native_corridor)
    edit('track/geometry_acceleration.gd',native_adapter)
elif sys.argv[1]=='miters':
    edit('track/road_edges.gd',edge_miters)
    edit('track/native_track_visual.gd',reuse_miters)
elif sys.argv[1]=='restore':
    for p in (OUT/'reference').rglob('*.gd'):
        relative=p.relative_to(OUT/'reference')
        if len(relative.parts)>1: task.base.replace_file(PROJECT/relative,p.read_bytes())
else: raise SystemExit('Unknown candidate')
