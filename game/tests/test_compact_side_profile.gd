extends SceneTree
## CG09: inspect emitted window apertures/door seams and actual Garage views.
var checks: int=0
var failures: int=0
var output: String="res://../docs/evidence/compact-side-profile-2026-10-10"
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)

func bounds(node: Node3D,metal_only: bool=false) -> AABB:
	var result: AABB
	var first: bool=true
	for part: Node in node.get_children():
		if part is not MeshInstance3D:continue
		for vertex: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point: Vector3=part.transform*vertex
			if metal_only and point.y>1.015:continue
			result=AABB(point,Vector3.ZERO) if first else result.expand(point)
			first=false
	return result

func capture(view: CarShowroom,label: String,yaw: float,elevation: float,zoom: float) -> void:
	view.yaw=yaw
	view.elevation=elevation
	view.set_zoom(zoom)
	for frame: int in range(12):await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)

func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var model:=CarVisual.new()
	model.batch_parts=false
	root.add_child(model)
	for suffix: String in ["Left","Right"]:
		var door: MeshInstance3D=model.body.get_node("DoorWindow"+suffix+"Glass")
		var quarter: MeshInstance3D=model.body.get_node("QuarterWindow"+suffix+"Glass")
		var door_seal: MeshInstance3D=model.body.get_node("DoorWindow"+suffix+"Seal")
		var quarter_seal: MeshInstance3D=model.body.get_node("QuarterWindow"+suffix+"Seal")
		var a: AABB=door.mesh.get_aabb()
		var b: AABB=quarter.mesh.get_aabb()
		var sa: AABB=door_seal.mesh.get_aabb()
		var sb: AABB=quarter_seal.mesh.get_aabb()
		check(absf(a.position.y-b.position.y)<0.001,"actual glass sill heights align "+suffix)
		check(absf(a.end.y-b.end.y)<0.001,"actual glass roof heights align "+suffix)
		check(absf(sa.position.y-sb.position.y)<0.001 and absf(sa.end.y-sb.end.y)<0.001,"actual opening rails align "+suffix)
		check(door_seal.material_override==quarter_seal.material_override,"matching window trim "+suffix)
		check(door.material_override==quarter.material_override,"matching glass finish "+suffix)
		check(sb.position.z-sa.end.z>0.055 and sb.position.z-sa.end.z<0.085,"slim aligned opening pillar "+suffix)
		var seams: Node3D=model.body.get_node("DoorSeams"+suffix)
		var metal: AABB=bounds(seams,true)
		check(metal.position.y<0.45 and metal.position.y>0.40,"door reaches rocker "+suffix)
		check(metal.size.z>1.50,"long hatchback door "+suffix)
		var pillar: float=(sa.end.z+sb.position.z)*0.5
		check(absf(metal.end.z-pillar)<0.008,"actual door rear aligns with window pillar "+suffix)
		check(bounds(seams).end.y>a.end.y,"door frame encloses window "+suffix)
		for stroke: Node3D in seams.get_children():
			if stroke.position.y>1.01:continue
			var floor: float=0.33
			for axle: float in [-1.28,1.28]:
				var offset: float=absf(stroke.position.z-axle)
				if offset<0.421:floor=maxf(floor,0.37+sqrt(0.421*0.421-offset*offset))
			check(stroke.position.y>floor+0.01,"actual door seam clears wheel opening "+suffix)
		print("SIDE_PROFILE ",suffix," glass rails ",a.position.y," ",a.end.y," quarter ",b.position.y," ",b.end.y," metal bounds ",metal)
	model.queue_free()
	await process_frame
	var directory: String="user://compact_side_profile_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(directory.path_join("records.json"))
	app.library=TrackLibrary.new(directory)
	app.cloud_root_override=directory.path_join("cloud")
	root.size=Vector2i(1280,720)
	root.add_child(app)
	while not app.startup_complete:await process_frame
	VehicleCatalog.selected="compact"
	app._show_screen("garage")
	await create_timer(0.45).timeout
	var view: CarShowroom=app.root_ui.find_child("GarageShowroom",true,false)
	await capture(view,"side-right-1280",PI/2,0.10,0.74)
	await capture(view,"side-left-1280",-PI/2,0.10,0.74)
	await capture(view,"front-quarter-1280",0.70,0.20,0.77)
	await capture(view,"rear-quarter-1280",2.35,0.22,0.77)
	var livery: Dictionary=VehicleLivery.defaults("compact")
	livery.colors.body="804439"
	livery.colors.accent="b7af9c"
	var parent: Node=view
	while parent is not GaragePage:parent=parent.get_parent()
	var page: GaragePage=parent as GaragePage
	page._preview_color(Color(livery.colors.body),"body")
	page._preview_color(Color(livery.colors.accent),"accent")
	page._update_pickers()
	await capture(view,"painted-side-1280",PI/2,0.10,0.74)
	root.size=Vector2i(960,540)
	page._reset()
	await capture(view,"side-right-960",PI/2,0.10,0.74)
	app.queue_free()
	await process_frame
	print("COMPACT_SIDE_PROFILE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
