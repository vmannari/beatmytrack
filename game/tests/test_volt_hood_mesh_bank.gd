extends SceneTree
## Exact prebuilt fallback arrays and independent body-paint bindings.
const K=preload("res://vehicle/electric_kits.gd")
const M=preload("res://vehicle/electric_reference_mesh.gd")
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)

func arrays_hash(mesh: ArrayMesh) -> String:
	return var_to_bytes(mesh.surface_get_arrays(0)).hex_encode().sha256_text()

func run() -> void:
	var legacy: Script=load("res://../docs/evidence/volt-hood-loading-2026-11-03/before/game/vehicle/electric_kits.gd")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(K.HOOD_MESH_ROOT.path_join("manifest.json")))
	check(K.hood_mesh_bank_valid(),"hood-specific source and engine guards admit the bank")
	for fault: String in ["revision","engine","hood_ids","sources","source_hash"]:
		var corrupt: Dictionary=manifest.duplicate(true)
		match fault:
			"revision": corrupt.revision="obsolete"
			"engine": corrupt.engine="different engine"
			"hood_ids": corrupt.hood_ids.reverse()
			"sources": corrupt.sources=[]
			"source_hash": corrupt.sources["electric_reference_body.gd"]="stale"
		check(not K._hood_manifest_matches(corrupt),"reject mismatching bank "+fault)

	check(manifest.meshes.size()==62 and manifest.total_bytes<3*1024*1024,"bounded 62-mesh package under 3 MiB")
	var expected: Dictionary={}
	var car:=CarVisual.new()
	car.vehicle_id="electric"
	var paint:=CompactFinish.paint(Color("205a78"))
	car.paint_materials={"body":paint}
	M.use_baked=false
	M.meshes.clear()
	# The archived original sampler provides the control, without any asset or
	# module substitution. Generate each quality once and retain only hashes.
	for simple: bool in [false,true]:
		car.simple_model=simple
		for option: Array in VehicleCustomisation.options("hood","electric").slice(1):
			var frame:=Node3D.new()
			legacy.hood(car,frame,str(option[0]))
			frame.free()
	for key: String in M.meshes: expected[key]=arrays_hash(M.meshes[key])
	check(expected.size()==62,"original sampler supplies all 62 controls")
	for item: Dictionary in manifest.meshes:
		var resource: ArrayMesh=load(K.HOOD_MESH_ROOT.path_join(item.file))
		check(resource.surface_get_material(0)==null,"immutable resource carries no paint "+str(item.key))
		check(resource!=null and arrays_hash(resource)==expected.get(item.key),"saved positions normals UVs tangents indices exact "+str(item.key))
		check(item.arrays_sha256==expected.get(item.key),"manifest arrays hash exact "+str(item.key))
	M.meshes.clear()
	M.use_baked=true
	for simple: bool in [false,true]:
		car.simple_model=simple
		for option: Array in VehicleCustomisation.options("hood","electric").slice(1):
			K.prepare_hood_meshes(str(option[0]),simple)
			var keys: int=M.meshes.size()
			var frame:=Node3D.new()
			K.hood(car,frame,str(option[0]))
			check(M.meshes.size()==keys,"selected hood needs no runtime sampling "+str(option[0]))
			var skin: MeshInstance3D=frame.find_child("VoltHoodSkinV5_*",true,false)
			check(skin!=null and skin.material_override==paint,"prebuilt mesh uses current car-owned paint "+str(option[0]))
			paint.albedo_color=Color("bc3724")
			check((skin.material_override as StandardMaterial3D).albedo_color==Color("bc3724"),"paint stays mutable "+str(option[0]))
			frame.free()
	check(M.meshes.size()==62,"only immutable selected hood resources are retained")
	for key: String in M.meshes: check(arrays_hash(M.meshes[key])==expected.get(key),"loaded resource remains exact "+key)
	var second:=CarVisual.new()
	second.vehicle_id="electric"
	second.paint_materials={"body":CompactFinish.paint(Color("c0bdb5"))}
	var first_frame:=Node3D.new()
	var second_frame:=Node3D.new()
	car.simple_model=false
	K.hood(car,first_frame,"volt_centre")
	K.hood(second,second_frame,"volt_centre")
	var first_skin: MeshInstance3D=first_frame.find_child("VoltHoodSkinV5_*",true,false)
	var second_skin: MeshInstance3D=second_frame.find_child("VoltHoodSkinV5_*",true,false)
	check(first_skin.mesh==second_skin.mesh,"two cars share only immutable geometry")
	check(first_skin.material_override!=second_skin.material_override and second_skin.material_override==second.paint_materials.body,"two cars retain independent paint")
	first_frame.free()
	second_frame.free()
	second.free()
	# Disabling prepared resources continues to expose the unchanged sampler.
	M.meshes.clear()
	M.use_baked=false
	K.prepare_hood_meshes("volt_centre",false)
	check(M.meshes.is_empty(),"explicit procedural mode bypasses the bank")
	var fallback:=Node3D.new()
	car.simple_model=false
	K.hood(car,fallback,"volt_centre")
	check(arrays_hash(M.meshes["VoltHoodSkinV5_volt_centre"])==expected.VoltHoodSkinV5_volt_centre,"procedural fallback remains exact")
	fallback.free()
	car.free()
	M.use_baked=true
	print("VOLT_HOOD_MESH_BANK: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
