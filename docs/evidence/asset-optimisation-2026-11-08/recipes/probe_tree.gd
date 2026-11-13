extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var kit:=NativeTrackVisual.new()
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_meta("scenery_lods_enabled",true)
	CreatorPropVisual.pine(tool,kit,Vector3.ZERO,1.0,0,Color("294a47"))
	print("TREE_TOOL ",tool.get_meta_list()," dropped ",tool.get_meta("tree_far_dropped",[]).size()," plans ",tool.get_meta("scenery_lod_plans",[]))
	tool.generate_normals();tool.index()
	var mesh:=PropGeometry.commit(tool)
	print("TREE_MESH ",mesh.get_meta_list()," packet lods ",mesh.get("_surfaces")[0].get("lods",[]).size())
	for source: ArrayMesh in CreatorPropVisual.pine_meshes.values():print("TREE_SOURCE ",source.get_meta_list()," dropped ",source.get_meta("tree_far_dropped",[]).size()," corners ",SceneryMeshLods.tree_corners(source).size()," verts ",source.surface_get_array_len(0))
	var winter:=WinterScenery.mesh_for("tree")
	print("WINTER_TREE ",winter.get_meta_list()," dropped ",winter.get_meta("tree_far_dropped",[]).size()," lods ",winter.get("_surfaces")[0].get("lods",[]).size())
	kit.free();quit()
