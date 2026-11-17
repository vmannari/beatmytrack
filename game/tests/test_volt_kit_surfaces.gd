extends SceneTree
const K = preload("res://vehicle/electric_kits.gd")
const Body = preload("res://vehicle/electric_body_kits.gd")
const M = preload("res://vehicle/electric_reference_mesh.gd")
const OUT = "res://../docs/evidence/volt-kit-review-2026-11-17"
var checks: int = 0
var failures: int = 0
var measurements: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("VKR_SURFACE_FAIL ", label)

func exposure(skin: MeshInstance3D, overlay: MeshInstance3D, axis: Vector3, label: String) -> void:
	var tree: TriangleMesh = skin.mesh.generate_triangle_mesh()
	var faces: PackedVector3Array = overlay.mesh.get_faces()
	var minimum: float = INF
	var maximum: float = -INF
	var misses: int = 0
	for at: int in range(0, faces.size(), 3):
		for point: Vector3 in [faces[at], faces[at+1], faces[at+2], (faces[at]+faces[at+1]+faces[at+2])/3.0]:
			var hit: Dictionary = tree.intersect_ray(point+axis*0.20, -axis)
			if hit.is_empty():
				misses += 1
				continue
			var gap: float = axis.dot(point-hit.position)
			minimum = minf(minimum, gap)
			maximum = maxf(maximum, gap)
	check(not faces.is_empty() and misses == 0, label + " has complete actual backing")
	check(minimum >= 0.00030 and maximum <= 0.0015, label + " remains exposed and flush " + str([minimum,maximum]))
	measurements.append({"part": label, "minimum_gap_m": minimum, "maximum_gap_m": maximum, "misses": misses, "triangles": faces.size()/3})

func closed_shell(parent: Node3D, label: String) -> void:
	var edges: Dictionary = {}
	for part: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
		var faces: PackedVector3Array = part.mesh.get_faces()
		for at: int in range(0, faces.size(), 3):
			for edge: int in range(3):
				var a: Vector3 = faces[at+edge].snapped(Vector3.ONE*0.000001)
				var b: Vector3 = faces[at+(edge+1)%3].snapped(Vector3.ONE*0.000001)
				var pair: Array = [a,b] if a < b else [b,a]
				edges[pair] = int(edges.get(pair,0))+1
	var invalid: int = 0
	for count: int in edges.values():
		if count != 2: invalid += 1
	check(invalid == 0, label + " has closed metal and returns " + str(invalid))

func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	var builder: Script = load("res://../build/volt-kit-review-2026-11-17/before/game/vehicle/electric_kits.gd") if before else K
	var body_builder: Script = load("res://../build/volt-kit-review-2026-11-17/before/game/vehicle/electric_body_kits.gd") if before else Body
	M.use_baked = false
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.paint_materials = {"body": CompactFinish.paint(Color("b8bbb9")), "accent": CompactFinish.paint(Color("647779"))}
		for option: Array in VehicleCustomisation.options("hood","electric").slice(1):
			var frame := Node3D.new()
			builder.hood(car,frame,str(option[0]))
			var skin: MeshInstance3D = frame.get_child(0)
			exposure(skin,frame.get_child(1),Vector3.UP,str(option[0])+" line simple="+str(simple))
			if option[0] == "volt_carbon": exposure(skin,frame.get_child(2),Vector3.UP,"carbon simple="+str(simple))
			frame.free()
		for option: String in ["volt_lip","volt_ducktail"]:
			var frame := Node3D.new()
			builder.aero(car,frame,option)
			closed_shell(frame,option+" simple="+str(simple))
			frame.free()
		var disc := Node3D.new()
		car.customisation.rims = "volt_disc"
		builder.rim(car,disc,1.0)
		var cover: MeshInstance3D = disc.find_child("VoltAeroDisc_1_0",false,false)
		check(cover.mesh.get_aabb().position.x > 0.155,"Aero disc clears the 149mm brake caliper front")
		disc.free()
		var twin := Node3D.new()
		builder.aero(car,twin,"volt_twin")
		var upper: MeshInstance3D = twin.find_child("VoltWingLowerV2_volt_twin1",false,false)
		for support: MeshInstance3D in twin.find_children("VoltWingSupportV2_*","MeshInstance3D",false,false):
			check((support.mesh.get_aabb().end+support.position).y >= upper.mesh.get_aabb().position.y,"Both twin-wing blades have continuous support")
		twin.free()
		# The complete native review covers all 15 bodies. These extremes also
		# exercise both inlay outlines and the highest valance against triangles.
		for option: String in ["volt_street","volt_wide","volt_race"]:
			var frame := Node3D.new()
			body_builder.build(car,frame,option,builder.index_for("body",option))
			var prefix: String = "VoltBodyV1_"+option
			exposure(frame.find_child(prefix+"FrontFace",false,false),frame.find_child(prefix+"FrontIntake",false,false),Vector3.FORWARD,option+" intake simple="+str(simple))
			exposure(frame.find_child(prefix+"RearFace",false,false),frame.find_child(prefix+"RearValance",false,false),Vector3.BACK,option+" valance simple="+str(simple))
			for side: float in [-1.0,1.0]:
				var suffix: String = str(side).replace(".","_")
				exposure(frame.find_child(prefix+"Sill"+suffix+"Face",false,false),frame.find_child(prefix+"SillInlay"+suffix,false,false),Vector3(side,0,0),option+" sill simple="+str(simple))
			frame.free()
		car.free()
	if not before:
		check(K.hood_mesh_bank_valid(),"Hood bank source guard is current")
		var bank: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(K.HOOD_MESH_ROOT.path_join("manifest.json")))
		for row: Dictionary in bank.meshes:
			check(M.meshes.has(row.key),"Every hood-bank mesh was regenerated from current source")
			if M.meshes.has(row.key):
				check(var_to_bytes(M.meshes[row.key].surface_get_arrays(0)).hex_encode().sha256_text() == row.arrays_sha256,"Actual rebuilt bank equals fresh source arrays")
	FileAccess.open(OUT.path_join("surfaces-before.json" if before else "surfaces.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"  "))
	print("VKR_SURFACES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
