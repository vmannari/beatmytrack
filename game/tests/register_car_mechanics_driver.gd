extends SceneTree
const D=preload("res://vehicle/car_detail_reduction.gd")
const S=preload("res://vehicle/car_surface_reduction.gd")
const OUT: String="res://../docs/evidence/car-mechanics-2026-11-17"
var targets: Dictionary={};var raw: Dictionary={};var post: Dictionary={}
func contour(label: String) -> bool:return label=="TomkartDriver"
func key(group: Dictionary, surface: bool) -> String:
	var codes: Array=[];var names: Array=[]
	for entry: Dictionary in group.entries:
		var label: String=str(entry.part.name)
		if targets.has(label):names.append(label)
		if contour(label) or (surface and targets.has(label)):continue
		codes.append(entry.code)
	codes.sort();names.sort();return var_to_bytes([names,codes]).hex_encode().sha256_text()
func detail(group: Dictionary) -> void:
	raw[key(group,false)]={"context":group.code,"recipe":D.recipe("kart",group.code).duplicate(true)}
	D.apply_group(group)
func surface(group: Dictionary) -> void:
	var path: String=S.ROOT.path_join("kart_"+group.code+".json")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"schema":S.SCHEMA,"context":group.code,"parts":{}}
	var removed: Array=[]
	for entry: Dictionary in group.entries:
		if targets.has(str(entry.part.name)) and data.parts.has(entry.code):data.parts.erase(entry.code);removed.append(entry.code)
	post[key(group,true)]={"context":group.code,"recipe":data,"removed_paint_rows":removed}
	S.apply_group(group,D)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	targets["TomkartDriver"]=true
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	D.offline=detail;S.offline=surface
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="kart";car.editable_kits=editable;car.cache_rest_pose=false;root.add_child(car)
		while not car.model_ready:await process_frame
		car.free();await process_frame
	FileAccess.open(OUT.path_join("driver-frame-registry.json"),FileAccess.WRITE).store_string(JSON.stringify({"raw":raw,"post":post},"  "))
	print("VSR_FRAME_REGISTRY ",raw.size()," raw / ",post.size()," post frames");quit()
