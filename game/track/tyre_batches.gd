extends MultiMeshInstance3D
## The root retains the public exact transform buffer; spatial children draw it.
## Derived presentation only. Neither tile membership nor slots enter race state.
const TILE: float = 32.0
const SPLIT_AT: int = 96
var members: Dictionary = {}
var batches: Dictionary = {}
var tiles: Array[Vector2i] = []
var slots: Array[int] = []
var dirty: Dictionary = {}
var ready_count: int = -1
var draw_layers: int = 1
@export var instance_poses: Array[Transform3D] = []
var poses_owned: bool = false

func set_pose(index: int, pose: Transform3D) -> void:
	if not poses_owned: instance_poses = instance_poses.duplicate(); poses_owned = true
	if instance_poses.size() != multimesh.instance_count: instance_poses.resize(multimesh.instance_count)
	instance_poses[index] = pose
	multimesh.set_instance_transform(index,pose); dirty[index] = true

func flush() -> void:
	if multimesh == null: return
	var count: int = multimesh.instance_count
	if instance_poses.size() != count:
		instance_poses.resize(count)
		for index: int in range(count): instance_poses[index] = multimesh.get_instance_transform(index)
	if count <= SPLIT_AT:
		if ready_count != -1:
			for child: Node in get_children(): child.free()
			members.clear(); batches.clear(); tiles.clear(); slots.clear(); ready_count = -1
		dirty.clear()
		layers = draw_layers
		return
	if ready_count != count:
		for child: Node in get_children(): child.free()
		members.clear(); batches.clear(); tiles.resize(count); slots.resize(count)
		for index: int in range(count):
			var at: Vector3 = instance_poses[index].origin
			var tile := Vector2i(floori(at.x/TILE),floori(at.z/TILE))
			tiles[index] = tile
			if not members.has(tile): members[tile] = []
			members[tile].append(index)
		for tile: Vector2i in members: _rebuild(tile)
		ready_count = count; dirty.clear(); layers = 0
		return
	layers = 0
	var rebuild: Dictionary = {}
	for index: int in dirty:
		var at: Vector3 = instance_poses[index].origin
		var tile := Vector2i(floori(at.x/TILE),floori(at.z/TILE))
		if tile != tiles[index]:
			members[tiles[index]].erase(index); rebuild[tiles[index]] = true
			if not members.has(tile): members[tile] = []
			members[tile].append(index); rebuild[tile] = true; tiles[index] = tile
	for tile: Vector2i in rebuild: _rebuild(tile)
	for index: int in dirty:
		if rebuild.has(tiles[index]): continue
		batches[tiles[index]].multimesh.set_instance_transform(slots[index],instance_poses[index])
	dirty.clear()

func _rebuild(tile: Vector2i) -> void:
	if members[tile].is_empty():
		if batches.has(tile): batches[tile].free(); batches.erase(tile)
		members.erase(tile)
		return
	members[tile].sort()
	var node: MultiMeshInstance3D = batches.get(tile)
	if node == null:
		node = MultiMeshInstance3D.new(); node.name = "TyreTile_%d_%d" % [tile.x,tile.y]
		node.multimesh = MultiMesh.new(); node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = multimesh.mesh; node.material_override = material_override
		node.layers = draw_layers; node.cast_shadow = cast_shadow
		add_child(node); batches[tile] = node
	node.multimesh.instance_count = members[tile].size()
	for slot: int in range(members[tile].size()):
		var index: int = members[tile][slot]; slots[index] = slot
		node.multimesh.set_instance_transform(slot,instance_poses[index])
