class_name JumpProfiles
extends RefCounted
## Versioned, document-owned profiles. Missing data keeps historical jump physics.
const VERSION: String = "jump-profiles-1"
const IDS: Array[String] = ["low_ramp_v1","kicker_v1","tabletop_v1","roller_v1","dune_v1"]

static func default_for(biome: String) -> String:
	return "dune_v1" if biome == "desert" else "low_ramp_v1"

static func id(object: Dictionary) -> String:
	return str(object.get("jump_profile","legacy"))

static func label(profile: String) -> String:
	return {"legacy":"Original ramp","low_ramp_v1":"Low ramp","kicker_v1":"Short kicker","tabletop_v1":"Tabletop","roller_v1":"Rounded bump","dune_v1":"Sand rise"}.get(profile,"Jump")

static func description(profile: String) -> String:
	match profile:
		"low_ramp_v1": return "Low ramp / a small hop in the facing direction"
		"kicker_v1": return "Short kicker / a firmer, short hop"
		"tabletop_v1": return "Tabletop / gentle approaches and a flat crown"
		"roller_v1": return "Rounded bump / stays grounded, works both ways"
		"dune_v1": return "Sand rise / broad, low and rounded; stays grounded"
	return "Original ramp / launches in the facing direction"

static func dimensions(profile: String) -> Vector2:
	match profile:
		"kicker_v1": return Vector2(5,5)
		"tabletop_v1": return Vector2(10,8)
		"roller_v1": return Vector2(6,8)
		"dune_v1": return Vector2(12,10)
	return Vector2(6,5)

static func peak(profile: String) -> float:
	return {"low_ramp_v1":0.30,"kicker_v1":0.48,"tabletop_v1":0.36,"roller_v1":0.16,"dune_v1":0.26}.get(profile,1.0)

static func rounded(profile: String) -> bool:
	return profile in ["tabletop_v1","roller_v1","dune_v1"]

static func height(object: Dictionary, local: Vector2) -> float:
	var profile: String = id(object)
	var scale_value: float = float(object.get("scale",1.0))
	var size: Vector2 = dimensions(profile)*scale_value
	var u: float = local.x/size.x+0.5
	var side: float = absf(local.y)/(size.y*0.5)
	if u < 0.0 or u > 1.0 or side > 1.0: return 0.0
	var shape: float = u
	match profile:
		"low_ramp_v1","kicker_v1": shape = u*u*(2.0-u)
		"tabletop_v1": shape = smoothstep(0.0,0.36,u)*(1.0-smoothstep(0.64,1.0,u))
		"roller_v1","dune_v1": shape = pow(sin(PI*u),2.0)
	if rounded(profile): shape *= 1.0-smoothstep(0.68,1.0,side)
	return shape*peak(profile)*scale_value

static func slope(object: Dictionary, local: Vector2, forward: Vector2) -> float:
	# The same analytic surface supplies the mesh and the tyre support angle.
	var delta: Vector2 = forward*0.005*float(object.get("scale",1.0))
	return (height(object,local+delta)-height(object,local-delta))/(delta.length()*2.0)

