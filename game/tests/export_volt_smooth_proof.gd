extends SceneTree
const WORK: String="res://../build/volt-reflection-smoothing-2026-11-15"
func arrays(mesh: Mesh) -> Dictionary:
	var a: Array=mesh.surface_get_arrays(0);var p: Array=[];var n: Array=[];var uv: Array=[]
	for v: Vector3 in a[Mesh.ARRAY_VERTEX]:p.append([v.x,v.y,v.z])
	for v: Vector3 in a[Mesh.ARRAY_NORMAL]:n.append([v.x,v.y,v.z])
	for v: Vector2 in a[Mesh.ARRAY_TEX_UV]:uv.append([v.x,v.y])
	return {"p":p,"n":n,"uv":uv,"indices":Array(a[Mesh.ARRAY_INDEX]),"tangent":Array(a[Mesh.ARRAY_TANGENT])}
func _initialize() -> void:
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog");var data: Dictionary={};var contours: Array=[]
	for label: String in catalog:
		if label=="ReferenceRear":continue
		data[label]={"before":arrays(catalog[label].current),"native":arrays(catalog[label].native),"after":arrays(load(WORK.path_join("candidates").path_join(label+".res")))}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/car_step10_volt.json")):
		contours.append({"name":row.name,"before":arrays(load("res://assets/vehicles/electric_rear_lamp_gaps_v1/"+str(row.file))),"after":arrays(load(WORK.path_join("contours").path_join(row.file)))})
	FileAccess.open(WORK.path_join("proof.json"),FileAccess.WRITE).store_string(JSON.stringify({"parts":data,"contours":contours}));quit()
