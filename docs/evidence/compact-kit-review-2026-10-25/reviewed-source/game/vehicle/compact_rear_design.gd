class_name CompactRearDesign
extends RefCounted
## Original retro rear fittings. Matte native geometry; no added textures/shaders.
const PLATE_CENTER: float=0.4856
static var meshes: Dictionary={}
static var lettering: Dictionary={}

static func build(car: CarVisual,paint: Material,trim: Material,metal: Material) -> void:
	_lamps(car,trim)
	_tailgate(car,paint,trim)
	_bumper_bevel(car)
	_plate(car,trim,metal)
	_window(car,trim)
	_exhaust(car,trim,metal)
	var lower: MeshInstance3D=VisualGeometry.box(car.body,Vector3(1.38,0.048,0.09),Vector3(0,0.350,1.989),car.underside_material)
	lower.name="RearLowerValanceShadow"

static func _lamps(car: CarVisual,trim: Material) -> void:
	var amber:=VisualGeometry.material(Color("d58b32"))
	var white:=VisualGeometry.material(Color("e7e4d2"))
	amber.roughness=0.48
	white.roughness=0.48
	car.brake_material.roughness=0.48
	var glint:=VisualGeometry.material(Color("c8c4ad"))
	glint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for side: float in [-1.0,1.0]:
		var suffix: String="Left" if side<0 else "Right"
		# One black housing: all three lenses share the same inset and contour.
		CompactDetail._rear_patch(car,side,0.716,0.872,0.620,0.920,0.012,trim,"RearLampHousing"+suffix)
		CompactDetail._rear_patch(car,side,0.730,0.858,0.860,0.908,0.017,amber,"RearIndicator"+suffix)
		CompactDetail._rear_patch(car,side,0.730,0.858,0.727,0.847,0.018,car.brake_material,"RearBrakeLens"+suffix)
		CompactDetail._rear_patch(car,side,0.730,0.858,0.633,0.714,0.017,white,"RearReverseLens"+suffix)
		# Short, quiet moulded optical highlights rather than emissive strips.
		for band: Vector3 in [Vector3(0.734,0.820,0.896),Vector3(0.734,0.792,0.835),Vector3(0.734,0.821,0.701)]:
			CompactDetail._rear_patch(car,side,band.x,band.y,band.z,band.z+0.002,0.0188,glint,"RearLensHighlight"+suffix+str(band.z))

static func _paint_band(car: CarVisual,paint: Material,darken: float) -> Material:
	var band: StandardMaterial3D=CompactFinish.paint((paint as StandardMaterial3D).albedo_color.darkened(darken))
	band.roughness=0.68
	band.clearcoat_enabled=false
	band.metallic_specular=0.20
	car.paint_variants.append({"material":band,"slot":"body","darken":darken})
	return band

static func _tail_point(x: float,y: float,offset: float=0.002) -> Vector3:
	var z: float=CompactCoachwork.rear_skin(x,y)
	if absf(x)<0.20 and absf(y-0.898)<0.075:
		# Fit the actual emitted steel triangles at the pressed handle pocket.
		# Analytical samples alone can cross their linear interpolation.
		var row: int=mini(23,int(CompactCoachwork.body_fraction(y,1.01)*24))
		var across: float=(x/(CompactCoachwork.width_at_height(y)-CompactCoachwork.rear_radius(y))+1)*0.5
		var column: int=clampi(int(across*40),0,39)
		var a: Vector3=CompactCoachwork.rear_face_point(column/40.0,row/24.0)
		var b: Vector3=CompactCoachwork.rear_face_point((column+1)/40.0,row/24.0)
		var c: Vector3=CompactCoachwork.rear_face_point((column+1)/40.0,(row+1)/24.0)
		var d: Vector3=CompactCoachwork.rear_face_point(column/40.0,(row+1)/24.0)
		var weights: Vector3=_barycentric(Vector2(x,y),a,b,c)
		if weights.x>=0 and weights.y>=0 and weights.z>=0:z=weights.x*a.z+weights.y*b.z+weights.z*c.z
		else:
			weights=_barycentric(Vector2(x,y),a,c,d)
			z=weights.x*a.z+weights.y*c.z+weights.z*d.z
	return Vector3(x,y,z+offset)

static func _barycentric(p: Vector2,a: Vector3,b: Vector3,c: Vector3) -> Vector3:
	var v0:=Vector2(b.x-a.x,b.y-a.y)
	var v1:=Vector2(c.x-a.x,c.y-a.y)
	var v2: Vector2=p-Vector2(a.x,a.y)
	var denominator: float=v0.x*v1.y-v1.x*v0.y
	var second: float=(v2.x*v1.y-v1.x*v2.y)/denominator
	var third: float=(v0.x*v2.y-v2.x*v0.y)/denominator
	return Vector3(1-second-third,second,third)

static func _tailgate(car: CarVisual,paint: Material,trim: Material) -> void:
	var seam_root:=Node3D.new()
	seam_root.name="TailgatePanelSeam"
	car.body.add_child(seam_root)
	var path: Array[Vector2]=[Vector2(-0.695,0.624),Vector2(0.695,0.624),Vector2(0.695,1.006),Vector2(-0.695,1.006)]
	var outline: Array[Vector2]=[]
	for corner: int in range(4):
		var a: Vector2=path[corner].move_toward(path[(corner+3)%4],0.020)
		var b: Vector2=path[corner].move_toward(path[(corner+1)%4],0.020)
		for step: int in range(5):
			var t: float=step/4.0
			outline.append(a.lerp(path[corner],t).lerp(path[corner].lerp(b,t),t))
	for index: int in range(outline.size()):
		var a: Vector2=outline[index]
		var b: Vector2=outline[(index+1)%outline.size()]
		var steps: int=maxi(1,int(ceil(a.distance_to(b)/0.035)))
		for step: int in range(steps):
			var p: Vector2=a.lerp(b,step/float(steps))
			var q: Vector2=a.lerp(b,(step+1)/float(steps))
			p.x*=CompactCoachwork.width_at_height(p.y)/0.88
			q.x*=CompactCoachwork.width_at_height(q.y)/0.88
			car._seam(seam_root,_tail_point(p.x,p.y,0.003),_tail_point(q.x,q.y,0.003),0.0045,trim)
	var upper: Material=_paint_band(car,paint,0.025)
	var lower: Material=_paint_band(car,paint,0.065)
	var crease: Material=_paint_band(car,paint,0.16)
	for band: Array in [["TailgateUpperPlane",0.803,0.999,upper],["TailgateLowerPlane",0.631,0.781,lower],["TailgateCrease",0.782,0.800,crease]]:
		_surface(car,band[0],24 if band[0]=="TailgateUpperPlane" else 4,12 if band[0]=="TailgateUpperPlane" else 1,func(u: float,v: float) -> Vector3:
			var y: float=lerpf(band[1],band[2],v)
			var x: float=lerpf(-0.675,0.675,u)*CompactCoachwork.width_at_height(y)/0.88
			return _tail_point(x,y,0.002 if band[0]!="TailgateCrease" else 0.001),band[3],Vector3.BACK)
	# Recess follows the actual inset steel; a beveled painted surround frames it.
	var recess: Material=_paint_band(car,paint,0.19)
	_surface(car,"RearHandleRecess",12,4,func(u: float,v: float) -> Vector3:
		return _tail_point(lerpf(-0.173,0.173,u),lerpf(0.850,0.946,v),0.003),recess,Vector3.BACK)
	var handle: MeshInstance3D=VisualGeometry.box(car.body,Vector3(0.308,0.047,0.015),Vector3(0,0.908,CompactCoachwork.rear_skin(0,0.908)+0.010),trim)
	handle.name="RearRecessedHandle"
	for side: float in [-1.0,1.0]:
		_surface(car,"RearCornerContour"+str(side),4,16,func(u: float,v: float) -> Vector3:
			var y: float=lerpf(0.620,0.982,v)
			var x: float=side*lerpf(0.868,0.878,u)/0.88*CompactCoachwork.width_at_height(y)
			return _tail_point(x,y,0.0015),lower,Vector3(side,0,1).normalized())

static func _bumper_bevel(car: CarVisual) -> void:
	var plastic: Material=CompactFinish.rubber(Color("242c2f"))
	# Match existing bumper stations, so the narrow matte bevel cannot cross it.
	_surface(car,"RearBumperUpperBevel",96,2,func(u: float,v: float) -> Vector3:
		var point: Vector3=CompactCoachwork._bumper_point(true,u,lerpf(3.0/24,5.0/24,v))
		var tangent: Vector2=(CompactCoachwork._bumper_path(true,minf(1,u+0.0002))-CompactCoachwork._bumper_path(true,maxf(0,u-0.0002))).normalized()
		return point+Vector3(-tangent.y,0,tangent.x)*0.0008,plastic,Vector3(0,0.5,1).normalized())

static func _ink(color: Color) -> Material:
	var result:=VisualGeometry.material(color)
	result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

static func _plate(car: CarVisual,trim: Material,metal: Material) -> void:
	var ivory: Material=VisualGeometry.material(Color("e6dfc9"))
	ivory.roughness=0.85
	var blue: Material=_ink(Color("263e52"))
	var red: Material=_ink(Color("8d463b"))
	# 2:1 American format with a restrained fictional jurisdiction header.
	_rounded_plate(car,"RearPlateFrame",Vector2(0.436,0.220),0.010,2.115,trim)
	_rounded_plate(car,"RearPlateBorder",Vector2(0.420,0.212),0.008,2.124,blue)
	_rounded_plate(car,"RearPlateFace",Vector2(0.412,0.206),0.007,2.127,ivory)
	_text(car,"RearPlateLetters","BMT 01",0.0020,Vector3(0,PLATE_CENTER-0.010,2.129),blue)
	_text(car,"RearPlateHeader","BEAT MY TRACK",0.00048,Vector3(0,PLATE_CENTER+0.070,2.129),blue)
	var rule: MeshInstance3D=VisualGeometry.box(car.body,Vector3(0.350,0.0025,0.001),Vector3(0,PLATE_CENTER+0.047,2.129),red)
	rule.name="RearPlateHeaderRule"
	for side: float in [-1.0,1.0]:
		var screw: MeshInstance3D=VisualGeometry.cylinder(car.body,0.004,0.002,Vector3(side*0.184,PLATE_CENTER+0.053,2.130),metal,true)
		screw.rotation.x=PI*0.5

static func _rounded_plate(car: CarVisual,label: String,size: Vector2,radius: float,z: float,material: Material) -> void:
	if not meshes.has(label):
		var outline: Array[Vector3]=[]
		for corner: int in range(4):
			var direction:=Vector2(1 if corner in [0,3] else -1,1 if corner in [0,1] else -1)
			var center: Vector2=direction*(size*0.5-Vector2.ONE*radius)
			for step: int in range(5):
				var angle: float=corner*PI*0.5+step/4.0*PI*0.5
				var point: Vector2=center+Vector2(cos(angle),sin(angle))*radius
				outline.append(Vector3(point.x,PLATE_CENTER+point.y,z))
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index: int in range(outline.size()):
			for point: Vector3 in [Vector3(0,PLATE_CENTER,z),outline[(index+1)%outline.size()],outline[index]]:
				tool.set_normal(Vector3.BACK)
				tool.add_vertex(point)
		meshes[label]=tool.commit()
	var mesh:=MeshInstance3D.new()
	mesh.name=label
	mesh.mesh=meshes[label]
	mesh.material_override=material
	car.body.add_child(mesh)

static func _text(car: CarVisual,label: String,value: String,pixel: float,position: Vector3,material: Material) -> void:
	if not lettering.has(label):
		var resource:=TextMesh.new()
		resource.font=preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
		resource.font_size=48
		resource.pixel_size=pixel
		resource.depth=0.0
		resource.text=value
		lettering[label]=resource
	var mesh:=MeshInstance3D.new()
	mesh.name=label
	mesh.mesh=lettering[label]
	mesh.position=position
	mesh.material_override=material
	car.body.add_child(mesh)

static func _window(car: CarVisual,trim: Material) -> void:
	var glazing=preload("res://vehicle/compact_glazing.gd")
	var normal:=Vector3(0,0.84,0.54).normalized()
	var pivot: Vector3=glazing._sheet_point(false,0.50,0.035,true)+normal*0.020
	var cap: MeshInstance3D=VisualGeometry.cylinder(car.body,0.026,0.015,pivot,trim,true)
	cap.name="RearWiperPivot"
	cap.quaternion=Quaternion(Vector3.UP,normal)
	var arm_root:=Node3D.new()
	arm_root.name="RearWiperArm"
	car.body.add_child(arm_root)
	var a: Vector3=glazing._sheet_point(false,0.515,0.06,true)+normal*0.022
	var b: Vector3=glazing._sheet_point(false,0.64,0.23,true)+normal*0.020
	var c: Vector3=glazing._sheet_point(false,0.83,0.33,true)+normal*0.017
	car._seam(arm_root,pivot,a,0.023,trim)
	car._seam(arm_root,a,b,0.014,trim)
	car._seam(arm_root,b,c,0.012,trim)
	var blade: Vector3=glazing._sheet_point(false,0.91,0.37,true)+normal*0.015
	car._seam(arm_root,b,blade,0.018,trim)

static func _exhaust(car: CarVisual,trim: Material,metal: Material) -> void:
	var interior: Material=CompactFinish.rubber(Color("0b1013"))
	var assembly:=Node3D.new()
	assembly.name="RearExhaustAssembly"
	car.body.add_child(assembly)
	for pipe: int in range(2):
		var center:=Vector3(0.47+pipe*0.135,0.310,2.142)
		var parent:=Node3D.new()
		parent.name="RearExhaust"+str(pipe+1)
		parent.position=center
		assembly.add_child(parent)
		# Sixteen radial segments; open mouth, bevelled metal rim, dark inner wall.
		for section: int in range(3):
			var radii: Array[Vector2]=[Vector2(0.049,0.049),Vector2(0.049,0.039),Vector2(0.039,0.038)]
			var depths: Array[Vector2]=[Vector2(-0.105,-0.004),Vector2(-0.004,0.002),Vector2(0.002,-0.060)]
			var mesh:=MeshInstance3D.new()
			mesh.name="Barrel" if section==0 else "Rim" if section==1 else "Interior"
			var tool:=SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for segment: int in range(16):
				var points: Array[Vector3]=[]
				for uv: Vector2 in [Vector2(segment/16.0,0),Vector2((segment+1)/16.0,0),Vector2((segment+1)/16.0,1),Vector2(segment/16.0,1)]:
					var radius: float=lerpf(radii[section].x,radii[section].y,uv.y)
					points.append(Vector3(cos(uv.x*TAU)*radius,sin(uv.x*TAU)*radius,lerpf(depths[section].x,depths[section].y,uv.y)))
				var normal: Vector3=Vector3.BACK if section==1 else Vector3(cos((segment+0.5)/16.0*TAU),sin((segment+0.5)/16.0*TAU),0)*(1 if section==0 else -1)
				CompactDetail._tile_quad(tool,points,normal)
			mesh.mesh=tool.commit()
			mesh.material_override=metal if section==1 else trim if section==0 else interior
			parent.add_child(mesh)
		var back: MeshInstance3D=VisualGeometry.cylinder(parent,0.038,0.002,Vector3(0,0,-0.064),interior,true)
		back.rotation.x=PI*0.5
		back.name="DarkBack"
		if car.batch_parts:
			# Both fixed pipes share one sibling batch; unbatched fixtures retain names.
			for part: Node3D in parent.get_children():
				var pose: Transform3D=parent.transform*part.transform
				parent.remove_child(part)
				assembly.add_child(part)
				part.transform=pose
			parent.free()

static func _surface(car: CarVisual,label: String,columns: int,rows: int,sample: Callable,material: Material,normal_hint: Vector3) -> void:
	var key: String = label+"_simple" if car.simple_model else label
	if car.simple_model:
		columns = maxi(2,columns/2)
		rows = maxi(1,rows/2)
	if not meshes.has(key) or not VisualGeometry.optimize_model_geometry:
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(rows):
			for column: int in range(columns):
				var points: Array[Vector3]=[]
				for uv: Vector2 in [Vector2(column/float(columns),row/float(rows)),Vector2((column+1)/float(columns),row/float(rows)),Vector2((column+1)/float(columns),(row+1)/float(rows)),Vector2(column/float(columns),(row+1)/float(rows))]:points.append(sample.call(uv.x,uv.y))
				var normal: Vector3=(points[1]-points[0]).cross(points[3]-points[0]).normalized()
				if normal.dot(normal_hint)<0:normal=-normal
				CompactDetail._tile_quad(tool,points,normal)
		meshes[key]=tool.commit()
	var mesh:=MeshInstance3D.new()
	mesh.name=label
	mesh.mesh=meshes[key]
	mesh.material_override=material
	car.body.add_child(mesh)
