extends SceneTree
## Optional cover profiles must leave the owner's accepted cabin roofs exact.
const Current=preload("res://vehicle/forklift_kit_surface.gd")
const Before=preload("res://../docs/evidence/forklift-cover-guard-variation-2026-11-03/before/game/vehicle/forklift_kit_surface.gd")
var checks: int=0
var failures: int=0

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value:
		failures+=1
		print("FAIL: ",label)

func run() -> void:
	var holder:=Node3D.new()
	root.add_child(holder)
	var cases: Array[Array]=[
		[Rect2(-0.77,-0.93,1.54,1.88),2.65,0.018,[]],
		[Rect2(-0.765,-0.97,1.53,0.64),2.60,0.018,[]],
		[Rect2(-0.695,0.645,1.39,0.79),1.499,0.022,[Rect2(-0.45,0.81,0.90,0.47)]]]
	for simple: bool in [false,true]:
		for parameters: Array in cases:
			var pockets: Array[Rect2]=[]
			for pocket: Rect2 in parameters[3]: pockets.append(pocket)
			var before: MeshInstance3D=Before.deck(holder,"Before",parameters[0],parameters[1],parameters[2],pockets,null,null,simple)
			var current: MeshInstance3D=Current.deck(holder,"Current",parameters[0],parameters[1],parameters[2],pockets,null,null,simple)
			check(before.mesh.get_surface_count()==current.mesh.get_surface_count(),"retained deck surface count")
			var exact: bool=true
			for surface: int in range(before.mesh.get_surface_count()):
				if before.mesh.surface_get_arrays(surface)!=current.mesh.surface_get_arrays(surface): exact=false
			check(exact,"all retained vertex, normal, UV and index buffers exact")
			check(before.mesh.get_aabb()==current.mesh.get_aabb(),"retained roof bounds exact")
			before.free(); current.free()
	holder.free()
	print("FORKLIFT_COVER_DECKS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
