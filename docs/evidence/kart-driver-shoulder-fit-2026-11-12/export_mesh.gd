extends SceneTree
func _initialize() -> void:
 var m: ArrayMesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
 var a: Array = m.surface_get_arrays(1)
 var p: Array = []
 for v: Vector3 in a[Mesh.ARRAY_VERTEX]: p.append([v.x,v.y,v.z])
 FileAccess.open("res://../docs/evidence/kart-driver-shoulder-fit-2026-11-12/mesh-debug.json",FileAccess.WRITE).store_string(JSON.stringify({"p":p,"i":Array(a[Mesh.ARRAY_INDEX]),"prefix":m.get_meta("kart_suit_static_vertices")}))
 quit()
