extends RefCounted
## Closed, bevelled kit sections and forged spoke solids; immutable native meshes.
const G = preload("res://vehicle/kart_geometry.gd")

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b-a).cross(c-a).length_squared()<1e-18: return
	tool.set_normal(normal.normalized())
	var points: Array[Vector3] = [a,b,c]
	if (b-a).cross(c-a).dot(normal)>0: points.reverse()
	for point: Vector3 in points:
		tool.set_uv(Vector2(point.x,point.y))
		tool.add_vertex(point)

static func _point(station: Vector4, section: Vector2) -> Vector3:
	return Vector3(section.x*station.y,station.z+section.y*station.w,station.x)

static func formed(parent: Node3D, label: String, profile: Array[Vector4], contour: Array[Vector2], material: Material, simple: bool, fillet: float = 0.08) -> MeshInstance3D:
	return G.attach(parent,label+"|kit-section-v2|"+str(profile)+"|"+str(contour)+"|"+str(fillet)+("|simple" if simple else "|full"),material,func() -> ArrayMesh:
		var ring: Array[Vector2] = []
		for index: int in range(contour.size()):
			var corner: Vector2 = contour[index]
			var a: Vector2 = corner.lerp(contour[posmod(index-1,contour.size())],fillet)
			var b: Vector2 = corner.lerp(contour[(index+1)%contour.size()],fillet)
			for step: int in range(2 if simple else 3):
				var t: float = float(step)/(1 if simple else 2)
				ring.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
		var clockwise: bool = Geometry2D.is_polygon_clockwise(PackedVector2Array(ring))
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: int in range(ring.size()):
			var a: Vector2 = ring[side]
			var b: Vector2 = ring[(side+1)%ring.size()]
			var delta: Vector2 = b-a
			var outward: Vector2 = Vector2(-delta.y,delta.x) if clockwise else Vector2(delta.y,-delta.x)
			var mesh: ArrayMesh = G.surface(1,profile.size()-1,func(u: float,v: float) -> Vector3:
				# Adjacent sides and caps must use identical endpoint coordinates.
				var section: Vector2 = a if u==0.0 else b if u==1.0 else a.lerp(b,u)
				return _point(preload("res://vehicle/kart_bodywork.gd")._station(profile,v),section),func(_u: float,_v: float) -> Vector3:
				return Vector3(outward.x,outward.y,0))
			tool.append_from(mesh,0,Transform3D.IDENTITY)
		var caps: PackedInt32Array = Geometry2D.triangulate_polygon(PackedVector2Array(ring))
		assert(not caps.is_empty(),"Kart kit section must close without crossing itself")
		for end: int in [0,1]:
			# Match the sampled side endpoint exactly, including float interpolation.
			var station: Vector4 = preload("res://vehicle/kart_bodywork.gd")._station(profile,float(end))
			# The side streams already have indices. Appending bare cap vertices
			# leaves them unreferenced; append another indexed surface instead.
			var cap := SurfaceTool.new()
			cap.begin(Mesh.PRIMITIVE_TRIANGLES)
			for face: int in range(caps.size()/3):
				_triangle(cap,_point(station,ring[caps[face*3]]),_point(station,ring[caps[face*3+1]]),_point(station,ring[caps[face*3+2]]),Vector3(0,0,-1 if end==0 else 1))
			cap.index()
			tool.append_from(cap.commit(),0,Transform3D.IDENTITY)
		tool.index()
		tool.generate_tangents()
		return tool.commit())

static func lathe(parent: Node3D, label: String, profile: Array[Vector2], material: Material, simple: bool) -> MeshInstance3D:
	var exterior: Array[Vector2] = profile.duplicate()
	# Mirroring axial coordinates reverses the profile and every surface normal.
	if not Geometry2D.is_polygon_clockwise(PackedVector2Array(exterior)): exterior.reverse()
	return G.lathe(parent,label+"_exterior_v2",exterior,material,simple)

static func _path(points: Array[Vector3], t: float, closed: bool) -> Vector3:
	if not closed: return G.curve(points,t)
	var count: int = points.size()-1
	var at: float = fposmod(t,1.0)*count
	var row: int = int(at)
	return points[row].cubic_interpolate(points[(row+1)%count],points[posmod(row-1,count)],points[(row+2)%count],at-row)

static func tube(parent: Node3D, label: String, points: Array[Vector3], radius: float, material: Material, simple: bool, segments: int = 32) -> void:
	G.attach(parent,label+"|closed-tube-v1|"+str(points)+"|"+str(radius)+"|"+str(segments)+("|simple" if simple else "|full"),material,func() -> ArrayMesh:
		var closed: bool = points[0].distance_squared_to(points[-1])<1e-12
		var columns: int = 8 if radius<0.018 else 12
		var rows: int = segments
		if simple:
			columns = maxi(4,columns/2)
			rows = maxi(2,rows/2)
		var centers: Array[Vector3] = []
		var tangents: Array[Vector3] = []
		var axes: Array[Vector3] = []
		for row: int in range(rows+1):
			var t: float = float(row)/rows
			centers.append(_path(points,t,closed))
			var before: float = t-0.0001 if closed else maxf(0,t-0.0001)
			var after: float = t+0.0001 if closed else minf(1,t+0.0001)
			var tangent: Vector3 = (_path(points,after,closed)-_path(points,before,closed)).normalized()
			tangents.append(tangent)
			if row==0:
				axes.append(tangent.cross(Vector3.UP if absf(tangent.y)<0.8 else Vector3.RIGHT).normalized())
			else:
				axes.append((Quaternion(tangents[row-1],tangent)*axes[row-1]).slide(tangent).normalized())
		if closed:
			var correction: float = axes[-1].signed_angle_to(axes[0],tangents[0])
			for row: int in range(rows+1): axes[row] = Basis(tangents[row],correction*row/rows)*axes[row]
			centers[-1] = centers[0]; tangents[-1] = tangents[0]; axes[-1] = axes[0]
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		for row: int in range(rows+1):
			for column: int in range(columns+1):
				var angle: float = TAU*(column%columns)/columns
				var normal: Vector3 = axes[row]*cos(angle)+tangents[row].cross(axes[row])*sin(angle)
				vertices.append(centers[row]+normal*radius)
				normals.append(normal)
				uv.append(Vector2(float(column)/columns,float(row)/rows))
		for row: int in range(rows):
			for column: int in range(columns):
				var a: int = row*(columns+1)+column
				indices.append_array(PackedInt32Array([a,a+columns+2,a+1,a,a+columns+1,a+columns+2]))
		if not closed:
			for row: int in [0,rows]:
				var normal: Vector3 = tangents[row]*(-1 if row==0 else 1)
				var center_index: int = vertices.size()
				vertices.append(centers[row]); normals.append(normal); uv.append(Vector2(0.5,0.5))
				var rim: int = vertices.size()
				for column: int in range(columns):
					vertices.append(vertices[row*(columns+1)+column]); normals.append(normal)
					uv.append(Vector2(cos(TAU*column/columns),sin(TAU*column/columns))*0.5+Vector2.ONE*0.5)
				for column: int in range(columns):
					var b: int = rim+column
					var c: int = rim+(column+1)%columns
					if (vertices[b]-centers[row]).cross(vertices[c]-centers[row]).dot(normal)>0:
						indices.append_array(PackedInt32Array([center_index,c,b]))
					else: indices.append_array(PackedInt32Array([center_index,b,c]))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return mesh)

static func spoke(parent: Node3D, label: String, polygon: Array[Vector2], angle: float, side: float, material: Material) -> void:
	# Polygon coordinates are radial/tangential. A shallow bevel closes both faces.
	G.attach(parent,label+"|forged-v1|"+str(polygon)+"|"+str(angle)+"|"+str(side),material,func() -> ArrayMesh:
		var center := Vector2.ZERO
		for point: Vector2 in polygon: center += point/polygon.size()
		var point3 := func(point: Vector2, x: float) -> Vector3:
			return Vector3(side*x,sin(angle)*point.x+cos(angle)*point.y,cos(angle)*point.x-sin(angle)*point.y)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings: Array[PackedVector3Array] = []
		for layer: int in range(4):
			var ring := PackedVector3Array()
			for point: Vector2 in polygon:
				var q: Vector2 = point.move_toward(center,0.0015) if layer in [0,3] else point
				ring.append(point3.call(q,[0.092,0.094,0.118,0.120][layer]))
			rings.append(ring)
		var clockwise: bool = Geometry2D.is_polygon_clockwise(PackedVector2Array(polygon))
		for layer: int in range(3):
			for index: int in range(polygon.size()):
				var next: int = (index+1)%polygon.size()
				var d: Vector2 = polygon[next]-polygon[index]
				var normal2: Vector2 = Vector2(-d.y,d.x) if clockwise else Vector2(d.y,-d.x)
				var normal: Vector3 = point3.call(center+normal2,0)-point3.call(center,0)
				_triangle(tool,rings[layer][index],rings[layer][next],rings[layer+1][next],normal)
				_triangle(tool,rings[layer][index],rings[layer+1][next],rings[layer+1][index],normal)
		var caps: PackedInt32Array = Geometry2D.triangulate_polygon(PackedVector2Array(polygon))
		assert(not caps.is_empty())
		for layer: int in [0,3]:
			for face: int in range(caps.size()/3):
				_triangle(tool,rings[layer][caps[face*3]],rings[layer][caps[face*3+1]],rings[layer][caps[face*3+2]],Vector3(side*(-1 if layer==0 else 1),0,0))
		tool.index()
		return tool.commit())
