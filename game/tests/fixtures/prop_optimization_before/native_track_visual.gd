class_name BeforePropTrackVisual
extends NativeTrackVisual

func _build_placed_objects(track: NativeTrack) -> void:
	ContactShading.build_props(self,track)
	if theme_id == "winter": BeforeWinterScenery.build_authored(self,track)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	var ink_tool := SurfaceTool.new()
	ink_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ink_count: int = 0
	var egypt_tool := SurfaceTool.new(); egypt_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var egypt_count: int = 0
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[])+track.metadata.get("scenery_objects",[]):
		if _menu_yield_due():
			await get_tree().process_frame
			if not is_inside_tree(): return
			_slice_started = Time.get_ticks_usec()
		var center := Vector3(float(object.position[0]),0.014,-float(object.position[1]))
		if ground_support != null: center.y += ground_support.ground(Vector2(center.x,-center.z))
		if theme_id == "winter" and str(object.kind) in BeforeWinterScenery.TYPES: continue
		var object_scale: float = float(object.get("scale",1.0))
		if object.kind in BeforePropEgypt.KINDS:
			BeforeCreatorPropVisual.append(egypt_tool,self,object.kind,center,object_scale,deg_to_rad(float(object.rotation)))
			egypt_count += 1
			continue
		if object.kind == "light" and theme_id == "night_city":
			var lamp := OmniLight3D.new()
			lamp.name = "StreetLamp"
			lamp.position = center+(Vector3(0.4,4.65,0)*object_scale).rotated(Vector3.UP,deg_to_rad(float(object.rotation)))
			lamp.light_color = Color("ffda98")
			lamp.light_energy = 5.0
			lamp.omni_range = 15.0*object_scale
			lamp.omni_attenuation = 1.2
			lamp.shadow_enabled = false
			lamp.light_cull_mask = 1
			add_child(lamp)
			var glow := VisualGeometry.material(Color("ffe3ae"))
			glow.emission_enabled = true
			glow.emission = Color("ffda98")
			VisualGeometry.box(self,Vector3(0.8,0.06,0.32)*object_scale,lamp.position,glow)
		if object.kind in CreatorCatalog.SOFT:
			var node := Node3D.new()
			add_child(node)
			node.position = center
			node.rotation.y = deg_to_rad(float(object.rotation))
			node.set_meta("prop_origin",center)
			node.set_meta("prop_yaw",node.rotation.y)
			if object.kind in BreakableProps.KINDS:
				BeforeBreakablePropVisual.build(node,self,object.kind,object_scale)
				BeforeBreakablePropVisual.ensure_debris(self)
			else:
				var prop_tool := SurfaceTool.new()
				prop_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				BeforeCreatorPropVisual.append(prop_tool,self,object.kind,Vector3.ZERO,object_scale,0)
				_finish_prop_mesh(prop_tool,node)
			light_instances.append(node)
			continue
		if object.kind in ["tree","broadleaf","bush","barrier","rock","boulder","slate","cliff"]:
			if object.kind == "tree": _pine(ink_tool,center,1.25*object_scale,-deg_to_rad(float(object.rotation)),TrackTheme.foliage(theme_id))
			else: BeforeCreatorPropVisual.append(ink_tool,self,object.kind,center,object_scale,deg_to_rad(float(object.rotation)),float(object.get("length",-1.0)))
			ink_count += 1
			continue
		if BeforeCreatorPropVisual.append(tool,self,object.kind,center,object_scale,deg_to_rad(float(object.rotation)),float(object.get("length",-1.0)),ContainerPaint.value(object) if object.kind == "container" else ""):
			count += 1
			continue
		if object.kind == "tree":
			_pine(tool,center,1.25*object_scale,-deg_to_rad(float(object.rotation)),TrackTheme.foliage(theme_id))
		elif object.kind == "rock":
			_mound(tool,center,Vector3(0.95,0.5,0.9)*object_scale,deg_to_rad(float(object.rotation)),TrackTheme.stone(theme_id))
		elif object.kind in ["boulder","slate","cliff"]:
			var size: Vector2 = CreatorObjects.size_of(object)
			var height: float = {"boulder":2.0,"slate":0.65,"cliff":3.4}[object.kind]*object_scale
			var turn: float = deg_to_rad(float(object.rotation))
			_mound(tool,center,Vector3(size.x*0.5,height,size.y*0.5),turn,TrackTheme.stone(theme_id))
			if object.kind == "cliff":
				for x: float in [-0.3,0.1,0.35]:
					_mound(tool,center+Vector3(size.x*x,0,0).rotated(Vector3.UP,turn),Vector3(size.x*0.19,height*(0.8+x),size.y*0.47),turn+x,TrackTheme.stone(theme_id).darkened(0.08))
		elif object.kind in ["oil","puddle","jump","speed_bump"]:
			HazardVisual.build(self,object)
			if ground_support != null: (get_child(get_child_count()-1) as Node3D).position.y += ground_support.ground(Vector2(object.position[0],object.position[1]))
			continue
		elif object.kind in ["tyre_wall","tyre_stack"]: continue # Shared instanced mesh below.
		else: continue # Barrier/water/dirt already rendered from exact native cells.
		count += 1
	if egypt_count > 0:
		egypt_tool.index()
		var egypt_mesh := MeshInstance3D.new()
		egypt_mesh.name = "EgyptianStonework"
		egypt_mesh.mesh = egypt_tool.commit()
		if _capture_editor_prop_arrays: egypt_mesh.set_meta("editor_prop_arrays",egypt_tool.commit_to_arrays())
		egypt_mesh.material_override = BeforePropEgypt.material()
		add_child(egypt_mesh)
	if count > 0:
		tool.generate_normals()
		tool.index()
		var mesh := MeshInstance3D.new()
		mesh.mesh = tool.commit()
		if _capture_editor_prop_arrays: mesh.set_meta("editor_prop_arrays",tool.commit_to_arrays())
		var material := VisualGeometry.material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		# Small roof seams and foliage use their silhouettes, not intersecting ink hulls.
		material.vertex_color_is_srgb = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material
		add_child(mesh)

	if ink_count > 0:
		ink_tool.generate_normals()
		ink_tool.index()
		var ink_mesh := MeshInstance3D.new()
		ink_mesh.mesh = ink_tool.commit()
		if _capture_editor_prop_arrays: ink_mesh.set_meta("editor_prop_arrays",ink_tool.commit_to_arrays())
		var ink_material := VisualGeometry.material(Color.WHITE)
		ink_material.vertex_color_use_as_albedo = true
		ink_material.vertex_color_is_srgb = true
		ink_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		VisualGeometry.ink(ink_material)
		ink_mesh.material_override = ink_material
		add_child(ink_mesh)

	if not track.tyre_origins.is_empty():
		var stack := SurfaceTool.new()
		stack.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tyre(stack,Vector3.ZERO)
		_tyre(stack,Vector3.UP*0.30)
		stack.generate_normals()
		stack.index()
		tyre_instances = MultiMeshInstance3D.new()
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = stack.commit()
		instances.instance_count = track.tyre_origins.size()
		tyre_instances.multimesh = instances
		_tyre_positions.clear()
		_tyre_spins.clear()
		var rubber := VisualGeometry.material(Color.WHITE)
		rubber.vertex_color_use_as_albedo = true
		rubber.vertex_color_is_srgb = true
		rubber.cull_mode = BaseMaterial3D.CULL_DISABLED
		tyre_instances.material_override = rubber
		add_child(tyre_instances)
		update_tyres(VehicleState.new(),track.tyre_origins)

func _pine(tool: SurfaceTool, center: Vector3, scale_value: float, turn: float, color: Color) -> void:
	BeforeCreatorPropVisual.pine(tool,self,center,scale_value,turn,color)
