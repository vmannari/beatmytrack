class_name NightPropEffects
extends Node3D
## One bounded cosmetic clock per world; never writes track or vehicle state.
const MAX_BUSHES: int=32
const MAX_FIRES: int=32
const MAX_LIGHTS: int=4
@export var externally_ticked: bool=false
@export var elapsed: float=0.0
@export var barrel_sources: Array[Dictionary]=[]
var surfaces: Array[ShaderMaterial]=[]
var warm_lights: Array[OmniLight3D]=[]
var barrel_poses: Dictionary={}

static func build(kit: Node3D, objects: Array) -> NightPropEffects:
	var old: Node=kit.get_node_or_null("NightPropEffects")
	if old!=null: kit.remove_child(old); old.queue_free()
	if kit.theme_id!="night_city" or kit._capture_editor_prop_arrays or kit._suppress_night_fx: return null
	var root:=NightPropEffects.new(); root.name="NightPropEffects"; root.add_to_group("night_prop_effects",true)
	root.externally_ticked=not kit.editor_preview
	var rows: Array=[[],[],[],[]]
	var bushes: int=0; var fires: int=0; var lamps: int=0
	var soft_index: int=-1
	for object: Dictionary in objects:
		if object.kind in CreatorCatalog.SOFT: soft_index+=1
		if object.kind not in PropNight.KINDS: continue
		var scale: float=float(object.get("scale",1.0)); var turn: float=deg_to_rad(float(object.rotation))
		var point:=Vector2(object.position[0],object.position[1])
		var center:=Vector3(point.x,0.014,-point.y)
		if kit.ground_support!=null: center.y+=kit.ground_support.ground(point)
		var pose:=Transform3D(Basis(Vector3.UP,turn).scaled(Vector3.ONE*scale),center)
		if object.kind=="firefly_bush" and bushes<MAX_BUSHES:
			for i: int in range(12):
				var angle: float=i*2.39996
				rows[0].append([pose*Vector3(cos(angle)*(0.4+(i%3)*0.30),0.48+(i%5)*0.25,sin(angle)*(0.5+(i%3)*0.28)),Vector2(0.10,0.10)*scale,float(i+bushes*13)*0.618034,scale])
			bushes+=1
		elif object.kind=="burning_barrel":
			if fires<MAX_FIRES:
				root.barrel_sources.append({"index":soft_index,"flame":rows[1].size(),"ember":rows[2].size(),"smoke":rows[3].size(),"scale":scale,"light":lamps if lamps<MAX_LIGHTS else -1,"fuel":pose*Vector3(0,0.83,0)})
				rows[1].append([pose*Vector3(0,1.555,0),Vector2(1.08,1.45)*scale,float(fires*7)*0.618034,scale])
				for i: int in range(7): rows[2].append([pose*Vector3(0,0.95,0),Vector2(0.025,0.055)*scale,float(i+fires*11)*0.618034,scale])
				for i: int in range(3): rows[3].append([pose*Vector3(0,1.1,0),Vector2(0.60,0.70)*scale,float(i+fires*5)*0.618034,scale])
				fires+=1
			if lamps<MAX_LIGHTS:
				root._light(pose*Vector3(0,1.12,0),scale,2.1,5.5); lamps+=1
		elif object.kind=="burning_car":
			# Two openings share the original32-emitter/four-light world budgets.
			for site: int in range(2):
				if fires>=MAX_FIRES: break
				var origin:=Vector3(1.43,0.94,0.04) if site==0 else Vector3(-0.38,1.03,0)
				var size: float=1.35 if site==0 else 1.05
				rows[1].append([pose*origin+Vector3.UP*0.68*scale*size,Vector2(1.10,1.45)*scale*size,float(fires*7)*0.618034,scale*size])
				for i: int in range(7): rows[2].append([pose*origin,Vector2(0.025,0.055)*scale,float(i+fires*11)*0.618034,scale*size])
				for i: int in range(3): rows[3].append([pose*(origin+Vector3.UP*0.25),Vector2(0.85,0.95)*scale,float(i+fires*5)*0.618034,scale*size])
				fires+=1
			if lamps<MAX_LIGHTS:
				root._light(pose*Vector3(0.8,1.25,0),scale,3.0,6.0); lamps+=1
		elif object.kind=="abandoned_warehouse":
			for side: float in [-1.0,1.0]:
				if lamps>=MAX_LIGHTS: break
				root._light(pose*Vector3(side*7.35,3.95,side*7.5),scale,2.0,9.0); lamps+=1
		elif object.kind=="lantern_post" and lamps<MAX_LIGHTS:
			root._light(pose*Vector3(0.65,2.22,0),scale,1.8,6.0); lamps+=1
	if bushes+fires+lamps==0: root.free(); return null
	for kind: int in range(4):
		if rows[kind].is_empty(): continue
		var mesh: Mesh
		var material: ShaderMaterial
		if kind==1:
			var volume:=BoxMesh.new(); volume.size=Vector3.ONE; mesh=volume
			material=NightFireVolume.material()
		else:
			var card:=QuadMesh.new(); card.size=Vector2.ONE; mesh=card
			material=ShaderMaterial.new(); material.shader=preload("res://track/night_prop_effect.gdshader")
			material.resource_local_to_scene=true; material.set_shader_parameter("effect_kind",kind)
		var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_custom_data=true; mm.mesh=mesh
		mm.instance_count=rows[kind].size()
		var bounds:=AABB(rows[kind][0][0],Vector3.ZERO)
		for i: int in range(rows[kind].size()):
			var row: Array=rows[kind][i]
			# Z retains source scale for the shader's world-space excursions.
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(row[1].x,row[1].y,row[1].x if kind==1 else row[3])),row[0]))
			mm.set_instance_custom_data(i,Color(fposmod(row[2],1.0),0 if kind==1 else [0.1,0.5,0.45,0.17][kind],1 if kind==1 else row[3],1))
			bounds=bounds.expand(row[0])
		# Shader displacement is invisible to CPU culling. Include the full motion,
		# billboard extent and maximum supported source scale, including smoke rise.
		var reach: float=0.0
		for row: Array in rows[kind]: reach=maxf(reach,float(row[3])*3.5)
		mm.custom_aabb=bounds.grow(reach)
		var node:=MultiMeshInstance3D.new(); node.name=["Fireflies","Flames","Embers","Smoke"][kind]
		node.set_meta("rest_bounds",mm.custom_aabb)
		node.multimesh=mm; node.material_override=material; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	kit.add_child(root)
	return root

func _light(p: Vector3, scale: float, energy: float, reach: float) -> void:
	var lamp:=OmniLight3D.new(); lamp.name="WarmPropLight"; lamp.position=p
	lamp.light_color=Color("ff9e45"); lamp.light_energy=energy; lamp.omni_range=reach*scale
	lamp.shadow_enabled=false; lamp.light_cull_mask=1
	lamp.set_meta("rest_energy",energy); add_child(lamp)

func _ready() -> void:
	# Prepared worlds share immutable geometry, but each receives its own clock
	# materials. Explicit copies also cover Node.duplicate before scene packing.
	surfaces.clear(); warm_lights.clear(); barrel_poses.clear()
	barrel_sources=barrel_sources.duplicate(true)
	for child: Node in get_children():
		if child is MultiMeshInstance3D:
			child.material_override=child.material_override.duplicate()
			surfaces.append(child.material_override)
		elif child is OmniLight3D: warm_lights.append(child)
	_publish()

func _process(delta: float) -> void:
	if not externally_ticked: advance(delta,false)

func advance(delta: float, paused: bool) -> void:
	if paused or not is_visible_in_tree() or delta<=0.0: return
	elapsed+=minf(delta,0.1)
	_publish()

func _publish() -> void:
	for material: ShaderMaterial in surfaces: material.set_shader_parameter("elapsed",elapsed)
	for i: int in range(warm_lights.size()):
		_publish_light(i)

func _publish_light(i: int) -> void:
	var lamp: OmniLight3D=warm_lights[i]
	var energy: float=float(lamp.get_meta("fuel_energy",1.0))
	lamp.light_energy=float(lamp.get_meta("rest_energy"))*energy*(0.96+0.025*sin(elapsed*7.3+i*2.1)+0.015*sin(elapsed*11.7+i))

func sync_barrels(nodes: Array, state: VehicleState) -> void:
	if barrel_sources.is_empty() or not is_visible_in_tree(): return
	var changed: bool=false
	# All sources share the same parent; its inverse is identical for this pass.
	var world_to_local: Transform3D=(get_parent() as Node3D).global_transform.affine_inverse()
	for source: Dictionary in barrel_sources:
		if int(source.index)>=nodes.size(): continue
		var node: Node3D=nodes[int(source.index)]
		if not node.has_meta("burning_barrel_scale"): continue
		var pose: Transform3D=world_to_local*node.global_transform
		var row: Array=state.light_props[int(source.index)] if int(source.index)<state.light_props.size() else []
		var key: Array=[pose,row.slice(10)]
		if barrel_poses.get(source.index)==key: continue
		barrel_poses[source.index]=key; changed=true
		var scale: float=float(source.scale)
		var tilt: float=float(row[4]) if row.size()==BurningBarrel.ROW_SIZE else 0.0
		var ground: float=pose.origin.y-(0.55*absf(cos(tilt))+0.515*absf(sin(tilt)))*scale-0.014
		var kit: Node3D=get_parent()
		if kit.ground_support!=null and row.size()==BurningBarrel.ROW_SIZE:
			var p:=Vector2(float(row[11]),float(row[12]))+Vector2.from_angle(float(row[13]))*0.65*scale
			ground=kit.ground_support.ground(p)
		var profile: Dictionary=BurningBarrelVisual.fire_profile(pose,row,scale,ground)
		var fuel: Vector3=profile.fuel
		source.fuel=fuel
		var flame: MultiMesh=get_node("Flames").multimesh
		flame.set_instance_transform(int(source.flame),profile.pose)
		var custom: Color=flame.get_instance_custom_data(int(source.flame))
		custom.g=profile.spread; custom.b=profile.energy; flame.set_instance_custom_data(int(source.flame),custom)
		for effect: String in ["Embers","Smoke"]:
			var mm: MultiMesh=get_node(effect).multimesh
			var start: int=int(source.ember if effect=="Embers" else source.smoke)
			var size:=Vector3(0.025,0.055,1)*scale if effect=="Embers" else Vector3(0.60,0.70,1)*scale
			var p: Vector3=fuel+Vector3.UP*(0.12 if effect=="Embers" else 0.27)*scale
			for i: int in range(7 if effect=="Embers" else 3):
				var angle: float=i*2.39996
				var offset: Vector3=Basis(Vector3.UP,float(profile.direction))*Vector3(cos(angle)*profile.size.x*0.25,0,sin(angle)*profile.size.z*0.25)*float(profile.spread)
				mm.set_instance_transform(start+i,Transform3D(Basis.from_scale(size),p+offset))
				var colour: Color=mm.get_instance_custom_data(start+i); colour.a=profile.energy if effect=="Embers" else profile.smoke
				mm.set_instance_custom_data(start+i,colour)
		if int(source.light)>=0 and int(source.light)<warm_lights.size():
			var light_index: int=int(source.light)
			warm_lights[light_index].position=fuel+Vector3.UP*0.29*scale
			preload("res://track/night_light_budget.gd").set_available(warm_lights[light_index],float(profile.energy)>0.0001)
			warm_lights[light_index].set_meta("fuel_energy",profile.energy); _publish_light(light_index)
	if changed:
		for effect: String in ["Flames","Embers","Smoke"]:
			var node: MultiMeshInstance3D=get_node(effect); var bounds: AABB=node.get_meta("rest_bounds")
			for source: Dictionary in barrel_sources:
				var reach: float=3.5*float(source.scale)
				bounds=bounds.merge(AABB(source.fuel-Vector3.ONE*reach,Vector3.ONE*reach*2))
			node.multimesh.custom_aabb=bounds
