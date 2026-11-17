extends SceneTree
const WORK: String="res://../build/rally-grille-closure-2026-11-16"
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var holder: Node3D=load(WORK.path_join("compact-full-before.scn")).instantiate();root.add_child(holder)
	var faces: Array=[]
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		var local: PackedVector3Array=part.mesh.get_faces()
		for i: int in range(0,local.size(),3):
			faces.append([part.global_transform*local[i],part.global_transform*local[i+1],part.global_transform*local[i+2],str(part.name)])
	for y: float in [0.61,0.625,0.64,0.655,0.67,0.68,0.70]:
		var line: Array=[]
		for x: float in [-0.48,-0.24,0,0.24,0.48]:
			var origin:=Vector3(x,y,-3)*HandlingConfig.BODY_SCALE
			var nearest: float=INF;var front: bool=false;var label: String=""
			for tri: Array in faces:
				var hit: Variant=Geometry3D.ray_intersects_triangle(origin,Vector3.BACK,tri[0],tri[1],tri[2])
				if hit==null or hit.z>=nearest:continue
				nearest=hit.z;front=(tri[1]-tri[0]).cross(tri[2]-tri[0]).dot(Vector3.BACK)>0;label=tri[3]
			line.append([x,nearest/HandlingConfig.BODY_SCALE,front,label])
		print("RGC_RAY y=",y," ",line)
	holder.free();quit()
