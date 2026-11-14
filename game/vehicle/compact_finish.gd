class_name CompactFinish
extends RefCounted
## Restrained original automotive finish. Shared by driving and the showroom.
static func paint(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.43
	result.metallic = 0.06
	result.metallic_specular = 0.38
	result.clearcoat_enabled = true
	result.clearcoat = 0.20
	result.clearcoat_roughness = 0.32
	return result

static func rubber(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.82
	result.metallic_specular = 0.24
	return result

static func alloy(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.85
	result.roughness = 0.30
	return result

static func glass(color: Color) -> StandardMaterial3D:
	# Opaque reflective glazing. Starting with the generic toon material would
	# disable specular response even when roughness/clearcoat were then set.
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color, 1.0)
	result.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.roughness = 0.22
	result.metallic_specular = 0.62
	result.clearcoat_enabled = true
	result.clearcoat = 0.18
	result.clearcoat_roughness = 0.25
	return result

static func industrial_paint(color: Color) -> StandardMaterial3D:
	var result := paint(color)
	result.roughness = 0.52
	result.metallic = 0.02
	result.clearcoat = 0.08
	result.clearcoat_roughness = 0.48
	return result

static func polymer(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.72
	result.metallic_specular = 0.28
	return result
