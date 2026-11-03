extends SceneTree
const Surface=preload("res://vehicle/forklift_kit_surface.gd")

func _initialize() -> void:
	var holder:=Node3D.new()
	root.add_child(holder)
	var paint:=StandardMaterial3D.new()
	var pockets: Array[Rect2]=[Rect2(-0.45,0.81,0.90,0.47)]
	for simple: bool in [false,true]:
		var node: MeshInstance3D=Surface.deck(holder,"probe",Rect2(-0.695,0.645,1.39,0.79),1.499,0.022,pockets,paint,paint,simple)
		var faces: PackedVector3Array=node.mesh.get_faces()
		var edges: Dictionary={}
		for i: int in range(0,faces.size(),3):
			for edge: int in range(3):
				var a: Vector3=faces[i+edge]; var b: Vector3=faces[i+(edge+1)%3]
				var sa: String=str(Vector3i(roundi(a.x*1000000),roundi(a.y*1000000),roundi(a.z*1000000)))
				var sb: String=str(Vector3i(roundi(b.x*1000000),roundi(b.y*1000000),roundi(b.z*1000000)))
				var key: String=sa+"/"+sb if sa<sb else sb+"/"+sa
				if not edges.has(key): edges[key]=[]
				edges[key].append([a,b])
		var count: int=0
		for key: String in edges:
			if edges[key].size()!=2:
				if count<24: print("SEAM ",simple," ",key," ",edges[key])
				count+=1
		print("SEAM_TOTAL ",simple," ",count)
	quit()
