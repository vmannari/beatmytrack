class_name TrailRenderPreparation
extends RefCounted
## One covered draw shares the live ribbon mesh/shader. The race ring is untouched.

static func begin(trails: SkidTrails, camera: Camera3D, track: NativeTrack, state: VehicleState) -> MultiMeshInstance3D:
	if DisplayServer.get_name() == "headless" or trails == null or camera == null or state == null or not trails.is_visible_in_tree(): return null
	var source: MultiMesh = trails.instances
	if source == null or source.mesh == null or source.mesh.get_surface_count() != 1: return null
	var source_batch: MultiMeshInstance3D
	for child: Node in trails.get_children():
		if child is MultiMeshInstance3D and child.multimesh == source:
			source_batch = child
			break
	if source_batch == null: return null
	var source_material: Material = source_batch.material_override if source_batch.material_override != null else source.mesh.surface_get_material(0)
	if not source_material is ShaderMaterial: return null
	# Own only uniforms for the preparation; retain the exact live Shader RID.
	var material: ShaderMaterial = source_material.duplicate()
	var instance := MultiMesh.new()
	instance.transform_format = source.transform_format
	instance.use_colors = source.use_colors
	instance.use_custom_data = source.use_custom_data
	instance.mesh = source.mesh
	instance.instance_count = 1
	instance.visible_instance_count = 0
	# Reuse the parallel renderer's encoder rather than inventing its data layout.
	# This unparented encoder owns one slot and never samples the real race ring.
	var encoder := SkidTrails.new()
	encoder.instances = instance
	encoder.mark_transforms.resize(1)
	encoder.mark_colors.resize(1)
	encoder.mark_custom.resize(1)
	encoder.trail_visibility = TrailVisibility.new(instance, encoder.mark_transforms)
	encoder._bridge_material = material
	encoder.bridge_clipping_enabled = trails.bridge_clipping_enabled
	encoder.desert_sand = track != null and track.metadata.get("theme", "pine") == "desert"
	encoder._bind_bridges(track)
	var world_point: Vector3 = VisualGeometry.world(state.position)
	var kind: int = SkidTrails.surface_at(track, world_point, state.track_elevated)
	var center: Vector3 = camera.global_position-camera.global_basis.z*maxf(camera.near+1.0, 10.0)
	var local_center: Vector3 = source_batch.to_local(center)
	encoder._mark(local_center-Vector3(0, 0, 0.4), local_center+Vector3(0, 0, 0.4), 0.0, kind, 0.58)
	encoder.free()
	var batch := MultiMeshInstance3D.new()
	batch.name = "CoveredTrailPreparation"
	batch.multimesh = instance
	batch.material_override = material
	batch.cast_shadow = source_batch.cast_shadow
	batch.layers = source_batch.layers
	batch.transform = source_batch.transform
	batch.extra_cull_margin = 1.0
	trails.add_child(batch)
	return batch

static func end(batch: MultiMeshInstance3D) -> void:
	if is_instance_valid(batch): batch.free()
