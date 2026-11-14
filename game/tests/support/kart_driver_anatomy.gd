extends RefCounted
## Offline anatomy enlargement. Contact points, topology and authored steering poses stay fitted.
const STEERING = preload("res://vehicle/kart_steering.gd")
const REVISION = "race_readability_wider_shoulders_v2"
const HELMET_SCALE: float = 1.20
const COLUMNS: int = 17
const ARM_VERTICES: int = 21*COLUMNS

static func torso(point: Vector3) -> Vector3:
	var front: float = 1-smoothstep(0.18,0.30,point.z)
	var free_back: float = smoothstep(0.60,0.68,point.y)
	var weight: float = smoothstep(0.46,0.68,point.y)*maxf(front,free_back)
	return Vector3(point.x*(1+0.28*weight),point.y+maxf(0,point.y-0.60)*0.35,point.z-0.020*weight*front)

static func center(t: float, root: Vector3, elbow: Vector3, wrist: Vector3) -> Vector3:
	var entry: Vector3 = elbow+(root-elbow).normalized()*0.035
	var exit: Vector3 = elbow+(wrist-elbow).normalized()*0.035
	if t<=0.45: return root.lerp(entry,t/0.45)
	if t>=0.55: return exit.lerp(wrist,(t-0.55)/0.45)
	var u: float = (t-0.45)/0.10
	return entry*(1-u)*(1-u)+elbow*2*u*(1-u)+exit*u*u

static func frame(t: float, root: Vector3, elbow: Vector3, wrist: Vector3) -> Basis:
	var tangent: Vector3 = (center(minf(1,t+0.001),root,elbow,wrist)-center(maxf(0,t-0.001),root,elbow,wrist)).normalized()
	var across: Vector3 = (Vector3.RIGHT-tangent*tangent.x).normalized()
	return Basis(across,tangent.cross(across).normalized(),tangent)

static func arm(point: Vector3, t: float, side: float, input: float) -> Vector3:
	var shoulder: Vector3 = STEERING.mirrored(STEERING.SHOULDER,side)
	var root: Vector3 = shoulder+Vector3(-side*0.025,0,-0.015)
	var wrist: Vector3 = STEERING.CENTER+(STEERING.wheel_basis(input)*STEERING.REST.inverse())*(STEERING.mirrored(STEERING.WRIST,side)-STEERING.SOURCE_CENTER)
	var elbow: Vector3 = STEERING.elbow_for(shoulder,wrist,STEERING.mirrored(Vector3(0.23,0.52,0.10),side))
	var offset: Vector3 = frame(t,root,elbow,wrist).transposed()*(point-center(t,root,elbow,wrist))
	# Keep the elbow and distal axis: the glove grip and neutral wrist remain fitted.
	var width: float = 1+0.16*(1-smoothstep(0.65,1,t))
	offset.x *= width
	offset.y *= width
	return center(t,torso(root),elbow,wrist)+frame(t,torso(root),elbow,wrist)*offset

static func normals(points: PackedVector3Array, indices: PackedInt32Array, fallback: PackedVector3Array) -> PackedVector3Array:
	var sums: Dictionary = {}
	var keys: Array[Vector3i] = []
	for point: Vector3 in points: keys.append(Vector3i((point*100000).round()))
	for corner: int in range(0,indices.size(),3):
		var a: int = indices[corner]
		var b: int = indices[corner+1]
		var c: int = indices[corner+2]
		var face: Vector3 = (points[c]-points[a]).cross(points[b]-points[a])
		for vertex: int in [a,b,c]: sums[keys[vertex]] = sums.get(keys[vertex],Vector3.ZERO)+face
	var result := PackedVector3Array()
	for vertex: int in range(points.size()):
		var normal: Vector3 = sums.get(keys[vertex],fallback[vertex])
		result.append(normal.normalized() if normal.length_squared()>1e-20 else fallback[vertex])
	return result

static func suit(arrays: Array, prefix: int, input: float) -> Array:
	var result: Array = arrays.duplicate(true)
	var original: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var points: PackedVector3Array = original.duplicate()
	for vertex: int in range(prefix): points[vertex] = torso(original[vertex])
	for side: int in range(2):
		var offset: int = prefix+side*ARM_VERTICES
		for vertex: int in range(ARM_VERTICES): points[offset+vertex] = arm(original[offset+vertex],float(vertex/COLUMNS)/20,-1 if side==0 else 1,input)
	var first_joint: int = prefix+2*ARM_VERTICES
	var split: int = first_joint
	while split<points.size() and original[split].x<0: split += 1
	for span: Vector3i in [Vector3i(first_joint,split,-1),Vector3i(split,points.size(),1)]:
		var count: int = (span.y-span.x)/5
		assert(count>8 and count*5==span.y-span.x)
		for vertex: int in range(span.x,span.y):
			var weight: float = [0.16,0.33,0.50,0.67,0.84][(vertex-span.x)/count]
			points[vertex] = torso(original[vertex]).lerp(arm(original[vertex],0.10,span.z,input),weight)
	# Fair only new shoulder patch interiors; the actual sewn boundaries stay fixed.
	var neighbours: Dictionary = {}
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for corner: int in range(0,indices.size(),3):
		for a: int in range(3):
			var vertex: int = indices[corner+a]
			if vertex<first_joint: continue
			if not neighbours.has(vertex): neighbours[vertex] = {}
			for b: int in range(3):
				if a!=b: neighbours[vertex][indices[corner+b]] = true
	for iteration: int in range(12):
		var next: PackedVector3Array = points.duplicate()
		for vertex: int in neighbours:
			var average := Vector3.ZERO
			for neighbour: int in neighbours[vertex]: average += points[neighbour]
			next[vertex] = points[vertex].lerp(average/neighbours[vertex].size(),0.35)
		points = next
	result[Mesh.ARRAY_VERTEX] = points
	result[Mesh.ARRAY_NORMAL] = normals(points,indices,arrays[Mesh.ARRAY_NORMAL])
	return result

static func resize(original: ArrayMesh) -> ArrayMesh:
	if original.get_meta("kart_driver_anatomy","")==REVISION: return original
	var pose_count: int = STEERING.STEPS*2
	assert(original.get_surface_count()==6 and original.get_blend_shape_count()==pose_count)
	var result := ArrayMesh.new()
	result.blend_shape_mode = original.blend_shape_mode
	for shape: int in range(pose_count): result.add_blend_shape(original.get_blend_shape_name(shape))
	var prefix: int = original.get_meta("kart_suit_static_vertices")
	var packets: Array = original.get("_surfaces").duplicate(true)
	var bounds := AABB()
	var first: bool = true
	for surface: int in range(1,6):
		var arrays: Array = original.surface_get_arrays(surface)
		var targets: Array[Array] = original.surface_get_blend_shape_arrays(surface)
		for pose: int in range(pose_count+1):
			var current: Array = arrays.duplicate(true)
			if pose>0:
				current[Mesh.ARRAY_VERTEX] = targets[pose-1][Mesh.ARRAY_VERTEX]
				current[Mesh.ARRAY_NORMAL] = targets[pose-1][Mesh.ARRAY_NORMAL]
			if surface==1:
				var input: float = 0 if pose==0 else float((pose-1)%STEERING.STEPS+1)/STEERING.STEPS*(-1 if pose<=STEERING.STEPS else 1)
				current = suit(current,prefix,input)
			else:
				var points: PackedVector3Array = current[Mesh.ARRAY_VERTEX]
				var pivot := Vector3(0,0.740213,0.388)
				for vertex: int in range(points.size()): points[vertex] = torso(pivot)+(points[vertex]-pivot)*HELMET_SCALE
				current[Mesh.ARRAY_VERTEX] = points
			for point: Vector3 in current[Mesh.ARRAY_VERTEX]:
				if first: bounds = AABB(point,Vector3.ZERO); first = false
				else: bounds = bounds.expand(point)
			if pose==0: arrays = current
			else:
				targets[pose-1][Mesh.ARRAY_VERTEX] = current[Mesh.ARRAY_VERTEX]
				targets[pose-1][Mesh.ARRAY_NORMAL] = current[Mesh.ARRAY_NORMAL]
		var rebuilt := ArrayMesh.new()
		rebuilt.blend_shape_mode = original.blend_shape_mode
		for shape: int in range(pose_count): rebuilt.add_blend_shape(original.get_blend_shape_name(shape))
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,targets)
		var packet: Dictionary = rebuilt.get("_surfaces")[0]
		packet.material = original.surface_get_material(surface)
		packets[surface] = packet
	for pose: Array in [original.surface_get_arrays(0)]+original.surface_get_blend_shape_arrays(0):
		for point: Vector3 in pose[Mesh.ARRAY_VERTEX]: bounds = bounds.expand(point)
	result.set("_surfaces",packets)
	for key: StringName in original.get_meta_list(): result.set_meta(key,original.get_meta(key))
	result.set_meta("kart_driver_anatomy",REVISION)
	result.custom_aabb = bounds.grow(0.003)
	return result
