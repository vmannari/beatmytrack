extends SceneTree
## CME02-CME04: bake component distance indices into exact final batch masters.
const Source=preload("res://tests/support/car_pass10_source.gd")
const Lods=preload("res://tests/support/car_refinement_lods.gd")
const WORK: String="res://../build/car-mechanics-2026-11-17"
const OUT: String="res://../docs/evidence/car-mechanics-2026-11-17"
var components: Array=[]
var resources: Dictionary={}
var reports: Array=[]
var mesh_cache: Dictionary={}
var proofs: Dictionary={}
var identity:=Lods.new()
func _initialize() -> void:run.call_deferred()
func point_key(p: Vector3) -> String:return "%d,%d,%d" % [roundi(p.x*100000),roundi(p.y*100000),roundi(p.z*100000)]
func face_key(a: Vector3,b: Vector3,c: Vector3) -> String:
	var keys: Array[String]=[point_key(a),point_key(b),point_key(c)];keys.sort();return "|".join(keys)
func inner_rim(source: Mesh) -> PackedInt32Array:
	var a: Array=source.surface_get_arrays(0);var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX];var result:=PackedInt32Array()
	var rings: Dictionary={}
	for side: int in [-1,1]:
		var ring: Array[int]=[]
		for at: int in range(v.size()):
			if absf(v[at].x-side*0.103)<0.00001 and absf(Vector2(v[at].y,v[at].z).length()-0.111)<0.00001:ring.append(at)
		ring.sort_custom(func(one: int,two: int) -> bool:return atan2(v[one].y,v[one].z)<atan2(v[two].y,v[two].z))
		var distinct: Array[int]=[]
		for at: int in ring:
			if distinct.is_empty() or v[at].distance_to(v[distinct[-1]])>0.000001:distinct.append(at)
		if distinct.size()>16 and v[distinct[0]].distance_to(v[distinct[-1]])<0.000001:distinct.pop_back()
		assert(distinct.size() in [15,16],"Current inner bore retains its accepted angular stations")
		for at: int in range(1,distinct.size(),2):
			var previous: Vector3=v[distinct[at-1]]
			var next: Vector3=v[distinct[(at+1)%distinct.size()]]
			var span: float=fposmod(atan2(next.y,next.z)-atan2(previous.y,previous.z),TAU)
			if span>TAU/8.0+0.0001:continue
			for vertex: int in ring:
				if v[vertex].distance_to(v[distinct[at]])<0.000001:rings[vertex]=distinct[at-1]
	for at: int in range(0,indices.size(),3):
		var tri: Array[int]=[]
		for offset: int in range(3):tri.append(rings.get(indices[at+offset],indices[at+offset]))
		if tri[0]==tri[1] or tri[1]==tri[2] or tri[0]==tri[2]:continue
		result.append_array(tri)
	return result
func distant(source: Mesh,kind: String) -> Dictionary:
	var code: String=preload("res://vehicle/car_detail_reduction.gd").mesh_key(source)+kind
	if mesh_cache.has(code):return mesh_cache[code]
	var result: Dictionary={}
	if kind=="lattice":
		var original: PackedInt32Array=source.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var front:=PackedInt32Array()
		assert(original.size()==24*8*3)
		for column: int in range(24):front.append_array(original.slice(column*24,column*24+6))
		result={"indices":front,"error":0.015}
	elif kind=="rim":
		var indices: PackedInt32Array=inner_rim(source)
		if not indices.is_empty():result={"indices":indices,"error":0.012}
	else:
		var importer:=ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(0))
		importer.generate_lods(0,0,[])
		for at: int in range(importer.get_surface_lod_count(0)):
			var indices: PackedInt32Array=importer.get_surface_lod_indices(0,at)
			var error: float=importer.get_surface_lod_size(0,at)
			print("DISTANCE_LEVEL ",source.resource_path," ",indices.size()/3," error=",error)
			if indices.size()<source.get_faces().size()*0.95:
				var retopology_path: String=WORK.path_join("distance-retopology.json")
				if FileAccess.file_exists(retopology_path):
					var retopology: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(retopology_path))
					if retopology.has(code):indices=PackedInt32Array(retopology[code])
				var a: Array=source.surface_get_arrays(0);var points: Array=[]
				for p: Vector3 in a[Mesh.ARRAY_VERTEX]:points.append([p.x,p.y,p.z])
				proofs[code]={"vertices":points,"before":Array(a[Mesh.ARRAY_INDEX]),"after":Array(indices),"engine_error":error,"resource":source.resource_path}
				result={"indices":indices,"error":maxf(0.006,error*4)}
				var review_path: String=OUT.path_join("distance-review.json")
				if FileAccess.file_exists(review_path):
					var review: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(review_path))
					if not review.has(code) or not review[code].accepted:result={}
					else:result.error=maxf(0.006,float(review[code].surface_upper_bound_m)*4)
				break
		if result.is_empty():print("DISTANCE_NO_LEVEL ",source.resource_path," levels=",importer.get_surface_lod_count(0))
	mesh_cache[code]=result;return result
func observe(car: CarVisual,holders: Variant) -> void:
	var parts: Array=car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders:parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	for part: MeshInstance3D in parts:
		var label: String=str(part.name);var kind: String=""
		if label=="FrontGrilleLattice":kind="lattice"
		elif label=="DishedMagnesiumRim":kind="rim"
		elif label.begins_with("SportDuctRim") or label.begins_with("SportGuardRing"):kind="guard"
		if kind.is_empty() or part.mesh==null or part.mesh.get_surface_count()!=1:continue
		var reduced: Dictionary=distant(part.mesh,kind)
		if reduced.is_empty():continue
		var a: Array=part.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var original: PackedInt32Array=a[Mesh.ARRAY_INDEX]
		var faces: Dictionary={};var points: Array[Vector3]=[]
		for p: Vector3 in vertices:points.append(part.global_transform*p)
		for at: int in range(0,original.size(),3):faces[face_key(points[original[at]],points[original[at+1]],points[original[at+2]])]=true
		components.append({"kind":kind,"faces":faces,"points":points,"indices":reduced.indices,"error":reduced.error,"label":label})
func compile(car: CarVisual,label: String) -> void:
	var matched: int=0;var saved: int=0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if not part.mesh is ArrayMesh or part.mesh.get_blend_shape_count()>0:continue
		var source: ArrayMesh=part.mesh;var master: String=identity.master_key(source)
		var packets: Array=source.get("_surfaces").duplicate(true);var changed: bool=false
		for sf: int in range(source.get_surface_count()):
			var a: Array=source.surface_get_arrays(sf)
			if a[Mesh.ARRAY_INDEX]==null:continue
			var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var original: PackedInt32Array=a[Mesh.ARRAY_INDEX]
			var faces: Dictionary={};var by_position: Dictionary={}
			for at: int in range(vertices.size()):by_position[point_key(part.global_transform*vertices[at])]=at
			for at: int in range(0,original.size(),3):
				faces[face_key(part.global_transform*vertices[original[at]],part.global_transform*vertices[original[at+1]],part.global_transform*vertices[original[at+2]])]=at
			var remove: Dictionary={};var replacement:=PackedInt32Array();var error: float=0
			for component: Dictionary in components:
				var found: Array[int]=[]
				for key: String in component.faces:
					if faces.has(key):found.append(faces[key])
				if found.size()!=component.faces.size():continue
				var valid: bool=true;var next:=PackedInt32Array()
				for old: int in component.indices:
					var key: String=point_key(component.points[old])
					if not by_position.has(key):valid=false;break
					next.append(by_position[key])
				if not valid:continue
				for at: int in found:remove[at]=true
				replacement.append_array(next);error=maxf(error,component.error)
				matched+=1;saved+=found.size()-next.size()/3
			if remove.is_empty():continue
			# Keep all unrelated existing distance levels. A component candidate is
			# admitted only for a surface that previously kept its complete master.
			if not packets[sf].get("lods",[]).is_empty():continue
			var selected:=PackedInt32Array()
			for at: int in range(0,original.size(),3):
				if not remove.has(at):selected.append_array(original.slice(at,at+3))
			selected.append_array(replacement)
			if selected.is_empty() or selected.size()>=original.size():continue
			var temporary:=ArrayMesh.new();var arrays: Array=a.duplicate();arrays[Mesh.ARRAY_INDEX]=original
			temporary.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{error:selected})
			packets[sf].lods=temporary.get("_surfaces")[0].lods;changed=true
		if not changed:continue
		var result:=ArrayMesh.new();result.set("_surfaces",packets);result.custom_aabb=source.custom_aabb
		assert(identity.master_key(result)==master,"All master GPU bytes, bounds, surfaces and indices remain exact")
		var native:=Resource.new()
		native.set_meta("car_mechanics_vehicle",car.vehicle_id);native.set_meta("car_mechanics_master",master)
		var levels: Array=[]
		for packet: Dictionary in packets:levels.append(packet.get("lods",[]))
		native.set_meta("car_mechanics_levels",levels)
		var name: String=car.vehicle_id+"_mechanics_"+master+".res"
		assert(ResourceSaver.save(native,WORK.path_join("staged").path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
		resources[name]="game/assets/vehicles/car_coarse_v1/"+name
	reports.append({"vehicle":car.vehicle_id,"case":label,"components":components.size(),"matched":matched,"far_triangles_saved":saved})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("staged")))
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Source.observer=observe
	for id: String in ["compact","kart","hovercraft"]:
		for editable: bool in [false,true]:
			components=[]
			var car=Source.new();car.vehicle_id=id;car.simple_model=true;car.cache_rest_pose=false;car.editable_kits=editable;car.livery=VehicleLivery.defaults(id);car.customisation=VehicleCustomisation.defaults();root.add_child(car)
			while not car.model_ready:await process_frame
			compile(car,"editable" if editable else "fixed")
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,id).slice(1):
						components=[]
						var choice: Dictionary=car.customisation.duplicate();choice[category]=option[0];car.change_kit_parts(choice)
						compile(car,category+"/"+option[0])
						choice=car.customisation.duplicate();choice[category]="stock";car.change_kit_parts(choice)
			car.free();await process_frame
	FileAccess.open(OUT.path_join("distance-staged.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":resources,"cases":reports},"  "))
	FileAccess.open(WORK.path_join("distance-proof-input.json"),FileAccess.WRITE).store_string(JSON.stringify(proofs))
	print("MECHANICS_DISTANCE ",resources.size()," resources / ",reports.size()," cases");quit()
