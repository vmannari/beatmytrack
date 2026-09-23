class_name GrassTufts
extends Node3D
## Presentation-only, spatially culled opaque grass. No simulation or collisions.

const CHUNK: float = 16.0
const TUFTS_PER_CLUSTER: int = 120
var tuft_count: int = 0
var audit_placements: bool = false
var placements: Array[Transform3D] = []

func build(track: NativeTrack, tint: Color, sliced: bool = false) -> void:
	var slice_started: int = Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 230923
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/grass_tuft.gdshader")
	material.set_shader_parameter("ground_tint",tint)
	material.set_shader_parameter("grass_macro_mask",NativeTrackVisual.GRASS_MACRO)
	material.set_shader_parameter("painted_grass_texture",NativeTrackVisual.GRASS_TEXTURE)
	var meshes: Array[ArrayMesh] = []
	for variant: int in range(5): meshes.append(_mesh(variant))
	var extent: Vector2 = track.half_extent
	for cz: int in range(ceili(extent.y*2.0/CHUNK)):
		for cx: int in range(ceili(extent.x*2.0/CHUNK)):
			if sliced and Time.get_ticks_usec()-slice_started > 4000:
				await get_tree().process_frame
				if not is_inside_tree(): return
				slice_started = Time.get_ticks_usec()
			var origin := Vector3(cx*CHUNK-extent.x,0,cz*CHUNK-extent.y)
			var transforms: Array[Transform3D] = []
			var tints: Array[Color] = []
			for cluster: int in range(4):
				var center := Vector2((cluster%2)*8.0+rng.randf_range(2,6),(cluster/2)*8.0+rng.randf_range(2,6))
				for tuft: int in range(TUFTS_PER_CLUSTER):
					var angle: float = rng.randf()*TAU
					var radius: float = sqrt(rng.randf())*1.5
					var local: Vector2 = center+Vector2.from_angle(angle)*radius
					var point := Vector2(origin.x+local.x,-origin.z-local.y)
					# Whole blade footprint remains on grass, clear of roads and bridges.
					if not _clear(track,point,0.45): continue
					var scale_value: float = rng.randf_range(0.75,1.25)
					var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(scale_value,rng.randf_range(0.8,1.2),scale_value))
					var height: float = -0.058 if not track.metadata.get("creator_document",{}).get("pieces",[]).is_empty() else 0.002
					transforms.append(Transform3D(basis,Vector3(local.x,height,local.y)))
					if audit_placements: placements.append(Transform3D(basis,origin+Vector3(local.x,height,local.y)))
					var shade: float = rng.randf_range(0.94,1.06)
					tints.append(Color(shade,shade,shade,1))
			if transforms.is_empty(): continue
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.use_colors = true
			batch.mesh = meshes[(cx+cz*3)%meshes.size()]
			batch.instance_count = transforms.size()
			for i: int in range(transforms.size()):
				batch.set_instance_transform(i,transforms[i])
				batch.set_instance_color(i,tints[i])
			var instance := MultiMeshInstance3D.new()
			instance.name = "Grass_%d_%d" % [cx,cz]
			instance.multimesh = batch
			instance.material_override = material
			instance.position = origin
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Frustum culling uses the small batch bounds in driving AND editor cameras.
			add_child(instance)
			tuft_count += transforms.size()

static func _clear(track: NativeTrack, point: Vector2, margin: float = 0.4) -> bool:
	for offset: Vector2 in [Vector2.ZERO,Vector2(margin,0),Vector2(-margin,0),Vector2(0,margin),Vector2(0,-margin)]:
		var p: Vector2 = point+offset
		if track.cell_at(p) != 1: return false
		var x: int = floori((p.x+track.half_extent.x)/track.cell_size)
		var y: int = floori((track.half_extent.y-p.y)/track.cell_size)
		if track.deck_cells[y*track.grid_width+x] >= 0: return false
	return true

static func _mesh(variant: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade: int in range(3+variant):
		var angle: float = blade*2.399+variant*0.7
		var axis := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-axis.z,0,axis.x)*0.018
		var base: Vector3 = axis*0.035
		var tip: Vector3 = base+axis*0.075+Vector3.UP*(0.055+float((blade+variant)%4)*0.012)
		var ridge: Vector3 = base+axis*0.014+Vector3.UP*0.033
		for vertex: Vector3 in [base-side,ridge,tip,ridge,base+side,tip]:
			tool.set_normal((Vector3.UP+axis*0.3).normalized())
			tool.add_vertex(vertex)
	return tool.commit()
