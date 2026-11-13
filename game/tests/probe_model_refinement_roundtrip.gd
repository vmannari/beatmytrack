extends SceneTree
const Base = preload("res://vehicle/modular_car_base.gd")
const Buffers = preload("res://tests/support/car_model_buffers.gd")
func _initialize() -> void: run.call_deferred()
func stats(node: Node,label: String) -> void:
	var triangles: int = 0
	var rows: Array = []
	for part: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null: continue
		var count: int = part.mesh.get_faces().size()/3
		if part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: triangles += count
		rows.append({"part":str(node.get_path_to(part)),"triangles":count,"path":part.mesh.resource_path,"scene_id":part.mesh.resource_scene_unique_id})
	print("ROUNDTRIP ",label," triangles=",triangles," ",JSON.stringify(rows))
func disk(path: String,label: String) -> void:
	var scene: PackedScene = ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var node: Node = scene.instantiate()
	stats(node,label)
	node.free()
func run() -> void:
	Base.enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var car := CarVisual.new()
	car.vehicle_id = "forklift"
	car.simple_model = true
	root.add_child(car)
	while not car.model_ready: await process_frame
	stats(car,"source")
	var path: String = Base.path_for(car)
	Base.enabled = true
	assert(Base.bake(car)==OK)
	Base.enabled = false
	disk(path,"base")
	assert(preload("res://vehicle/car_mesh_lods.gd").new().bake(path,"forklift",0.5)==OK)
	disk(path,"lod")
	assert(Buffers.bake(path,"forklift")==OK)
	disk(path,"packed")
	car.free()
	quit()
