extends "res://../build/asset-optimisation-2026-11-08/native.gd"
func scenery()->void:
	for theme: String in ["pine","winter"]:
		for kind: String in ["tree","tyre_wall"]:
			var a: NativeTrackVisual=await prop(theme,kind,false);var b: NativeTrackVisual=await prop(theme,kind,true)
			for node: Node in b.get_children():
				var mesh: Mesh=node.multimesh.mesh if node is MultiMeshInstance3D else node.mesh if node is MeshInstance3D else null
				if mesh is ArrayMesh:
					var p: Dictionary=mesh.get("_surfaces")[0];var levels: Array=p.get("lods",[])
					print("PACKET ",theme," ",kind," ",node.name," vc ",p.vertex_count," ic ",p.get("index_count",0)," lod ",levels[0] if levels.size() else 0," bytes ",levels[1].size() if levels.size() else 0," format ",p.format)
			for extent: float in [6.0,30.0,60.0,120.0]:
				camera.size=extent;camera.look_at_from_position(Vector3(-0.32,0.83,0.53)*65.0,Vector3.ZERO)
				a.show();b.hide();var aa: Dictionary=await observe();a.hide();b.show();var bb: Dictionary=await observe()
				print("NATIVE_PROBE ",theme," ",kind," extent ",extent," primitives ",aa.primitives," ",bb.primitives," pixel ",aa.image.compute_image_metrics(bb.image,false))
			a.free();b.free()
