extends RefCounted
## Fitted hovercraft bodywork in model metres. Names include the option and side
## because the shared surface cache stores immutable geometry by name.
const Surface = preload("res://vehicle/hovercraft_sport_surface.gd")
const Hull = preload("res://vehicle/hovercraft_sport_hull.gd")

const BOW = ["hover_blade","hover_twin","hover_shield","hover_arrow","hover_delta","hover_channel","hover_crest","hover_split","hover_jet","hover_enduro"]
const WINGS = ["hover_low","hover_twin","hover_swept","hover_delta","hover_raised","hover_split","hover_enduro","hover_arc","hover_sport","hover_gt"]
const SIDES = ["hover_sport","hover_twin","hover_guard","hover_blade","hover_delta","hover_channel","hover_enduro","hover_swept","hover_jet","hover_gt"]

static func build(car: CarVisual, category: String) -> void:
	if category == "rims": return
	var frame: Node3D = car.new_kit_frame(category,car.body)
	var kind: String = str(car.customisation[category])
	if kind == "stock": return
	match category:
		"hood": _bow(frame,kind,car.paint_materials,car.simple_model)
		"aero": _wing(frame,kind,car.paint_materials,car.simple_model)
		"body": _sides(frame,kind,car.paint_materials,car.simple_model)

static func _bow(parent: Node3D, kind: String, materials: Dictionary, simple: bool) -> void:
	var index: int = BOW.find(kind)
	if index < 0: return
	var paired: bool = index in [1,5,7,8]
	for side: float in ([-1.0,1.0] if paired else [0.0]):
		var label: String = "HoverBow_"+kind+"_"+str(int(side))
		var half: float = (0.075+0.012*(index%3)) if paired else (0.12+0.022*(index%4))
		var length: float = 0.60+0.035*(index%4)
		var center_z: float = -1.56+0.008*(index%3)
		var center_x: float = side*(0.22+0.025*(index%3))
		var rise: float = 0.018+0.006*(index%4)
		Surface.surface(parent,label,24 if simple else 40,12 if simple else 20,
			func(u: float,v: float) -> Vector3:
				var z: float = center_z+(u-0.5)*length
				var taper: float = pow(maxf(0.0,sin(PI*clampf(u,0.0,1.0))),0.7+0.15*(index%3))
				if index in [3,4,7]: taper *= lerpf(0.50,1.25,clampf(u,0.0,1.0))
				var skew: float = (u-0.5)*0.06*side*(index%3)
				var x: float = center_x+skew+cos(v*TAU)*half*taper
				var y: float = Hull.deck_y(x,z)-0.004+sin(v*TAU)*rise*taper
				return Vector3(x,y,z),
			func(_u: float,v: float) -> Vector3: return Vector3(cos(v*TAU),sin(v*TAU),0),materials.body,simple)

static func _wing(parent: Node3D, kind: String, materials: Dictionary, simple: bool) -> void:
	var index: int = WINGS.find(kind)
	if index < 0: return
	var height: float = 1.41+0.035*(index%4)
	var span: float = 0.79+0.025*(index%4)
	var chord: float = 0.20+0.025*(index%3)
	for side: float in [-1.0,1.0]:
		var x: float = side*(span-0.09)
		Surface.tube(parent,"HoverStay_"+kind+"_"+str(int(side)),func(u: float) -> Vector3:
			return Vector3(x,lerpf(0.76,height,u),lerpf(1.60,1.76,u)),0.018,8 if simple else 16,materials.detail,simple)
	var layers: int = 2 if index in [1,5] else 1
	for layer: int in range(layers):
		var level: float = height+layer*0.105
		var layer_span: float = span*(1.0-0.08*layer)
		Surface.surface(parent,"HoverWing_"+kind+"_"+str(layer),32 if simple else 64,12 if simple else 20,
			func(u: float,v: float) -> Vector3:
				var x: float = (u*2.0-1.0)*layer_span
				var tip: float = pow(maxf(0.0,1.0-pow(absf(x)/layer_span,6.0)),0.5)
				var sweep: float = absf(x)/layer_span*(0.04+0.035*(index%4))
				var z: float = 1.76+sweep+cos(v*TAU)*chord*0.5*tip
				var y: float = level+sin(v*TAU)*0.035*tip+(0.045*pow(absf(x)/layer_span,2.0) if index == 7 else 0.0)
				return Vector3(x,y,z),
			func(_u: float,v: float) -> Vector3: return Vector3(0,sin(v*TAU),cos(v*TAU)),materials.accent if layer==1 else materials.body,simple)

static func _sides(parent: Node3D, kind: String, materials: Dictionary, simple: bool) -> void:
	var index: int = SIDES.find(kind)
	if index < 0: return
	# Each pair forms a full-length, enclosed pontoon. The inside half overlaps
	# the hull, while the outside changes the plan and side silhouette.
	var profiles: Array = [
		[1.95,0.21,0.14,0.85,0], [2.20,0.25,0.15,0.75,1],
		[1.80,0.28,0.19,0.48,2], [2.30,0.18,0.11,1.15,3],
		[2.10,0.27,0.14,0.95,4], [2.00,0.24,0.18,0.60,5],
		[2.35,0.30,0.19,0.52,6], [2.25,0.22,0.13,0.90,7],
		[1.85,0.25,0.16,1.05,8], [2.30,0.28,0.16,0.78,9]]
	var profile: Array = profiles[index]
	for side: float in [-1.0,1.0]:
		var length: float = float(profile[0])
		var width: float = float(profile[1])
		var height: float = float(profile[2])
		var end_shape: float = float(profile[3])
		var label: String = "HoverSponson_v2_"+kind+"_"+str(int(side))
		var outside: Callable = func(u: float) -> Vector3:
			var t: float = clampf(u,0.0,1.0)
			var z: float = (t-0.5)*length
			var taper: float = pow(maxf(0.0,sin(PI*t)),end_shape)
			if index in [4,7,8]: taper *= lerpf(0.72,1.15,t)
			var edge: float = Hull.half_width(z,0.97)
			return Vector3(side*(edge-0.045+width*1.25*taper),0.62,z)
		Surface.surface(parent,label,40 if simple else 80,16 if simple else 24,
			func(u: float,v: float) -> Vector3:
				var t: float = clampf(u,0.0,1.0)
				var z: float = (t-0.5)*length
				var taper: float = pow(maxf(0.0,sin(PI*t)),end_shape)
				if index in [4,7,8]: taper *= lerpf(0.72,1.15,t)
				var edge: float = Hull.half_width(z,0.97)
				var angle: float = v*TAU
				var section: float = 0.55 if index in [2,5,6] else 1.0
				var across: float = signf(cos(angle))*pow(absf(cos(angle)),section)
				var vertical: float = signf(sin(angle))*pow(absf(sin(angle)),section)
				var x: float = side*(edge-0.045+width*(0.25+across)*taper)
				var y: float = 0.62+vertical*height*taper
				return Vector3(x,y,z),
			func(_u: float,v: float) -> Vector3: return Vector3(side*cos(v*TAU),sin(v*TAU),0),materials.body,simple)
		# A contrasting inset follows the outer shoulder, with paired rails or a
		# deeper guard on selected designs so the styles read at Garage scale.
		var stripe_height: float = 0.035 if index in [1,5,9] else 0.0
		Surface.tube(parent,label+"_Inset",func(u: float) -> Vector3:
			var p: Vector3 = outside.call(lerpf(0.10,0.90,u))
			p.y += stripe_height
			p.x += side*0.003
			return p,0.012 if index in [2,6] else 0.008,24 if simple else 48,materials.accent,simple)
		if index in [1,5,9]:
			Surface.tube(parent,label+"_LowerInset",func(u: float) -> Vector3:
				var p: Vector3 = outside.call(lerpf(0.16,0.84,u))
				p.y -= 0.045
				p.x -= side*0.008
				return p,0.007,24 if simple else 48,materials.detail if index==9 else materials.accent,simple)
		if index in [2,5,8,9]:
			# Fitted dark panel follows the rounded outside of the pontoon.
			Surface.surface(parent,label+"_SidePanel",24 if simple else 48,6 if simple else 12,
				func(u: float,v: float) -> Vector3:
					var t: float = lerpf(0.20,0.80,u)
					var z: float = (t-0.5)*length
					var taper: float = pow(maxf(0.0,sin(PI*t)),end_shape)
					if index in [4,7,8]: taper *= lerpf(0.72,1.15,t)
					var angle: float = (v*2.0-1.0)*0.58*pow(maxf(0.0,sin(PI*clampf(u,0.0,1.0))),0.5)
					var section: float = 0.55 if index in [2,5,6] else 1.0
					var across: float = pow(absf(cos(angle)),section)
					var vertical: float = signf(sin(angle))*pow(absf(sin(angle)),section)
					return Vector3(side*(Hull.half_width(z,0.97)-0.043+width*(0.25+across)*taper),0.62+vertical*height*taper,z),
				func(_u: float,_v: float) -> Vector3: return Vector3(side,0,0),materials.accent,simple)
		if index in [3,4,7]:
			# A swept upper fin grows out of the pontoon rather than floating above it.
			Surface.surface(parent,label+"_SweptFin",24 if simple else 48,12 if simple else 20,
				func(u: float,v: float) -> Vector3:
					var t: float = lerpf(0.16,0.84,u)
					var z: float = (t-0.5)*length
					var taper: float = pow(maxf(0.0,sin(PI*t)),end_shape)
					if index in [4,7,8]: taper *= lerpf(0.72,1.15,t)
					var fin_taper: float = pow(maxf(0.0,sin(PI*clampf(u,0.0,1.0))),0.65)
					var x: float = side*(Hull.half_width(z,0.97)-0.045+(0.38+0.07*cos(v*TAU))*width*taper)
					var y: float = 0.62+height*0.88*taper+(0.045+0.015*(index%3))*fin_taper*(1.0+sin(v*TAU))
					return Vector3(x,y,z),
				func(_u: float,v: float) -> Vector3: return Vector3(side*cos(v*TAU),sin(v*TAU),0),materials.body,simple)
