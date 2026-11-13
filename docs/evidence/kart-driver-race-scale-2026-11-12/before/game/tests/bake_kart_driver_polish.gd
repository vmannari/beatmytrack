extends SceneTree
## KSF01-KSF03: connected rounded shoulders, retained cockpit and steering fit.
const OUT: String = "res://../docs/evidence/kart-driver-polish-2026-11-12"
const DEST: String = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"
const STEERING = preload("res://vehicle/kart_steering.gd")
const HELMET = preload("res://vehicle/kart_helmet.gd")
var body_source: Array = []
var static_vertex_count: int = 0
var shoulder_loops: Array[PackedInt32Array] = []
const RINGS: int = 20
const SIDES: int = 16
const JOIN_ROW: int = 2

func _initialize() -> void: run.call_deferred()

func clean_opening_boundary(source: PackedInt32Array, points: PackedVector3Array) -> PackedInt32Array:
	var result: PackedInt32Array = source
	for iteration: int in range(32):
		var edges: Dictionary = {}
		var incident: Dictionary = {}
		for corner: int in range(0,result.size(),3):
			for offset: int in range(3):
				var a: int = result[corner+offset]
				var b: int = result[corner+(offset+1)%3]
				var edge := Vector2i(mini(a,b),maxi(a,b))
				edges[edge] = int(edges.get(edge,0))+1
				if not incident.has(a): incident[a] = []
				incident[a].append(corner)
		var degree: Dictionary = {}
		for edge: Vector2i in edges:
			if edges[edge] != 1: continue
			degree[edge.x] = int(degree.get(edge.x,0))+1
			degree[edge.y] = int(degree.get(edge.y,0))+1
		var remove: Dictionary = {}
		for vertex: int in degree:
			if degree[vertex] <= 2: continue
			var pending: Array = incident[vertex].duplicate()
			var fans: Array[Array] = []
			var areas: Array[float] = []
			while not pending.is_empty():
				var stack: Array = [pending.pop_back()]
				var fan: Array = []
				var area: float = 0
				while not stack.is_empty():
					var triangle: int = stack.pop_back()
					fan.append(triangle)
					var a: Vector3 = points[result[triangle]]
					var b: Vector3 = points[result[triangle+1]]
					var c: Vector3 = points[result[triangle+2]]
					area += (b-a).cross(c-a).length()
					for candidate: int in pending.duplicate():
						var joined: bool = false
						for offset: int in range(3):
							var index: int = result[triangle+offset]
							if index != vertex and index in [result[candidate],result[candidate+1],result[candidate+2]]: joined = true
						if joined: pending.erase(candidate); stack.append(candidate)
				fans.append(fan)
				areas.append(area)
			var largest: int = 0
			for fan: int in range(areas.size()):
				if areas[fan] > areas[largest]: largest = fan
			for fan: int in range(fans.size()):
				if fan != largest:
					for triangle: int in fans[fan]: remove[triangle] = true
		if remove.is_empty(): return result
		var cleaned := PackedInt32Array()
		for corner: int in range(0,result.size(),3):
			if remove.has(corner): continue
			for offset: int in range(3): cleaned.append(result[corner+offset])
		result = cleaned
	printerr("SHOULDER_OPENING could not resolve a corner-only attachment")
	return PackedInt32Array()

func prepare_shoulder_openings() -> bool:
	var points: PackedVector3Array = body_source[Mesh.ARRAY_VERTEX]
	var original: PackedInt32Array = body_source[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	for corner: int in range(0,original.size(),3):
		var point: Vector3 = (points[original[corner]]+points[original[corner+1]]+points[original[corner+2]])/3
		var local: Vector3 = (Vector3(absf(point.x),point.y,point.z)-Vector3(0.205,0.685,0.295))/Vector3(0.10,0.11,0.16)
		if local.length_squared() < 1: continue
		for offset: int in range(3): kept.append(original[corner+offset])
	var edges: Dictionary = {}
	kept = clean_opening_boundary(kept,points)
	if kept.is_empty(): return false
	for corner: int in range(0,kept.size(),3):
		for offset: int in range(3):
			var a: int = kept[corner+offset]
			var b: int = kept[corner+(offset+1)%3]
			var edge := Vector2i(mini(a,b),maxi(a,b))
			edges[edge] = int(edges.get(edge,0))+1
	var links: Dictionary = {}
	for edge: Vector2i in edges:
		if edges[edge] != 1: continue
		for pair: Vector2i in [edge,Vector2i(edge.y,edge.x)]:
			if not links.has(pair.x): links[pair.x] = []
			links[pair.x].append(pair.y)
	for side: float in [-1.0,1.0]:
		var pending: Dictionary = {}
		for index: int in links:
			if points[index].x*side > 0: pending[index] = true
		var opening := PackedInt32Array()
		while not pending.is_empty():
			var start: int = pending.keys()[0]
			var loop := PackedInt32Array()
			var previous: int = -1
			var current: int = start
			while current != start or loop.is_empty():
				if links[current].size() != 2: printerr("SHOULDER_OPENING nonmanifold boundary"); return false
				loop.append(current)
				pending.erase(current)
				var next: int = links[current][0] if links[current][0] != previous else links[current][1]
				previous = current
				current = next
				if loop.size() > links.size(): printerr("SHOULDER_OPENING branching boundary"); return false
			# The existing reconstruction has tiny four-edge sampling apertures.
			# Keep those unchanged; each new shoulder opening is a large loop.
			if loop.size() < 8: continue
			if not opening.is_empty(): printerr("SHOULDER_OPENING multiple new openings"); return false
			opening = loop
		if opening.is_empty(): printerr("SHOULDER_OPENING no closed perimeter"); return false
		var neutral_arm: Array = sleeve(0,side)
		var arm_points: PackedVector3Array = neutral_arm[Mesh.ARRAY_VERTEX]
		var center := Vector3.ZERO
		for column: int in range(SIDES): center += arm_points[JOIN_ROW*(SIDES+1)+column]
		center /= SIDES
		var tangent: Vector3 = (arm_points[(JOIN_ROW+1)*(SIDES+1)]-arm_points[(JOIN_ROW-1)*(SIDES+1)]).normalized()
		var across: Vector3 = (arm_points[JOIN_ROW*(SIDES+1)]-center).normalized()
		var up: Vector3 = tangent.cross(across).normalized()
		# Parameterise around the opening itself, not the lower sleeve ring.
		center = Vector3.ZERO
		for vertex: int in opening: center += points[vertex]
		center /= opening.size()
		var area: float = 0
		for index: int in range(opening.size()):
			var a: Vector3 = points[opening[index]]-center
			var b: Vector3 = points[opening[(index+1)%opening.size()]]-center
			area += a.dot(across)*b.dot(up)-b.dot(across)*a.dot(up)
		if area < 0: opening.reverse()
		var start: int = 0
		var nearest: float = INF
		for index: int in range(opening.size()):
			var delta: Vector3 = points[opening[index]]-center
			var angle: float = absf(atan2(delta.dot(up),delta.dot(across)))
			if angle < nearest: nearest = angle; start = index
		var ordered := PackedInt32Array()
		for index: int in range(opening.size()): ordered.append(opening[(start+index)%opening.size()])
		shoulder_loops.append(ordered)
	# Relax only the newly cut shoulder perimeter and its immediate garment
	# neighbours. The backrest, pelvis and legs retain their fitted positions.
	var neighbours: Dictionary = {}
	for corner: int in range(0,kept.size(),3):
		for a: int in range(3):
			var vertex: int = kept[corner+a]
			if not neighbours.has(vertex): neighbours[vertex] = {}
			for b: int in range(3):
				if a != b: neighbours[vertex][kept[corner+b]] = true
	var weights: Dictionary = {}
	for loop: PackedInt32Array in shoulder_loops:
		for vertex: int in loop:
			weights[vertex] = 1.0
			for neighbour: int in neighbours[vertex]:
				if not weights.has(neighbour): weights[neighbour] = 0.45
	for iteration: int in range(12):
		var updated: PackedVector3Array = points.duplicate()
		for vertex: int in weights:
			if points[vertex].y < 0.60 or points[vertex].z > 0.41: continue
			var average := Vector3.ZERO
			for neighbour: int in neighbours[vertex]: average += points[neighbour]
			average /= neighbours[vertex].size()
			updated[vertex] = points[vertex].lerp(average,0.38*weights[vertex])
		points = updated
	body_source[Mesh.ARRAY_VERTEX] = points
	body_source[Mesh.ARRAY_INDEX] = kept
	return true

func shoulder_joint(arrays: Array, loop: PackedInt32Array, arm_offset: int) -> void:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Join the actual torso perimeter to sleeve join row with shared boundary
	# vertices. No open tube edge or overlapping shoulder pad remains visible.
	var center := Vector3.ZERO
	for column: int in range(SIDES): center += points[arm_offset+JOIN_ROW*(SIDES+1)+column]
	center /= SIDES
	var tangent: Vector3 = (points[arm_offset+(JOIN_ROW+1)*(SIDES+1)]-points[arm_offset+(JOIN_ROW-1)*(SIDES+1)]).normalized()
	var ordered: PackedInt32Array = loop
	var reverse_patch: bool = false
	var found_edge: bool = false
	for corner: int in range(0,indices.size(),3):
		for offset: int in range(3):
			var a: int = indices[corner+offset]
			var b: int = indices[corner+(offset+1)%3]
			if a == ordered[0] and b == ordered[1]: reverse_patch = true; found_edge = true
			if a == ordered[1] and b == ordered[0]: found_edge = true
	assert(found_edge,"The joint must share the actual torso boundary")
	var fractions := PackedFloat32Array([0.0])
	var length: float = 0
	for index: int in range(ordered.size()):
		length += points[ordered[index]].distance_to(points[ordered[(index+1)%ordered.size()]])
		fractions.append(length)
	for index: int in range(fractions.size()): fractions[index] /= length
	var joint_start: int = points.size()
	var previous: PackedInt32Array = ordered
	for weight: float in [0.16,0.33,0.50,0.67,0.84]:
		var ring := PackedInt32Array()
		for index: int in range(ordered.size()):
			var u: float = fractions[index]*SIDES
			var column: int = mini(SIDES-1,floori(u))
			var blend: float = u-column
			var a: int = arm_offset+JOIN_ROW*(SIDES+1)+column
			var b: int = a+1
			var target: Vector3 = points[a].lerp(points[b],blend)
			var normal: Vector3 = normals[ordered[index]].lerp(normals[a].lerp(normals[b],blend),weight).normalized()
			ring.append(points.size())
			points.append(points[ordered[index]].lerp(target,weight)+normal*sin(weight*PI)*0.005)
			normals.append(normal)
			uv.append(uv[ordered[index]].lerp(uv[a].lerp(uv[b],blend),weight))
			colors.append(colors[ordered[index]].lerp(colors[a].lerp(colors[b],blend),weight))
		for index: int in range(ordered.size()):
			var next: int = (index+1)%ordered.size()
			for triangle: Array in [[previous[index],previous[next],ring[next]],[previous[index],ring[next],ring[index]]]:
				if reverse_patch: triangle.reverse()
				for vertex: int in triangle: indices.append(vertex)
		previous = ring
	var i: int = 0
	var j: int = 0
	while i < ordered.size() or j < SIDES:
		var triangle: Array
		if i < ordered.size() and (j == SIDES or fractions[i+1] <= float(j+1)/SIDES):
			triangle = [previous[i%ordered.size()],previous[(i+1)%ordered.size()],arm_offset+JOIN_ROW*(SIDES+1)+j%SIDES]
			i += 1
		else:
			triangle = [previous[i%ordered.size()],arm_offset+JOIN_ROW*(SIDES+1)+(j+1)%SIDES,arm_offset+JOIN_ROW*(SIDES+1)+j%SIDES]
			j += 1
		if reverse_patch: triangle.reverse()
		for vertex: int in triangle: indices.append(vertex)
	# Fair the new connected patch while keeping both sewn boundaries fixed.
	var neighbours: Dictionary = {}
	for corner: int in range(0,indices.size(),3):
		for a: int in range(3):
			var vertex: int = indices[corner+a]
			if vertex < joint_start: continue
			if not neighbours.has(vertex): neighbours[vertex] = {}
			for b: int in range(3):
				if a != b: neighbours[vertex][indices[corner+b]] = true
	for iteration: int in range(24):
		var updated: PackedVector3Array = points.duplicate()
		for vertex: int in neighbours:
			var average := Vector3.ZERO
			for neighbour: int in neighbours[vertex]: average += points[neighbour]
			updated[vertex] = points[vertex].lerp(average/neighbours[vertex].size(),0.48)
		points = updated
	# Match the sleeve tangent at the sewn edge so the join cannot pinch into
	# a narrow neck and flare back out into a cut-looking cylinder.
	for row: int in range(5):
		var weight: float = [0.16,0.33,0.50,0.67,0.84][row]
		var blend: float = smoothstep(0.30,0.84,weight)
		for index: int in range(ordered.size()):
			var u: float = fractions[index]*SIDES
			var column: int = mini(SIDES-1,floori(u))
			var a: int = arm_offset+JOIN_ROW*(SIDES+1)+column
			var target: Vector3 = points[a].lerp(points[a+1],u-column)
			var extension: Vector3 = target-tangent*(1-weight)*0.10
			var vertex: int = joint_start+row*ordered.size()+index
			points[vertex] = points[vertex].lerp(extension,blend)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

func sleeve_center(t: float, shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> Vector3:
	# Straight limb shafts meet in a short rounded elbow. Curving both entire
	# shafts into one spline made the old silhouette read as a rubber hose.
	# Bury the small sleeve root in the torso. The first visible section grows
	# into a rounded deltoid below the neck, rather than exposing a cut tube.
	var root: Vector3 = shoulder+Vector3(-signf(shoulder.x)*0.025,0,-0.015)
	var entry: Vector3 = elbow+(root-elbow).normalized()*0.035
	var exit: Vector3 = elbow+(wrist-elbow).normalized()*0.035
	if t <= 0.45: return root.lerp(entry,t/0.45)
	if t >= 0.55: return exit.lerp(wrist,(t-0.55)/0.45)
	var u: float = (t-0.45)/0.10
	return entry*(1-u)*(1-u)+elbow*2*u*(1-u)+exit*u*u

func sleeve_radius(t: float) -> float:
	# Deltoid, upper arm, elbow, forearm muscle and narrow wrist/cuff.
	var profile: Array[Vector2] = [Vector2(0,0.018),Vector2(0.05,0.046),Vector2(0.10,0.061),Vector2(0.12,0.063),Vector2(0.35,0.053),Vector2(0.50,0.046),Vector2(0.62,0.050),Vector2(0.82,0.039),Vector2(0.94,0.033),Vector2(1,0.034)]
	for index: int in range(profile.size()-1):
		if t <= profile[index+1].x:
			return lerpf(profile[index].y,profile[index+1].y,smoothstep(profile[index].x,profile[index+1].x,t))
	return profile[-1].y

func sleeve(input: float, side: float) -> Array:
	var shoulder: Vector3 = STEERING.mirrored(STEERING.SHOULDER,side)
	var pole: Vector3 = STEERING.mirrored(Vector3(0.23,0.52,0.10),side)
	var rotation: Basis = STEERING.wheel_basis(input)*STEERING.REST.inverse()
	var wrist: Vector3 = STEERING.CENTER+rotation*(STEERING.mirrored(STEERING.WRIST,side)-STEERING.SOURCE_CENTER)
	var elbow: Vector3 = STEERING.elbow_for(shoulder,wrist,pole)
	var outer_elbow: Vector3 = ((elbow-shoulder).normalized()-(wrist-elbow).normalized()).normalized()
	var vertices := PackedVector3Array()
	var reference := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for row: int in range(RINGS+1):
		var t: float = float(row)/RINGS
		var point: Vector3 = sleeve_center(t,shoulder,elbow,wrist)
		var tangent: Vector3 = (sleeve_center(minf(1,t+0.001),shoulder,elbow,wrist)-sleeve_center(maxf(0,t-0.001),shoulder,elbow,wrist)).normalized()
		var across: Vector3 = (Vector3.RIGHT-tangent*tangent.dot(Vector3.RIGHT)).normalized()
		var up: Vector3 = tangent.cross(across).normalized()
		var radius: float = sleeve_radius(t)
		for column: int in range(SIDES+1):
			var a: float = TAU*column/SIDES
			var normal: Vector3 = across*cos(a)+up*sin(a)
			var inner: float = maxf(0,-normal.dot(outer_elbow))
			var fold: float = (0.003*exp(-pow((t-0.43)/0.024,2))-0.0025*exp(-pow((t-0.49)/0.020,2))+0.002*exp(-pow((t-0.55)/0.025,2)))*inner*inner
			var elbow_tip: float = 0.004*exp(-pow((t-0.50)/0.055,2))*pow(maxf(0,normal.dot(outer_elbow)),3)
			var cuff: float = 0.001*exp(-pow((t-0.96)/0.020,2))
			# The sleeve is slightly flatter across the arm than in its bend plane.
			var section: Vector3 = across*cos(a)*0.91+up*sin(a)
			var vertex: Vector3 = point+section*radius+normal*(fold+elbow_tip+cuff)
			vertices.append(vertex)
			reference.append(normal)
			uv.append(Vector2(float(column)/SIDES,t))
			var color: Color = Color("465861").lerp(Color("26343a"),smoothstep(0.94,0.97,t))
			var elbow_panel: float = exp(-pow((t-0.5)/0.09,4))*maxf(0,normal.dot(outer_elbow))*0.55
			color = color.lerp(Color("354852"),elbow_panel)
			var seam: float = exp(-pow(wrapf(a-0.35,-PI,PI)/0.08,2))*smoothstep(0.02,0.10,t)*(1-smoothstep(0.88,0.94,t))
			color = color.lerp(Color("61767e"),seam*0.30)
			var shoulder_color: Color = Color("465861").lerp(Color("61767e"),smoothstep(0.66,0.72,vertex.y)*0.6)
			colors.append(color.lerp(shoulder_color,1-smoothstep(0.10,0.23,t)))
	for row: int in range(RINGS):
		if row < JOIN_ROW: continue # Replaced by the connected shoulder joint.
		for column: int in range(SIDES):
			var a: int = row*(SIDES+1)+column
			for triangle: Array in [[a,a+1,a+SIDES+2],[a,a+SIDES+2,a+SIDES+1]]:
				if (vertices[triangle[1]]-vertices[triangle[0]]).cross(vertices[triangle[2]]-vertices[triangle[0]]).dot(reference[triangle[0]]) > 0: triangle.reverse()
				for index: int in triangle: indices.append(index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = reference
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = welded_normals(arrays)
	return arrays

func garment(original: Array, input: float) -> Array:
	var result: Array = body_source.duplicate(true)
	var vertices: PackedVector3Array = result[Mesh.ARRAY_VERTEX]
	var reference: PackedVector3Array = result[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = result[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = result[Mesh.ARRAY_COLOR]
	var indices := PackedInt32Array()
	indices.append_array(result[Mesh.ARRAY_INDEX])
	# Keep the original physical boot soles and fitted zipper as separate islands.
	var retained_indices := PackedInt32Array()
	var original_indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
	assert(original_indices.size()/3 == 6780)
	for corner: int in range(original_indices.size()):
		if corner < 72*3 or corner >= original_indices.size()-544*3: retained_indices.append(original_indices[corner])
	var retained_map: Dictionary = {}
	for index: int in retained_indices:
		if not retained_map.has(index):
			retained_map[index] = vertices.size()
			vertices.append(original[Mesh.ARRAY_VERTEX][index])
			reference.append(original[Mesh.ARRAY_NORMAL][index])
			uv.append(original[Mesh.ARRAY_TEX_UV][index])
			colors.append(original[Mesh.ARRAY_COLOR][index])
		indices.append(retained_map[index])
	static_vertex_count = vertices.size()
	for side: float in [-1.0,1.0]:
		var arm: Array = sleeve(input,side)
		var offset: int = vertices.size()
		for index: int in arm[Mesh.ARRAY_INDEX]: indices.append(index+offset)
		vertices.append_array(arm[Mesh.ARRAY_VERTEX])
		reference.append_array(arm[Mesh.ARRAY_NORMAL])
		uv.append_array(arm[Mesh.ARRAY_TEX_UV])
		colors.append_array(arm[Mesh.ARRAY_COLOR])
	result[Mesh.ARRAY_VERTEX] = vertices
	result[Mesh.ARRAY_NORMAL] = reference
	result[Mesh.ARRAY_TEX_UV] = uv
	result[Mesh.ARRAY_COLOR] = colors
	result[Mesh.ARRAY_INDEX] = indices
	result[Mesh.ARRAY_TANGENT] = null
	for side: int in range(2): shoulder_joint(result,shoulder_loops[side],static_vertex_count+side*(RINGS+1)*(SIDES+1))
	result[Mesh.ARRAY_NORMAL] = welded_normals(result)
	# Broad cloth normals over the shoulder transition; preserve the crisp
	# elbow and forearm response below the upper-arm region.
	var smooth: PackedVector3Array = result[Mesh.ARRAY_NORMAL]
	var points: PackedVector3Array = result[Mesh.ARRAY_VERTEX]
	var faces: PackedInt32Array = result[Mesh.ARRAY_INDEX]
	for iteration: int in range(12):
		var sums := PackedVector3Array()
		sums.resize(points.size())
		for corner: int in range(0,faces.size(),3):
			for a: int in range(3):
				var vertex: int = faces[corner+a]
				if points[vertex].y < 0.61: continue
				for b: int in range(3): sums[vertex] += smooth[faces[corner+b]]
		for vertex: int in range(points.size()):
			if sums[vertex].length_squared() > 0.001: smooth[vertex] = smooth[vertex].lerp(sums[vertex].normalized(),0.6*smoothstep(0.61,0.68,points[vertex].y)).normalized()
	result[Mesh.ARRAY_NORMAL] = smooth
	return result

func welded_normals(arrays: Array) -> PackedVector3Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index: int in range(vertices.size()): indices.append(index)
	var sums: Dictionary = {}
	var keys: Array[Vector3i] = []
	for point: Vector3 in vertices: keys.append(Vector3i((point*100000).round()))
	for corner: int in range(0,indices.size(),3):
		var a: int = indices[corner]
		var b: int = indices[corner+1]
		var c: int = indices[corner+2]
		var normal: Vector3 = (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		for index: int in [a,b,c]: sums[keys[index]] = sums.get(keys[index],Vector3.ZERO)+normal
	var result := PackedVector3Array()
	for index: int in range(vertices.size()):
		var normal: Vector3 = sums.get(keys[index],normals[index])
		result.append(normal.normalized() if normal.length_squared() > 1e-20 else normals[index].normalized())
	return result

func glove_normals(arrays: Array) -> PackedVector3Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index: int in range(vertices.size()): indices.append(index)
	var sums: Dictionary = {}
	var keys: Array[Vector3i] = []
	for point: Vector3 in vertices: keys.append(Vector3i((point*100000).round()))
	for corner: int in range(0,indices.size(),3):
		var a: int = indices[corner]
		var b: int = indices[corner+1]
		var c: int = indices[corner+2]
		var normal: Vector3 = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
		if normal.dot(normals[a]+normals[b]+normals[c]) < 0: normal = -normal
		for index: int in [a,b,c]: sums[keys[index]] = sums.get(keys[index],Vector3.ZERO)+normal
	var result := PackedVector3Array()
	for index: int in range(vertices.size()): result.append(sums.get(keys[index],normals[index]).normalized())
	return result


func run() -> void:
	var evidence_root: String = OUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): evidence_root = argument.trim_prefix("--evidence-root=")
	var original: ArrayMesh = load(OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	assert(original != null)
	var neutral := ArrayMesh.new()
	var bindings: Dictionary = {}
	var body_vertices := PackedVector3Array()
	var body_normals := PackedVector3Array()
	var points: PackedFloat32Array = FileAccess.get_file_as_bytes("res://../build/kart-driver-polish-2026-11-12/body-vertices.bin").to_float32_array()
	var vectors: PackedFloat32Array = FileAccess.get_file_as_bytes("res://../build/kart-driver-polish-2026-11-12/body-normals.bin").to_float32_array()
	for index: int in range(0,points.size(),3):
		body_vertices.append(Vector3(points[index],points[index+1],points[index+2]))
		body_normals.append(Vector3(vectors[index],vectors[index+1],vectors[index+2]))
	var body_indices: PackedInt32Array = FileAccess.get_file_as_bytes("res://../build/kart-driver-polish-2026-11-12/body-indices.bin").to_int32_array()
	body_source.resize(Mesh.ARRAY_MAX)
	body_source[Mesh.ARRAY_VERTEX] = body_vertices
	body_source[Mesh.ARRAY_NORMAL] = body_normals
	body_source[Mesh.ARRAY_INDEX] = body_indices
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,body_source)
	importer.generate_lods(60,0,[])
	for lod: int in range(importer.get_surface_lod_count(0)):
		if body_indices.size()/3 <= 4200: break
		body_indices = importer.get_surface_lod_indices(0,lod)
	var compact := PackedVector3Array()
	var compact_normals := PackedVector3Array()
	var mapping: Dictionary = {}
	for corner: int in range(body_indices.size()):
		var index: int = body_indices[corner]
		if not mapping.has(index):
			mapping[index] = compact.size()
			compact.append(body_vertices[index])
			compact_normals.append(body_normals[index])
		body_indices[corner] = mapping[index]
	body_vertices = compact
	body_normals = compact_normals
	body_source[Mesh.ARRAY_VERTEX] = body_vertices
	body_source[Mesh.ARRAY_NORMAL] = body_normals
	body_source[Mesh.ARRAY_INDEX] = body_indices
	var body_uv := PackedVector2Array()
	var body_colors := PackedColorArray()
	for point: Vector3 in body_vertices:
		body_uv.append(Vector2(point.x,point.y))
		var color := Color("465861")
		color = color.lerp(Color("61767e"),smoothstep(0.66,0.72,point.y)*0.6)
		if point.y > 0.74: color = Color("26343a")
		if point.z < -0.32 and point.y > 0.42: color = Color("354852")
		body_colors.append(color)
	body_source[Mesh.ARRAY_TEX_UV] = body_uv
	body_source[Mesh.ARRAY_COLOR] = body_colors
	# The numpy reconstruction uses counterclockwise outward faces. Native
	# Godot buffers require clockwise faces; retain every fitted vertex.
	for corner: int in range(0,body_indices.size(),3):
		var swap: int = body_indices[corner+1]
		body_indices[corner+1] = body_indices[corner+2]
		body_indices[corner+2] = swap
	body_source[Mesh.ARRAY_INDEX] = body_indices
	if not prepare_shoulder_openings(): quit(1); return
	for surface: int in range(original.get_surface_count()):
		var material: StandardMaterial3D = original.surface_get_material(surface)
		if material.resource_name not in ["RT_DriverSuit","RT_Gloves"]: continue
		var arrays: Array = original.surface_get_arrays(surface)
		bindings[neutral.get_surface_count()] = arrays.duplicate(true)
		if material.resource_name == "RT_DriverSuit": arrays = garment(arrays,0)
		else:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index: int in range(vertices.size()): vertices[index] += STEERING.CENTER-STEERING.SOURCE_CENTER
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_TANGENT] = null
		if material.resource_name != "RT_DriverSuit": arrays[Mesh.ARRAY_NORMAL] = glove_normals(arrays)
		# Preserve the measured back, pelvis, boot and pedal surfaces exactly.
		# Reduce the bright zipper contrast, keeping the slate tailoring panels.
		if material.resource_name == "RT_DriverSuit":
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for index: int in range(colors.size()):
				if colors[index].r > 0.50: colors[index] = Color("667b83")
			arrays[Mesh.ARRAY_COLOR] = colors
		material = material.duplicate()
		# A broad diffuse response avoids triangular light bands across cloth.
		# Keep the matte palette and disabled specular of the established suit.
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		neutral.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		neutral.surface_set_material(neutral.get_surface_count()-1,material)
	# Build all six material roles; the shared finisher retains the static split.
	# Replace the 401-triangle printed head with a shaped shell, actual opaque
	# visor, rubber aperture returns, vents and recessed visor hardware.
	var helmet := Node3D.new()
	preload("res://vehicle/kart_geometry.gd").use_baked = false
	HELMET.build(helmet,true)
	var groups: Dictionary = {}
	var materials: Dictionary = {}
	var scale := Vector3(0.69,0.773,0.78)
	var pose := Transform3D(Basis.from_scale(scale),Vector3(0,0.740213-0.765*scale.y,0.388-0.225*scale.z))
	for node: MeshInstance3D in helmet.get_children():
		var material: StandardMaterial3D = node.get_active_material(0)
		var label: String = "HelmetShell" if material.albedo_color.r > 0.7 else "HelmetHardware" if material.metallic > 0.5 else "HelmetVisor" if material.metallic > 0.1 else "HelmetTrim"
		if not groups.has(label):
			groups[label] = SurfaceTool.new()
			materials[label] = material
			material.resource_name = "RT_Helemt" if label == "HelmetShell" else label
		groups[label].append_from(node.mesh,0,pose*node.transform)
	for label: String in groups:
		groups[label].index()
		groups[label].commit(neutral)
		neutral.surface_set_material(neutral.get_surface_count()-1,materials[label])
	helmet.free()
	var result := ArrayMesh.new()
	result.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for direction: int in [-1,1]:
		for step: int in range(1,STEERING.STEPS+1): result.add_blend_shape("Steer%s%d" % ["Left" if direction < 0 else "Right",step])
	var bounds: AABB = neutral.get_aabb()
	for surface: int in range(neutral.get_surface_count()):
		var arrays: Array = neutral.surface_get_arrays(surface)
		var material: StandardMaterial3D = neutral.surface_get_material(surface)
		var movable: bool = material.resource_name in ["RT_DriverSuit","RT_Gloves"]
		var shapes: Array[Array] = []
		for direction: int in [-1,1]:
			for step: int in range(1,STEERING.STEPS+1):
				var input: float = float(direction*step)/STEERING.STEPS
				var posed: Array = arrays.duplicate()
				if material.resource_name == "RT_DriverSuit": posed = garment(bindings[surface],input)
				elif material.resource_name == "RT_Gloves":
					var vertices: PackedVector3Array = posed[Mesh.ARRAY_VERTEX].duplicate()
					var rotation: Basis = STEERING.wheel_basis(input)*STEERING.REST.inverse()
					var original_points: PackedVector3Array = bindings[surface][Mesh.ARRAY_VERTEX]
					for index: int in range(vertices.size()): vertices[index] = STEERING.CENTER+rotation*(original_points[index]-STEERING.SOURCE_CENTER)
					posed[Mesh.ARRAY_VERTEX] = vertices
				if posed[Mesh.ARRAY_INDEX] != arrays[Mesh.ARRAY_INDEX]: printerr("SHOULDER_TOPOLOGY pose changed connectivity"); quit(1); return
				var normals: PackedVector3Array = posed[Mesh.ARRAY_NORMAL] if material.resource_name == "RT_DriverSuit" else glove_normals(posed) if movable else arrays[Mesh.ARRAY_NORMAL]
				var shape: Array = []
				shape.resize(Mesh.ARRAY_MAX)
				shape[Mesh.ARRAY_VERTEX] = posed[Mesh.ARRAY_VERTEX]
				shape[Mesh.ARRAY_NORMAL] = normals
				if arrays[Mesh.ARRAY_TANGENT] != null: shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
				shapes.append(shape)
				for point: Vector3 in posed[Mesh.ARRAY_VERTEX]: bounds = bounds.expand(point)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
		result.surface_set_material(surface,material)
	result.custom_aabb = bounds.grow(0.002)
	result.set_meta("kart_suit_static_vertices",static_vertex_count)
	preload("res://tests/support/kart_driver_finish.gd").save(result)
	FileAccess.open(evidence_root+"/bake.json",FileAccess.WRITE).store_string(JSON.stringify({"triangles":result.get_faces().size()/3,"driver_triangles":(result.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()+result.surface_get_arrays(1)[Mesh.ARRAY_INDEX].size())/3,"surfaces":result.get_surface_count(),"steering_shapes":result.get_blend_shape_count(),"bounds":str(bounds),"source":FileAccess.get_sha256(OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")},"\t"))
	print("KART_DRIVER_SHOULDER_BAKE total=",result.get_faces().size()/3," triangles; ",result.get_surface_count()," materials; ",result.get_blend_shape_count()," steering poses; animated body and static helmet saved")
	quit()
