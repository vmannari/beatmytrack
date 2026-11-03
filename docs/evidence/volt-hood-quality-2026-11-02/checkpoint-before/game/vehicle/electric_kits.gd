extends RefCounted
## Volt cosmetic parts, in the reference body's unscaled coordinates.
const M = preload("res://vehicle/electric_reference_mesh.gd")
const B = preload("res://vehicle/electric_reference_body.gd")

static func index_for(category: String, id: String) -> int:
	var choices: Array = VehicleCustomisation.options(category,"electric")
	for i: int in range(choices.size()):
		if choices[i][0] == id: return i
	return 0

static func build(car: CarVisual, category: String) -> void:
	if category == "rims":
		for rotor: Node3D in car.rolling_wheels:
			var side: float = signf((rotor.get_parent() as Node3D).position.x)
			var frame: Node3D = car.new_kit_frame("rims",rotor)
			if str(car.customisation.rims)=="stock":
				var graphite := CompactFinish.alloy(Color("5c6265"))
				graphite.metallic=0.72
				graphite.roughness=0.30
				var inner := CompactFinish.alloy(Color("252a2d"))
				inner.roughness=0.52
				load("res://vehicle/electric_reference_details.gd").stock_rim(car,frame,side,graphite,inner,CompactFinish.alloy(Color("bac6c6")))
			else: rim(car,frame,side)
		return
	var frame: Node3D = car.new_kit_frame(category,car.body)
	var option: String = str(car.customisation[category])
	if option == "stock":
		if category=="hood": B.build_hood(car,frame,car.paint_materials.body,CompactFinish.rubber(Color("152025")))
		return
	match category:
		"hood": hood(car,frame,option)
		"aero": aero(car,frame,option)
		"body": body_kit(car,frame,option)

static func hood(car: CarVisual, parent: Node3D, option: String) -> void:
	var i: int = index_for("hood",option)
	var dark: Material = CompactFinish.rubber(Color("27343b"))
	var paint: Material = car.paint_materials.body
	var accent: Material = car.paint_materials.accent
	var zones: Array = []
	match i:
		1: zones = [[0.32,0.68,0.24,0.82]]
		3: zones = [[0.28,0.72,0.18,0.88]]
		8: zones = [[0.42,0.58,0.24,0.84]]
		9: zones = [[0.30,0.70,0.35,0.78]]
		14: zones = [[0.22,0.78,0.32,0.72]]
		2: zones = [[0.25,0.36,0.22,0.84],[0.64,0.75,0.22,0.84]]
		4: zones = [[0.18,0.24,0.28,0.78],[0.76,0.82,0.28,0.78]]
		7: zones = [[0.18,0.32,0.39,0.86],[0.68,0.82,0.39,0.86]]
		11: zones = [[0.12,0.19,0.24,0.78],[0.81,0.88,0.24,0.78]]
		13: zones = [[0.29,0.39,0.25,0.82],[0.61,0.71,0.25,0.82]]
		15: zones = [[0.16,0.30,0.24,0.72],[0.70,0.84,0.24,0.72]]
		5: zones = [[0.14,0.26,0.34,0.70],[0.74,0.86,0.34,0.70]]
		12: zones = [[0.22,0.35,0.27,0.78],[0.65,0.78,0.27,0.78]]
		6: zones = [[0.26,0.36,0.36,0.66],[0.45,0.55,0.36,0.66],[0.64,0.74,0.36,0.66]]
		10: zones = [[0.30,0.47,0.27,0.79],[0.53,0.70,0.27,0.79]]
	# Reskin the entire hood as one continuous formed surface, rather than
	# stacking visibly separate plates on top of the factory panel.
	M.patch(parent,"VoltHoodSkinV3_"+option,64,40,func(u: float,v: float)->Vector3:
		return sculpted_hood_point(zones,i,u,v),paint,Vector3.UP,car.simple_model)
	M.ribbon(parent,"VoltHoodShutLineV3_"+option,func(t: float)->Vector3:
		var u: float
		var v: float
		if t<0.25:
			u=lerpf(0.09,0.91,t*4.0); v=0.045
		elif t<0.50:
			u=0.91; v=lerpf(0.045,0.97,(t-0.25)*4.0)
		elif t<0.75:
			u=lerpf(0.91,0.09,(t-0.50)*4.0); v=0.97
		else:
			u=0.09; v=lerpf(0.97,0.045,(t-0.75)*4.0)
		return sculpted_hood_point(zones,i,u,v)+Vector3.UP*0.0015,96,0.0009,dark,car.simple_model)
	if i in [1,9,14]:
		# Narrow recessed-looking extractor details give the painted sculpt a
		# readable edge even on very dark body colours.
		var zone: Array=zones[0]
		var metal: Material=CompactFinish.alloy(Color("9aa6a9"))
		for side: int in range(2):
			M.patch(parent,"VoltHoodSlotV3_"+option+str(side),8,20,func(u: float,v: float)->Vector3:
				var across: float=lerpf(0.11,0.24,u) if side==0 else lerpf(0.76,0.89,u)
				var uv: Vector2=hood_zone_uv(zone,across,lerpf(0.18,0.83,v))
				return sculpted_hood_point(zones,i,uv.x,uv.y)+Vector3.UP*0.011,dark,Vector3.UP,car.simple_model)
			M.patch(parent,"VoltHoodSlotEdgeV3_"+option+str(side),4,18,func(u: float,v: float)->Vector3:
				var across: float=lerpf(0.15,0.20,u) if side==0 else lerpf(0.80,0.85,u)
				var uv: Vector2=hood_zone_uv(zone,across,lerpf(0.24,0.77,v))
				return sculpted_hood_point(zones,i,uv.x,uv.y)+Vector3.UP*0.015,metal,Vector3.UP,car.simple_model)
	if i in [3,5,6,10,12]:
		for n: int in range(zones.size()):
			var zone: Array=zones[n]
			M.patch(parent,"VoltHoodInlayV3_"+option+str(n),20,24,func(u: float,v: float)->Vector3:
				var uv: Vector2=hood_zone_uv(zone,u,v)
				return sculpted_hood_point(zones,i,uv.x,uv.y)+Vector3.UP*0.010,dark,Vector3.UP,car.simple_model)
			if i in [5,6,12]:
				var blades: int=5 if i==12 else 3
				for bar: int in range(blades):
					var along: float=lerpf(0.20,0.80,float(bar)/float(blades-1))
					M.ribbon(parent,"VoltHoodVentV3_"+option+str(n)+str(bar),func(t: float)->Vector3:
						var uv: Vector2=hood_zone_uv(zone,lerpf(0.12,0.88,t),along)
						return sculpted_hood_point(zones,i,uv.x,uv.y)+Vector3.UP*0.019,12,0.004,accent,car.simple_model)

static func sculpted_hood_point(zones: Array,i: int,u: float,v: float) -> Vector3:
	var relief:=0.0
	for zone: Array in zones:
		var centre: float=(float(zone[0])+float(zone[1]))*0.5
		var width: float=(float(zone[1])-float(zone[0]))*0.75
		var x: float=absf(u-centre)/maxf(width,0.001)
		var length: float=(float(zone[3])-float(zone[2]))*0.5
		var z: float=absf(v-(float(zone[2])+float(zone[3]))*0.5)/maxf(length,0.001)
		relief=maxf(relief,exp(-2.2*x*x-1.8*z*z))
	var edge: float=pow(maxf(0.0,sin(PI*u)*sin(PI*v)),0.5)
	return B.hood_point(u,v)+Vector3.UP*(0.007+(0.110+0.006*float(i%5))*relief*edge)

static func hood_zone_uv(zone: Array,u: float,v: float) -> Vector2:
	var taper: float=lerpf(0.64,1.0,sin(PI*v))
	var centre: float=(float(zone[0])+float(zone[1]))*0.5
	var width: float=(float(zone[1])-float(zone[0]))*0.5*1.28*taper
	return Vector2(clampf(centre+(2.0*u-1.0)*width,0.06,0.94),lerpf(float(zone[2]),float(zone[3]),v))

static func aero(car: CarVisual, parent: Node3D, option: String) -> void:
	var i: int = index_for("aero",option)
	var paint: Material=car.paint_materials.body
	var dark: Material=CompactFinish.rubber(Color("202c32"))
	if i in [1,2]:
		var rise: float=0.065 if i==1 else 0.145
		M.patch(parent,"VoltDeckAeroV2_"+option,48,10,func(u: float,v: float)->Vector3:
			var p: Vector3=B.deck_point(lerpf(0.12,0.88,u),lerpf(0.63,0.985,v))
			p.y+=0.020+rise*pow(sin(PI*v*0.5),1.4)*sin(PI*u)
			return p,dark,Vector3.UP,car.simple_model)
		M.patch(parent,"VoltDeckAeroEdgeV2_"+option,48,4,func(u: float,v: float)->Vector3:
			var p: Vector3=B.deck_point(lerpf(0.12,0.88,u),lerpf(0.90,0.985,v))
			p.y+=0.025+rise*pow(sin(PI*lerpf(0.77,1.0,v)*0.5),1.4)*sin(PI*u)
			return p,dark,Vector3.UP,car.simple_model)
		M.patch(parent,"VoltDeckAeroFaceV2_"+option,48,6,func(u: float,v: float)->Vector3:
			var p: Vector3=B.deck_point(lerpf(0.12,0.88,u),0.985)
			p.y+=0.012+rise*v*sin(PI*u)
			p.z+=0.007
			return p,dark,Vector3.BACK,car.simple_model)
		return
	var width: float = [0.0,1.10,1.18,1.18,1.27,1.22,1.30,1.43,1.27,1.38,1.38,1.36,1.16,1.50,1.48,1.30][i]
	var height: float = [0.0,0.0,0.0,0.99,1.02,1.04,1.04,1.15,1.03,1.08,1.18,1.08,1.00,1.10,1.23,1.00][i]
	var chord: float = [0.0,0.0,0.0,0.18,0.21,0.20,0.17,0.25,0.20,0.27,0.23,0.22,0.18,0.24,0.27,0.16][i]
	var z: float=2.08
	var layers: int=2 if i in [6,11] else 1
	for layer: int in range(layers):
		var y: float=height+(float(layer)*0.065 if i!=11 else 0.0)
		M.patch(parent,"VoltWingV2_"+option+str(layer),32,6,func(u: float,v: float)->Vector3:
			return wing_point(i,layer,width,y,chord,z,u,v,true),paint if i in [5,8,12] else dark,Vector3.UP,car.simple_model)
		M.patch(parent,"VoltWingLowerV2_"+option+str(layer),32,2,func(u: float,v: float)->Vector3:
			return wing_point(i,layer,width,y,chord,z,u,v,false),dark,Vector3.DOWN,car.simple_model)
		for edge: int in range(4):
			M.patch(parent,"VoltWingReturnV3_"+option+str(layer)+str(edge),32 if edge<2 else 6,2,func(u: float,v: float)->Vector3:
				var along: float=u if edge<2 else float(edge-2)
				var across: float=float(edge) if edge<2 else u
				return wing_point(i,layer,width,y,chord,z,along,across,false).lerp(wing_point(i,layer,width,y,chord,z,along,across,true),v),dark,Vector3.UP,car.simple_model)
	for side: float in [-1.0,1.0]:
		var foot: float=B.deck_point(0.25 if side<0 else 0.75,0.84).y
		var support := VisualGeometry.box(parent,Vector3(0.045,height-foot,0.12),Vector3(side*width*0.32,(height+foot)*0.5,z),dark)
		support.name="VoltWingSupportV2_"+option+str(side)
		if i in [7,9,10,13,14]:
			var endplate := VisualGeometry.box(parent,Vector3(0.025,0.075,chord+0.06),Vector3(side*width*0.49,height,z+0.025),dark)
			endplate.name="VoltWingEndplateV2_"+option+str(side)

static func wing_point(i: int,layer: int,width: float,y: float,chord: float,z: float,u: float,v: float,upper: bool) -> Vector3:
	var position: float=lerpf(-1.0,-0.05,u) if i==11 and layer==0 else lerpf(0.05,1.0,u) if i==11 else 2.0*u-1.0
	var sweep: float=(0.07 if i in [4,8,9,13] else 0.025)*(2.0*u-1.0)*(2.0*u-1.0)
	var arch: float=(0.025 if i==8 else 0.007)*sin(PI*u)
	return Vector3(position*width*0.5,y+arch+(0.009*sin(PI*v) if upper else -0.012),z+sweep+chord*(v-0.5))

static func body_kit(car: CarVisual, parent: Node3D, option: String) -> void:
	var i: int=index_for("body",option)
	var dark: Material=CompactFinish.rubber(Color("202b30"))
	var accent: Material=car.paint_materials.accent
	var molding: Material=CompactFinish.alloy(Color("859297"))
	var extension: float=0.045+float((i-1)%5)*0.012
	var depth: float=0.07+float((i-1)/5)*0.018
	var style: int=(i-1)%5
	var group: int=(i-1)/5
	# A real horizontal splitter projects beyond the bumper, with a closed
	# lower face. It remains below the lamps and clear of the front tires.
	for face: int in range(2):
		M.patch(parent,"VoltSplitterV2_"+option+str(face),40,5,func(u: float,v: float)->Vector3:
			var p: Vector3=B.cap_point(false,lerpf(0.045,0.955,u),0.065)
			p.z-=0.012+depth*v*(0.75+0.25*sin(PI*u))
			p.y-=float(face)*0.018+0.012*v
			return p,dark,Vector3.UP if face==0 else Vector3.DOWN,car.simple_model)
	for side: float in [-1.0,1.0]:
		M.patch(parent,"VoltBumperBladeV2_"+option+str(side),16,10,func(u: float,v: float)->Vector3:
			var start: float=0.055 if side<0 else 0.755
			var across: float=start+0.19*u
			var upper: float=0.12+0.012*float((i-1)%4)
			var p: Vector3=B.cap_point(false,across,lerpf(0.06,upper,v))
			p.z-=0.014+0.012*sin(PI*u)*sin(PI*v)
			return p,dark,Vector3.FORWARD,car.simple_model)
	M.patch(parent,"VoltRearDiffuserV2_"+option,36,8,func(u: float,v: float)->Vector3:
		return B.cap_point(true,lerpf(0.10,0.90,u),lerpf(0.055,0.21+0.008*float(i%4),v))+Vector3.BACK*(0.012+0.012*sin(PI*u)),dark,Vector3.BACK,car.simple_model)
	for side: float in [-1.0,1.0]:
		M.patch(parent,"VoltSillKitV3_"+option+str(side),40,10,func(u: float,v: float)->Vector3:
			return sill_point(side,i,extension,u,v),dark,Vector3(side,0,0),car.simple_model)
		match style:
			0:
				M.patch(parent,"VoltSillStripeV3_"+option+str(side),36,3,func(u: float,v: float)->Vector3:
					return sill_point(side,i,extension,lerpf(0.06,0.94,u),lerpf(0.72,0.87,v))+Vector3(side*0.006,0,0),molding,Vector3(side,0,0),car.simple_model)
			1:
				M.patch(parent,"VoltSillInsertV3_"+option+str(side),32,6,func(u: float,v: float)->Vector3:
					var t: float=lerpf(0.12,0.82,u)
					var low: float=0.25+0.15*u
					var high: float=0.70-0.12*u
					return sill_point(side,i,extension,t,lerpf(low,high,v))+Vector3(side*0.006,0,0),molding,Vector3(side,0,0),car.simple_model)
			2:
				for fin: int in range(3+group):
					M.patch(parent,"VoltSillFinV3_"+option+str(side)+str(fin),4,8,func(u: float,v: float)->Vector3:
						var start: float=0.53+float(fin)*0.085
						var t: float=start+0.028*u+0.018*v
						return sill_point(side,i,extension,t,lerpf(0.18,0.88,v))+Vector3(side*0.007,0,0),molding,Vector3(side,0,0),car.simple_model)
			3:
				for channel: int in range(2):
					M.patch(parent,"VoltSillChannelV3_"+option+str(side)+str(channel),36,3,func(u: float,v: float)->Vector3:
						var row: float=0.29+0.34*float(channel)
						return sill_point(side,i,extension,lerpf(0.09,0.91,u),row+0.11*v)+Vector3(side*0.006,0,0),molding,Vector3(side,0,0),car.simple_model)
			4:
				M.patch(parent,"VoltSillSweepV3_"+option+str(side),36,5,func(u: float,v: float)->Vector3:
					var t: float=lerpf(0.12,0.90,u)
					var row: float=lerpf(0.20,0.70,u)
					return sill_point(side,i,extension,t,row+0.14*v)+Vector3(side*0.007,0,0),molding,Vector3(side,0,0),car.simple_model)
		if group==1:
			M.patch(parent,"VoltSillLowerStripeV3_"+option+str(side),36,4,func(u: float,v: float)->Vector3:
				return sill_point(side,i,extension,lerpf(0.10,0.90,u),lerpf(0.08,0.26,v))+Vector3(side*0.010,0,0),molding,Vector3(side,0,0),car.simple_model)
		elif group==2:
			M.patch(parent,"VoltSillLowerSweepV3_"+option+str(side),36,6,func(u: float,v: float)->Vector3:
				var t: float=lerpf(0.12,0.88,u)
				var low: float=lerpf(0.06,0.22,u)
				return sill_point(side,i,extension,t,low+0.27*v)+Vector3(side*0.010,0,0),molding,Vector3(side,0,0),car.simple_model)
		if group>0:
			M.patch(parent,"VoltSillRearAccentV3_"+option+str(side),12,5,func(u: float,v: float)->Vector3:
				return sill_point(side,i,extension,lerpf(0.82,0.96,u),lerpf(0.12,0.12+0.28*float(group),v))+Vector3(side*0.008,0,0),molding if group==2 else accent,Vector3(side,0,0),car.simple_model)

static func sill_point(side: float,i: int,extension: float,u: float,v: float) -> Vector3:
	var z: float=lerpf(-0.88,0.88,u)
	var top: float=0.365+0.012*float((i-1)%5)+0.015*sin(PI*u)
	var y: float=lerpf(0.235,top,v)
	var p: Vector3=B.side_point(side,z,y)
	p.x+=side*(0.020+extension*sin(PI*u)*(1.0-0.35*v))
	return p

static func rim(car: CarVisual, parent: Node3D, side: float) -> void:
	var option: String=str(car.customisation.rims)
	var i: int=index_for("rims",option)
	var count: int=[0,3,4,5,6,7,8,9,10,12,5,6,9,5,1,10][i]
	var metal := CompactFinish.alloy(Color("929b9e") if i in [2,5,8,11,15] else Color("545f65"))
	var dark := CompactFinish.alloy(Color("252e32"))
	M.patch(parent,"VoltRimRing_"+option+str(side),48,3,func(u: float,v: float)->Vector3:
		var a: float=TAU*u
		var r: float=lerpf(0.285,0.307,v)
		return Vector3(side*0.15,r*sin(a),r*cos(a)),metal,Vector3(side,0,0),car.simple_model)
	if i==14:
		M.patch(parent,"VoltAeroDisc_"+str(side),48,8,func(u: float,v: float)->Vector3:
			var a: float=TAU*u
			var r: float=lerpf(0.035,0.285,v)
			return Vector3(side*(0.145+0.008*(1.0-v)),r*sin(a),r*cos(a)),metal,Vector3(side,0,0),car.simple_model)
	else:
		var split: bool=i in [10,11,15]
		for spoke: int in range(count):
			for branch: int in range(2 if split else 1):
				M.patch(parent,"VoltSpoke_"+option+str(side)+"_"+str(spoke)+"_"+str(branch),4,10,func(u: float,v: float)->Vector3:
					return spoke_point(side,i,spoke,count,branch,split,u,v),metal,Vector3(side,0,0),car.simple_model)
				for edge: int in range(2):
					M.patch(parent,"VoltSpokeWall_"+option+str(side)+"_"+str(spoke)+"_"+str(branch)+"_"+str(edge),2,10,func(u: float,v: float)->Vector3:
						var point: Vector3=spoke_point(side,i,spoke,count,branch,split,float(edge),v)
						point.x-=side*0.022*u
						return point,dark,Vector3(side,0,0),car.simple_model)
	var cap := VisualGeometry.cylinder(parent,0.052,0.012,Vector3(side*0.154,0,0),dark,true)
	cap.name="VoltRimCap_"+option
	cap.rotation.z=PI*0.5

static func spoke_point(side: float,i: int,spoke: int,count: int,branch: int,split: bool,u: float,v: float) -> Vector3:
	var radius: float=lerpf(0.052,0.285,v)
	var spread: float=(float(branch)-0.5)*0.20*v if split else 0.0
	var sweep: float=(0.30*v*v if i==12 else 0.13*v if i==13 else 0.0)
	var half: float=0.045 if i==15 else 0.060 if split else 0.23 if i in [1,2,13] else 0.11 if i>=8 else 0.16
	var angle: float=TAU*float(spoke)/float(count)+spread+sweep+(2.0*u-1.0)*half
	return Vector3(side*(0.151+0.008*sin(PI*v)),radius*sin(angle),radius*cos(angle))
