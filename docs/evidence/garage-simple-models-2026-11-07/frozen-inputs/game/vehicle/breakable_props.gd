class_name BreakableProps
extends RefCounted
## Canonical run-owned damage/debris; fixed order, no scene physics or randomness.
const KINDS: Array[String] = ["hay_bale","crate","snowman","snow_lantern","ice_lantern"]
const HAY: int = 0
const WOOD: int = 1
const SNOW: int = 2
const ICE: int = 3
const POWDER: int = 4
const WINTER_KINDS: Array[String] = ["snowman","snow_lantern","ice_lantern"]
const MAX_WINTER_FRAGMENTS: int = 192
const HAY_MASS: float = 85.0
const CRATE_MASS: float = 22.0
const WOOD_PIECES: int = 6
const MAX_HAY_CLUMPS: int = 128
const MIN_HAY_FRACTION: float = 0.025
const CRATE_DAMAGE_SPEED: float = 4.0
# Damage: integrity, contact latch, distinct hit count.
# Fragment: type, source, x,y, vx,vy, yaw, spin, length,width, mass, amount.

static func prepare(state: VehicleState, props: Array) -> void:
	if not state.prop_destruction.is_empty(): return
	for object: Dictionary in props:
		if object.kind in KINDS:
			for item: Dictionary in props: state.prop_destruction.append([1.0,false,0])
			return

static func mass(kind: String, scale: float, integrity: float) -> float:
	if kind in WINTER_KINDS: return {"snowman":48.0,"snow_lantern":9.0,"ice_lantern":14.0}[kind]*scale*scale*scale
	return (HAY_MASS*integrity if kind == "hay_bale" else CRATE_MASS)*scale*scale*scale

static func size_fraction(kind: String, integrity: float) -> float:
	return pow(maxf(0.0,integrity),1.0/3.0) if kind == "hay_bale" else 1.0

static func step_one(state: VehicleState, props: Array, index: int, contact: Callable, previous: Vector2, dt: float, car_mass: float, car_radius: float) -> void:
	var object: Dictionary = props[index]
	var damage: Array = state.prop_destruction[index]
	var row: Array = state.light_props[index]
	var integrity: float = float(damage[0])
	if integrity <= 0.0: return
	var scale: float = float(object.get("scale",1.0))
	var p := Vector2(row[0],row[1]); var velocity := Vector2(row[2],row[3])
	var radius: float = CreatorObjects.size_of(object).x*0.35*size_fraction(object.kind,integrity)
	var touching: bool = false
	if not state.track_elevated and state.jump_height <= 0:
		var delta: Vector2 = p-Geometry2D.get_closest_point_to_segment(p,previous,state.position)
		touching = delta.length_squared() < pow(car_radius+radius,2.0)
		if touching:
			var relative: Vector2 = state.velocity-velocity
			var normal: Vector2 = delta.normalized() if delta.length_squared() > 0.000001 else (relative.normalized() if relative.length_squared() > 0.000001 else state.forward())
			var approach: float = (state.velocity-velocity).dot(normal)
			if approach > 0:
				var weight: float = mass(object.kind,scale,integrity)
				var impulse: float = minf(approach/(1.0/car_mass+1.0/weight),car_mass*1.2)
				var change: Vector2 = normal*impulse/car_mass
				state.velocity -= change; state.collision_impulse -= change
				velocity += normal*impulse/weight
				if not bool(damage[1]):
					damage[2] = int(damage[2])+1
					if object.kind == "hay_bale" and approach >= 1.0:
						var shed: float = minf(integrity,minf(0.45,0.02+0.022*(approach-1.0)))
						if integrity-shed <= MIN_HAY_FRACTION: shed = integrity
						integrity -= shed
						_shed_hay(state,index,p,velocity,normal,scale,shed,int(damage[2]))
					elif object.kind == "crate" and approach > CRATE_DAMAGE_SPEED:
						integrity = maxf(0.0,integrity-minf(1.0,0.03+(approach-CRATE_DAMAGE_SPEED)*0.09))
						if integrity <= 0.000001:
							integrity = 0.0
							_break_crate(state,index,object,p,velocity,normal,scale)
					elif object.kind in WINTER_KINDS and approach >= (2.0 if object.kind == "snowman" else 1.6):
						integrity = 0.0
						_break_winter(state,index,object,p,velocity,normal,scale)
					if approach >= CRATE_DAMAGE_SPEED: state.collision_count += 1
				row[4] = float(row[4])+normal.dot(state.right())*minf(approach,12.0)*dt*0.7
	# Latch one impact until separation; sustained contact cannot shred each tick.
	damage[0] = integrity; damage[1] = touching
	velocity = velocity.limit_length(16).move_toward(Vector2.ZERO,(6.0 if object.kind == "hay_bale" else 5.0)*dt)
	if velocity != Vector2.ZERO and integrity > 0.0:
		var next: Vector2 = p+velocity*dt
		if Vector3(contact.call(next,radius,false)).z <= 0: p = next
		else: velocity = Vector2.ZERO
	row[0] = p.x; row[1] = p.y; row[2] = velocity.x; row[3] = velocity.y

static func _shed_hay(state: VehicleState, source: int, p: Vector2, velocity: Vector2, normal: Vector2, scale: float, amount: float, impact: int) -> void:
	for piece: int in range(2):
		var count: int = 0; var oldest: int = -1
		for i: int in range(state.prop_fragments.size()):
			if int(state.prop_fragments[i][0]) != HAY: continue
			count += 1
			if oldest < 0: oldest = i
		if count >= MAX_HAY_CLUMPS: state.prop_fragments.remove_at(oldest)
		var angle: float = source*1.7+impact*2.4+piece*PI
		var outward := Vector2(cos(angle),sin(angle))
		var site: Vector2 = p+outward*scale*0.40
		var motion: Vector2 = velocity*0.16+normal*0.8+outward*0.55
		state.prop_fragments.append([HAY,source,site.x,site.y,motion.x,motion.y,angle,0.0,scale*(0.45+amount),scale*(0.35+amount),0.0,amount*0.5])

static func _break_crate(state: VehicleState, source: int, object: Dictionary, p: Vector2, velocity: Vector2, normal: Vector2, scale: float) -> void:
	var heading: float = deg_to_rad(float(object.rotation))+float(state.light_props[source][4])
	for piece: int in range(WOOD_PIECES):
		var angle: float = heading+piece*2.4+source*0.13
		var outward := Vector2(cos(angle),sin(angle))
		var site: Vector2 = p+outward*scale*(0.24+(piece%3)*0.11)
		var motion: Vector2 = velocity*0.65+normal*0.45+outward*0.55
		state.prop_fragments.append([WOOD,source,site.x,site.y,motion.x,motion.y,angle,(piece%2*2-1)*1.4,scale*(0.64+(piece%3)*0.12),scale*(0.11+(piece%2)*0.035),CRATE_MASS*scale*scale*scale/WOOD_PIECES,1.0])

static func step_fragments(state: VehicleState, contact: Callable, previous: Vector2, dt: float, car_mass: float, car_radius: float) -> void:
	# Winter fragments are finite-life cosmetic material. Their saved lifetime
	# is canonical, so rewind/reset never leaves effects or light behind.
	for index: int in range(state.prop_fragments.size()-1,-1,-1):
		var piece: Array=state.prop_fragments[index]
		if int(piece[0])>=SNOW:
			piece[11]=maxf(0.0,float(piece[11])-dt)
			if float(piece[11])<=0.0: state.prop_fragments.remove_at(index)
	for row: Array in state.prop_fragments:
		var p := Vector2(row[2],row[3]); var velocity := Vector2(row[4],row[5])
		if int(row[0]) == WOOD and not state.track_elevated and state.jump_height <= 0:
			var probe: Vector2 = Geometry2D.get_closest_point_to_segment(p,previous,state.position)
			if probe.distance_squared_to(p) < pow(car_radius+float(row[8])*0.5,2.0):
				var local: Vector2 = (probe-p).rotated(-float(row[6]))
				var half := Vector2(float(row[8]),float(row[9]))*0.5
				var offset: Vector2 = local.clamp(-half,half)-local
				if offset.length_squared() < car_radius*car_radius:
					var relative: Vector2 = state.velocity-velocity
					var normal: Vector2 = offset.normalized().rotated(float(row[6])) if offset.length_squared() > 0.000001 else (relative.normalized() if relative.length_squared() > 0.000001 else state.forward())
					var approach: float = (state.velocity-velocity).dot(normal)
					if approach > 0:
						var impulse: float = minf(approach/(1.0/car_mass+1.0/float(row[10])),car_mass*0.035)
						var change: Vector2 = normal*impulse/car_mass
						state.velocity -= change; state.collision_impulse -= change
						velocity += normal*impulse/float(row[10])
						if absf(state.yaw_rate) < 0.8: state.yaw_rate = clampf(state.yaw_rate+normal.dot(state.right())*change.length()*0.22,-0.8,0.8)
						row[7] = float(row[7])+normal.dot(state.right())*minf(approach,8.0)*0.08
		velocity = velocity.limit_length(12).move_toward(Vector2.ZERO,(7.0 if int(row[0]) == WOOD else 5.5)*dt)
		if velocity != Vector2.ZERO:
			var next: Vector2 = p+velocity*dt
			# Loose hay never queries collision or changes the car, surfaces or grip.
			if int(row[0]) != WOOD or Vector3(contact.call(next,float(row[9])*0.5,false)).z <= 0: p = next
			else: velocity = Vector2.ZERO
		row[2] = p.x; row[3] = p.y; row[4] = velocity.x; row[5] = velocity.y
		row[6] = fposmod(float(row[6])+float(row[7])*dt,TAU)
		row[7] = move_toward(float(row[7]),0.0,3.0*dt)

static func _break_winter(state: VehicleState, source: int, object: Dictionary, p: Vector2, velocity: Vector2, normal: Vector2, scale: float) -> void:
	var ice: bool=object.kind=="ice_lantern"
	var snowman: bool=object.kind=="snowman"
	var chunks: int=8 if ice or snowman else 6
	var powder: int=2 if ice else 5
	for i: int in range(chunks+powder):
		var count: int=0; var oldest: int=-1
		for j: int in range(state.prop_fragments.size()):
			if int(state.prop_fragments[j][0])<SNOW: continue
			count+=1
			if oldest<0: oldest=j
		if count>=MAX_WINTER_FRAGMENTS: state.prop_fragments.remove_at(oldest)
		var angle: float=source*1.71+i*2.399+deg_to_rad(float(object.rotation))
		var outward:=Vector2(cos(angle),sin(angle))
		var mist: bool=i>=chunks
		var kind: int=POWDER if mist else ICE if ice else SNOW
		var motion: Vector2=velocity*(0.16 if mist else 0.32)+normal*(0.50 if mist else 0.9)+outward*(0.65 if mist else 1.2)
		var site: Vector2=p+outward*scale*(0.12+(i%3)*0.08)
		var reach: float=scale*((0.24+(i%3)*0.055) if snowman else (0.17+(i%3)*0.035))
		var duration: float=0.85+(i%3)*0.1 if mist else 3.0
		# Type-specific fields 10/11 store duration/remaining life, preserving
		# the twelve-field snapshot layout and all old hay/wood semantics.
		state.prop_fragments.append([kind,source,site.x,site.y,motion.x,motion.y,angle,(1.0 if i%2 else -1.0)*2.8,reach,reach*(0.70 if ice else 0.90),duration,duration])
