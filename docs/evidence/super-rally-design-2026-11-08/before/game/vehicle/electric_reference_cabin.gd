extends RefCounted
## Formed glasshouse for the premium Electric fastback; front is negative Z.
const Surface = preload("res://vehicle/electric_reference_mesh.gd")
const Body = preload("res://vehicle/electric_reference_body.gd")

static func cubic(a: float,b: float,c: float,d: float,t: float) -> float:
	var s: float=1.0-t
	return s*s*s*a+3.0*s*s*t*b+3.0*s*t*t*c+t*t*t*d

static func roof_z(t: float) -> float:
	# The cowl is brought forward while the original rear-glass foot stays put.
	return Body.cabin_z(t)

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
	# Ease the backlight into the rearward-bowed deck intersection. The
	# roof seam and side corners retain their original positions/tangents.
	if absf(across)<1.0:
		var rear_foot: Vector3=Body.rear_glass_foot(across)
		var rear_blend: float=smoothstep(0.657,1.0,t)
		y+=(rear_foot.y-foot)*rear_blend
		z+=(rear_foot.z-foot_z)*rear_blend
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
	return lerpf(Body.WINDOW_A_FOOT,0.080,v)

static func glass_end(_v: float) -> float:
	return 0.965

static func b_center(v: float) -> float:
	return lerpf(Body.WINDOW_B_FOOT,0.460,v)

static func c_center(v: float) -> float:
	# Bow the rear door glass edge gently rearward while retaining its fitted
	# endpoints at the door seam and roof rail.
	return lerpf(Body.WINDOW_C_FOOT,0.742,v)+0.012*sin(PI*v)

static func rear_screen_inset(v: float) -> float:
	# The sides gently sweep inwards as the glass approaches the rear deck.
	return 0.02+0.08*v*v

static func hatch_left_u(on_deck: bool,v: float,width: float) -> float:
	return Body.hatch_left_u(on_deck,v,width)

static func hatch_seam_point(t: float) -> Vector3:
	# One symmetric shut line runs from the roof boundary, along the rear
	# glass and deck, then down and across the lower face of the liftgate.
	var a: float=minf(t,1.0-t)*56.0
	var mirrored: bool=t>0.5
	if a<=9.0:
		return top_point(0.98 if mirrored else 0.02,lerpf(0.760,1.0,a/9.0))+Vector3.UP*0.003
	if a<=13.0:
		var p: float=(a-9.0)/4.0
		var u: float=hatch_left_u(true,p,0.768)
		return Body.deck_point(1.0-u if mirrored else u,p)+Vector3.UP*0.003
	if a<=17.0:
		var p: float=(a-13.0)/4.0
		var v: float=lerpf(1.0,0.32,p)
		var u: float=Body.hatch_rear_left_u(v)
		return Body.cap_point(true,1.0-u if mirrored else u,v)+Vector3.UP*(0.003*(1.0-p))+Vector3.BACK*(0.006*p)
	var start: float=hatch_left_u(false,0.32,0.70)
	var u: float=lerpf(start,0.50,(a-17.0)/11.0)
	return Body.cap_point(true,1.0-u if mirrored else u,0.32)+Vector3.BACK*0.006

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
	var sections: Array=[["ReferenceCanopyGlass",0.0,0.285,top_glass,24],["ReferencePanoramicRoof",0.289,0.756,roof_glass,20]]
	for section: Array in sections:
		var label: String=section[0]
		var begin: float=section[1]
		var end: float=section[2]
		var material: Material=section[3]
		var rows: int=section[4]
		Surface.patch(car.body,label,48,rows,func(u: float,v: float)->Vector3:
			return top_point(lerpf(0.02,0.98,u),lerpf(begin,end,v)),material,Vector3.UP,car.simple_model)
	Surface.patch(car.body,"ReferenceRearScreen",48,22,func(u: float,v: float)->Vector3:
		var inset: float=rear_screen_inset(v)
		return top_point(lerpf(inset,1.0-inset,u),lerpf(0.760,0.970,v)),top_glass,Vector3.UP,car.simple_model)
	for side: int in range(2):
		Surface.patch(car.body,"ReferenceRearGlassSurround"+str(side),2,22,func(u: float,v: float)->Vector3:
			var inset: float=rear_screen_inset(v)
			var across: float=lerpf(0.02,inset,u) if side==0 else lerpf(1.0-inset,0.98,u)
			return top_point(across,lerpf(0.760,0.970,v)),paint,Vector3.UP,car.simple_model)
	Surface.patch(car.body,"ReferenceRearGlassFoot",48,2,func(u: float,v: float)->Vector3:
		return top_point(lerpf(0.02,0.98,u),lerpf(0.970,1.0,v)),paint,Vector3.UP,car.simple_model)
	Surface.ribbon(car.body,"ReferenceTrunkShutLine",hatch_seam_point,56,0.0013,trim,car.simple_model)
	for seam: int in range(2):
		var begin: float=0.285 if seam==0 else 0.756
		var end: float=0.289 if seam==0 else 0.760
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
		Surface.patch(car.body,"ReferenceRearQuarterPanel"+suffix,18,24,func(u: float,v: float)->Vector3:
			return side_point(side,lerpf(c_center(v)+0.008,glass_end(v),u),lerpf(0.075,0.945,v)),paint,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceRearPillar"+suffix,10,24,func(u: float,v: float)->Vector3:
			return side_point(side,lerpf(glass_end(v),1.0,u),lerpf(0.075,0.945,v)),paint,hint,car.simple_model)
		Surface.patch(car.body,"ReferenceWindowGasket"+suffix,56,2,func(u: float,v: float)->Vector3:
			return side_point(side,lerpf(glass_start(0.0),c_center(0.0)+0.008,u),lerpf(0.067,0.081,v))+Vector3(side*0.001,0.0,0.0),trim,hint,car.simple_model)
		# Continue the shut lines across the narrow painted window belt.
		for index: int in range(3):
			var station: float=[Body.WINDOW_A_FOOT,Body.WINDOW_B_FOOT,Body.WINDOW_C_FOOT][index]
			Surface.ribbon(car.body,"ReferenceWindowDoorJoin"+suffix+str(index),func(u: float)->Vector3:
				var p: Vector3
				if u < 0.25:
					var z: float=roof_z(station)
					p=Body.side_point(side,z,Body.shoulder(z)-0.002*(1.0-smoothstep(0.0,0.25,u)))
				else:
					p=side_point(side,station,0.075*(u-0.25)/0.75)
				return p+Vector3(side*0.0015,0,0),12,0.0014,trim,car.simple_model)
