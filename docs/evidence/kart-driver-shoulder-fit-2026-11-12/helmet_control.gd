extends SceneTree
func _initialize() -> void:
 var a: ArrayMesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res")
 var b: ArrayMesh = load("res://../docs/evidence/kart-driver-shoulder-fit-2026-11-12/concurrent-layout/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res")
 var aa: Array = a.get("_surfaces")
 var bb: Array = b.get("_surfaces")
 var stable: bool = true
 for surface: int in range(4):
  var ma: Material = aa[surface].material
  var mb: Material = bb[surface].material
  for property: String in ["albedo_color","metallic","roughness","metallic_specular","cull_mode","shading_mode","diffuse_mode","transparency"]: stable = stable and ma.get(property)==mb.get(property)
  aa[surface].erase("material")
  bb[surface].erase("material")
  stable = stable and aa[surface]==bb[surface]
 print("HELMET_RAW_PACKETS_AND_FINISH ",stable," old bounds ",b.custom_aabb," new ",a.custom_aabb)
 quit(0 if stable else 1)
