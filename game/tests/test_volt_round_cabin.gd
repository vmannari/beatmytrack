extends SceneTree
## Actual canopy/rail/cowl/shoulder joins in both detail levels.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var count := 0
var fails := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
 count += 1
 if not ok:
  fails += 1
  print("FAIL: ",message)
func edge(mesh: MeshInstance3D, axis: int, value: float) -> Array[Vector3]:
 var arrays: Array = mesh.mesh.surface_get_arrays(0)
 var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
 var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var result: Array[Vector3] = []
 for i: int in range(points.size()):
  if absf(uv[i][axis]-value)<0.00001: result.append(mesh.transform*points[i])
 return result
func edge_normal(mesh: MeshInstance3D, axis: int, value: float) -> Array[Vector3]:
 var arrays: Array = mesh.mesh.surface_get_arrays(0)
 var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 var result: Array[Vector3] = []
 for i: int in range(normals.size()):
  if absf(uv[i][axis]-value)<0.00001: result.append((mesh.transform.basis*normals[i]).normalized())
 return result
func path_gap(first: Array[Vector3], path: Array[Vector3]) -> float:
 path.sort_custom(func(a: Vector3,b: Vector3)->bool:return a.x<b.x)
 var maximum := 0.0
 for p: Vector3 in first:
  var near := INF
  for i: int in range(path.size()-1):
   near=minf(near,p.distance_to(Geometry3D.get_closest_point_to_segment(p,path[i],path[i+1])))
  maximum=maxf(maximum,near)
 return maximum
func path_gap_z(first: Array[Vector3], path: Array[Vector3]) -> float:
 path.sort_custom(func(a: Vector3,b: Vector3)->bool:return a.z<b.z)
 var maximum := 0.0
 for p: Vector3 in first:
  var near := INF
  for i: int in range(path.size()-1):
   near=minf(near,p.distance_to(Geometry3D.get_closest_point_to_segment(p,path[i],path[i+1])))
  maximum=maxf(maximum,near)
 return maximum
func normal_angle(points: Array[Vector3], normals: Array[Vector3], other_points: Array[Vector3], other_normals: Array[Vector3]) -> float:
 var maximum := 0.0
 for i: int in range(points.size()):
  var closest := INF
  var index := -1
  for j: int in range(other_points.size()):
   var distance: float=points[i].distance_squared_to(other_points[j])
   if distance<closest:
    closest=distance
    index=j
  if index>=0: maximum=maxf(maximum,normals[i].angle_to(other_normals[index]))
 return rad_to_deg(maximum)
func max_dist(first: Array[Vector3], other: Array[Vector3]) -> float:
 var maximum := 0.0
 for p: Vector3 in first:
  var near := INF
  for q: Vector3 in other: near = minf(near,p.distance_to(q))
  maximum = maxf(maximum,near)
 return maximum
func run() -> void:
 preload("res://vehicle/prepared_car_cache.gd").enabled=false
 M.use_baked="--prepared" in OS.get_cmdline_user_args()
 M.meshes.clear()
 for simple: bool in [false,true]:
  var car:=CarVisual.new()
  car.vehicle_id="electric"
  car.simple_model=simple
  car.batch_parts=false
  car.cache_rest_pose=false
  root.add_child(car)
  while not car.model_ready: await process_frame
  var glass: MeshInstance3D=car.body.get_node_or_null("ReferenceCanopyGlass")
  var lrail: MeshInstance3D=car.body.get_node_or_null("ReferenceRoofRail0")
  var rrail: MeshInstance3D=car.body.get_node_or_null("ReferenceRoofRail1")
  var hood: MeshInstance3D=car.body.get_node_or_null("ReferenceHood")
  check(glass!=null and lrail!=null and rrail!=null and hood!=null,"canopy, rails and bonnet exist")
  if glass!=null and lrail!=null and rrail!=null and hood!=null:
   var arrays: Array=glass.mesh.surface_get_arrays(0)
   var high: float=-INF
   for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: high=maxf(high,point.y)
   var l: float=max_dist(edge(glass,0,0.0),edge(lrail,0,1.0))
   var r: float=max_dist(edge(glass,0,1.0),edge(rrail,0,0.0))
   var l_angle: float=normal_angle(edge(glass,0,0.0),edge_normal(glass,0,0.0),edge(lrail,0,1.0),edge_normal(lrail,0,1.0))
   var r_angle: float=normal_angle(edge(glass,0,1.0),edge_normal(glass,0,1.0),edge(rrail,0,0.0),edge_normal(rrail,0,0.0))
   var lower_front: Array[Vector3]=edge(glass,1,0.0)
   var cowl_gap: float=path_gap(lower_front,edge(hood,1,1.0))
   var center: Vector3=lower_front[0]
   for p: Vector3 in lower_front:
    if absf(p.x)<absf(center.x): center=p
   print("VOLT_CABIN_DETAIL: ",simple," high=",high," left=",l," right=",r," cowl=",center," gap=",cowl_gap," normals=",l_angle,",",r_angle)
   check(high<1.36 and high>1.30,"low roof crown")
   check(l<0.0001 and r<0.0001,"glass and roof rails meet")
   check(l_angle<1.0 and r_angle<1.0,"glass and rail normals agree")
   check(cowl_gap<0.006,"windscreen fits bonnet edge")
   check(absf(center.y-1.0)<0.005 and absf(center.z+0.9)<0.001,"windshield foot remains at the bonnet cowl")
   for side: String in ["-1_0","1_0"]:
    var sill: MeshInstance3D=car.body.get_node_or_null("ReferenceWindowBottom"+side)
    var flank: MeshInstance3D=car.body.get_node_or_null("ReferenceSide"+side)
    check(sill!=null and flank!=null,"window base and body flank exist "+side)
    if sill!=null and flank!=null:
     var flank_gap: float=path_gap_z(edge(sill,1,0.0),edge(flank,1,1.0))
     print("VOLT_CABIN_FLANK ",simple," ",side," gap=",flank_gap)
     check(flank_gap<0.006,"window base meets side shoulder "+side)
  car.free()
 print("VOLT_CABIN_FIT: ",count," checks, ",fails," failures")
 quit(1 if fails else 0)
