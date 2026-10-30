class_name CompactKitSurface
extends RefCounted
## Closed fabricated sections. Small corner radii retain broad, readable faces.

static func contour(polygon: Array[Vector2], t: float, radius: float) -> Vector2:
	var station: float = fposmod(t,1.0)*polygon.size()
	var index: int = int(station)
	var p: Vector2 = polygon[index]
	var before: Vector2 = polygon[posmod(index-1,polygon.size())]
	var after: Vector2 = polygon[(index+1)%polygon.size()]
	var a: Vector2 = p+(before-p).normalized()*minf(radius,p.distance_to(before)*0.2)
	var b: Vector2 = p+(after-p).normalized()*minf(radius,p.distance_to(after)*0.2)
	var next: Vector2 = after+(p-after).normalized()*minf(radius,p.distance_to(after)*0.2)
	var progress: float = station-index
	if progress<0.25:
		var u: float = progress*4
		return a.lerp(p,u).lerp(p.lerp(b,u),u)
	return b.lerp(next,(progress-0.25)/0.75)

static func panel(root: Node3D, key: String, sample: Callable, material: Material, hint: Vector3, columns: int, rows: int) -> void:
	if CompactKits.simple_parts:
		key += "/simple"
		columns = maxi(8,columns/2)
		rows = maxi(4,rows/2)
	CompactKits._load_prepared(key)
	if not CompactKits.meshes.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(rows):
			for column: int in range(columns):
				var a: Vector3 = sample.call(column/float(columns),row/float(rows))
				var b: Vector3 = sample.call((column+1)/float(columns),row/float(rows))
				var c: Vector3 = sample.call((column+1)/float(columns),(row+1)/float(rows))
				var d: Vector3 = sample.call(column/float(columns),(row+1)/float(rows))
				for points: Array in [[a,b,c],[a,c,d]]:
					var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0])
					if normal.length_squared()<1e-20: continue
					normal = normal.normalized()
					if normal.dot(hint)<0: normal = -normal
					CompactAero._triangle(tool,points[0],points[1],points[2],normal)
		tool.index()
		tool.generate_tangents()
		CompactKits.meshes[key] = tool.commit()
	CompactAero._attach(root,key,material)

static func solid(root: Node3D, key: String, sample: Callable, material: Material, columns: int, rows: int) -> void:
	var cache_key: String = key+("/simple" if CompactKits.simple_parts else "")
	CompactKits._load_prepared(cache_key)
	var ready: bool = CompactKits.meshes.has(cache_key)
	var part: MeshInstance3D = skin(root,key,sample,material,columns,rows)
	if ready: return
	# End returns belong to the same immutable surface, reducing cache entries
	# and ensuring every prepared version includes the complete solid.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(part.mesh,0,Transform3D.IDENTITY)
	tool.deindex()
	var count: int = maxi(4,rows/2) if CompactKits.simple_parts else rows
	for end: float in [0.0,1.0]:
		var origin := Vector3.ZERO
		for index: int in range(count): origin += (sample.call(end,index/float(count)) as Vector3)/count
		var axis: Vector3 = (sample.call(minf(1,end+0.0001),0.0) as Vector3)-(sample.call(maxf(0,end-0.0001),0.0) as Vector3)
		var normal: Vector3 = axis.normalized()*(-1 if end==0 else 1)
		for index: int in range(count):
			CompactAero._triangle(tool,origin,sample.call(end,index/float(count)),sample.call(end,(index+1)/float(count)),normal)
	tool.index()
	tool.generate_tangents()
	CompactKits.meshes[cache_key] = tool.commit()
	part.mesh = CompactKits.meshes[cache_key]

static func skin(root: Node3D, key: String, sample: Callable, material: Material, columns: int, rows: int) -> MeshInstance3D:
	if CompactKits.simple_parts:
		key += "/simple"
		columns = maxi(8,columns/2)
		rows = maxi(4,rows/2)
	CompactKits._load_prepared(key)
	if not CompactKits.meshes.has(key):
		# A consistent winding follows the section around concave folds. Choosing
		# an independent centre-facing direction per triangle can invert returns.
		var center := Vector3.ZERO
		for ring: int in range(rows): center += (sample.call(0.5,ring/float(rows)) as Vector3)/rows
		var du: Vector3 = (sample.call(0.5001,0.0) as Vector3)-(sample.call(0.4999,0.0) as Vector3)
		var dv: Vector3 = (sample.call(0.5,0.0001) as Vector3)-(sample.call(0.5,0.9999) as Vector3)
		var sign_out: float = 1 if du.cross(dv).dot((sample.call(0.5,0.0) as Vector3)-center)>0 else -1
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(rows):
			for column: int in range(columns):
				var uv: Array[Vector2] = [Vector2(column/float(columns),row/float(rows)),Vector2((column+1)/float(columns),row/float(rows)),Vector2((column+1)/float(columns),(row+1)/float(rows)),Vector2(column/float(columns),(row+1)/float(rows))]
				var points: Array[Vector3] = []
				var normals: Array[Vector3] = []
				for t: Vector2 in uv:
					points.append(sample.call(t.x,t.y))
					var along: Vector3 = (sample.call(minf(1,t.x+0.0001),t.y) as Vector3)-(sample.call(maxf(0,t.x-0.0001),t.y) as Vector3)
					var across: Vector3 = (sample.call(t.x,fposmod(t.y+0.0001,1.0)) as Vector3)-(sample.call(t.x,fposmod(t.y-0.0001,1.0)) as Vector3)
					normals.append(along.cross(across).normalized()*sign_out)
				for triangle: Array in [[0,1,2],[0,2,3]]:
					var face: Vector3 = (points[triangle[1]]-points[triangle[0]]).cross(points[triangle[2]]-points[triangle[0]])
					if face.length_squared()<1e-20: continue
					var order: Array = [triangle[0],triangle[2],triangle[1]] if sign_out>0 else triangle
					var flat: Vector3 = face.normalized()*sign_out
					var wrong: bool = flat.dot(normals[triangle[0]]+normals[triangle[1]]+normals[triangle[2]])<0.02
					for index: int in order:
						tool.set_normal(flat if wrong or normals[index].length_squared()<0.5 else normals[index])
						tool.set_uv(uv[index])
						tool.add_vertex(points[index])
		tool.index()
		tool.generate_tangents()
		CompactKits.meshes[key] = tool.commit()
	var part := MeshInstance3D.new()
	part.name = key.get_file().replace(".","_")
	part.mesh = CompactKits.meshes[key]
	part.material_override = material
	root.add_child(part)
	return part
