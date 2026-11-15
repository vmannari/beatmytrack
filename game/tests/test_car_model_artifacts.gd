extends "res://tests/test_car_simplification.gd"
## CMA01-CMA04: real source/prepared geometry, LOD and paint regression checks.
const Budget=preload("res://vehicle/car_budget_reduction.gd")
const ARTIFACT_OUT: String="res://../docs/evidence/car-model-artifacts-2026-11-14"
var protected_parts: Dictionary={}
var protected_triangles: Dictionary={}
var audited: int=0

func _initialize() -> void: review.call_deferred()

func audit(car: CarVisual, parts: Array) -> void:
	var originals: Dictionary={}
	var injected: Dictionary={}
	for part: MeshInstance3D in parts:
		if part.mesh!=null and Budget.is_protected(part):
			originals[part]=part.mesh
			# A valid but obsolete cached recipe must still be ignored. An exact
			# duplicate makes this control independent of visual error tolerances.
			var key: String=Budget.code(part.mesh,car.vehicle_id)
			if not injected.has(key):
				injected[key]=Budget.meshes.get(key)
				var obsolete: ArrayMesh=packed(part.mesh).duplicate()
				obsolete.set_meta("car_budget_source",key)
				Budget.meshes[key]=obsolete
			protected_parts[car.vehicle_id]=int(protected_parts.get(car.vehicle_id,0))+1
			protected_triangles[car.vehicle_id]=int(protected_triangles.get(car.vehicle_id,0))+part.mesh.get_faces().size()/3
	Budget.offline=Callable()
	Budget.apply(car)
	Budget.offline=audit
	for part: MeshInstance3D in originals:
		check(part.mesh==originals[part],"critical geometry is never replaced by a budget recipe "+car.vehicle_id)
		audited+=1
	for key: String in injected:
		Budget.meshes.erase(key)
		if injected[key]!=null: Budget.meshes[key]=injected[key]

func packed(mesh: Mesh) -> ArrayMesh:
	if mesh is ArrayMesh: return mesh
	var packets: Array=[]
	for surface: int in range(mesh.get_surface_count()): packets.append(RenderingServer.mesh_get_surface(mesh.get_rid(),surface))
	var result:=ArrayMesh.new();result.set("_surfaces",packets);result.custom_aabb=mesh.get_aabb()
	return result

func check_finished(car: CarVisual) -> void:
	var lods=preload("res://vehicle/car_mesh_lods.gd").new()
	var found: int=0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null or not Budget.is_protected(part): continue
		found+=1
		check(not lods.eligible(part,car.vehicle_id),"panel joins and openings cannot split again at distant LODs")
		if part.mesh is ArrayMesh:
			for packet: Dictionary in part.mesh.get("_surfaces"):
				check(not packet.has("lods") or packet.lods.is_empty(),"delivered critical mesh already has no approximate LOD")
		var faces: PackedVector3Array=part.mesh.get_faces()
		part.mesh=lods.full_detail(part.mesh)
		check(part.mesh.get_faces()==faces,"LOD preparation retains exact critical triangle corners")
		if part.mesh is ArrayMesh:
			for packet: Dictionary in part.mesh.get("_surfaces"):
				check(not packet.has("lods") or packet.lods.is_empty(),"protected prepared mesh has no approximate LOD")
		if car.vehicle_id=="kart" and "Helmet" in str(part.name):
			check(faces.size()/3>=1000,"helmet retains the complete brow and jaw shell")
	if car.vehicle_id in ["kart","compact","electric","hovercraft"]: check(found>0,"critical exterior geometry survives final batching "+car.vehicle_id)
	var livery: Dictionary=VehicleLivery.defaults(car.vehicle_id)
	livery.colors.body="ee2244";livery.colors.accent="22aaee"
	car.apply_livery(livery)
	for variant: Dictionary in car.paint_variants:
		var expected:=Color(str(livery.colors[variant.slot])).darkened(float(variant.get("darken",0)))
		check(variant.material.albedo_color.is_equal_approx(expected),"protected paint follows current editable colour")

func review() -> void:
	var routing=preload("res://vehicle/prepared_asset_sources.gd")
	check(routing.vehicles_for("game/assets/liveries/previews_v2/super_rally/apex_twin.png")==["super_rally"],"unfinished Challenger thumbnails cannot invalidate the other five models")
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		check(id in routing.vehicles_for("game/assets/liveries/apex_twin.svg"),"shared paint artwork still invalidates its consumers "+id)
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=false
	if not prepared: Budget.offline=audit
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		for fitted: bool in [false,true]:
			var car:=CarVisual.new();car.vehicle_id=id;car.cache_rest_pose=false;car.editable_kits=fitted;car.livery=VehicleLivery.defaults(id)
			if fitted:
				for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			root.add_child(car)
			while not car.model_ready: await process_frame
			check_finished(car)
			if not fitted: check(inventory(car,false).triangles>=9000 and inventory(car,false).triangles<=11000,"stock quality repairs retain the approximately 10k budget "+id)
			car.free();await process_frame
	if not prepared: check(audited>20,"actual protected source geometry audited")
	var result: Dictionary={"checks":checks,"failures":failures,"audited":audited,"protected_parts":protected_parts,"protected_triangles":protected_triangles,"prepared":prepared}
	FileAccess.open(ARTIFACT_OUT.path_join("artifact-proof-prepared.json" if prepared else "artifact-proof-source.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CAR_ARTIFACTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
