extends SceneTree
## C10K01-C10K02: original-corner retessellation, stock budgets and every module.
const Budget=preload("res://vehicle/car_budget_reduction.gd")
var WORK: String=OS.get_environment("BMT_CAR_BUDGET_WORK") if OS.has_environment("BMT_CAR_BUDGET_WORK") else "res://../build/car-10k-models-2026-11-14"
var OUT: String=OS.get_environment("BMT_CAR_BUDGET_OUT") if OS.has_environment("BMT_CAR_BUDGET_OUT") else "res://../docs/evidence/car-10k-models-2026-11-14"
var catalog: Dictionary={}
var observations: Array=[]
var active: Dictionary={}
var plan: Dictionary={}
var rows: Array=[]
var saved: Dictionary={}
var compact=preload("res://tests/support/car_static_reduction_bake.gd").new()

func root_for(parents: PackedInt32Array, at: int) -> int:
	while parents[at]!=at: at=parents[at]
	return at

func guard_components(source: Mesh, surface: int, levels: Array, vehicle: String, label: String) -> Array:
	var arrays: Array=source.surface_get_arrays(surface)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var identities: Dictionary={};var dense:=PackedInt32Array();var parents:=PackedInt32Array()
	for vertex: Vector3 in vertices:
		var key: Vector3=vertex.snapped(Vector3.ONE*0.00001)
		if not identities.has(key): identities[key]=parents.size();parents.append(parents.size())
		dense.append(identities[key])
	var indices: PackedInt32Array=levels[0].indices
	for at: int in range(0,indices.size(),3):
		var a: int=root_for(parents,dense[indices[at]])
		for corner: int in [1,2]:
			var b: int=root_for(parents,dense[indices[at+corner]])
			if a!=b: parents[b]=a
	var components: Dictionary={}
	for at: int in range(vertices.size()):
		dense[at]=root_for(parents,dense[at])
		var key: int=dense[at]
		if not components.has(key): components[key]={"box":AABB(vertices[at],Vector3.ZERO),"triangles":0,"faces":[]}
		else: components[key].box=components[key].box.expand(vertices[at])
	for at: int in range(0,indices.size(),3):
		var component: Dictionary=components[dense[indices[at]]]
		component.triangles+=1;component.faces.append([indices[at],indices[at+1],indices[at+2]])
	var accepted: Array=[]
	for level: Dictionary in levels:
		var boxes: Dictionary={};var counts: Dictionary={}
		for index: int in level.indices:
			var key: int=dense[index]
			boxes[key]=boxes[key].expand(vertices[index]) if boxes.has(key) else AABB(vertices[index],Vector3.ZERO)
			counts[key]=int(counts.get(key,0))+1
		var restore: Dictionary={}
		for key: int in components:
			var original: AABB=components[key].box
			var center: Vector3=original.get_center()
			# Authored mirror regions survive sibling batching. These locations
			# follow CompactCoachwork, ElectricReferenceDetails and ForkliftModel;
			# other small islands may simplify at the owner's new racing budget.
			var important: bool="mirror" in label.to_lower()
			if vehicle in ["compact","electric"]: important=important or (absf(center.x)>0.72 and center.y>0.9 and center.y<1.25 and center.z> -1.0 and center.z< -0.25)
			if vehicle=="forklift": important=important or (absf(center.x)>0.7 and center.y>1.8 and center.y<2.4 and center.z> -0.85 and center.z< -0.25)
			if not important:
				# Retain disconnected skins and details instead of leaving holes.
				if not boxes.has(key) and original.size.length()>0.005: restore[key]=true
				continue
			if not boxes.has(key) or int(counts.get(key,0))/3<mini(8,int(components[key].triangles)):
				restore[key]=true;continue
			var box: AABB=boxes[key]
			for axis: int in range(3):
				var margin: float=maxf(0.001,original.size[axis]*0.04)
				if absf(box.position[axis]-original.position[axis])>margin or absf(box.end[axis]-original.end[axis])>margin: restore[key]=true
		var repaired:=PackedInt32Array()
		for at: int in range(0,level.indices.size(),3):
			if not restore.has(dense[level.indices[at]]): repaired.append_array(level.indices.slice(at,at+3))
		for key: int in restore:
			for face: Array in components[key].faces: repaired.append_array(PackedInt32Array(face))
		var corrected: Dictionary=level.duplicate()
		corrected.indices=repaired;corrected.count=repaired.size()/3
		accepted.append(corrected)
	accepted.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.count>b.count if a.count!=b.count else a.error<b.error)
	var distinct: Array=[];var counts: Dictionary={}
	for level: Dictionary in accepted:
		if not counts.has(level.count): distinct.append(level);counts[level.count]=true
	return distinct

func filter_catalog() -> void:
	var protected_keys: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK.path_join("protected-roles.json"))) if FileAccess.file_exists(WORK.path_join("protected-roles.json")) else {}
	var bonnet: Dictionary={}
	for row: Dictionary in observations:
		if row.vehicle=="compact" and row.case.get("category","")=="hood": bonnet=row.weights
	for entry: Dictionary in catalog.values():
		if entry.vehicle!="kart":
			for surface: int in range(entry.choices.size()): entry.choices[surface]=guard_components(entry.source,surface,entry.choices[surface],entry.vehicle,entry.name)
	for key: String in bonnet:
		for surface: int in range(catalog[key].choices.size()): catalog[key].choices[surface]=[catalog[key].choices[surface][0]]
	for key: String in protected_keys:
		if catalog.has(key):
			for surface: int in range(catalog[key].choices.size()): catalog[key].choices[surface]=[catalog[key].choices[surface][0]]

func read_dissolved() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK.path_join("dissolved-boundaries.json" if "--boundaries" in OS.get_cmdline_user_args() else "dissolved.json")))
	for key: String in catalog:
		var entry: Dictionary=catalog[key]
		assert(data.has(key),"Retessellation cache lacks the current exact source geometry")
		# Planar retessellation and native reductions have different floors.
		# Keep both families so closed tyre/helmet restoration does not force
		# unnecessary reductions in the remaining bodywork.
		for surface: int in range(data[key].size()):
			var levels: Array=entry.choices[surface].duplicate() if entry.vehicle in ["compact","kart","forklift"] else []
			for row: Dictionary in data[key][surface]:
				var indices:=PackedInt32Array(row.indices)
				levels.append({"error":float(row.angle)*PI/180.0*entry.source.get_aabb().size.length(),"indices":indices,"count":indices.size()/3})
			levels.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.count>b.count if a.count!=b.count else a.error<b.error)
			var distinct: Array=[];var counts: Dictionary={}
			for level: Dictionary in levels:
				if not counts.has(level.count): distinct.append(level);counts[level.count]=true
			entry.choices[surface]=distinct

func rebuild_levels() -> void:
	for entry: Dictionary in catalog.values():
		var source: Mesh=entry.source
		var importer:=ImporterMesh.new()
		for surface: int in range(source.get_surface_count()):
			var arrays: Array=source.surface_get_arrays(surface).duplicate()
			if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
				var indices:=PackedInt32Array();indices.resize(arrays[Mesh.ARRAY_VERTEX].size())
				for at: int in range(indices.size()): indices[at]=at
				arrays[Mesh.ARRAY_INDEX]=indices
			# These untextured structural/paint pieces need no UV seam locks in
			# the solver. Their original encoded UVs/tangents remain in the output.
			if not source.has_meta("pixel_integrated_contour") and "plate" not in str(entry.name).to_lower():
				arrays[Mesh.ARRAY_TEX_UV]=null;arrays[Mesh.ARRAY_TEX_UV2]=null;arrays[Mesh.ARRAY_TANGENT]=null
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
		importer.generate_lods(2.0,0.0,[])
		entry.choices=[]
		for surface: int in range(source.get_surface_count()):
			var original: PackedInt32Array=importer.get_surface_arrays(surface)[Mesh.ARRAY_INDEX]
			var levels: Array=[{"error":0.0,"indices":original,"count":original.size()/3}]
			if "--no-prune" in OS.get_cmdline_user_args():
				var tool:=SurfaceTool.new();tool.create_from_arrays(importer.get_surface_arrays(surface))
				for ratio: float in [0.85,0.7,0.55,0.45,0.35,0.25,0.15,0.08,0.04]:
					var target: int=maxi(3,int(original.size()/3*ratio)*3)
					if target>=original.size(): continue
					var indices: PackedInt32Array=tool.generate_lod(0.025,target)
					if not indices.is_empty(): levels.append({"error":(1.0-ratio)*source.get_aabb().size.length(),"indices":indices,"count":indices.size()/3})
			else:
				for at: int in range(importer.get_surface_lod_count(surface)):
					var indices: PackedInt32Array=importer.get_surface_lod_indices(surface,at)
					if not indices.is_empty(): levels.append({"error":importer.get_surface_lod_size(surface,at),"indices":indices,"count":indices.size()/3})
			levels.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.count>b.count)
			entry.choices.append(levels)

func _initialize() -> void: run.call_deferred()

func collect(car: CarVisual,parts: Array) -> void:
	var weights: Dictionary={};var total: int=0;var protected_count: int=0
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var source: Mesh=part.mesh
		var before: int=source.get_faces().size()/3;total+=before
		if Budget.is_protected(part) or (source is ArrayMesh and source.get_blend_shape_count()>0):
			protected_count+=before;continue
		var key: String=Budget.code(source,car.vehicle_id)
		weights[key]=int(weights.get(key,0))+1
		if catalog.has(key): continue
		var importer:=ImporterMesh.new()
		for surface: int in range(source.get_surface_count()):
			var arrays: Array=source.surface_get_arrays(surface).duplicate()
			if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
				var indices:=PackedInt32Array();indices.resize(arrays[Mesh.ARRAY_VERTEX].size())
				for at: int in range(indices.size()): indices[at]=at
				arrays[Mesh.ARRAY_INDEX]=indices
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
		# Only near-identical normals weld for the simplifier. Output uses original
		# encoded vertices; sharp normals, all UVs and morph topology remain intact.
		importer.generate_lods(0.1,0.0,[])
		var choices: Array=[];var packets: Array=[]
		for surface: int in range(source.get_surface_count()):
			var original: PackedInt32Array=importer.get_surface_arrays(surface)[Mesh.ARRAY_INDEX]
			var levels: Array=[{"error":0.0,"indices":original,"count":original.size()/3}]
			for at: int in range(importer.get_surface_lod_count(surface)):
				var indices: PackedInt32Array=importer.get_surface_lod_indices(surface,at)
				if not indices.is_empty(): levels.append({"error":importer.get_surface_lod_size(surface,at),"indices":indices,"count":indices.size()/3})
			levels.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.count>b.count)
			choices.append(levels)
			var packet: Dictionary=RenderingServer.mesh_get_surface(source.get_rid(),surface)
			packet.material=StandardMaterial3D.new();packets.append(packet)
		catalog[key]={"source":source,"vehicle":car.vehicle_id,"choices":choices,"packets":packets,"before":before,"name":str(part.name)}
	observations.append({"vehicle":car.vehicle_id,"case":active.duplicate(),"weights":weights,"before":total,"protected":protected_count})

func choose_stock(id: String) -> void:
	var cases: Array=observations.filter(func(row: Dictionary)->bool:return row.vehicle==id and row.case.get("stock",false))
	var totals: Array=[]
	for row: Dictionary in cases: totals.append(row.before)
	var states: Dictionary={}
	for row: Dictionary in cases:
		for key: String in row.weights:
			for surface: int in range(catalog[key].choices.size()): states[key+":"+str(surface)]={"key":key,"surface":surface,"level":0}
	while totals.max()>10300:
		var best: Dictionary={};var score: float=INF
		for state: Dictionary in states.values():
			var choices: Array=catalog[state.key].choices[state.surface]
			if state.level+1>=choices.size(): continue
			var current: Dictionary=choices[state.level];var next: Dictionary=choices[state.level+1]
			var reductions: Array=[];var valid: bool=true;var saves: int=0
			for at: int in range(cases.size()):
				var delta: int=(int(current.count)-int(next.count))*int(cases[at].weights.get(state.key,0))
				reductions.append(delta);saves+=delta
				if int(totals[at])-delta<9000: valid=false
			if not valid or saves<=0: continue
			var cost: float=maxf(0.000000001,float(next.error)-float(current.error))/saves
			if cost<score: score=cost;best={"state":state,"reductions":reductions}
		if best.is_empty(): break
		best.state.level+=1
		for at: int in range(totals.size()): totals[at]-=int(best.reductions[at])
	for state: Dictionary in states.values():
		if not plan.has(state.key): plan[state.key]=[]
		plan[state.key].append(state.level)
	for at: int in range(cases.size()):
		rows.append({"vehicle":id,"editable":cases[at].case.editable,"before":cases[at].before,"after":totals[at]})
		print("TEN_K_STOCK_PLAN ",id," ",cases[at].case.editable," ",cases[at].before," -> ",totals[at])

func publish_stage() -> void:
	var directory: String=WORK.path_join("staged-final-five")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	# Candidate proofs must see only this plan, just like the published folder.
	# An older experiment can otherwise supply a now-unselected source key.
	for name: String in DirAccess.get_files_at(ProjectSettings.globalize_path(directory)):
		if name.ends_with(".res") and name.get_slice("_",0) in ["compact","kart","forklift","electric","hovercraft"]:
			assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(name)))==OK)
	for key: String in catalog:
		var entry: Dictionary=catalog[key]
		if not plan.has(key):
			var ratio: float=10000.0/float(rows.filter(func(r: Dictionary)->bool:return r.vehicle==entry.vehicle)[0].before)
			if entry.vehicle=="kart": ratio=(10000.0-3695.0)/(24223.0-3695.0)
			if entry.vehicle in ["compact","electric","forklift"]: ratio*=0.65
			if entry.vehicle=="hovercraft": ratio*=0.4
			plan[key]=[]
			for levels: Array in entry.choices:
				var level: int=0;var distance: float=INF
				for at: int in range(levels.size()):
					var diff: float=absf(float(levels[at].count)-float(levels[0].count)*ratio)
					if diff<distance: level=at;distance=diff
				plan[key].append(level)
		var packets: Array=entry.packets.duplicate(true);var after: int=0
		for surface: int in range(packets.size()):
			var level: Dictionary=entry.choices[surface][int(plan[key][surface])]
			after+=int(level.count)
			var packet: Dictionary=packets[surface];var stride: int=2 if int(packet.vertex_count)<=65536 else 4
			packet.aabb=entry.source.get_aabb()
			var raw:=PackedByteArray();raw.resize(level.indices.size()*stride)
			for at: int in range(level.indices.size()):
				if stride==2: raw.encode_u16(at*stride,level.indices[at])
				else: raw.encode_u32(at*stride,level.indices[at])
			packet.index_data=raw;packet.index_count=level.indices.size();packet.format=int(packet.format)|Mesh.ARRAY_FORMAT_INDEX;packet.erase("lods")
		if after==int(entry.before): continue
		var mesh:=ArrayMesh.new();mesh.set("_surfaces",packets);mesh.custom_aabb=entry.source.get_aabb()
		mesh=compact.compact(mesh);mesh.custom_aabb=entry.source.get_aabb()
		for property: StringName in entry.source.get_meta_list(): mesh.set_meta(property,entry.source.get_meta(property))
		mesh.set_meta("car_budget_source",key)
		assert(mesh.get_surface_count()==entry.source.get_surface_count() and mesh.get_aabb()==entry.source.get_aabb(),key+" bounds "+str(mesh.get_aabb())+" / "+str(entry.source.get_aabb()))
		assert(ResourceSaver.save(mesh,directory.path_join(key+".res"),ResourceSaver.FLAG_COMPRESS)==OK)
		saved[key]={"vehicle":entry.vehicle,"before":entry.before,"after":after,"name":entry.name,"levels":plan[key]}
	FileAccess.open(OUT.path_join("plan.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"parts":saved,"observations":observations},"  "))

func run() -> void:
	var only: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--vehicle="): only=argument.trim_prefix("--vehicle=")
	if "--resume" in OS.get_cmdline_user_args():
		var data: Resource=load(WORK.path_join("bake-cache.res"))
		catalog=data.get_meta("catalog");observations=data.get_meta("observations");plan=data.get_meta("plan");rows=data.get_meta("rows")
		for key: String in catalog.keys():
			if catalog[key].vehicle=="super_rally": catalog.erase(key)
		observations=observations.filter(func(row: Dictionary)->bool:return row.vehicle!="super_rally")
		if "--replan" in OS.get_cmdline_user_args():
			plan={};rows=[]
			if "--dissolved" in OS.get_cmdline_user_args(): read_dissolved()
			elif "--rebuild-levels" in OS.get_cmdline_user_args(): rebuild_levels()
			filter_catalog()
			for id: String in VehicleCatalog.IDS:
				if id!="super_rally": choose_stock(id)
		publish_stage();print("TEN_K_STAGED ",saved.size()," resources");quit();return
	if not only.is_empty():
		var data: Resource=load(WORK.path_join("bake-cache.res"))
		catalog=data.get_meta("catalog");observations=data.get_meta("observations");rows=data.get_meta("rows")
		for key: String in catalog.keys():
			if catalog[key].vehicle==only: catalog.erase(key)
		observations=observations.filter(func(row: Dictionary)->bool:return row.vehicle!=only)
		rows=rows.filter(func(row: Dictionary)->bool:return row.vehicle!=only)
	for path: String in ["modular_car_base","modular_car_kits","prepared_car_cache"]: load("res://vehicle/"+path+".gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	Budget.offline=collect
	for id: String in VehicleCatalog.IDS:
		if id=="super_rally": continue
		if not only.is_empty() and only!=id: continue
		for editable: bool in [false,true]:
			active={"stock":true,"editable":editable}
			var car:=CarVisual.new();car.vehicle_id=id;car.editable_kits=editable;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id)
			root.add_child(car)
			while not car.model_ready: await process_frame
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,id):
						active={"stock":false,"category":category,"option":option[0]}
						var selected: Dictionary=car.customisation.duplicate();selected[category]=option[0];car.change_kit_parts(selected)
					var selected: Dictionary=car.customisation.duplicate();selected[category]="stock";car.change_kit_parts(selected)
			car.free();await process_frame
		choose_stock(id)
		print("TEN_K_CATALOG ",id," pieces=",catalog.size())
	var data:=Resource.new()
	for entry: Array in [["catalog",catalog],["observations",observations],["plan",plan],["rows",rows]]: data.set_meta(entry[0],entry[1])
	assert(ResourceSaver.save(data,WORK.path_join("bake-cache.res"),ResourceSaver.FLAG_COMPRESS)==OK)
	if "--collect" in OS.get_cmdline_user_args():
		print("TEN_K_COLLECTED ",catalog.size()," source pieces");quit();return
	plan={};rows=[];read_dissolved();filter_catalog()
	for id: String in VehicleCatalog.IDS:
		if id!="super_rally": choose_stock(id)
	publish_stage()
	print("TEN_K_STAGED ",saved.size()," resources")
	quit()
