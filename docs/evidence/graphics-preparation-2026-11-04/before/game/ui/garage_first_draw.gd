extends Node
## Garage-owned staging survives its retained page moving between menu slots.
const Key=preload("res://race/world_render_preparation.gd")
static var warmed: Dictionary={}
var pending: Array[Dictionary]=[]
var held: Array[WeakRef]=[]
func queue_geometry(node: GeometryInstance3D) -> bool:
	var key: String=Key._key(node)
	for index: int in range(pending.size()-1,-1,-1):
		if pending[index].node.get_ref()==node: pending.remove_at(index)
	if warmed.has(key):
		node.show()
		return false
	pending.append({"node":weakref(node),"key":key})
	held.append(weakref(node))
	node.hide()
	return true
func hold(world: Node) -> void:
	for node: GeometryInstance3D in world.find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree(): continue
		var key: String=Key._key(node)
		if warmed.has(key): continue
		pending.append({"node":weakref(node),"key":key})
		held.append(weakref(node))
		node.hide()
func release() -> void:
	for reference: WeakRef in held:
		var node: Object=reference.get_ref()
		if is_instance_valid(node): node.show()
	held.clear()
	pending.clear()
func prepare(draw: Callable,current: Callable) -> bool:
	while not pending.is_empty():
		if not current.is_valid() or not current.call(): return false
		var key: String=pending[0].key
		var shown: int=0
		var copies: Array[MeshInstance3D]=[]
		var drawn_keys: Array[Dictionary]=[]
		var camera: Camera3D=get_parent().get("camera")
		for index: int in range(pending.size()-1,-1,-1):
			if pending[index].key!=key or shown>=8: continue
			var node: Object=pending[index].node.get_ref()
			if is_instance_valid(node):
				drawn_keys.append({"node":weakref(node),"key":Key._key(node)})
				if node is MeshInstance3D:
					var copy:=MeshInstance3D.new()
					copy.set_meta("garage_opening_warm",true)
					copy.mesh=node.mesh
					copy.material_override=node.material_override
					copy.material_overlay=node.material_overlay
					copy.cast_shadow=node.cast_shadow
					copy.layers=8
					for surface: int in range(node.mesh.get_surface_count()): copy.set_surface_override_material(surface,node.get_surface_override_material(surface))
					camera.get_parent().add_child(copy)
					copy.global_transform=node.global_transform
					var delta: Vector3=(node.to_local(camera.global_position)-node.get_aabb().get_center()).abs()
					copy.extra_cull_margin=maxf(node.extra_cull_margin,maxf(delta.x,maxf(delta.y,delta.z))+camera.near+1.0)
					copies.append(copy)
			pending.remove_at(index)
			shown+=1
		var drawn: bool=await draw.call()
		for copy: MeshInstance3D in copies:
			if is_instance_valid(copy):
				if copy.get_parent()!=null: copy.get_parent().remove_child(copy)
				copy.queue_free()
		if not current.is_valid() or not current.call(): return false
		if drawn:
			if warmed.size()>=512: warmed.clear()
			for entry: Dictionary in drawn_keys:
				var node: Object=entry.node.get_ref()
				if is_instance_valid(node) and Key._key(node)==entry.key: warmed[entry.key]=true
	return current.is_valid() and current.call()
