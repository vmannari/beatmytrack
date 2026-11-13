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

# Original surfaces informed by low EV bonnets and pressed performance-car
# channels. Dimensions are metres before the existing whole-car scale.
const HOOD_REVISION := "volt-solid-hoods-5"
const HOOD_MESH_ROOT := "res://assets/vehicles/electric_hoods_v5"
const HOOD_MESH_SOURCES: Array[String] = ["electric_kits.gd","electric_reference_body.gd","electric_reference_mesh.gd"]
static var _hood_mesh_bank_checked: bool = false
static var _hood_mesh_bank_valid: bool = false

static func hood_mesh_bank_valid() -> bool:
	if _hood_mesh_bank_checked: return _hood_mesh_bank_valid
	_hood_mesh_bank_checked=true
	var path: String=HOOD_MESH_ROOT.path_join("manifest.json")
	if not FileAccess.file_exists(path): return false
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	_hood_mesh_bank_valid=_hood_manifest_matches(manifest)
	return _hood_mesh_bank_valid

static func hood_option_ids() -> Array[String]:
	var ids: Array[String]=[]
	for option: Array in VehicleCustomisation.options("hood","electric"): ids.append(str(option[0]))
	return ids

static func _hood_manifest_matches(manifest: Variant) -> bool:
	if not manifest is Dictionary or manifest.get("revision")!=HOOD_REVISION or manifest.get("engine")!=Engine.get_version_info().string: return false
	if manifest.get("hood_ids",[])!=hood_option_ids() or not manifest.get("sources") is Dictionary: return false
	# Unrelated car changes can invalidate a complete module, but cannot
	# invalidate these original hood arrays. Retain exact local-source guards
	# and the hood ordering used by index_for, without unrelated catalogue copy.
	for file: String in HOOD_MESH_SOURCES:
		var source: String="res://vehicle/"+file
		if FileAccess.file_exists(source) and manifest.sources.get(file)!=FileAccess.get_sha256(source): return false
	return true

static func prepare_hood_meshes(option: String,simple: bool) -> void:
	if not M.use_baked or not hood_mesh_bank_valid(): return
	var labels: Array[String]=["VoltHoodSkinV5_"+option,"VoltHoodShutLineV5_"+option]
	if option=="volt_carbon": labels.append("VoltCarbonInsetV4")
	for label: String in labels:
		var key: String=label+("_simple" if simple else "")
		if M.meshes.has(key): continue
		var path: String=HOOD_MESH_ROOT.path_join(key.sha256_text().left(24)+".res")
		if not ResourceLoader.exists(path): continue
		var mesh: ArrayMesh=load(path) as ArrayMesh
		if mesh!=null: M.meshes[key]=mesh


static func hood(car: CarVisual, parent: Node3D, option: String) -> void:
	prepare_hood_meshes(option,car.simple_model)
	var i: int=index_for("hood",option)
	var paint: Material=car.paint_materials.body
	var dark: Material=CompactFinish.rubber(Color("10191d"))
	M.patch(parent,"VoltHoodSkinV5_"+option,80,48,func(u: float,v: float)->Vector3:
		return formed_hood_point(i,u,v),paint,Vector3.UP,car.simple_model)
	# Reuse the factory panel perimeter. All four outer edges have exactly
	# the factory positions and tangents; there is no floating replacement lid.
	M.ribbon(parent,"VoltHoodShutLineV5_"+option,func(t: float)->Vector3:
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
		return formed_hood_point(i,u,v)+Vector3.UP*0.0012,144,0.0009,dark,car.simple_model)
	if i==3:
		var carbon:=CompactFinish.paint(Color("172126"))
		carbon.roughness=0.46
		carbon.clearcoat=0.10
		M.patch(parent,"VoltCarbonInsetV4",28,32,func(u: float,v: float)->Vector3:
			var along: float=lerpf(0.22,0.86,v)
			var half_width: float=lerpf(0.10,0.20,smoothstep(0.0,0.75,v))
			var across: float=0.5+(2.0*u-1.0)*half_width
			return formed_hood_point(i,across,along)+Vector3.UP*0.0008,carbon,Vector3.UP,car.simple_model)
static func press(x: float,centre: float,width: float) -> float:
	return 1.0-smoothstep(width*0.40,width,absf(x-centre))

static func formed_hood_point(i: int,u: float,v: float) -> Vector3:
	var p: Vector3=B.hood_point(u,v)
	# Compact support and zero edge slope preserve the nose/cowl/fender joins.
	var envelope: float=smoothstep(0.08,0.28,v)*(1.0-smoothstep(0.82,0.96,v))*smoothstep(0.08,0.18,u)*(1.0-smoothstep(0.82,0.92,u))
	var sweep: float=lerpf(0.15,0.25,smoothstep(0.15,0.9,v))
	var centre: float=press(u,0.5,0.22)
	var relief:=0.0
	match i:
		1: relief=0.022*centre-0.006*(press(u,0.28,0.045)+press(u,0.72,0.045))
		2: relief=-0.016*(press(u,0.5-sweep*0.72,0.055)+press(u,0.5+sweep*0.72,0.055))
		3: relief=0.012*press(u,0.5,lerpf(0.15,0.24,v))
		4: relief=0.018*(press(u,0.5-sweep,0.040)+press(u,0.5+sweep,0.040))
		5: relief=0.009*centre+0.015*(press(u,0.5-sweep,0.075)+press(u,0.5+sweep,0.075))
		6: relief=0.017*(press(u,0.37,0.052)+press(u,0.5,0.052)+press(u,0.63,0.052))
		7: relief=-0.018*(press(u,0.5-sweep,0.065)+press(u,0.5+sweep,0.065))
		8: relief=0.030*press(u,0.5,0.13)
		9: relief=0.023*press(u,0.5,lerpf(0.06,0.30,v))
		10: relief=-0.012*(press(u,0.425,0.046)+press(u,0.575,0.046))+0.009*press(u,0.5,0.032)
		11: relief=0.022*(press(u,0.22,0.065)+press(u,0.78,0.065))
		12: relief=0.019*press(u,0.5,0.30)-0.009*(press(u,0.32,0.060)+press(u,0.68,0.060))
		13: relief=0.024*(press(u,0.35,0.05)+press(u,0.65,0.05))
		14: relief=0.028*press(u,0.5,0.32)-0.008*(press(u,0.25,0.05)+press(u,0.75,0.05))
		15: relief=0.022*centre-0.006*(press(u,0.5-sweep,0.05)+press(u,0.5+sweep,0.05))
	p.y+=relief*envelope
	return p

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
	preload("res://vehicle/electric_body_kits.gd").build(car,parent,option,index_for("body",option))

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
