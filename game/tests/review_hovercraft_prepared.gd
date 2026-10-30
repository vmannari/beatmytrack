extends "res://tests/test_garage_prepared_cars.gd"
## Preserve every original assertion; compare implicit uniforms to renderer defaults.
## The original raw fixture compares null against serialized false/colour defaults.
func run() -> void:
	if not "--hovercraft-only" in OS.get_cmdline_user_args():
		await super.run()
		return
	# Keep the same four per-car assertions, with the hovercraft bake and adoption
	# in one native process. Unrelated Electric authors can change the broad guard.
	Prepared.enabled = false
	var reference: CarVisual = make("hovercraft",false)
	while not reference.model_ready: await process_frame
	assert(Prepared.bake(reference) == OK)
	Prepared.enabled = true
	Prepared.source_hashes.clear()
	var original: Array = shape(reference)
	var before: int = Prepared.hits
	var restored: CarVisual = make("hovercraft",true)
	check(Prepared.hits == before+1,"prepared native resource used hovercraft")
	check(original == shape(restored),"all geometry, articulation and effective finish values match hovercraft")
	var paint: Dictionary = VehicleLivery.defaults("hovercraft")
	paint.colors.body = "c72d34"
	restored.apply_livery(paint)
	check(shape(reference) == original,"preview paint cannot mutate reference materials hovercraft")
	var other: CarVisual = make("hovercraft",true)
	check(shape(other) == original,"future instance retains native stock finish hovercraft")
	reference.free(); restored.free(); other.free()
	await process_frame
	print("HOVERCRAFT_PREPARED_REVIEW ",checks," checks, ",failures," failures")
	var suffix: String = "-wrong" if "--wrong-hover-glass" in OS.get_cmdline_user_args() else ""
	var file := FileAccess.open("res://../docs/evidence/hovercraft-model-rebuild-2026-10-28/prepared"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	file.close()
	quit(1 if failures else 0)

func finish(material: Material) -> Array:
	if material is ShaderMaterial:
		var effective: ShaderMaterial = material.duplicate()
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			if effective.get_shader_parameter(uniform.name) == null:
				effective.set_shader_parameter(uniform.name,RenderingServer.shader_get_parameter_default(material.shader.get_rid(),uniform.name))
		return super.finish(effective)
	return super.finish(material)

func make(id: String,prepared: bool) -> CarVisual:
	var car: CarVisual = super.make(id,prepared)
	if prepared and id == "hovercraft" and "--wrong-hover-glass" in OS.get_cmdline_user_args():
		for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			for surface: int in range(node.mesh.get_surface_count()):
				var material: Material = node.get_active_material(surface)
				if material is ShaderMaterial and material.shader.resource_path == "res://vehicle/electric_glass.gdshader":
					var wrong: ShaderMaterial = material.duplicate()
					wrong.set_shader_parameter("glass_tint_srgb",Vector3(0.8,0.0,0.0))
					node.material_override = wrong
	return car
