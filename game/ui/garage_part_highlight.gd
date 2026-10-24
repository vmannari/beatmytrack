extends RefCounted
## Menu-only overlay, applied to the selected part's existing mesh instances.
var meshes: Array[Dictionary] = []
var material: ShaderMaterial

func clear() -> void:
	for entry: Dictionary in meshes:
		var node: MeshInstance3D = entry.node.get_ref()
		if is_instance_valid(node) and node.material_overlay == material: node.material_overlay = entry.previous
	meshes.clear()

func show_part(car: CarVisual, category: String) -> void:
	clear()
	if material == null:
		material = ShaderMaterial.new()
		material.shader = preload("res://ui/garage_part_highlight.gdshader")
	for frame: Node3D in car.kit_frames.get(category,[]): _visit(frame)

func _visit(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		meshes.append({"node":weakref(node),"previous":node.material_overlay})
		node.material_overlay = material
	for child: Node in node.get_children(): _visit(child)
