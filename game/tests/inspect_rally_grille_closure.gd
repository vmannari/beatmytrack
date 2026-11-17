extends SceneTree
func _initialize() -> void:
 var mesh: Mesh=load("res://assets/vehicles/racing_simple_v1/compact/front_coachwork_simple.res")
 var points: PackedVector3Array=mesh.get_faces();var reversed: int=0
 for i: int in range(0,points.size(),3):
  if (points[i+1]-points[i]).cross(points[i+2]-points[i]).z<0:reversed+=1
 print("RGC_MASTER ",points.size()/3," triangles; backwards=",reversed);quit()
