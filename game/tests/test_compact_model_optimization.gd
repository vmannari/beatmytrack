extends SceneTree
## CG16: exact material/triangle attribute comparison and measured build costs.
var checks: int=0
var failures: int=0
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)

func material_key(material: Material) -> String:
	var data: Array=[material.get_class(),material.render_priority]
	if material is StandardMaterial3D:
		data.append_array([material.albedo_color,material.roughness,material.metallic,material.metallic_specular,material.diffuse_mode,material.specular_mode,material.clearcoat_enabled,material.clearcoat,material.clearcoat_roughness,material.emission_enabled,material.emission,material.emission_energy_multiplier,material.cull_mode,material.transparency,material.vertex_color_use_as_albedo])
	elif material is ShaderMaterial:
		data.append(material.shader.resource_path)
		for uniform: Dictionary in material.shader.get_shader_uniform_list():data.append(material.get_shader_parameter(uniform.name))
	if material.next_pass!=null:data.append(material_key(material.next_pass))
	return var_to_bytes(data).hex_encode()

func collect(node: Node,transform: Transform3D,result: Dictionary) -> void:
	if node is Node3D:transform*=node.transform
	if node is MeshInstance3D:
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
			var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
			var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var key: String=material_key(node.get_active_material(surface))
			if not result.has(key):result[key]=[]
			var count: int=indices.size() if not indices.is_empty() else vertices.size()
			for triangle: int in range(count/3):
				var values:=PackedFloat32Array()
				for corner: int in range(3):
					var index: int=indices[triangle*3+corner] if not indices.is_empty() else triangle*3+corner
					var p: Vector3=transform*vertices[index]
					values.append_array(PackedFloat32Array([p.x,p.y,p.z]))
					if not normals.is_empty():
						var n: Vector3=transform.basis*normals[index]
						values.append_array(PackedFloat32Array([n.x,n.y,n.z]))
					if not tangents.is_empty():
						var t: Vector3=transform.basis*Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
						values.append_array(PackedFloat32Array([t.x,t.y,t.z,tangents[index*4+3]]))
					if not uv.is_empty():values.append_array(PackedFloat32Array([uv[index].x,uv[index].y]))
					if not colors.is_empty():values.append_array(PackedFloat32Array([colors[index].r,colors[index].g,colors[index].b,colors[index].a]))
				# Signed zero has the same geometric and shader meaning.
				for index: int in range(values.size()):
					if values[index]==0:values[index]=0
				result[key].append(var_to_bytes(values).hex_encode())
	for child: Node in node.get_children():collect(child,transform,result)

func geometry(car: CarVisual) -> Dictionary:
	var result: Dictionary={}
	collect(car,Transform3D.IDENTITY,result)
	for key: String in result:result[key].sort()
	return result

func _run() -> void:
	var world:=Node3D.new()
	root.add_child(world)
	for id: String in VehicleCatalog.IDS:
		VisualGeometry.optimize_model_geometry=false
		var control:=CarVisual.new()
		control.vehicle_id=id
		world.add_child(control)
		var before: Dictionary=geometry(control)
		VisualGeometry.optimize_model_geometry=true
		var optimized:=CarVisual.new()
		optimized.vehicle_id=id
		world.add_child(optimized)
		var after: Dictionary=geometry(optimized)
		check(before.size()==after.size(),id+" material roles retained")
		for key: String in before:
			check(after.has(key) and before[key]==after[key],id+" exact triangle positions/normals/tangents/UV/colors")
		check(control.rolling_wheels.size()==optimized.rolling_wheels.size() and control.front_wheels.size()==optimized.front_wheels.size(),id+" independent wheel transforms retained")
		if id=="compact":
			var livery: Dictionary=VehicleLivery.defaults(id)
			livery.colors.body="804439"
			optimized.apply_livery(livery)
			check(control.paint_materials.body.albedo_color!=optimized.paint_materials.body.albedo_color,"shared geometry keeps paint materials per instance")
		print("MODEL_ATTRIBUTE_PARITY ",id," ",before.size()," material groups")
		control.queue_free()
		optimized.queue_free()
		await process_frame
	var times: Dictionary={}
	for flag: bool in [false,true]:
		VisualGeometry.optimize_model_geometry=flag
		var samples: Array[float]=[]
		for iteration: int in range(10):
			var began: int=Time.get_ticks_usec()
			var car:=CarVisual.new()
			world.add_child(car)
			var elapsed: float=(Time.get_ticks_usec()-began)/1000.0
			if iteration>1:samples.append(elapsed)
			car.queue_free()
			await process_frame
		samples.sort()
		times["optimized" if flag else "control"]={"median_ms":samples[samples.size()/2],"samples":samples}
	print("MODEL_WARM_BUILD_MS ",JSON.stringify(times))
	var output: String=ProjectSettings.globalize_path("res://../docs/evidence/compact-surface-optimization-2026-10-11")
	var file:=FileAccess.open(output.path_join("build-profile.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(times,"\t"))
	file.close()
	VisualGeometry.optimize_model_geometry=true
	print("MODEL_OPTIMIZATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
