extends SceneTree
func _initialize() -> void:
 var directory: String="res://../build/challenger-convex-fenders-2026-11-16/native/"
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../build/challenger-convex-fenders-2026-11-16/trial-contours.json"))
 for tier: String in ["simple","full"]:
  var path: String=directory+tier+"_body_contour.res"
  var source: ArrayMesh=load(path)
  var arrays: Array=source.surface_get_arrays(0)
  var points:=PackedVector3Array()
  for value: Array in data[tier]:points.append(Vector3(value[0],value[1],value[2]))
  arrays[Mesh.ARRAY_VERTEX]=points
  var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  for meta: StringName in source.get_meta_list():result.set_meta(meta,source.get_meta(meta))
  assert(ResourceSaver.save(result,path)==OK)
 assert(DirAccess.copy_absolute("res://../build/challenger-convex-fenders-2026-11-16/trial-profile.json",directory+"hood_profile.json")==OK)
 print("TRIAL_NATIVE_SEATING_COMPLETE")
 quit()
