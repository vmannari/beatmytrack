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
		# Separate moulded modules, with seated fixings and narrow grip flutes.
		for stripe: int in range(1,stripes):
			var z: float = lerpf(-half.y,half.y,float(stripe)/stripes)
			for row: int in range(24):
				var x0: float = lerpf(-half.x,half.x,float(row)/24.0)
				var x1: float = lerpf(-half.x,half.x,float(row+1)/24.0)
				var y0: float = 0.046+SpeedBumps.HEIGHT*scale_value*pow(cos(x0/half.x*PI*0.5),2.0)
				var y1: float = 0.046+SpeedBumps.HEIGHT*scale_value*pow(cos(x1/half.x*PI*0.5),2.0)
				CreatorBridgeVisual.quad(tool,Vector3(x0,y0,z-0.005*scale_value),Vector3(x1,y1,z-0.005*scale_value),Vector3(x1,y1,z+0.005*scale_value),Vector3(x0,y0,z+0.005*scale_value),Color("171f21"))
		for stripe: int in range(stripes):
			var z: float = lerpf(-half.y,half.y,(float(stripe)+0.5)/stripes)
			for side: float in [-1.0,1.0]:
				var x: float = half.x*0.70*side
				var y: float = 0.047+SpeedBumps.HEIGHT*scale_value*pow(cos(x/half.x*PI*0.5),2.0)
				PropGeometry.tube(tool,Vector3(x,y,z),Vector3(x,y+0.004*scale_value,z),0.040*scale_value,0.027*scale_value,Color("868a76"),8)
		for row: int in [5,9,15,19]:
			var x: float = lerpf(-half.x,half.x,float(row)/24.0)
			var y: float = 0.047+SpeedBumps.HEIGHT*scale_value*pow(cos(x/half.x*PI*0.5),2.0)
			CreatorBridgeVisual.quad(tool,Vector3(x-0.007*scale_value,y,-half.y),Vector3(x+0.007*scale_value,y,-half.y),Vector3(x+0.007*scale_value,y,half.y),Vector3(x-0.007*scale_value,y,half.y),Color("69633e"))
	elif object.kind == "jump":
		preload("res://track/jump_visual.gd").build(tool,object)
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
		# Broken broad sheen follows the liquid surface; no emissive rainbow.
		for arc: int in range(3):
			for i: int in range(12):
				var a: float = -0.62+float(i)*0.07+arc*1.6
				var b: float = a+0.066
				var radius: float = 0.45+arc*0.14
				var width: float = 0.015 if object.kind == "oil" else 0.028
				CreatorBridgeVisual.quad(tool,Vector3(cos(a)*half.x*radius,0.052,sin(a)*half.y*radius),Vector3(cos(b)*half.x*radius,0.052,sin(b)*half.y*radius),Vector3(cos(b)*half.x*(radius+width),0.052,sin(b)*half.y*(radius+width)),Vector3(cos(a)*half.x*(radius+width),0.052,sin(a)*half.y*(radius+width)),Color("354549") if object.kind == "oil" else Color("70948d"))
	tool.generate_normals()
	tool.index()
	var mesh := MeshInstance3D.new()
	mesh.add_to_group("race_hazard_rendering")
	mesh.name = "SpeedBump" if object.kind == "speed_bump" else "Hazard"
	mesh.mesh = tool.commit()
	mesh.position = Vector3(object.position[0],0,-object.position[1])
	mesh.rotation.y = deg_to_rad(float(object.rotation))
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/hazard.gdshader")
	material.set_shader_parameter("water",object.kind == "puddle")
	if object.kind == "jump" and JumpProfiles.rounded(JumpProfiles.id(object)):
		var sand: bool = JumpProfiles.id(object) == "dune_v1"
		material.shader = preload("res://track/jump_earth.gdshader")
		material.set_shader_parameter("sand_profile",sand)
		material.set_shader_parameter("earth_color",TrackTheme.DESERT[0] if sand else Color("89734f"))
		material.set_shader_parameter("desert_road_albedo",preload("res://track/track_visual_assets.gd").DESERT_ROAD_ALBEDO)
		material.set_shader_parameter("desert_road_reference",preload("res://track/track_visual_assets.gd").desert_road_reference)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
