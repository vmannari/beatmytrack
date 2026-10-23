class_name BurningBarrelVisual
extends RefCounted
## Render the exact run-owned cylinder pose; never integrate scene physics.
static var drum: ArrayMesh
static func build(node: Node3D, kit: Node, scale: float) -> void:
	node.set_meta("burning_barrel_scale",scale)
	if drum==null:
		var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		CreatorPropVisual.append(tool,kit,"burning_barrel",Vector3.ZERO,1,0)
		tool.index(); drum=PropGeometry.commit(tool)
	var body:=MeshInstance3D.new(); body.name="BurningDrum"; body.mesh=drum; body.material_override=PropNight.material()
	body.scale=Vector3.ONE*scale; body.position.y=-0.55*scale
	node.add_child(body)
	var origin: Vector3=node.get_meta("prop_origin",node.position)
	node.position=origin+Vector3.UP*0.55*scale

static func present(node: Node3D, row: Array, ground: float) -> void:
	var scale: float=float(node.get_meta("burning_barrel_scale"))
	var tilt: float=float(row[4]) if row.size()==BurningBarrel.ROW_SIZE else 0.0
	var direction: float=float(row[5]) if row.size()==BurningBarrel.ROW_SIZE else 0.0
	var roll: float=float(row[8]) if row.size()==BurningBarrel.ROW_SIZE else 0.0
	var axis:=Vector3(-sin(direction),0,-cos(direction))
	var yaw: float=float(node.get_meta("prop_yaw",0.0))+roll
	var supported: float=(0.55*absf(cos(tilt))+0.515*absf(sin(tilt)))*scale
	node.transform=Transform3D(Basis(axis,tilt)*Basis(Vector3.UP,yaw),Vector3(float(row[0]),ground+0.014+supported,-float(row[1])))

static func fuel(node: Node3D) -> Vector3:
	return node.transform*Vector3(0,0.28*float(node.get_meta("burning_barrel_scale")),0)

static func fire_profile(pose: Transform3D, row: Array, scale: float, ground: float) -> Dictionary:
	var fuel: Vector3=pose*Vector3(0,0.28*scale,0)
	var age: float=float(row[10]) if row.size()==BurningBarrel.ROW_SIZE else -1.0
	var spread: float=smoothstep(0.0,1.25,maxf(0.0,age))
	var energy: float=1.0-smoothstep(1.0,BurningBarrel.FIRE_SECONDS,maxf(0.0,age))
	var smoke: float=1.0-smoothstep(5.0,BurningBarrel.SMOKE_SECONDS,maxf(0.0,age))
	var direction: float=float(row[13]) if age>=0 else 0.0
	var strength: float=float(row[14]) if age>=0 else 0.0
	var floor_point:=Vector3(float(row[11]),ground+0.035,-float(row[12])) if age>=0 else fuel
	floor_point+=Vector3(cos(direction),0,-sin(direction))*0.65*scale*spread
	fuel=fuel.lerp(floor_point,spread)
	var size:=Vector3(lerpf(1.08,3.0+1.8*strength,spread),lerpf(1.45,0.24+0.76*energy,spread),lerpf(1.08,2.2+1.0*strength,spread))*scale
	var basis:=Basis(Vector3.UP,direction)*Basis.from_scale(size)
	return {"fuel":fuel,"pose":Transform3D(basis,fuel+Vector3.UP*size.y*0.5),"energy":energy,"smoke":smoke,"spread":spread,"size":size,"direction":direction}
