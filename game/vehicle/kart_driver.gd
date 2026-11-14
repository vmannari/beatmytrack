extends RefCounted
## Tomkart's CC-BY-4.0 driver, posed offline; original thin open bucket.
## Credits and modification notes: legal/kart_driver_notices.txt.
const G = preload("res://vehicle/kart_geometry.gd")
const CLOTH: Shader = preload("res://vehicle/kart_driver_cloth.gdshader")

static func _finish_materials() -> Dictionary:
	# Per-car bindings preserve the immutable imported meshes and all steering
	# poses. The fixed and moving suit use one identical garment finish.
	var suit := ShaderMaterial.new()
	suit.resource_name = "RT_DriverSuit"
	suit.shader = CLOTH
	var glove := StandardMaterial3D.new()
	glove.resource_name = "RT_Gloves"
	glove.albedo_color = Color("202c31")
	glove.roughness = 0.76
	glove.metallic_specular = 0.20
	var visor := CompactFinish.glass(Color("263c47"))
	visor.resource_name = "HelmetVisor"
	visor.roughness = 0.20
	return {"RT_DriverSuit":suit,"RT_Gloves":glove,"HelmetVisor":visor}

static func _apply_finish(node: MeshInstance3D, materials: Dictionary) -> void:
	for surface: int in range(node.mesh.get_surface_count()):
		var source: Material = node.mesh.surface_get_material(surface)
		if source != null and materials.has(source.resource_name):
			node.set_surface_override_material(surface,materials[source.resource_name])

static func seat_point(u: float, v: float) -> Vector3:
	# Centreline runs from the front lip, under the hips, then up the back.
	var stations: Array[Vector4] = [Vector4(0.253,-0.27,0.215,0.045),Vector4(0.248,-0.12,0.230,0.060),Vector4(0.260,0.06,0.231,0.060),Vector4(0.385,0.18,0.223,0.025),Vector4(0.535,0.356,0.220,0.005),Vector4(0.625,0.419,0.210,0.0)]
	var p: Vector4 = G.curve(stations,v)
	var side: float = pow(absf(u),3)
	return Vector3(u*p.z,p.x+p.w*side,p.y-0.105*side*smoothstep(0.3,0.7,v))

static func seat_normal(u: float, v: float) -> Vector3:
	var across: Vector3 = seat_point(minf(1,u+0.001),v)-seat_point(maxf(-1,u-0.001),v)
	var along: Vector3 = seat_point(u,minf(1,v+0.001))-seat_point(u,maxf(0,v-0.001))
	return along.cross(across).normalized()

static func _seat(parent: Node3D, trim: Material, padding: Material, simple: bool) -> void:
	G.attach(parent,"MouldedSeatBucketOpenV2"+("|simple" if simple else "|full"),trim,func() -> ArrayMesh:
		var tool := SurfaceTool.new()
		var columns: int = 12 if simple else 24
		var rows: int = 16 if simple else 32
		for inner: bool in [true,false]:
			tool.append_from(G.surface(columns,rows,func(u: float,v: float) -> Vector3:
				var x: float = lerpf(-1,1,u)
				return seat_point(x,v)-seat_normal(x,v)*(0 if inner else 0.012),func(u: float,v: float) -> Vector3:
				return seat_normal(lerpf(-1,1,u),v)*(1 if inner else -1)),0,Transform3D.IDENTITY)
		# Rolled returns close the material thickness around the entire open rim.
		for edge: int in range(4):
			tool.append_from(G.surface(columns if edge < 2 else rows,1,func(u: float,v: float) -> Vector3:
				var x: float = lerpf(-1,1,u) if edge < 2 else (-1.0 if edge == 2 else 1.0)
				var t: float = float(edge) if edge < 2 else u
				return seat_point(x,t)-seat_normal(x,t)*v*0.012,func(u: float,_v: float) -> Vector3:
				if edge >= 2: return Vector3.LEFT if edge == 2 else Vector3.RIGHT
				return Vector3.FORWARD if edge == 0 else Vector3.UP),0,Transform3D.IDENTITY)
		return tool.commit())
	G.patch(parent,"SeatPanPaddingV2",20,16,func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-0.87,0.87,u)
		var t: float = lerpf(0.04,0.37,v)
		return seat_point(x,t)+seat_normal(x,t)*0.003,func(u: float,v: float) -> Vector3: return seat_normal(lerpf(-0.87,0.87,u),lerpf(0.04,0.37,v)),padding,simple)
	G.patch(parent,"SeatBackPaddingV2",20,20,func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-0.87,0.87,u)
		var t: float = lerpf(0.60,0.96,v)
		return seat_point(x,t)+seat_normal(x,t)*0.003,func(u: float,v: float) -> Vector3: return seat_normal(lerpf(-0.87,0.87,u),lerpf(0.60,0.96,v)),padding,simple)

static func seat_stays(parent: Node3D, metal: Material, simple: bool) -> void:
	for side: float in [-1.0,1.0]:
		var u: float = side*0.78
		var v: float = 0.80
		var normal: Vector3 = -seat_normal(u,v)
		var across: Vector3 = (seat_point(u+0.001,v)-seat_point(u-0.001,v)).normalized()
		var mount: Vector3 = seat_point(u,v)+normal*0.019
		var pad: MeshInstance3D = G.rounded(parent,"SeatMountPad"+str(side),mount,Vector3(0.052,0.050,0.016),0.005,metal,simple)
		pad.basis = Basis(across,normal.cross(across).normalized(),normal)
		var bolt: MeshInstance3D = G.ellipsoid(parent,"SeatMountFastener"+str(side),mount+normal*0.011,Vector3(0.008,0.008,0.004),metal,simple)
		bolt.basis = pad.basis
		G.tube(parent,"SeatStay",[Vector3(side*0.40,0.18,0.51),Vector3(side*0.30,0.33,0.42),mount],0.014,metal,simple,12)

static func build(parent: Node3D, trim: Material, simple: bool) -> void:
	_seat(parent,trim,CompactFinish.rubber(Color("30383b")),simple)
	var finishes: Dictionary = _finish_materials()
	var driver := MeshInstance3D.new()
	driver.name = "TomkartDriver"
	var directory: String="res://assets/vehicles/kart_refined_v1"+"/tomkart_driver_v1/"
	var split: bool=simple and ResourceLoader.exists(directory+"driver_steering.res") and ResourceLoader.exists(directory+"driver_static.res")
	driver.mesh = load(directory+("driver_steering.res" if split else "driver.res"))
	_apply_finish(driver,finishes)
	if split:
		var fixed := MeshInstance3D.new()
		fixed.name="DriverStaticSuit"
		fixed.mesh=load(directory+"driver_static.res")
		_apply_finish(fixed,finishes)
		driver.add_child(fixed)
	parent.add_child(driver)
	# The helmet never deforms with steering. Retain its four native finishes
	# without allocating six redundant copies of its vertex/normal data.
	var helmet := MeshInstance3D.new()
	helmet.name = "HelmetStatic"
	helmet.mesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res")
	_apply_finish(helmet,finishes)
	driver.add_child(helmet)
