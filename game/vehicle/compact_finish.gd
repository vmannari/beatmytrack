class_name CompactFinish
extends RefCounted
## Restrained original automotive finish. Shared by driving and the showroom.
static func paint(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.38
	result.metallic = 0.12
	result.metallic_specular = 0.35
	result.clearcoat_enabled = true
	result.clearcoat = 0.22
	result.clearcoat_roughness = 0.3
	return result

static func rubber(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.82
	result.metallic_specular = 0.18
	return result

static func alloy(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.75
	result.roughness = 0.34
	return result
