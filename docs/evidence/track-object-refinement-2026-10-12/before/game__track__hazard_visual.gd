class_name HazardVisual
extends RefCounted
## Original low-poly ramp and painted hazard meshes, in world metres.
static func build(parent: Node3D, object: Dictionary) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector2 = CreatorObjects.size_of(object)*0.5
	var scale_value: float = float(object.get("scale",1.0))
	if object.kind == "speed_bump":
		var stripes: int = maxi(1,ceili(half.y*2.0/(2.0/3.0*scale_value)))
		# Smooth low rubber crown. Alternating yellow modules read in wet/night
		# lighting without adding emissive effects or changing the road material.
		for row: int in range(24):
			var x0: float = lerpf(-half.x,half.x,float(row)/24.0)
			var x1: float = lerpf(-half.x,half.x,float(row+1)/24.0)
			var y0: float = 0.045+SpeedBumps.HEIGHT*scale_value*pow(cos(x0/half.x*PI*0.5),2.0)
			var y1: float = 0.045+SpeedBumps.HEIGHT*scale_value*pow(cos(x1/half.x*PI*0.5),2.0)
			for stripe: int in range(stripes):
				var z0: float = lerpf(-half.y,half.y,float(stripe)/stripes)
				var z1: float = lerpf(-half.y,half.y,float(stripe+1)/stripes)
				CreatorBridgeVisual.quad(tool,Vector3(x0,y0,z0),Vector3(x1,y1,z0),Vector3(x1,y1,z1),Vector3(x0,y0,z1),Color("d5ad38") if stripe%2 == 0 else Color("272b2d"))
			for side: float in [-1.0,1.0]:
				CreatorBridgeVisual.quad(tool,Vector3(x0,0.04,half.y*side),Vector3(x1,0.04,half.y*side),Vector3(x1,y1,half.y*side),Vector3(x0,y0,half.y*side),Color("272b2d"))
	elif object.kind == "jump":
		var a := Vector3(-half.x,0.04,-half.y)
		var b := Vector3(half.x,scale_value+0.04,-half.y)
		var c := Vector3(half.x,scale_value+0.04,half.y)
		var d := Vector3(-half.x,0.04,half.y)
		CreatorBridgeVisual.quad(tool,a,b,c,d,Color("777465"))
		CreatorBridgeVisual.quad(tool,a,Vector3(half.x,0.04,-half.y),b,a,Color("504f45"))
		CreatorBridgeVisual.quad(tool,d,c,Vector3(half.x,0.04,half.y),d,Color("504f45"))
		CreatorBridgeVisual.quad(tool,b,Vector3(half.x,0.04,-half.y),Vector3(half.x,0.04,half.y),c,Color("58594f"))
		# Broad ivory chevron points toward the raised takeoff lip.
		for side: float in [-1.0,1.0]:
			var points: Array[Vector2] = [Vector2(-0.8,side*1.5),Vector2(-0.45,side*1.65),Vector2(1.1,0),Vector2(0.6,0)]
			var v: Array[Vector3] = []
			for p: Vector2 in points:
				p *= scale_value
				v.append(Vector3(p.x,(p.x/(half.x*2)+0.5)*scale_value+0.06,p.y))
			CreatorBridgeVisual.quad(tool,v[0],v[1],v[2],v[3],Color("ded9bb"))
	else:
		var color := Color("1c252b") if object.kind == "oil" else Color("476a70")
		for i: int in range(48):
			var a: float = TAU*i/48.0
			var b: float = TAU*(i+1)/48.0
			var p := Vector3(cos(a)*half.x,0.05,sin(a)*half.y)
			p.x *= CreatorObjects.spill_radius(a); p.z *= CreatorObjects.spill_radius(a)
			var q := Vector3(cos(b)*half.x,0.05,sin(b)*half.y)
			q.x *= CreatorObjects.spill_radius(b); q.z *= CreatorObjects.spill_radius(b)
			tool.set_color(color)
			for v: Vector3 in [Vector3(0,0.05,0),q,p]: tool.add_vertex(v)
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "SpeedBump" if object.kind == "speed_bump" else "Hazard"
	mesh.mesh = tool.commit()
	mesh.position = Vector3(object.position[0],0,-object.position[1])
	mesh.rotation.y = deg_to_rad(float(object.rotation))
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/hazard.gdshader")
	material.set_shader_parameter("water",object.kind == "puddle")
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
