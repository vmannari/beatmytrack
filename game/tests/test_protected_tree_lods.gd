extends "res://tests/test_scenery_mesh_lods.gd"
## AOP02: authored interior detail only; near mesh, workers and spatial copies.
const EXACT = preload("res://tests/test_mesh_vertex_packing.gd")
func run()->void:
	var exact=EXACT.new()
	for theme: String in ["pine","winter","storm","night_city"]:
		for scale_value: float in [0.5,1.0,2.0]:
			var before: NativeTrackVisual=await make(theme,objects("tree",scale_value,3),false)
			var after: NativeTrackVisual=await make(theme,objects("tree",scale_value,3),true)
			var a: Array=meshes(before);var b: Array=meshes(after)
			check(a.size()==b.size(),"tree batching count retained "+theme)
			for index: int in range(a.size()):
				check(exact.expanded(a[index].mesh)[0]==exact.expanded(b[index].mesh)[0],"every original encoded tree corner retained "+theme)
				check(triangles(b[index].mesh,true)<triangles(a[index].mesh),"authored tree distance level reduces "+theme)
				check(triangles(b[index].mesh,true)>triangles(a[index].mesh)*0.75,"at least three quarters of authored tree detail retained "+theme)
			var full: Array[String]=triangle_set(b,false);var low: Array[String]=triangle_set(b,true)
			await after._partition_bank_meshes()
			check(triangle_set(meshes(after),false)==full,"spatial tree copies preserve every original corner "+theme)
			check(triangle_set(meshes(after),true)==low,"spatial tree copies preserve every distance corner "+theme)
			before.free();after.free()
		var editor: NativeTrackVisual=await make(theme,objects("tree"),true,true)
		for part: Dictionary in meshes(editor):check(not part.mesh.has_meta("scenery_lod_bytes"),"editor tree keeps full detail "+theme)
		editor.free();CreatorPropVisual.trim_cache()
		check(CreatorPropVisual.publish_warm(CreatorPropVisual.warm(Callable(),"tree",theme)),"worker tree publishes "+theme)
		var warmed: NativeTrackVisual=await make(theme,objects("tree"),true)
		for part: Dictionary in meshes(warmed):check(part.mesh.has_meta("scenery_lod_bytes"),"worker tree retains protected distance level "+theme)
		warmed.free()
		for kind: String in ["tyre_stack","tyre_wall"]:
			var original: NativeTrackVisual=await make(theme,objects(kind),false)
			var editor_tyres: NativeTrackVisual=await make(theme,objects(kind),true,true)
			var mesh: ArrayMesh=editor_tyres.tyre_instances.multimesh.mesh
			check(not mesh.has_meta("scenery_lod_bytes"),"editor tyres keep full detail "+theme)
			check(exact.expanded(mesh)[0]==exact.expanded(original.tyre_instances.multimesh.mesh)[0],"editor tyre corners remain exact "+theme)
			original.free();editor_tyres.free()
	exact.free()
	print("PROTECTED_TREE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
