extends RefCounted
## Connected contour strips replace the hidden faces of Rally seam boxes.
const TAG: String = "compact_seam_segments"

static func add(parent: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var segments: Array = parent.get_meta(TAG,[])
	segments.append([a,b,width,material])
	parent.set_meta(TAG,segments)

static func finish(car: CarVisual) -> void:
	if car.vehicle_id!="compact" or not car.simple_model: return
	for group: Node3D in car.find_children("*","Node3D",true,false):
		if not group.has_meta(TAG): continue
		var segments: Array = group.get_meta(TAG)
		group.remove_meta(TAG)
		var outward: Vector3 = Vector3.BACK if str(group.name)=="TailgatePanelSeam" else Vector3.LEFT if str(group.name)=="DoorSeamsLeft" else Vector3.RIGHT
		var chains: Array = []
		for segment: Array in segments:
			if chains.is_empty() or (chains[-1].points[-1] as Vector3).distance_squared_to(segment[0])>1e-12 or chains[-1].width!=segment[2]:
				chains.append({"points":[segment[0]],"width":segment[2],"material":segment[3]})
			chains[-1].points.append(segment[1])
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for chain: Dictionary in chains:
			var points: Array = chain.points
			var rows: Array = []
			var closed: bool = (points[0] as Vector3).distance_squared_to(points[-1])<1e-12
			for index: int in range(points.size()):
				var before: Vector3 = points[index-1] if index>0 else points[-2] if closed else points[0]
				var after: Vector3 = points[index+1] if index+1<points.size() else points[1] if closed else points[-1]
				var tangent: Vector3 = (after-before).normalized()
				var across: Vector3 = tangent.cross(outward).normalized()*float(chain.width)*0.5
				var center: Vector3 = points[index]+outward*float(chain.width)*0.5
				rows.append([center-across,center+across])
			for index: int in range(rows.size()-1):
				var corners: Array = [rows[index][0],rows[index][1],rows[index+1][1],rows[index+1][0]]
				for triangle: Array in [[0,1,2],[0,2,3]]:
					var cross: Vector3 = (corners[triangle[1]]-corners[triangle[0]]).cross(corners[triangle[2]]-corners[triangle[0]])
					if cross.length_squared()<1e-20: continue
					if cross.dot(outward)>0: triangle.reverse()
					for vertex: int in triangle:
						tool.set_normal(outward)
						tool.set_uv(Vector2.ZERO)
						tool.add_vertex(corners[vertex])
		tool.index()
		var part := MeshInstance3D.new()
		part.name = "ContinuousContour"
		part.mesh = tool.commit()
		part.material_override = segments[0][3]
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(part)
