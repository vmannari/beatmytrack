extends "res://tests/test_volt_body_construction.gd"
## Factory door and wheel-opening boundaries, checked on actual kit buffers.

func run() -> void:
	var control: bool="--fit-control" in OS.get_cmdline_user_args()
	var builder: Script=load("res://../docs/evidence/volt-door-fender-fit-2026-11-03/before/game/vehicle/electric_body_kits.gd") if control else preload("res://vehicle/electric_body_kits.gd")
	preload("res://vehicle/electric_reference_mesh.gd").use_baked=false
	var selected:=PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fit-options="): selected=argument.trim_prefix("--fit-options=").split(",")
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.paint_materials={"body":CompactFinish.paint(Color("b8bbb9")),"accent":CompactFinish.paint(Color("647779"))}
		var i:=0
		for option: Array in VehicleCustomisation.options("body","electric").slice(1):
			i+=1
			if not selected.is_empty() and str(option[0]) not in selected: continue
			var frame:=Node3D.new()
			builder.build(car,frame,str(option[0]),i)
			var label: String=str(option[0])+" simple="+str(simple)
			for node: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
				var name_value: String=str(node.name)
				var sill: bool=name_value.contains("Sill") and not name_value.contains("Inlay")
				var corner: bool=name_value.contains("Corner") and not name_value.contains("Blade")
				var a: Array=node.mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
				var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
				if sill:
					var maximum: float=-INF
					for point: Vector3 in vertices: maximum=maxf(maximum,point.y)
					check(maximum<=0.300,label+" entire skirt stays below factory door bottom "+name_value+" y="+str(maximum))
				if not name_value.ends_with("Face") or (not sill and not corner): continue
				var worst:=0.0
				var worst_pair: Array=[]
				var ends:=0
				for index: int in range(vertices.size()):
					if (sill and uv[index].x!=0.0 and uv[index].x!=1.0) or (corner and uv[index].x!=1.0): continue
					var p: Vector3=vertices[index]
					var axle: float=-B.AXLE if p.z<0.0 else B.AXLE
					var direction: float=-signf(axle) if sill else signf(axle)
					var angle: float=asin(clampf((p.y-0.24)/0.545,0.0,1.0))
					var expected: Vector3=B.fender_point(signf(p.x),axle,angle/PI if direction>0 else 1.0-angle/PI,1.0)
					if p.distance_to(expected)>worst:
						worst=p.distance_to(expected)
						worst_pair=[p,expected,uv[index]]
					ends+=1
				check(ends>0 and worst<=0.0011,label+" fits actual fender edge "+name_value+" gap="+str(worst))
				if worst>0.0011: print("FIT_DETAIL ",worst_pair)
			frame.free()
		car.free()
	print("VOLT_DOOR_FENDER_FIT: ",checks," checks, ",failures," failures; control=",control)
	quit(1 if failures else 0)
