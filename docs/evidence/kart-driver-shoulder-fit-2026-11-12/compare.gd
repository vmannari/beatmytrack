extends SceneTree
func _initialize() -> void:
 var a: ArrayMesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
 var b: ArrayMesh = load("res://../docs/evidence/kart-driver-shoulder-fit-2026-11-12/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
 print("prefix ",a.get_meta("kart_suit_static_vertices")," old ",b.get_meta("kart_suit_static_vertices"))
 for surface: int in range(2):
  var aa: Array = a.surface_get_arrays(surface)
  var bb: Array = b.surface_get_arrays(surface)
  for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:
   if aa[attribute]==null or bb[attribute]==null: continue
   var bad: int = 0
   var delta: float = 0
   for i: int in range(mini(aa[attribute].size(),bb[attribute].size())):
    if surface==1 and attribute==Mesh.ARRAY_VERTEX and i<1754: continue
    if surface==1 and attribute==Mesh.ARRAY_VERTEX and i>=1754 and (i-1754)%(21*17)<11*17: continue
    if aa[attribute][i]!=bb[attribute][i]:
     bad+=1
     if attribute==0 and bad<7: print("DIFF ",i," ",aa[attribute][i]," old ",bb[attribute][i])
     if attribute in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL]: delta=maxf(delta,aa[attribute][i].distance_to(bb[attribute][i]))
   print(surface," attr ",attribute," mismatches ",bad," max ",delta)
 quit()
