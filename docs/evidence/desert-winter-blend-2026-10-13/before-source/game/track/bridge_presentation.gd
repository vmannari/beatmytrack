class_name BridgePresentation
extends BridgeElevation
## Mesh construction over the shared pure elevation sampler.

func _init(data: NativeTrack) -> void:
	super(data)


func build(parent: Node3D) -> void:
	var theme: String = str(track.metadata.get("theme","pine"))
	var bridge_phases: Array[Dictionary] = []
	if theme == "desert":
		var pieces: Array = track.metadata.get("creator_document",{}).get("pieces",[])
		var phases: Dictionary = preload("res://track/desert_road_union.gd").phases(pieces,RoadPieces.prepare_endpoints(pieces))
		for i: int in range(pieces.size()):
			if pieces[i].kind == "bridge": bridge_phases.append(phases.get(i,{}))
	CreatorBridgeVisual.build(parent,track.creator_bridges,theme,bridge_phases)
	var palette: Array[Color] = TrackTheme.palette(str(track.metadata.get("theme", "pine")))
	var fascia := SurfaceTool.new()
	fascia.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fascia_count: int = 0
	for kind: int in [0,4]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count: int = 0
		for y: int in range(track.grid_height):
			for x: int in range(track.grid_width):
				if roles[y * track.grid_width + x] != kind:
					continue
				var vertices: Array[Vector3] = []
				for corner: Vector2 in [Vector2(x,y),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
					var p: Vector2 = point(corner)
					vertices.append(VisualGeometry.world(p) + Vector3.UP * (profile_height(p) + (0.85 if kind == 4 else 0.015)))
				surface.set_color(CreatorBridgeVisual.RAIL_TOP if kind == 4 else Color.WHITE)
				for i: int in [0,1,2,0,2,3]:
					var p := Vector2(vertices[i].x,-vertices[i].z)
					surface.set_uv(Vector2(p.dot(track.bridge_axis),p.dot(track.bridge_axis.orthogonal())))
					surface.add_vertex(vertices[i])
				# Close exposed deck edges with a shaded, substantial fascia.
				for i: int in range(4):
					var neighbor: Vector2i = Vector2i(x,y) + [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][i]
					if inside(neighbor) and roles[neighbor.y * track.grid_width + neighbor.x] >= 0: continue
					var drop: float = 0.85 if kind == 4 else 0.015
					var a: Vector3 = vertices[i] - Vector3.UP * drop
					var b: Vector3 = vertices[(i+1)%4] - Vector3.UP * drop
					CreatorBridgeVisual.quad(fascia,a,b,b-Vector3.UP*0.34,a-Vector3.UP*0.34,Color("817e70"))
					CreatorBridgeVisual.quad(fascia,a-Vector3.UP*0.34,b-Vector3.UP*0.34,b-Vector3.UP*0.42,a-Vector3.UP*0.42,Color("403f38"))
					fascia_count += 1
				if kind == 4:
					for i: int in range(4):
						var neighbor: Vector2i = Vector2i(x,y) + [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][i]
						if inside(neighbor) and roles[neighbor.y * track.grid_width + neighbor.x] == kind:
							continue
						var a: Vector3 = vertices[i]
						var b: Vector3 = vertices[(i+1)%4]
						# Plain raised parapet: one quiet side face, no stacked bands
						# or contrasting concrete posts on the raster rail cells.
						CreatorBridgeVisual.quad(surface,a,b,b-Vector3.UP*0.85,a-Vector3.UP*0.85,CreatorBridgeVisual.RAIL_SIDE)
				count += 1
		if count:
			surface.generate_normals()
			var mesh := MeshInstance3D.new()
			mesh.mesh = surface.commit()
			if kind == 0:
				var asphalt := ShaderMaterial.new()
				asphalt.shader = preload("res://track/storm_bridge_road.gdshader") if track.metadata.get("theme","pine") == "storm" else preload("res://track/bridge_road.gdshader")
				asphalt.set_shader_parameter("surface_factors", preload("res://assets/textures/surface_factors_v1.png"))
				asphalt.set_shader_parameter("road_color", palette[0])
				asphalt.set_shader_parameter("icy_road",track.metadata.get("theme","pine") == "winter")
				asphalt.set_shader_parameter("ice_albedo", NativeTrackVisual.WINTER_ICE)
				asphalt.set_shader_parameter("ice_finish", NativeTrackVisual.WINTER_ICE_FINISH)
				if track.metadata.get("theme","pine") == "winter": asphalt.set_shader_parameter("snow_albedo",NativeTrackVisual.WINTER_SNOW)
				asphalt.set_shader_parameter("wet_road",track.metadata.get("theme","pine") == "storm")
				asphalt.set_shader_parameter("packed_sand",track.metadata.get("theme","pine") == "desert")
				mesh.material_override = asphalt
			else:
				mesh.material_override = _structure_material()
			mesh.layers = 1 if kind == 0 else 2
			parent.add_child(mesh)
	if fascia_count > 0:
		fascia.generate_normals()
		var edge := MeshInstance3D.new()
		edge.name = "NativeBridgeFascia"
		edge.mesh = fascia.commit()
		edge.material_override = _structure_material()
		edge.layers = 2 # Separately culled from headlights while the car is below.
		parent.add_child(edge)


func _structure_material() -> StandardMaterial3D:
	var material := VisualGeometry.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
