extends SceneTree

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+message)

func _initialize() -> void:
	run.call_deferred()

func geometry_key(node: Node) -> String:
	var data: Array = []
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		data.append(mesh.mesh.get_faces())
	return var_to_bytes(data).hex_encode().sha256_text()

func run() -> void:
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "hovercraft"
		car.simple_model = simple
		car.editable_kits = true
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var fan: Node = car.body.get_node("FanRotor")
		for category: String in VehicleCustomisation.CATEGORIES:
			var seen: Array[String] = []
			var housings_seen: Array[String] = []
			check(VehicleCustomisation.options(category,"hovercraft").size() >= 11,"ten alternatives in "+category)
			for choice: Array in VehicleCustomisation.options(category,"hovercraft"):
				var value: Dictionary = VehicleCustomisation.defaults()
				value[category] = choice[0]
				check(VehicleCustomisation.valid(value,"hovercraft"),"valid "+category+"/"+str(choice[0]))
				car.graphics.restore_originals()
				car.change_kit_parts(value)
				var frame: Node = car.kit_frames[category][0]
				if category != "rims": check((frame.get_child_count() == 0) == (choice[0] == "stock"),"visible fitting "+category+"/"+str(choice[0]))
				fan = car.body.get_node("FanRotor")
				check(fan.has_node("FanRotorLeft") and fan.has_node("FanRotorRight"),"retains animated fans")
				var signature: String = geometry_key(fan if category == "rims" else frame)
				check(signature not in seen,"distinct geometry "+category+"/"+str(choice[0]))
				seen.append(signature)
				if category == "body" and choice[0] != "stock":
					var projection: float = 0.0
					var finite: bool = true
					for mesh: MeshInstance3D in frame.find_children("HoverSponson*","MeshInstance3D",true,false):
						for vertex: Vector3 in mesh.mesh.get_faces():
							finite = finite and vertex.is_finite()
							projection = maxf(projection,absf(vertex.x)-preload("res://vehicle/hovercraft_sport_hull.gd").half_width(vertex.z,0.97))
					check(finite and projection >= 0.14,"sponson visibly projects beyond hull "+str(choice[0]))
				if category == "rims":
					var housing_key: String = geometry_key(frame)
					check(housing_key not in housings_seen,"distinct complete housing "+str(choice[0]))
					housings_seen.append(housing_key)
					var left: Node3D = fan.get_node("FanRotorLeft")
					var maximum: float = 0.0
					for blade: MeshInstance3D in left.find_children("SportBlade*","MeshInstance3D",true,false):
						for vertex: Vector3 in blade.mesh.get_faces(): maximum = maxf(maximum,Vector2(vertex.x,vertex.y).length())
					check(maximum < 0.291,"blades clear the duct "+str(choice[0]))
			car.graphics.restore_originals()
			car.change_kit_parts(VehicleCustomisation.defaults())
		var fitted: Dictionary = VehicleCustomisation.defaults()
		fitted.rims = "hover_turbine"
		fitted.body = "hover_enduro"
		car.graphics.restore_originals()
		car.change_kit_parts(fitted)
		var fresh := CarVisual.new()
		fresh.vehicle_id = "hovercraft"
		fresh.simple_model = simple
		fresh.batch_parts = false
		fresh.customisation = fitted.duplicate(true)
		root.add_child(fresh)
		while not fresh.model_ready: await process_frame
		check(geometry_key(car.body.get_node("FanRotor")) == geometry_key(fresh.body.get_node("FanRotor")),"fresh race and editable fan rotors match")
		var edited_meshes: Array = car.kit_frames.rims[0].find_children("HoverHousing*","MeshInstance3D",true,false)
		var fresh_meshes: Array = fresh.body.find_children("HoverHousing*","MeshInstance3D",true,false)
		check(edited_meshes.size() == fresh_meshes.size() and edited_meshes.size() > 0,"fresh race and editable housings match")
		if edited_meshes.size() == fresh_meshes.size():
			for index: int in range(edited_meshes.size()):
				check(edited_meshes[index].mesh == fresh_meshes[index].mesh,"fresh race reuses identical housing mesh")
		var edited_sides: Array = car.kit_frames.body[0].find_children("HoverSponson*","MeshInstance3D",true,false)
		var fresh_sides: Array = fresh.body.find_children("HoverSponson*","MeshInstance3D",true,false)
		check(edited_sides.size() == fresh_sides.size() and edited_sides.size() > 0,"fresh race and editable sponsons match")
		if edited_sides.size() == fresh_sides.size():
			for index: int in range(edited_sides.size()):
				check(edited_sides[index].mesh == fresh_sides[index].mesh,"fresh race reuses identical sponson mesh")
		fresh.queue_free()
		car.queue_free()
		await process_frame
	print("HOVERCRAFT_KITS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
