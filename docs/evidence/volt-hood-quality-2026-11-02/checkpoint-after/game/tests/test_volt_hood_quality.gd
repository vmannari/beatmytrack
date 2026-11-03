extends SceneTree
## Actual mesh/material constraints for the hood defect, on both model qualities.
const B=preload("res://vehicle/electric_reference_body.gd")
const Kits=preload("res://vehicle/modular_car_kits.gd")
var checks:=0
var failures:=0

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)

func run() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	var historical: bool="--historical" in OS.get_cmdline_user_args()
	var legacy: Script=load("res://../docs/evidence/volt-hood-quality-2026-11-02/before/game/vehicle/electric_kits.gd") if historical else null
	preload("res://vehicle/prepared_car_cache.gd").enabled=prepared
	preload("res://vehicle/modular_car_base.gd").enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=prepared
	Kits.enabled=prepared
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.editable_kits=true
		car.batch_parts=prepared
		car.cache_rest_pose=prepared
		car.livery=VehicleLivery.defaults("electric")
		root.add_child(car)
		while not car.model_ready: await process_frame
		for item: Array in VehicleCustomisation.options("hood","electric"):
			var parts: Dictionary=VehicleCustomisation.defaults()
			parts.hood=item[0]
			var hits: int=Kits.hits
			car.change_kit_parts(parts)
			if historical and item[0]!="stock":
				for frame: Node3D in car.kit_frames.hood:
					frame.get_parent().remove_child(frame)
					frame.queue_free()
				car.kit_frames.hood=[]
				legacy.hood(car,car.new_kit_frame("hood",car.body),str(item[0]))
			if prepared and item[0]!="stock": check(Kits.hits==hits+1,"prepared module used "+str(item[0]))
			for colour: String in ["bc3724","205a78"]:
				var finish: Dictionary=VehicleLivery.defaults("electric")
				finish.colors.body=colour
				car.apply_livery(finish)
				var area:=0.0
				var painted:=0.0
				var active:=true
				for frame: Node3D in car.kit_frames.hood:
					for node: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
						for surface: int in range(node.mesh.get_surface_count()):
							var material: Material=node.get_active_material(surface)
							active=active and material!=null
							var arrays: Array=node.mesh.surface_get_arrays(surface)
							var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
							var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
							var count: int=vertices.size() if indices.is_empty() else indices.size()
							for tri: int in range(0,count,3):
								var a: Vector3=vertices[tri if indices.is_empty() else indices[tri]]
								var b: Vector3=vertices[tri+1 if indices.is_empty() else indices[tri+1]]
								var c: Vector3=vertices[tri+2 if indices.is_empty() else indices[tri+2]]
								var value: float=(b-a).cross(c-a).length()*0.5
								area+=value
								if material==car.paint_materials.body: painted+=value
							if material==car.paint_materials.body:
								active=active and (material as StandardMaterial3D).albedo_color.is_equal_approx(Color(colour))
				check(active,"all surfaces bound and body colour updates "+str(item[0])+"/"+colour)
				check(area>0.5 and painted/area>(0.73 if item[0]=="volt_carbon" else 0.87),"paint covers the hood "+str(item[0])+" ratio="+str(painted/maxf(area,0.0001)))
			if not prepared and item[0]!="stock":
				var skin: MeshInstance3D=car.body.find_child("VoltHoodSkinV3_*" if historical else "VoltHoodSkinV4_*",true,false)
				check(skin!=null,"one continuous replacement skin "+str(item[0]))
				if skin==null: continue
				var arrays: Array=skin.mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var bounded:=true
				var joined:=true
				var shading:=true
				for n: int in range(vertices.size()):
					var stock: Vector3=B.hood_point(uv[n].x,uv[n].y)
					var delta: Vector3=vertices[n]-stock
					bounded=bounded and vertices[n].is_finite() and absf(delta.x)<0.000001 and absf(delta.z)<0.000001 and delta.y>=-0.0201 and delta.y<=0.0301
					if uv[n].x in [0.0,1.0] or uv[n].y in [0.0,1.0]: joined=joined and delta.length()<0.000001
					shading=shading and normals[n].is_finite() and normals[n].y>0.25 and absf(normals[n].length()-1.0)<0.001
				check(bounded,"formed metal stays within -20/+30 mm "+str(item[0]))
				check(joined,"nose cowl and fender boundaries match Original "+str(item[0]))
				check(shading,"finite smooth upward skin normals "+str(item[0]))
		car.change_kit_parts(VehicleCustomisation.defaults())
		check(car.customisation==VehicleCustomisation.defaults(),"Original restores "+str(simple))
		car.queue_free()
		await process_frame
	print("VOLT_HOOD_QUALITY: ",checks," checks, ",failures," failures; prepared=",prepared)
	quit(1 if failures else 0)
