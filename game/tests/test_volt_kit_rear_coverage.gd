extends SceneTree
const M = preload("res://vehicle/electric_reference_mesh.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const Body = preload("res://vehicle/electric_body_kits.gd")
const K = preload("res://vehicle/electric_kits.gd")
const OUT = "res://../docs/evidence/volt-kit-review-2026-11-17"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var rows: Array = []
	var source: bool = "--source" in OS.get_cmdline_user_args()
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.editable_kits = true
		var original := PackedVector3Array()
		for label: String in ["SportRearValance","SportDiffuserFin0","SportDiffuserFin1","SportDiffuserFin2","SportDiffuserFin3","SportDiffuserFin4"]:
			var key: String = label + ("_simple" if simple else "")
			var native: Mesh = load(M.ASSET_ROOT.path_join(key.sha256_text().left(24)+".res"))
			original.append_array(native.get_faces())
		for option: Array in VehicleCustomisation.options("body","electric").slice(1):
			var module: Node3D
			if source:
				module = Node3D.new()
				var index: int = K.index_for("body",str(option[0]))
				M.patch(module,"RearProbe_"+str(option[0]),64,24 if simple else 12,func(u: float,v: float)->Vector3:return Body.cap_surface(index,true,u,v),CompactFinish.paint(Color.WHITE),Vector3.BACK,simple)
			else: module = load(Kits.path_for(car,"body",str(option[0]))).instantiate()
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for part: MeshInstance3D in module.find_children("*","MeshInstance3D",true,false):
				for point: Vector3 in part.mesh.get_faces(): tool.add_vertex(point)
			var mesh: Mesh = tool.commit()
			var tree: TriangleMesh = mesh.generate_triangle_mesh()
			var minimum: float = INF
			var misses: int = 0
			for point: Vector3 in original:
				var hit: Dictionary = tree.intersect_ray(point+Vector3.BACK*0.30,Vector3.FORWARD)
				if hit.is_empty(): misses += 1
				else: minimum = minf(minimum,hit.position.z-point.z)
			checks += 1
			if misses > 0 or minimum < 0.002:
				failures += 1
				printerr("VKR_REAR_FAIL ",option[0]," simple=",simple," minimum=",minimum," misses=",misses)
			rows.append({"option":option[0],"simple":simple,"minimum_coverage_m":minimum,"misses":misses})
			module.free()
		car.free()
	var suffix: String = "-source" if source else "-before" if "--before" in OS.get_cmdline_user_args() else ""
	FileAccess.open(OUT.path_join("rear-coverage"+suffix+".json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("VKR_REAR_COVERAGE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
