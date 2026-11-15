extends RefCounted
## C10K01: immutable offline racing meshes; no runtime simplification.
const ROOT: String="res://assets/vehicles/car_10k_v1"
const LIMIT: int=256
static var enabled: bool=false # Archived: owner restored the pre-10k models.
static var offline: Callable
static var meshes: Dictionary={}
static var hits: int=0

## CMA01-CMA03: preserve openings and shared panel boundaries before batching.
## Separate immutable material identities carry this policy through both batches.
static func is_protected(part: MeshInstance3D) -> bool:
	for surface: int in range(part.mesh.get_surface_count()):
		var material: Material=part.get_active_material(surface)
		if material==null: continue
		if material.has_meta("car_budget_preserve"): return true
		var source: Material=material.get_meta("livery_source") if material.has_meta("livery_source") else null
		if source!=null and source.has_meta("car_budget_preserve"): return true
	return false

static func required(car: CarVisual, part: MeshInstance3D) -> bool:
	for label: String in [str(part.name),part.mesh.resource_path.get_file().get_basename().to_pascal_case()]:
		var preserve: bool=car.vehicle_id=="kart" and "Helmet" in label
		if car.vehicle_id=="compact": preserve=preserve or "GlazingSeal" in label or label.begins_with("RolledRoof") or label.begins_with("CurvedBody") or label.begins_with("Cabin")
		if car.vehicle_id=="compact":
			for region: String in ["RolledWheelArch","ArchRubberSeal","RearLampHousing","RearIndicator","RearBrakeLens","RearReverseLens","RearLensHighlight"]:
				preserve=preserve or label.begins_with(region)
		if car.vehicle_id=="electric":
			for region: String in ["ReferenceRoofRail","ReferenceWindowTop","ReferenceWindowBottom","ReferenceRoofCrossSeal","ReferenceAPillar","ReferenceBPillar","ReferenceCPillar","ReferenceRearPillar","ReferenceRearGlassSurround","ReferenceRearGlassFoot","ReferenceArch","VoltFenderReturn","ReferenceWheelWell","ReferenceRearDiffuser"]:
				preserve=preserve or label.begins_with(region)
		for surface: int in range(part.mesh.get_surface_count()):
			var material: Material=part.get_active_material(surface)
			if material is ShaderMaterial and material.shader!=null and material.shader.resource_path in ["res://vehicle/window_reflection.gdshader","res://vehicle/electric_glass.gdshader","res://vehicle/compact_tire.gdshader","res://vehicle/kart_slick.gdshader"]: preserve=true
		if preserve: return true
	return false

static func tag(car: CarVisual, holders: Variant=null) -> void:
	if not car.simple_model or not car.batch_parts or car.vehicle_id=="super_rally": return
	var parts: Array=car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders: parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	for part: MeshInstance3D in parts:
		if part.mesh!=null and required(car,part): part.set_meta("car_budget_preserve",true)

static func protect(car: CarVisual, holders: Variant=null) -> void:
	if not car.simple_model or not car.batch_parts or car.vehicle_id=="super_rally": return
	var parts: Array=car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders: parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	var finishes: Dictionary=car.get_meta("car_budget_finishes",{})
	for part: MeshInstance3D in parts:
		if part.mesh==null or is_protected(part): continue
		var preserve: bool=part.has_meta("car_budget_preserve") or required(car,part)
		if not preserve: continue
		for surface: int in range(part.mesh.get_surface_count()):
			var material: Material=part.get_active_material(surface)
			if material==null: continue
			if not finishes.has(material):
				var selected: Material=material.duplicate()
				selected.set_meta("car_budget_preserve",true)
				# Opaque finishes retain their shader/depth behavior. The priority also
				# keeps final canonical material batching from losing the protection.
				selected.render_priority=mini(127,material.render_priority+1)
				finishes[material]=selected
				for slot: String in car.paint_materials:
					if car.paint_materials[slot]==material: car.paint_variants.append({"material":selected,"slot":slot})
				if material==car.accent_roof: car.paint_variants.append({"material":selected,"slot":"accent","darken":0.12})
				for variant: Dictionary in car.paint_variants.duplicate():
					if variant.material==material:
						var copy: Dictionary=variant.duplicate();copy.material=selected;car.paint_variants.append(copy)
			part.set_surface_override_material(surface,finishes[material])
		part.material_override=null
	car.set_meta("car_budget_finishes",finishes)

static func code(source: Mesh, id: String) -> String:
	return id+"_"+preload("res://vehicle/car_detail_reduction.gd").mesh_key(source)

static func swap(part: MeshInstance3D, selected: ArrayMesh) -> void:
	var finishes: Array[Material]=[]
	for surface: int in range(part.mesh.get_surface_count()): finishes.append(part.get_active_material(surface))
	if part.material_override!=null: part.mesh=selected
	elif finishes.size()==1:
		part.material_override=finishes[0];part.mesh=selected
	else:
		part.material_override=finishes[0];part.mesh=selected
		for surface: int in range(finishes.size()): part.set_surface_override_material(surface,finishes[surface])
		part.material_override=null

static func apply(car: CarVisual, holders: Variant=null) -> void:
	if not enabled or not car.simple_model or not car.batch_parts or car.vehicle_id=="super_rally": return
	var parts: Array=car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders: parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	if offline.is_valid():
		offline.call(car,parts)
		return
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		if is_protected(part): continue
		if part.mesh is ArrayMesh and part.mesh.get_blend_shape_count()>0: continue
		var key: String=code(part.mesh,car.vehicle_id)
		if not meshes.has(key):
			if meshes.size()>=LIMIT: meshes.clear()
			var path: String=ROOT.path_join(key+".res")
			meshes[key]=load(path) if ResourceLoader.exists(path) else null
		var selected: ArrayMesh=meshes[key]
		if selected==null or selected.get_meta("car_budget_source","")!=key or selected.get_surface_count()!=part.mesh.get_surface_count() or selected.get_aabb()!=part.mesh.get_aabb(): continue
		swap(part,selected)
		hits+=1
