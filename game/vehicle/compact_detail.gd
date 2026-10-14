class_name CompactDetail
extends RefCounted
## Original fictional hatch details, authored from the owner's visual direction.
## Shared opaque materials batch on the sprung body and four rolling pivots.
static var cached_tire: ArrayMesh
static var cached_simple_tire: ArrayMesh
static var rear_tiles: Dictionary = {}

static func tire(parent: Node3D, material: Material, simple: bool = false) -> void:
	var cached: ArrayMesh = cached_simple_tire if simple else cached_tire
	if VisualGeometry.optimize_model_geometry and cached!=null:
		_attach_tire(parent,cached)
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rounded shoulders, broad tread, recessed sidewall. Axis is local X.
	var profile: Array[Vector2] = [Vector2(-0.14,0.23),Vector2(-0.14,0.32),Vector2(-0.105,0.363),Vector2(-0.075,0.37),Vector2(0.075,0.37),Vector2(0.105,0.363),Vector2(0.14,0.32),Vector2(0.14,0.23)]
	var segments: int = 32 if simple else 64
	for row: int in range(profile.size()-1):
		for segment: int in range(segments):
			var a: float = TAU*segment/float(segments)
			var b: float = TAU*(segment+1)/float(segments)
			var p: Vector2 = profile[row]
			var q: Vector2 = profile[row+1]
			var points: Array[Vector3] = [Vector3(p.x,sin(a)*p.y,cos(a)*p.y),Vector3(q.x,sin(a)*q.y,cos(a)*q.y),Vector3(q.x,sin(b)*q.y,cos(b)*q.y),Vector3(p.x,sin(b)*p.y,cos(b)*p.y)]
			var tangent: Vector2 = (q-p).normalized()
			for index: int in [0,2,1,0,3,2]:
				var angle: float = a if index in [0,1] else b
				tool.set_normal(Vector3(-tangent.y,tangent.x*sin(angle),tangent.x*cos(angle)))
				tool.set_uv(Vector2(angle/TAU,float(row+(1 if index in [1,2] else 0))/(profile.size()-1)))
				tool.add_vertex(points[index])
	if VisualGeometry.optimize_model_geometry:tool.index()
	var resource: ArrayMesh=tool.commit()
	if VisualGeometry.optimize_model_geometry:
		if simple: cached_simple_tire=resource
		else: cached_tire=resource
	_attach_tire(parent,resource)

static func _attach_tire(parent: Node3D,resource: ArrayMesh) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = resource
	var tire_finish := ShaderMaterial.new()
	tire_finish.shader = preload("res://vehicle/compact_tire.gdshader")
	mesh.material_override = tire_finish
	parent.add_child(mesh)

static func build(car: CarVisual, blue: Material, cream: Material, trim: Material, alloy: Material) -> void:
	var rubber := VisualGeometry.material(Color("303234"))
	var bright := CompactFinish.alloy(Color("b5b8ae"))
	var amber := VisualGeometry.material(Color("d58b32"))
	var lens := VisualGeometry.material(Color("e7e4d2"))
	var shade := VisualGeometry.material(Color("384e55"))
	_front(car, blue, cream, trim, alloy)
	# The arch rolls out from the actual body skin to a narrow dark opening lip.
	for side: float in [-1.0,1.0]:
		for axle: float in [-1.28,1.28]:
			CompactCoachwork.build_arch(car,side,axle,blue,trim)
		_door(car,side,trim)
		var handle_z: float=CompactCoachwork.DOOR_REAR-0.15
		VisualGeometry.box(car.body,Vector3(0.018,0.046,0.17),Vector3(side*(CompactCoachwork.body_width(0.835,handle_z)+0.008),0.835,handle_z),trim)
		VisualGeometry.box(car.body,Vector3(0.023,0.021,0.13),Vector3(side*(CompactCoachwork.body_width(0.846,handle_z)+0.019),0.846,handle_z),bright)
		# Clear the leading door gap and sit on the rolled front-fender surface.
		var marker_z: float=-0.99
		VisualGeometry.box(car.body,Vector3(0.020,0.032,0.066),Vector3(side*(CompactCoachwork.body_width(0.82,marker_z)+0.015),0.82,marker_z),amber)
		CompactCoachwork.build_mirror(car,side,trim,bright)
		# Slim drip rails, black windscreen gasket, separate wiper blades.
		car._seam(car.body,Vector3(side*0.63,1.483,-0.34),Vector3(side*0.63,1.483,1.12),0.010,cream)
		car._seam(car.body,Vector3(side*0.67,1.083,-0.934),Vector3(side*0.16,1.12,-0.886),0.023,trim)
	for vent: int in range(18):
		var u: float=lerpf(-0.4,0.4,vent/17.0)
		var center: Vector3=CompactCoachwork.hood_point(u,0.965)
		var slope: Vector3=CompactCoachwork.hood_point(u,0.975)-CompactCoachwork.hood_point(u,0.955)
		var slot: MeshInstance3D=VisualGeometry.box(car.body,Vector3(0.014,0.002,0.025),center+Vector3.UP*0.001,trim)
		slot.rotation.x=-atan2(slope.y,slope.z)
	_wrap_bumper(car,trim,true)
	CompactRearDesign.build(car,blue,trim,bright)
	# Twin round lamps per side share the gently curved, recessed dark fascia.
	for side: float in [-1.0,1.0]:
		for offset: float in [0.405,0.651]:
			var x: float = side*offset
			for layer: int in range(4):
				var radii: Array[float] = [0.122,0.107,0.094,0.064]
				var materials: Array[Material] = [trim,bright,shade,lens]
				var light := VisualGeometry.cylinder(car.body,radii[layer],0.018,Vector3(x,0.798,_nose_z(x)-layer*0.009),materials[layer],true)
				light.rotation = Vector3(PI*0.5,-atan(0.40625*x),0)
			var glint := VisualGeometry.cylinder(car.body,0.028,0.009,Vector3(x-0.022,0.841,_nose_z(x)-0.038),lens,true)
			glint.rotation.x = PI*0.5
		var bumper_u: float=CompactCoachwork.front_bumper_parameter(side*0.61)
		var mount: Vector3=CompactCoachwork._bumper_point(false,bumper_u,0)
		var tangent: Vector2=(CompactCoachwork._bumper_path(false,bumper_u+0.0002)-CompactCoachwork._bumper_path(false,bumper_u-0.0002)).normalized()
		var outward:=Vector3(-tangent.y,0,tangent.x)
		var indicator: MeshInstance3D=VisualGeometry.box(car.body,Vector3(0.19,0.065,0.020),mount+outward*0.004+Vector3.UP*0.005,amber)
		indicator.name="FrontBumperIndicatorLeft" if side<0 else "FrontBumperIndicatorRight"
		indicator.rotation.y=atan2(-outward.x,-outward.z)
	# Recessed dark centres, alloy rim lips and explicit lug centres on every wheel.
	if CompactKits.choice(car,"rims") != "stock": return
	for rotor: Node3D in car.rolling_wheels:
		var side: float = signf((rotor.get_parent() as Node3D).position.x)
		rim_detail(car.wheel_kit_frame(rotor),side,alloy,trim,bright)

static func rim_detail(parent: Node3D,side: float,alloy: Material,trim: Material,bright: Material) -> void:
	var lip := Node3D.new()
	parent.add_child(lip)
	lip.position.x = side*0.143
	lip.rotation.z = -side*PI*0.5
	VisualGeometry.ring(lip,Vector3.ZERO,0.235,0.023,bright)
	_rim_bowl(parent,side,alloy)
	var cap := VisualGeometry.cylinder(parent,0.062,0.18,Vector3.ZERO,trim,true)
	cap.rotation.z = PI*0.5
	for lug: int in range(4):
		var a: float = lug*TAU/4.0
		var bolt := VisualGeometry.cylinder(parent,0.014,0.195,Vector3(0,sin(a)*0.047,cos(a)*0.047),bright,true)
		bolt.rotation.z = PI*0.5


static func _door(car: CarVisual,side: float,trim: Material) -> void:
	var path: Array[Vector2]=CompactCoachwork.door_outline()
	var outline: Array[Vector2]=[path[0]]
	# Open U around the metal door; the window frame continues above it.
	for index: int in [3,2]:
		var corner: Vector2=path[index]
		var previous: Vector2=path[0] if index==3 else path[3]
		var next: Vector2=path[2] if index==3 else path[1]
		var a: Vector2=corner.move_toward(previous,0.035)
		var b: Vector2=corner.move_toward(next,0.035)
		for step: int in range(9):
			var t: float=step/8.0
			outline.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
	outline.append(path[1])
	var seams:=Node3D.new()
	seams.name="DoorSeamsLeft" if side<0 else "DoorSeamsRight"
	car.body.add_child(seams)
	for index: int in range(outline.size()-1):
		var a: Vector2=outline[index]
		var b: Vector2=outline[index+1]
		var steps: int=maxi(1,int(ceil(a.distance_to(b)/0.025)))
		for step: int in range(steps):
			var p: Vector2=a.lerp(b,step/float(steps))
			var q: Vector2=a.lerp(b,(step+1)/float(steps))
			car._seam(seams,Vector3(side*(CompactCoachwork.body_width(p.y,p.x)+0.004),p.y,p.x),Vector3(side*(CompactCoachwork.body_width(q.y,q.x)+0.004),q.y,q.x),0.006,trim)
	# Trace the painted door frame outside the glass, all the way to the rail.
	for front: bool in [true,false]:
		for segment: int in range(24):
			var a: Vector3=_door_frame_point(side,front,lerpf(1.01,1.445,segment/24.0))
			var b: Vector3=_door_frame_point(side,front,lerpf(1.01,1.445,(segment+1)/24.0))
			car._seam(seams,a,b,0.004,trim)
	car._seam(seams,_door_frame_point(side,true,1.445),_door_frame_point(side,false,1.445),0.004,trim)

static func _door_frame_point(side: float,front: bool,y: float) -> Vector3:
	var height: float=(y-1.01)/0.47
	var point: Vector3=CompactCoachwork.cabin_side_point(side,0,height)
	return Vector3(point.x+side*0.004,y,point.z+0.03 if front else CompactCoachwork.DOOR_REAR)

static func _front(car: CarVisual, blue: Material, cream: Material, trim: Material, alloy: Material) -> void:
	# Curved nose with a separate moulded rubber bumper wrapping both corners.
	CompactCoachwork.build_nose(car,blue)
	_nose_band(car,0.783,0.660,0.932,-0.009,trim)
	for side: float in [-1,1]:
		_nose_tile(car,minf(side*0.79,side*0.828),maxf(side*0.79,side*0.828),0.688,0.908,-0.012,6,16,VisualGeometry.material(Color("b77929")))
	for row: int in range(5):
		_nose_band(car,0.280,0.691+row*0.046,0.702+row*0.046,-0.017,alloy)
	_wrap_bumper(car,trim)
	CompactCoachwork.build_hood(car,blue,cream)


static func _rear_skin(x: float, y: float) -> float:
	return CompactCoachwork.rear_skin(x,y)


static func _rear_patch(car: CarVisual, side: float, inner: float, outer: float, bottom: float, top: float, relief: float, material: Material,label: String="") -> void:
	# Rounded tiles follow the actual tail surface with shallow embedded backs.
	var key: String=var_to_bytes(PackedFloat64Array([side,inner,outer,bottom,top,relief])).hex_encode()
	if car.simple_model: key += "_simple"
	var tool: SurfaceTool
	if VisualGeometry.optimize_model_geometry:
		if rear_tiles.has(key):
			_attach_rear_tile(car,rear_tiles[key],material,label)
			return
		tool=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int=1 if top-bottom<0.004 else maxi(8,int(ceil((top-bottom)/0.015)))
	if car.simple_model: rows = maxi(1,rows/2)
	var columns: int = 4 if car.simple_model else 8
	for row: int in range(rows):
		var y0: float=lerpf(bottom,top,row/float(rows))
		var y1: float=lerpf(bottom,top,(row+1)/float(rows))
		var bounds0: Vector2=_rear_lamp_bounds(inner,outer,bottom,top,y0)
		var bounds1: Vector2=_rear_lamp_bounds(inner,outer,bottom,top,y1)
		for column: int in range(columns):
			var x0: float=lerpf(bounds0.x,bounds0.y,float(column)/columns)
			var x1: float=lerpf(bounds0.x,bounds0.y,float(column+1)/columns)
			var x2: float=lerpf(bounds1.x,bounds1.y,float(column+1)/columns)
			var x3: float=lerpf(bounds1.x,bounds1.y,float(column)/columns)
			var a:=Vector3(side*x0,y0,_rear_skin(x0,y0)+relief)
			var b:=Vector3(side*x1,y0,_rear_skin(x1,y0)+relief)
			var c:=Vector3(side*x2,y1,_rear_skin(x2,y1)+relief)
			var d:=Vector3(side*x3,y1,_rear_skin(x3,y1)+relief)
			var center: Vector3=(a+b+c+d)*0.25
			var normal:=Vector3(-(_rear_skin(center.x+0.0001,center.y)-_rear_skin(center.x-0.0001,center.y))/0.0002,-(_rear_skin(center.x,center.y+0.0001)-_rear_skin(center.x,center.y-0.0001))/0.0002,1).normalized()
			_rear_quad(tool,car,[a,b,c,d],normal,material)
			var inset:=Vector3(0,0,-relief-0.012)
			if column==0:_rear_quad(tool,car,[a,d,d+inset,a+inset],Vector3(-side,0,0),material)
			if column==columns-1:_rear_quad(tool,car,[b,c,c+inset,b+inset],Vector3(side,0,0),material)
			if row==0:_rear_quad(tool,car,[a,b,b+inset,a+inset],Vector3.DOWN,material)
			if row==rows-1:_rear_quad(tool,car,[d,c,c+inset,d+inset],Vector3.UP,material)
	if tool!=null:
		rear_tiles[key]=tool.commit()
		_attach_rear_tile(car,rear_tiles[key],material,label)

static func _rear_lamp_bounds(inner: float,outer: float,bottom: float,top: float,y: float) -> Vector2:
	var radius: float=minf(0.012,(top-bottom)*0.22)
	var edge: float=minf(y-bottom,top-y)
	var inset: float=radius-sqrt(maxf(0,radius*radius-pow(maxf(0,radius-edge),2)))
	return Vector2(inner+inset,outer-inset)/0.88*CompactCoachwork.width_at_height(y)

static func _rear_quad(tool: SurfaceTool,car: CarVisual,points: Array[Vector3],normal: Vector3,material: Material) -> void:
	if tool==null:car._panel(points,normal,material)
	else:_tile_quad(tool,points,normal.normalized())

static func _attach_rear_tile(car: CarVisual,resource: ArrayMesh,material: Material,label: String="") -> void:
	var tile:=MeshInstance3D.new()
	if not label.is_empty():tile.name=label
	tile.mesh=resource
	tile.material_override=material
	car.body.add_child(tile)


static func _nose_z(x: float) -> float:
	return -2.119+0.130*pow(x/0.8,2.0)


static func _wrap_bumper(car: CarVisual, rubber: Material, rear: bool = false) -> void:
	CompactCoachwork.build_bumper(car,rear,rubber)


static func _nose_band(car: CarVisual, half_width: float, bottom: float, top: float, offset: float, material: Material) -> void:
	_nose_tile(car,-half_width,half_width,bottom,top,offset,40 if half_width>0.7 else 16,12 if half_width>0.7 else 1,material)

static func _nose_tile(car: CarVisual, left: float, right: float, bottom: float, top: float, offset: float, columns: int, rows: int, material: Material) -> void:
	# The thin solid applique follows the shell in both directions. Its back is
	# embedded in the steel; an old rectangular back wall cut across the corner.
	var inset:=Vector3(0,0,0.024)
	if car.simple_model:
		columns = maxi(2,columns/2)
		rows = maxi(1,rows/2)
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(rows):
		var y0: float=lerpf(bottom,top,row/float(rows))
		var y1: float=lerpf(bottom,top,(row+1)/float(rows))
		for column: int in range(columns):
			var x0: float=lerpf(left,right,column/float(columns))
			var x1: float=lerpf(left,right,(column+1)/float(columns))
			var a:=Vector3(x0,y0,CompactCoachwork.front_skin(x0,y0)+offset)
			var b:=Vector3(x1,y0,CompactCoachwork.front_skin(x1,y0)+offset)
			var c:=Vector3(x1,y1,CompactCoachwork.front_skin(x1,y1)+offset)
			var d:=Vector3(x0,y1,CompactCoachwork.front_skin(x0,y1)+offset)
			_tile_quad(tool,[a,b,c,d],Vector3((b.z-a.z)/(x1-x0),(d.z-a.z)/(y1-y0),-1).normalized())
			if row==0:_tile_quad(tool,[a,b,b+inset,a+inset],Vector3.DOWN)
			if row==rows-1:_tile_quad(tool,[d,c,c+inset,d+inset],Vector3.UP)
			if column==0:_tile_quad(tool,[a,d,d+inset,a+inset],Vector3.LEFT)
			if column==columns-1:_tile_quad(tool,[b,c,c+inset,b+inset],Vector3.RIGHT)
	var tile:=MeshInstance3D.new()
	tile.mesh=tool.commit()
	tile.material_override=material
	car.body.add_child(tile)

static func _tile_quad(tool: SurfaceTool,points: Array[Vector3],normal: Vector3) -> void:
	var order: Array[int]=[0,1,2,0,2,3]
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0:order=[0,2,1,0,3,2]
	for index: int in order:
		tool.set_normal(normal)
		tool.add_vertex(points[index])


static func _rim_bowl(rotor: Node3D, side: float, metal: Material) -> void:
	# Sloping inner barrel from the bright lip to a recessed spoke bed.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in range(32):
		var a: float = TAU*segment/32.0
		var b: float = TAU*(segment+1)/32.0
		var points: Array[Vector3] = [Vector3(side*0.146,sin(a)*0.232,cos(a)*0.232),Vector3(side*0.146,sin(b)*0.232,cos(b)*0.232),Vector3(side*0.074,sin(b)*0.195,cos(b)*0.195),Vector3(side*0.074,sin(a)*0.195,cos(a)*0.195)]
		var normal := Vector3(side*0.46,-sin((a+b)*0.5)*0.89,-cos((a+b)*0.5)*0.89)
		var indices: Array[int] = [0,1,2,0,2,3]
		if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0: indices = [0,2,1,0,3,2]
		for index: int in indices:
			tool.set_normal(normal.normalized())
			tool.add_vertex(points[index])
	var part := MeshInstance3D.new()
	part.mesh = tool.commit()
	part.material_override = metal
	rotor.add_child(part)
