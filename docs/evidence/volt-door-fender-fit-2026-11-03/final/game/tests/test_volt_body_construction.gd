extends SceneTree
## Independent triangle checks: required body coverage, closed shells and budget.
const K=preload("res://vehicle/electric_kits.gd")
const B=preload("res://vehicle/electric_reference_body.gd")
var checks:=0
var failures:=0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",message)

func hit(faces: PackedVector3Array,start: Vector3,end: Vector3) -> bool:
	for triangle: int in range(faces.size()/3):
		var a: Vector3=faces[triangle*3]
		var b: Vector3=faces[triangle*3+1]
		var c: Vector3=faces[triangle*3+2]
		# Fast projected bounds reject most triangles before the exact test.
		if start.x==end.x and (start.x<minf(a.x,minf(b.x,c.x))-0.00001 or start.x>maxf(a.x,maxf(b.x,c.x))+0.00001): continue
		if start.y<minf(a.y,minf(b.y,c.y))-0.00001 or start.y>maxf(a.y,maxf(b.y,c.y))+0.00001: continue
		if start.z==end.z and (start.z<minf(a.z,minf(b.z,c.z))-0.00001 or start.z>maxf(a.z,maxf(b.z,c.z))+0.00001): continue
		if Geometry3D.segment_intersects_triangle(start,end,a,b,c)!=null: return true
	return false

func watertight(faces: PackedVector3Array,label: String) -> void:
	var edges: Dictionary={}
	for triangle: int in range(faces.size()/3):
		for edge: int in range(3):
			var a: Vector3=faces[triangle*3+edge].snapped(Vector3.ONE*0.000001)
			var b: Vector3=faces[triangle*3+(edge+1)%3].snapped(Vector3.ONE*0.000001)
			var key: Array=[a,b]
			if b<a: key.reverse()
			edges[key]=int(edges.get(key,0))+1
	var invalid:=0
	for count: int in edges.values():
		if count!=2: invalid+=1
	check(invalid==0,label+" has no open/nonmanifold shell edges: "+str(invalid))

func run() -> void:
	preload("res://vehicle/electric_reference_mesh.gd").use_baked=false
	var control: bool="--control" in OS.get_cmdline_user_args()
	var builder: Script=load("res://../docs/evidence/volt-body-refinement-2026-11-03/task-base/game/vehicle/electric_kits.gd") if control else K
	var selected:=PackedStringArray()
	var report_path: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--options="): selected=argument.trim_prefix("--options=").split(",")
		if argument.begins_with("--report="): report_path=argument.trim_prefix("--report=")
	var report: Array=[]
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.paint_materials={"body":CompactFinish.paint(Color("b8bbb9")),"accent":CompactFinish.paint(Color("647779"))}
		for option: Array in VehicleCustomisation.options("body","electric").slice(1):
			if not selected.is_empty() and str(option[0]) not in selected: continue
			var label: String=str(option[0])+" simple="+str(simple)
			var frame:=Node3D.new()
			builder.body_kit(car,frame,str(option[0]))
			var shells: Dictionary={}
			var regions: Dictionary={}
			var faces: PackedVector3Array=[]
			var bad_normals:=0
			var bad_triangles:=0
			for mesh: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
				check(mesh.mesh!=null and mesh.mesh.get_surface_count()>0,label+" populated "+str(mesh.name))
				if mesh.mesh==null or mesh.mesh.get_surface_count()==0: continue
				var triangles: PackedVector3Array=mesh.mesh.get_faces()
				faces.append_array(triangles)
				var name_value: String=str(mesh.name)
				if name_value.ends_with("Face"):
					regions[name_value.trim_prefix("VoltBodyV1_"+str(option[0])).trim_suffix("Face")]=triangles
				var group: String=""
				for suffix: String in ["Face","Back","Return0","Return1","Return2","Return3"]:
					if name_value.ends_with(suffix): group=name_value.trim_suffix(suffix); break
				if not group.is_empty():
					var accumulated: PackedVector3Array=shells.get(group,PackedVector3Array())
					accumulated.append_array(triangles)
					shells[group]=accumulated
				var normals: PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
				for normal: Vector3 in normals:
					if not normal.is_finite() or absf(normal.length()-1.0)>0.002: bad_normals+=1
				for t: int in range(triangles.size()/3):
					if (triangles[t*3+1]-triangles[t*3]).cross(triangles[t*3+2]-triangles[t*3]).length_squared()<1e-18:
						bad_triangles+=1
						print("DEGENERATE ",label," ",mesh.name," ",triangles[t*3]," ",triangles[t*3+1]," ",triangles[t*3+2])
			check(bad_normals==0,label+" finite unit normals "+str(bad_normals))
			check(bad_triangles==0,label+" nondegenerate triangles "+str(bad_triangles))
			check(faces.size()/3<=(9000 if simple else 30000),label+" body triangle budget "+str(faces.size()/3))
			check(shells.size()>=12,label+" complete formed assemblies")
			for group: String in shells: watertight(shells[group],label+" "+group)
			for rear: bool in [false,true]:
				var direction: Vector3=Vector3.BACK if rear else Vector3.FORWARD
				for across: float in [0.015,0.045,0.10,0.20,0.35,0.50,0.65,0.80,0.90,0.955,0.985]:
					for height: float in [0.025,0.10,0.20]:
						var p: Vector3=B.cap_point(rear,across,height)
						check(hit(regions.get("Rear" if rear else "Front",faces),p+direction*0.30,p-direction*0.01),label+" complete bumper "+str(rear)+" "+str(across)+"/"+str(height))
			for side: float in [-1.0,1.0]:
				var direction:=Vector3(side,0,0)
				var side_name: String=str(side).replace(".","_")
				for z: float in [-0.87,-0.72,-0.45,0.0,0.45,0.72,0.87]:
					# Body skirts belong below the factory doors (bottom 0.31).
					for y: float in [0.25,0.265,0.28]:
						var p: Vector3=B.side_point(side,z,y)
						check(hit(regions.get("Sill"+side_name,faces),p+direction*0.20,p-direction*0.01),label+" complete sill "+str(side)+" "+str(z)+"/"+str(y))
				for z: float in [-2.025,-1.97,1.97,2.025]:
					for y: float in [0.26,0.32,0.38]:
						var p: Vector3=B.flank_point(side,z,y)
						check(hit(regions.get(("Rear" if z>0.0 else "Front")+"Corner"+side_name,faces),p+direction*0.20,p-direction*0.01),label+" wrapped bumper corner "+str(side)+" "+str(z)+"/"+str(y))
			report.append({"id":option[0],"simple":simple,"triangles":faces.size()/3,"closed_shells":shells.size()})
			print("VOLT_BODY_CHECKED ",label)
			frame.free()
		car.free()
	var path: String="res://../docs/evidence/volt-body-refinement-2026-11-03/construction"+("-control" if control else "")+".json"
	if not report_path.is_empty(): path=report_path
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"choices":report},"\t")+"\n")
	print("VOLT_BODY_CONSTRUCTION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
