class_name TrailVisibility
extends RefCounted
## Preserve the renderer's single MultiMesh and full ring; compact only its draw view.
const PAGE_SIZE: int = 512
var active: bool = false
var _retained_count: int = 0
var retained_count: int:
	get: return _retained_count if active else instances.visible_instance_count
var instances: MultiMesh
var _transforms: Array[Transform3D]
var _bounds: Array[AABB] = []
var _valid: Array[bool] = []
var _all_bounds := AABB()
var _has_bounds: bool = false
var _offsets := PackedInt32Array()
var _selection: int = -1
var _packed: bool = false
var _buffer := PackedFloat32Array()
var _view_dirty: bool = true
var _view_pose := Transform3D(Basis.IDENTITY,Vector3.INF)
var _view_projection := Projection()
var _mesh_bounds: AABB

func _init(resource: MultiMesh, transforms: Array[Transform3D]) -> void:
	instances = resource
	_mesh_bounds = resource.mesh.get_aabb()
	_transforms = transforms
	for page: int in range(ceili(float(instances.instance_count)/PAGE_SIZE)):
		_bounds.append(AABB())
		_valid.append(false)
	_offsets.resize(_bounds.size())
	_offsets.fill(-1)
	_buffer.resize(instances.instance_count*20)

func clear() -> void:
	_retained_count = 0
	active = false
	_valid.fill(false)
	_offsets.fill(-1)
	_has_bounds = false
	_selection = -1
	_packed = false
	_view_dirty = true
	instances.custom_aabb = AABB()

func record(index: int, colors: PackedColorArray, custom: PackedColorArray) -> void:
	_retained_count = mini(instances.instance_count,_retained_count+1)
	var page: int = index/PAGE_SIZE
	if _selection & (1 << page) == 0: _view_dirty = true
	var box: AABB = _transforms[index]*_mesh_bounds
	_bounds[page] = _bounds[page].merge(box) if _valid[page] else box
	_valid[page] = true
	if index%PAGE_SIZE == PAGE_SIZE-1:
		_view_dirty = true
		_bounds[page] = _transforms[page*PAGE_SIZE]*_mesh_bounds
		for item: int in range(1,PAGE_SIZE): _bounds[page] = _bounds[page].merge(_transforms[page*PAGE_SIZE+item]*_mesh_bounds)
	_all_bounds = _all_bounds.merge(box) if _has_bounds else box
	_has_bounds = true
	# One resource and one draw: no additional batches or altered ring ordering.
	var slot: int = _offsets[page]+index%PAGE_SIZE if _packed and _offsets[page] >= 0 else (-1 if _packed else index)
	if slot >= 0:
		instances.set_instance_transform(slot,_transforms[index])
		instances.set_instance_color(slot,colors[index])
		instances.set_instance_custom_data(slot,custom[index])
	if not _packed: instances.visible_instance_count = retained_count

func present(camera: Camera3D, colors: PackedColorArray, custom: PackedColorArray, world: Transform3D = Transform3D.IDENTITY) -> void:
	if camera == null or retained_count < PAGE_SIZE*2: return
	if not active:
		_retained_count = instances.visible_instance_count
		active = true
		for index: int in range(_retained_count):
			var page: int = index/PAGE_SIZE
			var box: AABB = _transforms[index]*_mesh_bounds
			_bounds[page] = _bounds[page].merge(box) if _valid[page] else box
			_valid[page] = true
			_all_bounds = _all_bounds.merge(box) if _has_bounds else box
			_has_bounds = true
	var pose: Transform3D = camera.global_transform
	var projection: Projection = camera.get_camera_projection()
	# One metre of conservative padding covers a half-metre camera refresh
	# interval. Pose/projection changes and newly occupied groups refresh now.
	if not _view_dirty and pose.basis == _view_pose.basis and projection == _view_projection and pose.origin.distance_squared_to(_view_pose.origin) < 0.25:
		_update_count()
		return
	_view_dirty = false
	_view_pose = pose
	_view_projection = projection
	var planes: Array[Plane] = camera.get_frustum()
	var selection: int = 0
	for page: int in range(_bounds.size()):
		if not _valid[page]: continue
		var box: AABB = world * _bounds[page].grow(1.0)
		var visible: bool = true
		for plane: Plane in planes:
			if plane.distance_to(box.get_center()) > (box.size*0.5).dot(plane.normal.abs()):
				visible = false
				break
		if visible: selection |= 1 << page
	# Small rings and fully visible rings keep the renderer's direct uploads.
	var full: int = (1 << ceili(float(retained_count)/PAGE_SIZE))-1
	if retained_count < PAGE_SIZE*2 or selection == full: selection = full
	if selection == _selection:
		_update_count()
		return
	_selection = selection
	if selection == full and not _packed: return
	_offsets.fill(-1)
	var drawn: int = 0
	for page: int in range(_bounds.size()):
		if selection & (1 << page) == 0: continue
		_offsets[page] = drawn
		for index: int in range(page*PAGE_SIZE,mini((page+1)*PAGE_SIZE,retained_count)):
			_pack(drawn,index,colors,custom)
			drawn += 1
	# Unused slots are zero-area and never included in visible_instance_count.
	instances.buffer = _buffer
	instances.visible_instance_count = drawn
	instances.custom_aabb = _all_bounds.grow(0.005)
	_packed = selection != full

func _update_count() -> void:
	if not _packed: return
	var last: int = (retained_count-1)/PAGE_SIZE
	if _offsets[last] < 0: return
	var count: int = _offsets[last]+(retained_count-1)%PAGE_SIZE+1
	if instances.visible_instance_count != count: instances.visible_instance_count = count

func _pack(slot: int, index: int, colors: PackedColorArray, custom: PackedColorArray) -> void:
	var at: int = slot*20
	var pose: Transform3D = _transforms[index]
	_buffer[at] = pose.basis.x.x; _buffer[at+1] = pose.basis.y.x; _buffer[at+2] = pose.basis.z.x; _buffer[at+3] = pose.origin.x
	_buffer[at+4] = pose.basis.x.y; _buffer[at+5] = pose.basis.y.y; _buffer[at+6] = pose.basis.z.y; _buffer[at+7] = pose.origin.y
	_buffer[at+8] = pose.basis.x.z; _buffer[at+9] = pose.basis.y.z; _buffer[at+10] = pose.basis.z.z; _buffer[at+11] = pose.origin.z
	for channel: int in range(4):
		_buffer[at+12+channel] = colors[index][channel]
		_buffer[at+16+channel] = custom[index][channel]
