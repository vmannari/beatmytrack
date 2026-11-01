extends RefCounted
## Formed glasshouse for the premium Electric fastback; front is negative Z.
const Surface = preload("res://vehicle/electric_reference_mesh.gd")
const Body = preload("res://vehicle/electric_reference_body.gd")

static func cubic(a: float,b: float,c: float,d: float,t: float) -> float:
	var s: float=1.0-t
	return s*s*s*a+3.0*s*s*t*b+3.0*s*t*t*c+t*t*t*d

static func roof_z(t: float) -> float:
	# The cowl is brought forward while the original rear-glass foot stays put.
	return cubic(-1.02,-0.55,0.40,1.88,t)

static func roof_height(t: float) -> float:
	# A new, substantially lower glasshouse. The cowl and rear foot are
	# fitted below; these controls govern the raked screen and low roof arc.
	return cubic(0.840,1.230,1.340,0.885,t)

static func roof_width(t: float) -> float:
	return cubic(0.80,0.610,0.625,0.80,t)

static func top_point(u: float,t: float) -> Vector3:
	var across: float=2.0*u-1.0
	var y: float=roof_height(t)-0.030*across*across
	var cowl_z: float=-1.02+0.038*(1.0-across*across)
	var cowl_width: float=Body.top_width(cowl_z)
	var cowl_y: float=Body.shoulder(cowl_z)+0.025*(1.0-pow(across*0.80/cowl_width,2))
	var old_cowl_y: float=0.840-0.030*across*across
	y+=(cowl_y-old_cowl_y)*(1.0-smoothstep(0.0,0.30,t))
	var foot_z: float=1.88-0.16*(1.0-across*across)
	var foot: float=Body.shoulder(foot_z)+0.025*(1.0-pow(across*5.0/6.0,2))
	var old_foot: float=0.885-0.030*across*across
	y+=(foot-old_foot)*smoothstep(0.50,1.0,t)
	var z: float=roof_z(t)-0.16*(1.0-across*across)*smoothstep(0.72,1.0,t)+0.038*(1.0-across*across)*(1.0-smoothstep(0.0,0.30,t))
	return Vector3(across*roof_width(t),y,z)

static func belt_height(t: float) -> float:
	return Body.shoulder(roof_z(t))

static func side_point(side: float,t: float,v: float) -> Vector3:
	var upper: Vector3=top_point(1.0 if side>0.0 else 0.0,t)
	var lower:=Vector3(side*Body.side_width(upper.z,belt_height(t)),belt_height(t),upper.z)
	var p: Vector3=lower.lerp(upper,v)
	p.x+=side*0.012*sin(PI*v)*sin(PI*t)
	return p

static func glass_start(v: float) -> float:
	# Diagonal leading edge follows the windscreen into the roof.
	return lerpf(0.055,0.080,v)

static func glass_end(_v: float) -> float:
	return 0.965

static func b_center(v: float) -> float:
	return lerpf(0.472,0.460,v)

static func c_center(v: float) -> float:
	return lerpf(0.805,0.742,v)

static func build(car: CarVisual,paint: Material,trim: Material,glass: Material) -> void:
	# Windshield, panoramic roof and backlight are distinct, fitted sections of
	# one curved shell. Narrow dark seals meet the silver outer perimeter.
	# Blue-grey side glass stays dark while separating the individual panes.
	var side_glass: Material=glass.duplicate()
	if side_glass is ShaderMaterial:
		(side_glass as ShaderMaterial).set_shader_parameter("glass_tint_srgb",Vector3(0.095,0.140,0.175))
	var top_glass: Material=glass.duplicate()
	if top_glass is ShaderMaterial:
		(top_glass as ShaderMaterial).set_shader_parameter("show_frit",false)
	var roof_glass: Material=top_glass.duplicate()
	if roof_glass is ShaderMaterial:
		(roof_glass as ShaderMaterial).set_shader_parameter("glass_tint_srgb",Vector3(0.026,0.043,0.055))
	var sections: Array=[["ReferenceCanopyGlass",0.0,0.285,top_glass,24],["ReferencePanoramicRoof",0.289,0.653,roof_glass,24],["ReferenceRearScreen",0.657,1.0,top_glass,24]]
	for section: Array in sections:
		var label: String=section[0]
		var begin: float=section[1]
		var end: float=section[2]
		var material: Material=section[3]
		var rows: int=section[4]
		Surface.patch(car.body,label,48,rows,func(u: float,v: float)->Vector3:
			return top_point(lerpf(0.02,0.98,u),lerpf(begin,end,v)),material,Vector3.UP,car.simple_model)
	for seam: int in range(2):
		var begin: float=0.285 if seam==0 else 0.653
		var end: float=0.289 if seam==0 else 0.657
		Surface.patch(car.body,"ReferenceRoofCrossSeal"+str(seam),48,2,func(u: float,v: float)->Vector3:
			return top_point(lerpf(0.02,0.98,u),lerpf(begin,end,v)),trim,Vector3.UP,car.simple_model)
	for edge: int in range(2):
		Surface.patch(car.body,"ReferenceRoofRail"+str(edge),4,72,func(u: float,v: float)->Vector3:
			return top_point(lerpf(0.0,0.02,u) if edge==0 else lerpf(0.98,1.0,u),v),paint,Vector3.UP,car.simple_model)
	for side: float in [-1.0,1.0]:
		var hint:=Vector3(side,0.2,0.0)
		var suffix: String=str(side)
		Surface.patch(car.body,"ReferenceWindowBottom"+suffix,60,4,func(u: float,v: float)->Vector3:
			return side_point(side,u,lerpf(0.0,0.075,v)),paint,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceWindowTop"+suffix,60,4,func(u: float,v: float)->Vector3:
			return side_point(side,u,lerpf(0.945,1.0,v)),paint,hint,car.simple_model)
		# Each glass pane is separate, with the A, B and C pillars occupying the
		# intervening surface rather than floating above a single black window.
		Surface.patch(car.body,"ReferenceAPillar"+suffix,16,24,func(u: float,v: float)->Vector3:
			return side_point(side,lerpf(0.0,glass_start(v),u),lerpf(0.075,0.945,v)),paint,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceFrontSideGlass"+suffix,28,24,func(u: float,v: float)->Vector3:
			return side_point(side,lerpf(glass_start(v),b_center(v)-0.012,u),lerpf(0.075,0.945,v)),side_glass,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceBPillar"+suffix,4,24,func(u: float,v: float)->Vector3:
			return side_point(side,b_center(v)+lerpf(-0.012,0.012,u),lerpf(0.075,0.945,v)),trim,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceRearSideGlass"+suffix,22,24,func(u: float,v: float)->Vector3:
			return side_point(side,lerpf(b_center(v)+0.012,c_center(v)-0.008,u),lerpf(0.075,0.945,v)),side_glass,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceCPillar"+suffix,3,24,func(u: float,v: float)->Vector3:
			return side_point(side,c_center(v)+lerpf(-0.008,0.008,u),lerpf(0.075,0.945,v)),trim,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceQuarterGlass"+suffix,18,24,func(u: float,v: float)->Vector3:
			return side_point(side,lerpf(c_center(v)+0.008,glass_end(v),u),lerpf(0.075,0.945,v)),side_glass,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceRearPillar"+suffix,10,24,func(u: float,v: float)->Vector3:
			return side_point(side,lerpf(glass_end(v),1.0,u),lerpf(0.075,0.945,v)),paint,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceWindowGasket"+suffix,56,2,func(u: float,v: float)->Vector3:
			return side_point(side,lerpf(glass_start(0.0),glass_end(0.0),u),lerpf(0.067,0.081,v))+Vector3(side*0.001,0.0,0.0),trim,hint,car.simple_model)
