extends RefCounted
## Temporary draws reuse the actual particle/process/mesh materials. Live effect
## nodes, GPU particle ages, trail slots and canonical state remain untouched.
const BATCH_NAMES: Array[String] = ["WoodFragments","LooseHayFragments","GroundDrifts","BankPowder","AirborneGrains"]

static func begin(world: Node3D, effects: SandDust, camera: Camera3D, impact: TextureRect = null) -> Dictionary:
	var prepared: Dictionary = {"nodes":[],"restore":[],"particles":0,"batches":0,"damage_meshes":0,"canvas":0}
	if DisplayServer.get_name() == "headless" or world == null or camera == null: return prepared
	var center: Vector3 = camera.global_position-camera.global_basis.z*maxf(camera.near+1.0,10.0)
	if effects != null and effects.is_visible_in_tree():
		for source: Node in effects.get_children():
			if not source is GPUParticles3D or not source.is_visible_in_tree(): continue
			var particles := GPUParticles3D.new()
			particles.name = "Covered"+str(source.name)
			# The enclosing Game is disabled until the full countdown can begin.
			particles.process_mode = Node.PROCESS_MODE_ALWAYS
			for property: String in ["lifetime","fixed_fps","fract_delta","interpolate","local_coords","draw_order","collision_base_size","transform_align","cast_shadow","layers"]:
				particles.set(property,source.get(property))
			particles.amount = 1
			particles.one_shot = true
			particles.explosiveness = 1.0
			particles.randomness = 0.0
			particles.preprocess = minf(source.lifetime*0.2,0.05)
			particles.process_material = source.process_material
			particles.draw_passes = source.draw_passes
			for pass_index: int in range(source.draw_passes): particles.set_draw_pass_mesh(pass_index,source.get_draw_pass_mesh(pass_index))
			particles.visibility_aabb = source.visibility_aabb
			world.add_child(particles)
			particles.global_position = center
			prepared.nodes.append(particles)
			prepared.particles += 1
	# Empty debris and inactive weather batches need their instanced draw path,
	# not a plain MeshInstance proxy. The original buffers/populations stay exact.
	for source: Node in world.find_children("*","MultiMeshInstance3D",true,false):
		if str(source.name) not in BATCH_NAMES or not source.is_visible_in_tree() or source.multimesh.mesh == null: continue
		var resource: MultiMesh = source.multimesh
		var instances := MultiMesh.new()
		instances.transform_format = resource.transform_format
		instances.use_colors = resource.use_colors
		instances.use_custom_data = resource.use_custom_data
		instances.mesh = resource.mesh
		instances.instance_count = 1
		instances.set_instance_transform(0,Transform3D(Basis.IDENTITY,source.to_local(center)))
		if resource.use_colors: instances.set_instance_color(0,Color.WHITE)
		if resource.use_custom_data: instances.set_instance_custom_data(0,Color(0.5,0.5,0,1))
		var batch := MultiMeshInstance3D.new()
		batch.name = "Covered"+str(source.name)
		batch.multimesh = instances
		batch.material_override = source.material_override
		batch.material_overlay = source.material_overlay
		batch.cast_shadow = source.cast_shadow
		batch.layers = source.layers
		world.add_child(batch)
		batch.global_transform = source.global_transform
		batch.extra_cull_margin = 2.0
		prepared.nodes.append(batch)
		prepared.batches += 1
	# Damage phases use the prepared originals; only the temporary cull margin
	# and hidden-child flag are borrowed, then restored even after cancellation.
	for source: Node in world.find_children("*","MeshInstance3D",true,false):
		if not source.get_parent().has_meta("breakable_kind") or not str(source.name).begins_with("DamagePhase"): continue
		if not source.get_parent().is_visible_in_tree(): continue
		prepared.restore.append({"node":source,"visible":source.visible,"margin":source.extra_cull_margin})
		source.visible = true
		var delta: Vector3 = (source.to_local(camera.global_position)-source.get_aabb().get_center()).abs()
		source.extra_cull_margin = maxf(source.extra_cull_margin,maxf(delta.x,maxf(delta.y,delta.z))+camera.near+1.0)
		prepared.damage_meshes += 1
	# The normally hidden crash glass has its own canvas shader. Draw its actual
	# texture/material without inventing an impact or changing retained damage.
	if impact != null and impact.material != null and impact.texture != null:
		var glass := TextureRect.new()
		glass.name = "CoveredImpactPreparation"
		glass.texture = impact.texture
		glass.material = impact.material
		for property: String in ["expand_mode","stretch_mode","texture_filter","texture_repeat","light_mask","z_index"]: glass.set(property,impact.get(property))
		glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		impact.get_parent().add_child(glass)
		glass.position = impact.position
		glass.size = impact.size
		prepared.nodes.append(glass)
		prepared.canvas += 1
	return prepared

static func end(prepared: Dictionary) -> void:
	for entry: Dictionary in prepared.get("restore",[]):
		if is_instance_valid(entry.node):
			entry.node.visible = entry.visible
			entry.node.extra_cull_margin = entry.margin
	for node: Variant in prepared.get("nodes",[]):
		if is_instance_valid(node): node.free()
	prepared.clear()
