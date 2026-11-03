extends RefCounted
## Original formed steel surfaces. Closed volumes, shared geometry, private finishes.
static var meshes: Dictionary = {}

static func _triangle(tool: SurfaceTool, points: Array[Vector3], normals: Array[Vector3]) -> void:
	var cross: Vector3 = (points[1]-points[0]).cross(points[2]-points[0])
	if cross.length_squared() < 1e-18: return
	var order: Array = [0,2,1] if cross.dot(normals[0]+normals[1]+normals[2]) > 0.0 else [0,1,2]
	for i: int in order:
		tool.set_normal(normals[i])
		tool.set_uv(Vector2(points[i].x+points[i].z,points[i].y))
		tool.add_vertex(points[i])

static func _quad(tool: SurfaceTool, p: Array[Vector3], n: Array[Vector3]) -> void:
	_triangle(tool,[p[0],p[1],p[2]],[n[0],n[1],n[2]])
	_triangle(tool,[p[0],p[2],p[3]],[n[0],n[2],n[3]])

static func _tool() -> SurfaceTool:
	var result := SurfaceTool.new()
	result.begin(Mesh.PRIMITIVE_TRIANGLES)
	return result

static func _node(parent: Node3D, label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node

static func _key(values: Array) -> String:
	return var_to_bytes(values).hex_encode().sha256_text()

static func outline(size: Vector2, corner: float, at: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var h: Vector2 = size*0.5
	return PackedVector2Array([at+Vector2(-h.x+corner,-h.y),at+Vector2(h.x-corner,-h.y),at+Vector2(h.x,-h.y+corner),at+Vector2(h.x,h.y-corner),at+Vector2(h.x-corner,h.y),at+Vector2(-h.x+corner,h.y),at+Vector2(-h.x,h.y-corner),at+Vector2(-h.x,-h.y+corner)])

static func plate(parent: Node3D, label: String, polygon: PackedVector2Array, thickness: float, material: Material, bevel: float = 0.003) -> MeshInstance3D:
	# Local X/Z outline, thickness along Y. Four perimeter rings make a real edge bevel.
	var key: String = _key(["plate-1",polygon,thickness,bevel])
	if not meshes.has(key):
		var p: PackedVector2Array = polygon.duplicate()
		if Geometry2D.is_polygon_clockwise(p): p.reverse()
		var inset: Array[PackedVector2Array] = Geometry2D.offset_polygon(p,-bevel,Geometry2D.JOIN_MITER)
		assert(not inset.is_empty() and inset[0].size()==p.size())
		var inner := PackedVector2Array()
		for point: Vector2 in p:
			var closest: Vector2 = inset[0][0]
			for candidate: Vector2 in inset[0]:
				if candidate.distance_squared_to(point)<closest.distance_squared_to(point): closest=candidate
			inner.append(closest)
		var rings: Array[PackedVector2Array] = [inner,p,p,inner]
		var heights: Array[float] = [-thickness*0.5,-thickness*0.5+bevel,thickness*0.5-bevel,thickness*0.5]
		var tool := _tool()
		for ring: int in range(3):
			for i: int in range(p.size()):
				var j: int = (i+1)%p.size()
				var points: Array[Vector3] = [Vector3(rings[ring][i].x,heights[ring],rings[ring][i].y),Vector3(rings[ring][j].x,heights[ring],rings[ring][j].y),Vector3(rings[ring+1][j].x,heights[ring+1],rings[ring+1][j].y),Vector3(rings[ring+1][i].x,heights[ring+1],rings[ring+1][i].y)]
				var edge: Vector2 = p[j]-p[i]
				var hint := Vector3(edge.y,0,-edge.x).normalized()
				var normal: Vector3 = (points[1]-points[0]).cross(points[3]-points[0]).normalized()
				if normal.dot(hint)<0: normal=-normal
				_quad(tool,points,[normal,normal,normal,normal])
		var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(inner)
		for side: float in [-1.0,1.0]:
			for i: int in range(0,triangles.size(),3):
				var points: Array[Vector3] = []
				for j: int in range(3):
					var q: Vector2 = inner[triangles[i+j]]
					points.append(Vector3(q.x,side*thickness*0.5,q.y))
				_triangle(tool,points,[Vector3.UP*side,Vector3.UP*side,Vector3.UP*side])
		tool.index()
		meshes[key] = tool.commit()
	return _node(parent,label,meshes[key],material)

static func lathe(parent: Node3D, label: String, profile: PackedVector2Array, material: Material, simple: bool) -> MeshInstance3D:
	var key: String = _key(["lathe-1",profile,simple])
	if not meshes.has(key):
		var p: PackedVector2Array = profile.duplicate()
		if Geometry2D.is_polygon_clockwise(p): p.reverse()
		var tool := _tool()
		var largest: float=0.0
		for point: Vector2 in p: largest=maxf(largest,point.x)
		var steps: int = (16 if simple else 32) if largest<=0.08 else (32 if simple else 64)
		for i: int in range(p.size()):
			var q: Vector2 = p[(i+1)%p.size()]
			var d: Vector2 = q-p[i]
			for step: int in range(steps):
				var a: float = step*TAU/steps
				var b: float = (step+1)*TAU/steps
				var na := Vector3(cos(a)*d.y,-d.x,sin(a)*d.y).normalized()
				var nb := Vector3(cos(b)*d.y,-d.x,sin(b)*d.y).normalized()
				_quad(tool,[Vector3(cos(a)*p[i].x,p[i].y,sin(a)*p[i].x),Vector3(cos(b)*p[i].x,p[i].y,sin(b)*p[i].x),Vector3(cos(b)*q.x,q.y,sin(b)*q.x),Vector3(cos(a)*q.x,q.y,sin(a)*q.x)],[na,nb,nb,na])
		tool.index()
		meshes[key] = tool.commit()
	return _node(parent,label,meshes[key],material)

static func tube(parent: Node3D, label: String, path: Array[Vector3], size: Vector2, radius: float, material: Material, simple: bool) -> MeshInstance3D:
	var key: String = _key(["tube-1",path,size,radius,simple])
	if not meshes.has(key):
		var section := PackedVector2Array()
		var h: Vector2 = size*0.5
		var r: float = minf(radius,minf(h.x,h.y))
		var steps: int = 2 if simple else 4
		for corner: int in range(4):
			var angle: float = corner*PI*0.5
			var center := Vector2((h.x-r)*(1.0 if corner in [0,3] else -1.0),(h.y-r)*(1.0 if corner in [0,1] else -1.0))
			for step: int in range(steps+1):
				var a: float = angle+step*PI*0.5/steps
				section.append(center+Vector2(cos(a),sin(a))*r)
		var rings: Array[Array] = []
		var normals: Array[Array] = []
		var tangents: Array[Vector3] = []
		var axis: Vector3 = Vector3.RIGHT if absf((path[-1]-path[0]).normalized().dot(Vector3.RIGHT))<0.85 else Vector3.FORWARD
		for i: int in range(path.size()):
			var tangent: Vector3 = (path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]).normalized()
			var u: Vector3 = axis.slide(tangent).normalized()
			if u.length_squared()<0.5: u=Vector3.FORWARD.slide(tangent).normalized()
			var v: Vector3 = tangent.cross(u).normalized()
			var ring: Array[Vector3] = []
			var ns: Array[Vector3] = []
			for point: Vector2 in section:
				var clipped: Vector2 = point.clamp(-h+Vector2.ONE*r,h-Vector2.ONE*r)
				var n: Vector2 = (point-clipped).normalized()
				ring.append(path[i]+u*point.x+v*point.y)
				ns.append(u*n.x+v*n.y)
			rings.append(ring); normals.append(ns); tangents.append(tangent)
		var tool := _tool()
		for i: int in range(path.size()-1):
			for j: int in range(section.size()):
				var k: int = (j+1)%section.size()
				_quad(tool,[rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j]],[normals[i][j],normals[i][k],normals[i+1][k],normals[i+1][j]])
		for end: int in [0,path.size()-1]:
			var normal: Vector3 = tangents[end]*(-1 if end==0 else 1)
			for j: int in range(section.size()):
				_triangle(tool,[path[end],rings[end][j],rings[end][(j+1)%section.size()]],[normal,normal,normal])
		tool.index()
		meshes[key] = tool.commit()
	return _node(parent,label,meshes[key],material)

static func _edge_splits(a: Vector2, b: Vector2, xs: Array[float], zs: Array[float]) -> Array[Vector2]:
	var times: Array[float] = [0.0,1.0]
	if absf(b.x-a.x)>1e-7:
		for x: float in xs:
			var t: float = (x-a.x)/(b.x-a.x)
			if t>0.000001 and t<0.999999 and t not in times: times.append(t)
	if absf(b.y-a.y)>1e-7:
		for z: float in zs:
			var t: float = (z-a.y)/(b.y-a.y)
			if t>0.000001 and t<0.999999 and t not in times: times.append(t)
	times.sort()
	var result: Array[Vector2] = []
	for t: float in times: result.append(a.lerp(b,t).snapped(Vector2.ONE*0.0001))
	return result

static func _lid_height(q: Vector2, bounds: Rect2, base: float, crown: float) -> float:
	var p: Vector2 = (q-bounds.get_center())/(bounds.size*0.5)
	return base+crown*maxf(0.0,1-p.x*p.x)*maxf(0.0,1-p.y*p.y)

static func deck(parent: Node3D, label: String, bounds: Rect2, base: float, crown: float, pockets: Array[Rect2], paint: Material, recess: Material, simple: bool) -> MeshInstance3D:
	var key: String = _key(["deck-1",bounds,base,crown,pockets,simple])
	if not meshes.has(key):
		var perimeter: PackedVector2Array = outline(bounds.size,0.035,bounds.get_center())
		var xs: Array[float] = []; var zs: Array[float] = []
		var columns: int = 8 if simple else 14
		var rows: int = 6 if simple else 10
		# Match clipped faces and boundary walls on one 0.1 mm construction
		# grid so independently evaluated samples cannot leave hairline seams.
		for i: int in range(columns+1): xs.append(snappedf(lerpf(bounds.position.x,bounds.end.x,i/float(columns)),0.0001))
		for i: int in range(rows+1): zs.append(snappedf(lerpf(bounds.position.y,bounds.end.y,i/float(rows)),0.0001))
		for hole: Rect2 in pockets:
			for x: float in [hole.position.x,hole.end.x]:
				if x not in xs: xs.append(x)
			for z: float in [hole.position.y,hole.end.y]:
				if z not in zs: zs.append(z)
		xs.sort(); zs.sort()
		var shell := _tool(); var floors := _tool()
		var bottom: float = base-0.038
		var floor_y: float = base-0.014
		for x: int in range(xs.size()-1):
			for z: int in range(zs.size()-1):
				var cell := PackedVector2Array([Vector2(xs[x],zs[z]),Vector2(xs[x+1],zs[z]),Vector2(xs[x+1],zs[z+1]),Vector2(xs[x],zs[z+1])])
				var pieces: Array[PackedVector2Array] = Geometry2D.intersect_polygons(cell,perimeter)
				var in_pocket: bool = false
				for hole: Rect2 in pockets:
					if hole.has_point((cell[0]+cell[2])*0.5): in_pocket=true
				for piece: PackedVector2Array in pieces:
					var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(piece)
					for i: int in range(0,triangles.size(),3):
						var top_points: Array[Vector3] = []; var bottom_points: Array[Vector3] = []
						var top_normals: Array[Vector3] = []
						for j: int in range(3):
							var q: Vector2 = piece[triangles[i+j]].snapped(Vector2.ONE*0.0001)
							top_points.append(Vector3(q.x,floor_y if in_pocket else _lid_height(q,bounds,base,crown),q.y))
							bottom_points.append(Vector3(q.x,bottom,q.y))
							var dx: float = (_lid_height(q+Vector2(0.0001,0),bounds,base,crown)-_lid_height(q-Vector2(0.0001,0),bounds,base,crown))/0.0002
							var dz: float = (_lid_height(q+Vector2(0,0.0001),bounds,base,crown)-_lid_height(q-Vector2(0,0.0001),bounds,base,crown))/0.0002
							top_normals.append(Vector3.UP if in_pocket else Vector3(-dx,1,-dz).normalized())
						_triangle(floors if in_pocket else shell,top_points,top_normals)
						_triangle(shell,bottom_points,[Vector3.DOWN,Vector3.DOWN,Vector3.DOWN])
		var boundaries: Array[PackedVector2Array] = [perimeter]
		for hole: Rect2 in pockets: boundaries.append(PackedVector2Array([hole.position,Vector2(hole.end.x,hole.position.y),hole.end,Vector2(hole.position.x,hole.end.y)]))
		for boundary: int in range(boundaries.size()):
			var p: PackedVector2Array = boundaries[boundary]
			for i: int in range(p.size()):
				var a: Vector2 = p[i]; var b: Vector2 = p[(i+1)%p.size()]
				var splits: Array[Vector2] = _edge_splits(a,b,xs,zs)
				var direction: Vector2 = (b-a).normalized()
				var n: Vector3 = Vector3(direction.y,0,-direction.x)*(1 if boundary==0 else -1)
				for j: int in range(splits.size()-1):
					var q: Vector2 = splits[j]; var r: Vector2 = splits[j+1]
					_quad(shell,[Vector3(q.x,_lid_height(q,bounds,base,crown),q.y),Vector3(r.x,_lid_height(r,bounds,base,crown),r.y),Vector3(r.x,bottom if boundary==0 else floor_y,r.y),Vector3(q.x,bottom if boundary==0 else floor_y,q.y)],[n,n,n,n])
		shell.index(); floors.index()
		var mesh: ArrayMesh = shell.commit()
		if not pockets.is_empty(): floors.commit(mesh)
		meshes[key] = mesh
	var result: MeshInstance3D = _node(parent,label,meshes[key],null)
	result.set_surface_override_material(0,paint)
	if result.mesh.get_surface_count()>1: result.set_surface_override_material(1,recess)
	return result

static func wheel_face(parent: Node3D, radius: float, count: int, span: float, slot_radius: Vector2, dish: float, material: Material, simple: bool) -> MeshInstance3D:
	var key: String = _key(["wheel-face-1",radius,count,span,slot_radius,dish,simple])
	if not meshes.has(key):
		var tool := _tool()
		# Spend angular detail on the openings. The rolled flange supplies the
		# outer silhouette; large uncut sectors do not need matching subdivisions.
		var samples: Array[Vector2]=[]
		if count==0:
			var steps: int=24 if simple else 48
			for i: int in range(steps): samples.append(Vector2(i*TAU/steps,0))
		else:
			var divisions: int=4 if simple else 8
			for period: int in range(count):
				var center: float=period*TAU/count
				var half: float=PI/count*span
				samples.append(Vector2(center-PI/count,0))
				for i: int in range(divisions+1):
					var factor: float=0.0 if i in [0,divisions] else sin(PI*i/divisions)
					samples.append(Vector2(center-half*cos(PI*i/divisions),factor))
		samples.append(samples[0])
		var back: float = -0.012
		var outer: float = Vector2(radius*0.60,0).x
		var rings: Array[Array] = []
		for sample: Vector2 in samples:
			var angle: float=sample.x
			# Exact zero-width tips avoid numerically tiny slivers at each opening.
			var gap: float=sample.y*slot_radius.y*radius
			var low: float = slot_radius.x*radius-gap
			var high: float = slot_radius.x*radius+gap
			var radii := Vector2(low,high)
			var bevel: float=minf(0.002,gap*0.20) if count in [3,4,5,6] else 0.0
			var inner:=Vector2(radii.x+bevel,radii.y-bevel)
			rings.append([angle,radii.x,radii.y,inner.x,inner.y,bevel])
		for i: int in range(rings.size()-1):
			var a: float = rings[i][0]; var b: float = rings[i+1][0]
			var low_a: float = rings[i][1]; var low_b: float = rings[i+1][1]
			var high_a: float = rings[i][2]; var high_b: float = rings[i+1][2]
			var inner_low_a: float=rings[i][3]; var inner_low_b: float=rings[i+1][3]
			var inner_high_a: float=rings[i][4]; var inner_high_b: float=rings[i+1][4]
			for band: int in range(2):
				var ra0: float = 0.0 if band==0 else high_a
				var rb0: float = 0.0 if band==0 else high_b
				var ra1: float = low_a if band==0 else outer
				var rb1: float = low_b if band==0 else outer
				var front: Array[Vector3] = []; var ns: Array[Vector3] = []
				var points: Array[Vector2] = [Vector2(ra0,a),Vector2(rb0,b),Vector2(rb1,b),Vector2(ra1,a)]
				var back_points: Array[Vector2]=[Vector2(0 if band==0 else inner_high_a,a),Vector2(0 if band==0 else inner_high_b,b),Vector2(inner_low_b if band==0 else outer,b),Vector2(inner_low_a if band==0 else outer,a)]
				var rear: Array[Vector3] = []
				for corner: int in range(4):
					var p: Vector2=points[corner]
					var y: float = 0.014+dish*(1-p.x/outer)
					front.append(Vector3(cos(p.y)*p.x,y,sin(p.y)*p.x))
					ns.append(Vector3(cos(p.y)*dish/outer,1,sin(p.y)*dish/outer).normalized())
					var bp: Vector2=back_points[corner]
					rear.append(Vector3(cos(bp.y)*bp.x,back,sin(bp.y)*bp.x))
				_quad(tool,front,ns)
				_quad(tool,rear,[Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN])
			for boundary: int in range(3):
				if boundary<2 and is_equal_approx(low_a,high_a) and is_equal_approx(low_b,high_b): continue
				var ra: float = low_a if boundary==0 else high_a if boundary==1 else outer
				var rb: float = low_b if boundary==0 else high_b if boundary==1 else outer
				var ia: float=inner_low_a if boundary==0 else inner_high_a if boundary==1 else outer
				var ib: float=inner_low_b if boundary==0 else inner_high_b if boundary==1 else outer
				var depth_a: float=rings[i][5] if boundary<2 else 0.0
				var depth_b: float=rings[i+1][5] if boundary<2 else 0.0
				var n: Vector3 = Vector3(cos(a)+cos(b),0,sin(a)+sin(b)).normalized()*(-1 if boundary==0 else 1)
				var p: Array[Vector3] = [Vector3(cos(a)*ia,back,sin(a)*ia),Vector3(cos(b)*ib,back,sin(b)*ib),Vector3(cos(b)*ib,0.014+dish*(1-ib/outer)-depth_b,sin(b)*ib),Vector3(cos(a)*ia,0.014+dish*(1-ia/outer)-depth_a,sin(a)*ia)]
				if boundary<2:
					var tangent: Vector3 = p[1]-p[0]
					n = Vector3(tangent.z,0,-tangent.x).normalized()*(1 if boundary==0 else -1)
				_quad(tool,p,[n,n,n,n])
				if boundary<2 and (depth_a>0 or depth_b>0):
					var lip: Array[Vector3]=[Vector3(cos(a)*ra,0.014+dish*(1-ra/outer),sin(a)*ra),Vector3(cos(b)*rb,0.014+dish*(1-rb/outer),sin(b)*rb),p[2],p[3]]
					var normal: Vector3=(lip[1]-lip[0]).cross(lip[2]-lip[0])
					if normal.length_squared()<1e-18: normal=(lip[2]-lip[0]).cross(lip[3]-lip[0])
					normal=normal.normalized()
					if normal.dot(n)<0: normal=-normal
					_quad(tool,lip,[normal,normal,normal,normal])
		tool.index()
		meshes[key] = tool.commit()
	return _node(parent,"PressedWheelFace",meshes[key],material)
