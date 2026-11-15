extends SceneTree
const WORK: String="res://../build/volt-reflection-smoothing-2026-11-15"
const OUT: String="res://../docs/evidence/volt-reflection-smoothing-2026-11-15"
const D=preload("res://vehicle/car_detail_reduction.gd")
func hit(tree: TriangleMesh,p: Vector3,side: float) -> Vector3:
	var found: Dictionary=tree.intersect_ray(p+Vector3(side*0.20,0,0),Vector3(-side,0,0))
	assert(not found.is_empty(),"Every existing strip point retains native body backing")
	return Vector3(found.position.x+side*0.00105,p.y,p.z)
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("contours")))
	var rows: Array=[];var files: Dictionary={}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/car_step10_volt.json")):
		var side: float=-1 if "-1.0" in str(row.name) else 1
		var label: String="ReferenceSide-1_0" if side<0 else "ReferenceSide1_0"
		var backing: Mesh=load(WORK.path_join("candidates").path_join(label+".res"))
		var tree: TriangleMesh=backing.generate_triangle_mesh()
		var path: String="res://assets/vehicles/electric_rear_lamp_gaps_v1/"+str(row.file)
		var old: ArrayMesh=load(path);var a: Array=old.surface_get_arrays(0)
		var p: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var t: PackedFloat32Array=a[Mesh.ARRAY_TANGENT];var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
		var movement: float=0
		for at: int in range(p.size()):
			var half: Vector3=Vector3(t[at*4],t[at*4+1],t[at*4+2])*uv[at].y
			var centre: Vector3=hit(tree,p[at]-half,side)
			var point: Vector3=hit(tree,p[at],side)
			movement=maxf(movement,point.distance_to(p[at]));p[at]=point
			var delta: Vector3=point-centre;var axis: Vector3=delta.normalized()
			t[at*4]=axis.x;t[at*4+1]=axis.y;t[at*4+2]=axis.z;uv[at].y=delta.length()
		a[Mesh.ARRAY_VERTEX]=p;a[Mesh.ARRAY_TANGENT]=t;a[Mesh.ARRAY_TEX_UV]=uv
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
		for key: StringName in old.get_meta_list():mesh.set_meta(key,old.get_meta(key))
		mesh.set_meta("volt_contour_backing",D.mesh_key(backing))
		assert(mesh.get_faces().size()==old.get_faces().size())
		assert(ResourceSaver.save(mesh,WORK.path_join("contours").path_join(row.file),ResourceSaver.FLAG_COMPRESS)==OK)
		files[str(row.name)+"_fitted_v2_simple"]={"file":row.file,"path":"game/"+path.trim_prefix("res://")}
		rows.append({"name":row.name,"maximum_move_m":movement,"triangles":mesh.get_faces().size()/3})
	FileAccess.open(OUT.path_join("contours.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":files,"rows":rows},"  "))
	print("VSR_CONTOURS 14 strips retain topology and exact Y/Z paths; refitted at 1.05mm");quit()
