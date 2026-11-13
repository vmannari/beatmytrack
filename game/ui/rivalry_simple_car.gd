extends Control
## Tiny faceted podium models. Project once into the existing menu canvas so
## entry needs no CarVisual, SubViewport, lighting, reflections or car shaders.
var vehicle_id: String = "compact"
var livery: Dictionary = {}
var customisation: Dictionary = {} # Preserve the appearance payload; omit fitted detail.
var condition: Dictionary = {}
var fit_to_frame: bool = true
var presentation_ready: bool:
	get: return not faces.is_empty() and size.x > 1 and size.y > 1
var faces: Array[Dictionary] = []
var model_bounds: Rect2
var triangle_count: int = 0
var canvas_triangle_count: int = 0
var _canvas_mesh: ArrayMesh
var _layer: int = 0
var _view := Vector3(-6,4,-8).normalized()
var _right := Vector3(8,0,-6).normalized()
var _up := _right.cross(_view)
var _light := Vector3(-3,7,-5).normalized()
const RUBBER := Color("202832")
const GLASS := Color("314d60")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(queue_redraw)

func _pigment(slot: String, fallback: String) -> Color:
	return Color.from_string(str(livery.get("colors",{}).get(slot,fallback)),Color(fallback))

func _build() -> void:
	var paint: Color = _pigment("body","30627d")
	var accent: Color = _pigment("accent","e0d5b5")
	var detail: Color = _pigment("detail","a4abad")
	match vehicle_id:
		"kart":
			_box(Vector3(0,0.31,0),Vector3(1.25,0.16,1.95),RUBBER)
			_hull([Vector3(-1.2,0.47,0.37),Vector3(-0.58,0.55,0.46),Vector3(0.9,0.46,0.39)],0.28,paint)
			_box(Vector3(0,0.64,0.35),Vector3(0.55,0.6,0.22),RUBBER)
			_box(Vector3(0,0.72,0.08),Vector3(0.46,0.5,0.38),accent)
			_box(Vector3(0,1.08,0.09),Vector3(0.41,0.34,0.38),detail)
			_box(Vector3(0,1.09,-0.108),Vector3(0.35,0.13,0.02),GLASS)
			_wheels(0.8,0.79,0.27,0.29,detail)
		"forklift":
			_box(Vector3(0,0.65,0.28),Vector3(1.4,0.68,1.85),paint)
			_box(Vector3(0,0.95,0.36),Vector3(0.62,0.54,0.57),RUBBER)
			for side: float in [-1.0,1.0]:
				for end: float in [-0.35,1.0]:
					_box(Vector3(side*0.59,1.38,end),Vector3(0.1,1.05,0.1),RUBBER)
				_box(Vector3(side*0.5,1.12,-0.99),Vector3(0.12,2.0,0.15),RUBBER)
				_box(Vector3(side*0.47,0.2,-1.5),Vector3(0.15,0.09,1.1),detail)
			_box(Vector3(0,1.94,0.31),Vector3(1.42,0.13,1.6),accent)
			_box(Vector3(0,0.65,-1.05),Vector3(1.16,0.17,0.14),detail)
			_wheels(0.72,0.67,0.35,0.3,detail)
		"hovercraft":
			_hull([Vector3(-1.85,0.72,0.4),Vector3(-1.3,1.04,0.5),Vector3(1.5,1.04,0.5),Vector3(1.85,0.76,0.4)],0.1,RUBBER)
			_hull([Vector3(-1.65,0.65,0.58),Vector3(-1.0,0.92,0.68),Vector3(1.45,0.84,0.65)],0.38,paint)
			_cabin(-0.75,0.7,-0.25,0.6,0.57,0.67,1.17,accent)
			for side: float in [-1.0,1.0]:
				_cylinder(Vector3(side*0.6,0.99,1.35),0.4,0.27,RUBBER,false)
				_cylinder(Vector3(side*0.6,0.99,1.19),0.26,0.02,detail,false)
		_:
			var coupe: bool = vehicle_id == "super_rally"
			var volt: bool = vehicle_id == "electric"
			var length: float = 2.13 if coupe else 2.0 if volt else 1.85
			_hull([Vector3(-length,0.69,0.62),Vector3(-length+0.4,0.87,0.8),Vector3(length-0.27,0.86,0.81),Vector3(length,0.72,0.66)],0.3,paint)
			_cabin(-0.4 if coupe else -1.05 if volt else -0.84,1.15 if coupe else 1.4,-0.04 if coupe else -0.47 if volt else -0.39,0.64 if coupe else 0.95 if volt else 0.88,0.73,0.79,1.22 if coupe else 1.29 if volt else 1.44,accent)
			_wheels(0.87,1.27 if coupe else 1.14,0.34,0.25,detail)
			_box(Vector3(0,0.47,-length-0.01),Vector3(1.33,0.15,0.09),RUBBER)
			_box(Vector3(0,0.66,-length-0.015),Vector3(0.59,0.17,0.03),RUBBER)
			for side: float in [-1.0,1.0]:
				_box(Vector3(side*0.54,0.69,-length-0.025),Vector3(0.27,0.13,0.035),Color("e8dfb5"))
	faces.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.layer < b.layer if a.layer != b.layer else a.depth < b.depth)
	var first: bool = true
	for face: Dictionary in faces:
		for point: Vector2 in face.points:
			model_bounds = Rect2(point,Vector2.ZERO) if first else model_bounds.expand(point)
			first = false
	_batch_faces()
	queue_redraw()

func _batch_faces() -> void:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for face: Dictionary in faces:
		var offset: int = vertices.size()
		vertices.append_array(face.points)
		for point: Vector2 in face.points: colors.append(face.color)
		for index: int in Geometry2D.triangulate_polygon(face.points): indices.append(offset+index)
		# A narrow alpha fringe softens edges without a separate line draw for
		# every facet. All fill/fringe triangles share the same canvas batch.
		var center := Vector2.ZERO
		for point: Vector2 in face.points: center += point/face.points.size()
		for edge: int in range(face.points.size()):
			var a: Vector2 = face.points[edge]
			var b: Vector2 = face.points[(edge+1)%face.points.size()]
			var direction: Vector2 = (b-a).normalized()
			var outward := Vector2(direction.y,-direction.x)
			if outward.dot((a+b)*0.5-center)<0: outward = -outward
			offset = vertices.size()
			vertices.append_array(PackedVector2Array([a,b,b+outward*0.014,a+outward*0.014]))
			var clear: Color = face.color
			clear.a = 0
			colors.append_array(PackedColorArray([face.color,face.color,clear,clear]))
			indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_canvas_mesh = ArrayMesh.new()
	_canvas_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	canvas_triangle_count = indices.size()/3

func _project(point: Vector3) -> Vector2:
	return Vector2(point.dot(_right),-point.dot(_up))

func _face(points: PackedVector3Array, color: Color, center: Vector3) -> void:
	var middle := Vector3.ZERO
	for point: Vector3 in points: middle += point/points.size()
	var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
	if normal.dot(middle-center) < 0: normal = -normal
	triangle_count += points.size()-2
	if normal.dot(_view) <= 0: return
	var polygon := PackedVector2Array()
	for point: Vector3 in points: polygon.append(_project(point))
	var light: float = 0.57+0.43*maxf(0.0,normal.dot(_light))
	faces.append({"points":polygon,"color":Color(color.r*light,color.g*light,color.b*light,1.0),"depth":middle.dot(_view),"layer":_layer})

func _prism(points: PackedVector3Array, colors: Array[Color]) -> void:
	var center := Vector3.ZERO
	for point: Vector3 in points: center += point/points.size()
	for side: int in range(6):
		var indices: Array = [[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]][side]
		var face := PackedVector3Array()
		for index: int in indices: face.append(points[index])
		_face(face,colors[mini(side,colors.size()-1)],center)

func _box(center: Vector3, extent: Vector3, color: Color) -> void:
	var points := PackedVector3Array()
	for point: Vector3 in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,-1,1),Vector3(-1,-1,1),Vector3(-1,1,-1),Vector3(1,1,-1),Vector3(1,1,1),Vector3(-1,1,1)]:
		points.append(center+point*extent*0.5)
	_prism(points,[color])

func _cabin(front: float, rear: float, roof_front: float, roof_rear: float, width: float, low: float, high: float, roof: Color) -> void:
	_layer = 1
	_prism(PackedVector3Array([Vector3(-width,low,front),Vector3(width,low,front),Vector3(width,low,rear),Vector3(-width,low,rear),Vector3(-width*0.79,high,roof_front),Vector3(width*0.79,high,roof_front),Vector3(width*0.79,high,roof_rear),Vector3(-width*0.79,high,roof_rear)]),[RUBBER,roof,GLASS])
	_layer = 0

func _hull(sections: Array[Vector3], bottom: float, color: Color) -> void:
	var rings: Array[PackedVector3Array] = []
	var center := Vector3(0,(bottom+sections[0].z)*0.5,(sections[0].x+sections[-1].x)*0.5)
	# Short longitudinal faces keep painter ordering correct where the cabin
	# covers the deck. This is a fixed-angle illustration, not a general renderer.
	var slices: Array[Vector3] = []
	for index: int in range(sections.size()-1):
		var count: int = maxi(1,ceili(absf(sections[index+1].x-sections[index].x)/0.4))
		for step: int in range(count): slices.append(sections[index].lerp(sections[index+1],float(step)/count))
	slices.append(sections[-1])
	for section: Vector3 in slices:
		var ring := PackedVector3Array()
		var bevel: float = minf(0.07,(section.z-bottom)*0.25)
		for xy: Vector2 in [Vector2(-section.y+0.09,bottom),Vector2(section.y-0.09,bottom),Vector2(section.y,bottom+bevel),Vector2(section.y,section.z-bevel),Vector2(section.y-0.09,section.z),Vector2(-section.y+0.09,section.z),Vector2(-section.y,section.z-bevel),Vector2(-section.y,bottom+bevel)]:
			ring.append(Vector3(xy.x,xy.y,section.x))
		rings.append(ring)
	_face(rings[0],color,center)
	_face(rings[-1],color,center)
	for ring: int in range(rings.size()-1):
		for side: int in range(8):
			var next: int = (side+1)%8
			_face(PackedVector3Array([rings[ring][side],rings[ring][next],rings[ring+1][next],rings[ring+1][side]]),color,center)

func _wheels(x: float, z: float, radius: float, width: float, hub: Color) -> void:
	for side: float in [-1.0,1.0]:
		# Fixed camera: far wheels sit behind the body, near wheels cover it.
		_layer = 2 if side < 0 else -1
		for end: float in [-1.0,1.0]:
			_cylinder(Vector3(side*x,radius,end*z),radius,width,RUBBER)
			_cylinder(Vector3(side*(x+width*0.51),radius,end*z),radius*0.51,0.015,hub)
	_layer = 0

func _cylinder(center: Vector3, radius: float, width: float, color: Color, axle_x: bool = true) -> void:
	var rings: Array[PackedVector3Array] = []
	for end: float in [-0.5,0.5]:
		var ring := PackedVector3Array()
		for index: int in range(8):
			var angle: float = TAU*(index+0.5)/8.0
			ring.append(center+(Vector3(end*width,cos(angle)*radius,sin(angle)*radius) if axle_x else Vector3(sin(angle)*radius,cos(angle)*radius,end*width)))
		rings.append(ring)
	_face(rings[0],color,center)
	_face(rings[1],color,center)
	for side: int in range(8):
		var next: int = (side+1)%8
		_face(PackedVector3Array([rings[0][side],rings[0][next],rings[1][next],rings[1][side]]),color,center)

func _draw() -> void:
	if not presentation_ready: return
	var zoom: float = minf(size.x/maxf(model_bounds.size.x,0.01),size.y/maxf(model_bounds.size.y,0.01))*0.9
	draw_set_transform(size*0.5-model_bounds.get_center()*zoom,0,Vector2.ONE*zoom)
	draw_mesh(_canvas_mesh,null)
