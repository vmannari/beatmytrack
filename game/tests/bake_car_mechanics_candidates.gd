extends SceneTree
const WORK: String="res://../build/car-mechanics-2026-11-17"
const OUT: String="res://../docs/evidence/car-mechanics-2026-11-17"
const D=preload("res://vehicle/car_detail_reduction.gd")
const Split=preload("res://tests/support/kart_driver_split.gd")
var plan: Dictionary={"parts":{}}
func _initialize() -> void:run.call_deferred()
func corner(mesh: ArrayMesh,sf: int,pose: int) -> PackedByteArray:
	var packet: Dictionary=mesh.get("_surfaces")[sf]
	var n: int=packet.vertex_count
	var ps: int=RenderingServer.mesh_surface_get_format_vertex_stride(packet.format,n)
	var ns: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(packet.format,n)
	var ats: int=RenderingServer.mesh_surface_get_format_attribute_stride(packet.format,n)
	var raw: PackedByteArray=packet.vertex_data if pose<0 else packet.blend_shapes.slice(pose*n*(ps+ns),(pose+1)*n*(ps+ns))
	var result:=PackedByteArray()
	for i: int in mesh.surface_get_arrays(sf)[Mesh.ARRAY_INDEX]:
		result.append_array(raw.slice(i*ps,(i+1)*ps))
		result.append_array(raw.slice(n*ps+i*ns,n*ps+(i+1)*ns))
		if ats:result.append_array(packet.attribute_data.slice(i*ats,(i+1)*ats))
	return result
func candidate(source: Mesh,key: String,mesh: ArrayMesh) -> void:
	var packets: Array=mesh.get("_surfaces").duplicate(true)
	for p: Dictionary in packets:p.aabb=source.get_aabb()
	mesh.set("_surfaces",packets);mesh.custom_aabb=source.get_aabb()
	mesh.set_meta("car_pass10_source",key)
	var name: String=key+".res"
	assert(ResourceSaver.save(mesh,WORK.path_join("candidates").path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
	plan.parts[key]={"file":name,"before":source.get_faces().size()/3,"after":mesh.get_faces().size()/3}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("candidates")))
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var pins: Dictionary={}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("survey.json"))):
		if row.vehicle=="forklift" and row.name=="ChainPin" and int(row.triangles)==20:pins[row.key]=true
	for key: String in catalog:
		var row: Dictionary=catalog[key]
		if pins.has(key):
			var cylinder:=CylinderMesh.new();cylinder.top_radius=0.009;cylinder.bottom_radius=0.009;cylinder.height=0.066;cylinder.radial_segments=5;cylinder.rings=0
			var arrays: Array=cylinder.surface_get_arrays(0)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices:=PackedInt32Array()
			var old: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for at: int in range(0,old.size(),3):
				if absf(normals[old[at]].y)<0.5:indices.append_array(old.slice(at,at+3))
			for side: float in [-1.0,1.0]:
				var cap: Array[int]=[]
				for at: int in range(points.size()):
					if normals[at].y*side>0.9 and Vector2(points[at].x,points[at].z).length()>0.008:cap.append(at)
				cap.sort_custom(func(a: int,b: int) -> bool:return atan2(points[a].z,points[a].x)<atan2(points[b].z,points[b].x))
				# The engine repeats the seam vertex. Its planar attributes agree.
				if points[cap[0]].distance_to(points[cap[-1]])<0.000001:cap.remove_at(cap.size()-1)
				var unique: Array[int]=[]
				for at: int in cap:
					if unique.is_empty() or points[at].distance_to(points[unique[-1]])>0.000001:unique.append(at)
				cap=unique
				for at: int in range(1,cap.size()-1):
					var tri: Array[int]=[cap[0],cap[at],cap[at+1]]
					if (points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]]).y*side>0:tri.reverse()
					indices.append_array(tri)
			arrays[Mesh.ARRAY_INDEX]=indices
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			candidate(row.source,key,mesh)
	var path: String="res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver_steering.res"
	var source: ArrayMesh=load(path)
	var compact:=ArrayMesh.new();compact.blend_shape_mode=source.blend_shape_mode
	for at: int in range(source.get_blend_shape_count()):compact.add_blend_shape(source.get_blend_shape_name(at))
	var packets: Array=[];var before_vertices: int=0;var after_vertices: int=0;var checks: int=0
	var helper:=Split.new()
	for sf: int in range(source.get_surface_count()):
		assert(source.get("_surfaces")[sf].get("skin_data",PackedByteArray()).is_empty())
		packets.append(helper.rebuild_packet(source,sf,source.surface_get_arrays(sf)[Mesh.ARRAY_INDEX],true))
		before_vertices+=source.get("_surfaces")[sf].vertex_count;after_vertices+=packets[-1].vertex_count
	compact.set("_surfaces",packets);compact.custom_aabb=source.custom_aabb
	for property: StringName in source.get_meta_list():compact.set_meta(property,source.get_meta(property))
	for sf: int in range(source.get_surface_count()):
		for pose: int in range(-1,source.get_blend_shape_count()):
			assert(corner(source,sf,pose)==corner(compact,sf,pose),"Every rendered corner and morph sample retains its exact encoded records")
			checks+=1
	assert(source.get_faces().size()==compact.get_faces().size())
	assert(ResourceSaver.save(compact,WORK.path_join("candidates/driver_steering.res"),ResourceSaver.FLAG_COMPRESS)==OK)
	plan.driver={"file":"driver_steering.res","source_path":"game/"+path.trim_prefix("res://"),"before":source.get_faces().size()/3,"after":compact.get_faces().size()/3,"before_vertices":before_vertices,"after_vertices":after_vertices,"before_bytes":helper.payload(source),"after_bytes":helper.payload(compact),"exact_corner_checks":checks}
	FileAccess.open(OUT.path_join("selected-plan.json"),FileAccess.WRITE).store_string(JSON.stringify(plan,"  "))
	print("MECHANICS_CANDIDATES ",plan);quit()
