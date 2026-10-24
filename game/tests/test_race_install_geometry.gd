extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func value(item: Variant) -> Variant:
	if item is Texture2D:
		var data: Image = item.get_image()
		return [item.get_class(),data.get_size(),data.get_format(),data.get_data()] if data != null else [item.get_class(),item.get_size()]
	if item is ShaderMaterial:
		var result: Array = [item.shader.code,item.render_priority]
		for uniform: Dictionary in item.shader.get_shader_uniform_list(): result.append([uniform.name,value(item.get_shader_parameter(uniform.name))])
		return result
	if item is Material:
		var result: Array = [item.get_class()]
		for property: Dictionary in item.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and property.name not in ["resource_name","resource_path","resource_local_to_scene"]: result.append([property.name,value(item.get(property.name))])
		return result
	if item is Resource: return item.resource_path if not item.resource_path.is_empty() else item.get_class()
	return item
func fields_for(node: Node) -> Array:
	var fields: Array = [node.get_class(),node.get_groups()]
	if node is Node3D: fields.append([node.transform,node.visible])
	if node is GeometryInstance3D: fields.append([node.layers,node.cast_shadow,value(node.material_override)])
	var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
	if mesh != null:
		for surface: int in range(mesh.get_surface_count()): fields.append([mesh.surface_get_arrays(surface),value(mesh.surface_get_material(surface))])
	if node is MultiMeshInstance3D: fields.append([node.multimesh.instance_count,node.multimesh.visible_instance_count,node.multimesh.buffer])
	return fields
func digest(node: Node, hash: HashingContext) -> void:
	hash.update(var_to_bytes(fields_for(node)))
	for child: Node in node.get_children(): digest(child,hash)
func signature(node: Node) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); digest(node,hash); return hash.finish().hex_encode()
func difference(a: Variant,b: Variant,path: String) -> String:
	if var_to_bytes(a)==var_to_bytes(b): return ""
	if a is Array and b is Array:
		if a.size()!=b.size(): return path+" length "+str(a.size())+"/"+str(b.size())
		for index: int in range(a.size()):
			var found: String = difference(a[index],b[index],path+"/"+str(index))
			if not found.is_empty(): return found
	if typeof(a)>=TYPE_PACKED_BYTE_ARRAY and typeof(a)==typeof(b):
		if a.size()!=b.size(): return path+" packed length "+str(a.size())+"/"+str(b.size())
		for index: int in range(a.size()):
			if a[index]!=b[index]: return path+"/"+str(index)+" "+str(a[index])+"/"+str(b[index])
	return path+" "+str(a)+"/"+str(b)
func node_difference(a: Node,b: Node,path: String) -> String:
	var found: String = difference(fields_for(a),fields_for(b),path)
	if not found.is_empty(): return found
	if a.get_child_count()!=b.get_child_count(): return path+" children "+str(a.get_child_count())+"/"+str(b.get_child_count())
	for index: int in range(a.get_child_count()):
		found = node_difference(a.get_child(index),b.get_child(index),path+"/"+str(a.get_child(index).name))
		if not found.is_empty(): return found
	return ""
func run() -> void:
	for theme: String in TrackTheme.IDS:
		var document: Dictionary = TrackDocument.create_default(); document.theme = theme
		for index: int in range(12): document.objects.append({"kind":"cone","position":[-20+index*3,10],"rotation":index*15})
		var track: NativeTrack = TrackCompiler.compile(document)
		var roads = preload("res://editor/road_preparation.gd")
		var packet: Dictionary = roads.with_winter_cover(roads.prepare(track,true),track,func() -> bool: return false)
		var expected := NativeTrackVisual.new(); expected.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(expected); expected.cache_race_world = false; expected.cache_road_meshes = false; expected.race_road_packet = packet
		await expected.build(track,BridgePresentation.new(track),false)
		var before: String = signature(expected)
		var actual := NativeTrackVisual.new(); actual.process_mode = Node.PROCESS_MODE_DISABLED; root.add_child(actual); actual.cache_race_world = false; actual.cache_road_meshes = false; actual.race_road_packet = packet; actual.preserve_relief_surfaces = true
		await actual.build(track,BridgePresentation.new(track),true)
		checks += 1
		if not expected.world_built or not actual.world_built or before!=signature(actual): failures += 1; print("FAIL: exact sync/cooperative geometry and materials: ",theme," ",node_difference(expected,actual,"world"))
		print("RACE_INSTALL_GEOMETRY_THEME ",theme," sync=",before," cooperative=",signature(actual))
		expected.free(); actual.free(); await process_frame
	print("RACE_INSTALL_GEOMETRY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
