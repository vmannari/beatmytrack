extends "res://tests/register_rally_grille_closure.gd"
const WORK: String="res://../build/rally-grille-closure-2026-11-16"
var checks: int=0;var failures: int=0
var panels: Array=[]
var old_detail: Mesh
var old_targets: Dictionary={}
var costs: Array=[]
func shape_signature(mesh: Mesh) -> Array:
	var result: Array=[]
	for surface: int in range(mesh.get_surface_count()):
		var a: Array=mesh.surface_get_arrays(surface);var p: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var n: PackedVector3Array=a[Mesh.ARRAY_NORMAL];var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV];var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
		for i: int in range(0,indices.size(),3):
			var vertices: Array=[]
			for j: int in range(3):
				var index: int=indices[i+j];vertices.append(var_to_bytes([p[index],n[index],uv[index]]).hex_encode())
			vertices.sort();result.append(var_to_bytes(vertices).hex_encode().sha256_text())
	result.sort();return result
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("RGC_FAIL ",label)
func wanted(group: Dictionary) -> bool:
	for entry: Dictionary in group.entries:
		if str(entry.part.name)=="FrontCoachwork":return true
	return false
func outward_faces(mesh: Mesh) -> PackedVector3Array:
	var points: PackedVector3Array=mesh.get_faces();var front:=PackedVector3Array()
	for i: int in range(0,points.size(),3):
		if (points[i+1]-points[i]).cross(points[i+2]-points[i]).z>0:
			front.append_array(PackedVector3Array([points[i],points[i+1],points[i+2]]))
	return front
func outward_tree(mesh: Mesh,trim: PackedVector3Array) -> TriangleMesh:
	var front: PackedVector3Array=outward_faces(mesh);front.append_array(trim)
	var tree:=TriangleMesh.new();tree.create_from_faces(front);return tree
func detail(group: Dictionary) -> void:
	if wanted(group):
		var before: Dictionary=raw.get(key(group,false),{})
		check(not before.is_empty(),"every other raw member exact")
		var expected: Dictionary=before.recipe.parts.duplicate(true)
		var native: Mesh=load(WORK.path_join("before/game/assets/vehicles/racing_simple_v1/compact/front_coachwork_simple.res"))
		for row: Dictionary in expected.values():
			if row.source==D.mesh_key(native):old_detail=load(D.ROOT.path_join(row.mesh))
		for code: String in before.target_codes:
			if expected.has(code):
				var mesh: Mesh=load(D.ROOT.path_join(expected[code].mesh))
				old_targets["FrontFascia" if mesh.get_aabb().size.x>1.5 else "FrontCoachwork"]=mesh
			expected.erase(code)
		check(D.recipe("compact",group.code).parts==expected,"only fascia reduction row removed")
	D.apply_group(group)
func surface(group: Dictionary) -> void:
	if not wanted(group):S.apply_group(group,D);return
	var before: Dictionary=post.get(key(group,true),{})
	check(not before.is_empty(),"every other post-detail member exact")
	var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(S.ROOT.path_join("compact_"+group.code+".json")))
	check(current.parts==before.recipe.parts,"every unrelated surface row exact")
	S.apply_group(group,D)
	var old_surface: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(S.ROOT.path_join("compact_"+before.context+".json")))
	var difference: int=0
	for entry: Dictionary in group.entries:
		if not targeted(entry):continue
		var label: String="FrontCoachwork" if str(entry.part.name)=="FrontCoachwork" else "FrontFascia"
		var prior: Mesh=old_targets[label]
		for row: Dictionary in old_surface.parts.values():
			if row.source==D.mesh_key(old_targets[label]):prior=load(S.ROOT.path_join(row.mesh))
		var old_cost: int=prior.get_faces().size()/3;var new_cost: int=entry.part.mesh.get_faces().size()/3
		difference+=new_cost-old_cost;costs.append({"part":label,"before":old_cost,"after":new_cost})
	check(difference==316,"whole-model increase derives only from two repaired front panels")
	# The existing fascia and lamp housings cover the steel at upper corners.
	# Test the actual layered exterior, retaining only front-facing triangles.
	var trim:=PackedVector3Array()
	for entry: Dictionary in group.entries:
		var bounds: AABB=entry.part.mesh.get_aabb()
		if (bounds.size.x>1.5 and absf(bounds.position.y-0.660)<0.0001) or str(entry.part.name).begins_with("FrontLamp"):
			var faces: PackedVector3Array=outward_faces(entry.part.mesh)
			for i: int in range(faces.size()):faces[i]=entry.pose*faces[i]
			trim.append_array(faces)
	check(not trim.is_empty(),"actual unchanged dark front fascia included")
	for entry: Dictionary in group.entries:
		if str(entry.part.name)!="FrontCoachwork":continue
		check(D.mesh_key(entry.part.mesh)==entry.source,"original fascia GPU data retained")
		check(entry.part.mesh.get_faces().size()/3==512,"bounded original 512-triangle panel")
		var old_recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(S.ROOT.path_join("compact_"+before.context+".json")))
		var old_panel: Mesh=old_detail
		for row: Dictionary in old_recipe.parts.values():
			if row.source==D.mesh_key(old_detail):old_panel=load(S.ROOT.path_join(row.mesh))
		var restored: TriangleMesh=outward_tree(entry.part.mesh,trim)
		var rejected: TriangleMesh=outward_tree(old_panel,trim)
		var samples: int=0;var misses: int=0;var old_misses: int=0
		for iy: int in range(53):
			var y: float=lerpf(0.34,0.964,iy/52.0)
			for ix: int in range(81):
				var x: float=lerpf(-0.60,0.60,ix/80.0)
				if absf(x)<0.515 and y>0.675 and y<0.920:continue
				var origin:=Vector3(x,y,-3)
				samples+=1
				var hit: Dictionary=restored.intersect_ray(origin,Vector3.BACK)
				if hit.is_empty():misses+=1
				else:check((hit.normal as Vector3).z<0,"front-facing visible fascia")
				if rejected.intersect_ray(origin,Vector3.BACK).is_empty():old_misses+=1
		check(misses==0,"complete original fascia coverage outside grille aperture")
		check(old_misses>50,"old reduced mesh rejects coverage gate")
		panels.append({"samples":samples,"misses":misses,"old_misses":old_misses,"original_triangles":512,"old_triangles":old_panel.get_faces().size()/3})
func run() -> void:
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("frame-registry.json")));raw=registry.raw;post=registry.post;targets["FrontCoachwork"]=true
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false;D.offline=detail;S.offline=surface
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="compact";car.editable_kits=editable;car.cache_rest_pose=false;root.add_child(car)
		while not car.model_ready:await process_frame
		car.free();await process_frame
	var winding: Array=[]
	for name: String in ["game/assets/vehicles/compact_coachwork_v3/front_coachwork.res","game/assets/vehicles/racing_simple_v1/compact/front_coachwork_simple.res"]:
		var old: Mesh=load(WORK.path_join("before").path_join(name));var current: Mesh=load("res://"+name.trim_prefix("game/"))
		check(shape_signature(old)==shape_signature(current),"all native triangle positions/normals/UVs exact independent of winding")
		var bad: int=0
		var faces: PackedVector3Array=current.get_faces()
		for i: int in range(0,faces.size(),3):
			if (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).z<=0:bad+=1
		check(bad==0,"all native fascia faces outward")
		winding.append({"path":name,"triangles":faces.size()/3,"backwards":bad})
	FileAccess.open(OUT.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"panels":panels,"native":winding,"costs":costs},"  "))
	print("RGC_GEOMETRY ",checks," checks, ",failures," failures; ",panels);quit(1 if failures else 0)
