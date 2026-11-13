extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var car:=CarVisual.new();car.vehicle_id="super_rally";car.simple_model=true;car.batch_parts=false
 preload("res://vehicle/modular_car_base.gd").enabled=false
 preload("res://vehicle/modular_car_kits.gd").enabled=false
 root.add_child(car)
 while not car.model_ready:await process_frame
 for y:float in [.77,.79,.81,.84,.87]:
  var hits:Array=[]
  for mesh:MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
   if mesh.mesh==null:continue
   var t:Transform3D=car.global_transform.affine_inverse()*mesh.global_transform
   var faces:PackedVector3Array=mesh.mesh.get_faces()
   for i:int in range(0,faces.size(),3):
    var hit:Variant=Geometry3D.segment_intersects_triangle(Vector3(0,y,3),Vector3(0,y,1.8),t*faces[i],t*faces[i+1],t*faces[i+2])
    if hit!=null:hits.append([hit.z,str(mesh.name),str(mesh.get_active_material(0).albedo_color) if mesh.get_active_material(0) is StandardMaterial3D else "shader"])
  hits.sort_custom(func(a:Array,b:Array)->bool:return a[0]>b[0]);print("SURFACE_PICK ",y," ",hits.slice(0,5))
 car.free();quit()
