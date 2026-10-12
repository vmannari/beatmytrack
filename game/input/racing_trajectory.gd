class_name RacingTrajectory
extends RefCounted
## Derived development data only. Never changes track, rules or handling hashes.
const VERSION: String = "racing-trajectory-4"
const SPACING: float = 0.5
const MAX_SAMPLES: int = 8192
const LATERAL_UTILIZATION: float = 1.10
const DRIVE_UTILIZATION: float = 1.0
const BRAKE_UTILIZATION: float = 0.95
var points := PackedVector2Array()
var centers := PackedVector2Array()
var normals := PackedVector2Array()
var offsets := PackedFloat32Array()
var lower := PackedFloat32Array()
var upper := PackedFloat32Array()
var headings := PackedFloat32Array()
var curvature := PackedFloat32Array()
var speeds := PackedFloat32Array()
var grips := PackedFloat32Array()
var resistance := PackedFloat32Array()
var layers := PackedByteArray()
var route_indices := PackedInt32Array()
var cumulative := PackedFloat64Array()
var length: float
var route_length: float
var spacing: float
var reference_seconds: float = 0.0
var curvature_before: float = 0.0
var curvature_after: float = 0.0
var blocked_samples: int = 0
var cache_key: String = ""
var strategy: String = "minimum_curvature"
var pilot_ticks: int = 0
var pilot_candidates: Array = []
var safe_reference: bool = false
var _planning_config: HandlingConfig

static func identity(track: NativeTrack, config: HandlingConfig) -> String:
	return JSON.stringify([VERSION,track.content_hash,TrackCompiler.VERSION,VehicleSimulation.PHYSICS_VERSION,RaceRules.KEY,config.snapshot()],"",true).sha256_text()

func build(track: NativeTrack, config: HandlingConfig, method: String = "minimum_curvature", seed_line: PackedVector2Array = PackedVector2Array(), safe: bool = false) -> void:
	safe_reference = safe
	cache_key = identity(track,config)
	strategy = method
	_planning_config = config
	length = track.route_length
	route_length = track.route_length
	var count: int = clampi(ceili(length/SPACING),16,MAX_SAMPLES)
	spacing = length/count
	points.resize(count); centers.resize(count); normals.resize(count); offsets.resize(count)
	lower.resize(count); upper.resize(count); headings.resize(count); curvature.resize(count)
	speeds.resize(count); grips.resize(count); resistance.resize(count); layers.resize(count); route_indices.resize(count)
	var probe := VehicleState.new()
	var route_index: int = 0
	var previous_offset: float = 0.0
	for i: int in range(count):
		var s: float = i*spacing
		while route_index+1 < track.route.size() and track.route_cumulative[route_index+1] <= s: route_index += 1
		route_indices[i] = route_index
		centers[i] = track._race_route_point(s)
		var tangent: Vector2 = (track._race_route_point(s+2.0)-track._race_route_point(s-2.0)).normalized()
		normals[i] = Vector2(tangent.y,-tangent.x)
		layers[i] = int(track.elevated_at(centers[i],route_index))
		var margin: float = config.collision_radius+(0.15 if config.vehicle_id == "compact" and not safe_reference else 0.3)
		var limits := Vector2.ZERO
		for side: int in [-1,1]:
			var reach: float = 0.0
			# Connected road pieces can form wider junctions than the route's
			# nominal strip. Measure the contiguous drivable area itself.
			var scan_limit: float = 10.0 if config.vehicle_id == "compact" and not safe_reference else minf(track.route_widths[route_index]*0.5,10.0)
			while reach+0.25 <= scan_limit:
				var candidate: Vector2 = centers[i]+normals[i]*side*(reach+0.25)
				if track.cell_at(candidate,bool(layers[i])) not in [0,2,5]: break
				reach += 0.25
			if side < 0: limits.x = -maxf(0.0,reach-margin)
			else: limits.y = maxf(0.0,reach-margin)
		# Contiguous intervals prevent a smoothed line jumping through a solid prop.
		var best := Vector2.ZERO
		var best_score: float = INF
		var start: float = INF
		var samples: int = maxi(1,ceili((limits.y-limits.x)/0.25))
		for j: int in range(samples+2):
			var d: float = lerpf(limits.x,limits.y,minf(1.0,float(j)/samples))
			var valid: bool = j <= samples and not track.overlaps_obstacle(centers[i]+normals[i]*d,margin,bool(layers[i]))
			if valid and is_inf(start): start = d
			if not valid and not is_inf(start):
				var finish: float = lerpf(limits.x,limits.y,float(j-1)/samples)
				var nearest: float = clampf(previous_offset,start,finish)
				var score: float = absf(nearest-previous_offset)+absf(clampf(0.0,start,finish))*0.15
				if score < best_score: best_score = score; best = Vector2(start,finish)
				start = INF
		if is_inf(best_score): blocked_samples += 1
		lower[i] = best.x; upper[i] = best.y
		offsets[i] = clampf(previous_offset,best.x,best.y)
		previous_offset = offsets[i]
		points[i] = centers[i]+normals[i]*offsets[i]
		probe.position = points[i]; probe.track_elevated = bool(layers[i])
		probe.velocity = tangent*20.0
		var factors: Vector2 = track.surface_factors(probe)
		var dirt: float = config.dirty_tire_grip_loss if track.tire_pickup(probe) > 0.0 else 0.0
		grips[i] = factors.x*(1.0-dirt)
		resistance[i] = factors.y
	if seed_line.size() == count:
		for i: int in range(count):
			offsets[i] = clampf((seed_line[i]-centers[i]).dot(normals[i]),lower[i],upper[i])
			points[i] = centers[i]+normals[i]*offsets[i]
	curvature_before = _energy()
	var best_energy: float = _objective_energy()
	var best_points: PackedVector2Array = points.duplicate()
	var best_offsets: PackedFloat32Array = offsets.duplicate()
	# Bounded coordinate Newton descent on integral squared geometric curvature.
	# Variable chord lengths matter: the second-difference surrogate alone
	# incorrectly favours the smaller radius of an inside circular line.
	if method == "smoothing":
		for radius: int in [12,6,3,1]:
			for sweep: int in range(180):
				for i: int in range(count):
					var bend: Vector2 = points[posmod(i-2*radius,count)]-points[posmod(i-radius,count)]*4.0+points[i]*6.0-points[(i+radius)%count]*4.0+points[(i+2*radius)%count]
					offsets[i] = clampf(offsets[i]-0.15*bend.dot(normals[i]),lower[i],upper[i])
					points[i] = centers[i]+normals[i]*offsets[i]
		best_points = points.duplicate(); best_offsets = offsets.duplicate()
	for radius: int in ([8,4,2,1] if method in ["minimum_curvature","minimum_time","short_line"] else []):
		for sweep: int in range(45):
			for i: int in range(count):
				if upper[i]-lower[i] < 0.00001: continue
				var old: float = offsets[i]
				var cost: float = _local_energy(i,radius)
				points[i] = centers[i]+normals[i]*(old+0.05)
				var plus: float = _local_energy(i,radius)
				points[i] = centers[i]+normals[i]*(old-0.05)
				var minus: float = _local_energy(i,radius)
				var gradient: float = (plus-minus)/0.1
				var hessian: float = (plus+minus-2.0*cost)/0.0025
				var delta: float = clampf(-gradient/maxf(hessian,0.00001),-0.25,0.25)
				var accepted: bool = false
				for search: int in range(3):
					var next: float = clampf(old+delta,lower[i],upper[i])
					points[i] = centers[i]+normals[i]*next
					if _local_energy(i,radius) < cost:
						offsets[i] = next; accepted = true; break
					delta *= 0.4
				if not accepted: points[i] = centers[i]+normals[i]*old
		var energy: float = _objective_energy()
		if energy < best_energy:
			best_energy = energy; best_points = points.duplicate(); best_offsets = offsets.duplicate()
	points = best_points; offsets = best_offsets
	if config.vehicle_id == "compact" and not safe_reference:
		var smoothing_reach: int = maxi(1,roundi(3.0/spacing))
		for sweep: int in range(3):
			var smoothed: PackedVector2Array = points.duplicate()
			for i: int in range(count):
				var average := Vector2.ZERO
				var total: float = 0.0
				for shift: int in range(-smoothing_reach,smoothing_reach+1):
					var weight: float = smoothing_reach+1-abs(shift)
					average += points[posmod(i+shift,count)]*weight; total += weight
				average /= total
				if track.cell_at(average,bool(layers[i])) in [0,2,5] and not track.overlaps_obstacle(average,config.collision_radius+0.15,bool(layers[i])): smoothed[i] = average
			points = smoothed
	curvature_after = _energy()
	for i: int in range(count):
		# The finite vehicle follows a spatially filtered tangent, avoiding a
		# single raster/chord kink dictating braking for the entire corner.
		var reach: int = maxi(1,roundi((1.0 if config.vehicle_id == "compact" and not safe_reference else 2.0)/spacing))
		var a: Vector2 = points[posmod(i-reach,count)]
		var b: Vector2 = points[(i+reach)%count]
		headings[i] = atan2(b.x-a.x,b.y-a.y)
		var incoming: Vector2 = points[i]-a
		var outgoing: Vector2 = b-points[i]
		curvature[i] = -2.0*incoming.cross(outgoing)/maxf(incoming.length()*outgoing.length()*a.distance_to(b),0.00001)
		# Re-evaluate the final line, rather than using the seed's surface.
		probe.position = points[i]; probe.track_elevated = bool(layers[i])
		probe.velocity = Vector2(sin(headings[i]),cos(headings[i]))*20.0
		var factors: Vector2 = track.surface_factors(probe)
		grips[i] = factors.x*(1.0-(config.dirty_tire_grip_loss if track.tire_pickup(probe) > 0.0 else 0.0))
		resistance[i] = factors.y
		if config.vehicle_id == "compact" and not safe_reference:
			var normal := Vector2(cos(headings[i]),-sin(headings[i]))
			lower[i] = 0.0; upper[i] = 0.0
			for side: int in [-1,1]:
				var reach_distance: float = 0.0
				while reach_distance+0.25 <= 10.0:
					var candidate: Vector2 = points[i]+normal*side*(reach_distance+0.25)
					if track.cell_at(candidate,bool(layers[i])) not in [0,2,5] or track.overlaps_obstacle(candidate,config.collision_radius+0.15,bool(layers[i])): break
					reach_distance += 0.25
				if side < 0: lower[i] = -reach_distance
				else: upper[i] = reach_distance
			offsets[i] = 0.0
		speeds[i] = maxf(1.0,corner_speed(config,absf(curvature[i]),grips[i],safe_reference))
	_measure_distance()
	# Frenet prediction needs d(heading)/ds, not a second, inconsistent
	# circle fit through the filtered tangent's centre point.
	var derivative_reach: int = maxi(1,roundi(1.0/spacing))
	for i: int in range(count):
		var before: int = posmod(i-derivative_reach,count)
		var after: int = (i+derivative_reach)%count
		var ds: float = cumulative[after]-cumulative[before]
		if ds <= 0.0: ds += length
		if not safe_reference: curvature[i] = wrapf(headings[after]-headings[before],-PI,PI)/maxf(ds,0.000001)
		speeds[i] = maxf(1.0,corner_speed(config,absf(curvature[i]),grips[i],safe_reference))
	# Multiple cyclic passes propagate seam braking and acceleration constraints.
	for sweep: int in range(8):
		for i: int in range(count):
			var j: int = (i+1)%count
			var a: float = drive_acceleration(config,speeds[i],grips[i],resistance[i],curvature[i])*(DRIVE_UTILIZATION if config.vehicle_id == "compact" and not safe_reference else 0.90)
			speeds[j] = minf(speeds[j],sqrt(maxf(1.0,speeds[i]*speeds[i]+2.0*a*points[i].distance_to(points[j]))))
		for i: int in range(count-1,-1,-1):
			var j: int = (i+1)%count
			var brake: float = braking_acceleration(config,speeds[i],grips[i],curvature[i])*(BRAKE_UTILIZATION if config.vehicle_id == "compact" and not safe_reference else 0.82)
			speeds[i] = minf(speeds[i],sqrt(speeds[j]*speeds[j]+2.0*brake*points[i].distance_to(points[j])))
	reference_seconds = 0.0
	for i: int in range(count): reference_seconds += 2.0*points[i].distance_to(points[(i+1)%count])/maxf(0.1,speeds[i]+speeds[(i+1)%count])
	# Normalize the corridor to the final line before any cold/warm control.
	# Both routes then consume identical float32 control data after JSON restore.
	for i: int in range(count): lower[i] -= offsets[i]; upper[i] -= offsets[i]
	offsets.fill(0.0)
	_measure_distance()

func _measure_distance() -> void:
	cumulative.resize(points.size()+1)
	cumulative[0] = 0.0
	for i: int in range(points.size()):
		cumulative[i+1] = cumulative[i]+maxf(0.000001,points[i].distance_to(points[(i+1)%points.size()]))
	length = cumulative[points.size()]

func _distance_index(s: float) -> int:
	var low: int = 0
	var high: int = points.size()-1
	while low < high:
		var middle: int = (low+high+1)/2
		if cumulative[middle] <= s: low = middle
		else: high = middle-1
	return low

static func longitudinal_budget(config: HandlingConfig, speed: float, grip: float, k: float) -> float:
	var usage: float = clampf(speed*speed*absf(k)/maxf(0.01,config.lateral_grip*grip),0.0,1.0)
	return config.longitudinal_grip*grip*sqrt(maxf(0.25,1.0-usage*usage*0.65))

static func braking_acceleration(config: HandlingConfig, speed: float, grip: float, k: float) -> float:
	return minf(config.braking_force/config.mass,longitudinal_budget(config,speed,grip,k))

static func drive_acceleration(config: HandlingConfig, speed: float, grip: float, drag_rate: float, k: float = 0.0) -> float:
	var force: float = config.engine_force/config.mass*(1.0-0.45*clampf(speed/config.maximum_speed,0.0,1.0))
	var drag: float = (config.drag*speed*speed+config.rolling_resistance)/config.mass+drag_rate
	return maxf(0.1,minf(force,longitudinal_budget(config,speed,grip,k))-drag)

static func steering_speed(config: HandlingConfig, k: float, margin: float = 0.92) -> float:
	# Exact inverse of the canonical linear speed reduction, including the
	# flat region above 24 m/s. The old 0.9 loop unnecessarily discarded speed.
	var required: float = atan(k*config.wheelbase*config.rear_grip/(config.front_grip*margin))
	if required >= config.steering_angle: return 0.0
	if required <= config.steering_angle*(1.0-config.high_speed_steering_reduction): return config.maximum_speed
	return maxf(0.0,24.0*(1.0-required/config.steering_angle)/maxf(0.00001,config.high_speed_steering_reduction))

static func corner_speed(config: HandlingConfig, k: float, grip_factor: float, safe: bool = false) -> float:
	var utilization: float = LATERAL_UTILIZATION if config.vehicle_id == "compact" and not safe else 0.88
	var grip: float = config.lateral_grip*minf(config.front_grip,config.rear_grip)*grip_factor*utilization
	var bound: float = minf(config.maximum_speed*0.97,sqrt(grip/maxf(k,0.0001)))
	var yaw_capacity: float = maxf(config.maximum_yaw_rate,3.2) if config.vehicle_id == "compact" and not safe else config.maximum_yaw_rate
	return minf(bound,minf(yaw_capacity*(0.98 if config.vehicle_id == "compact" and not safe else 0.88)/maxf(k,0.0001),steering_speed(config,k)))

func _energy() -> float:
	var value: float = 0.0
	for i: int in range(points.size()): value += _curvature_cost(i,1)
	return value

func _curvature_cost(i: int, radius: int) -> float:
	var a: Vector2 = points[posmod(i-radius,points.size())]
	var b: Vector2 = points[(i+radius)%points.size()]
	var incoming: Vector2 = points[i]-a
	var outgoing: Vector2 = b-points[i]
	var k: float = 2.0*incoming.cross(outgoing)/maxf(incoming.length()*outgoing.length()*a.distance_to(b),0.00001)
	return k*k*(incoming.length()+outgoing.length())*0.5

func _planning_cost(i: int, radius: int) -> float:
	if strategy not in ["minimum_time","short_line"]: return _curvature_cost(i,radius)
	var a: Vector2 = points[posmod(i-radius,points.size())]
	var b: Vector2 = points[(i+radius)%points.size()]
	var incoming: Vector2 = points[i]-a
	var outgoing: Vector2 = b-points[i]
	var k: float = absf(2.0*incoming.cross(outgoing)/maxf(incoming.length()*outgoing.length()*a.distance_to(b),0.00001))
	var ds: float = (incoming.length()+outgoing.length())*0.5
	var bound: float = corner_speed(_planning_config,k,grips[i],safe_reference)
	var impossible: float = maxf(0.0,k-tan(_planning_config.steering_angle)*_planning_config.front_grip/_planning_config.rear_grip/_planning_config.wheelbase*0.92)
	if strategy == "short_line": return ds*(1.0+80.0*k*k+5000.0*impossible*impossible)
	return ds/maxf(bound,1.0)+ds*impossible*impossible*20.0

func _objective_energy() -> float:
	var value: float = 0.0
	var reach: int = maxi(1,roundi(2.0/spacing)) if strategy in ["minimum_time","short_line"] else 1
	for i: int in range(points.size()): value += _planning_cost(i,reach)/reach
	return value

func _local_energy(i: int, radius: int) -> float:
	if strategy in ["minimum_time","short_line"]: radius = maxi(radius,maxi(1,roundi(2.0/spacing)))
	return _planning_cost(posmod(i-radius,points.size()),radius)+_planning_cost(i,radius)+_planning_cost((i+radius)%points.size(),radius)

func at(s: float) -> Dictionary:
	var distance: float = fposmod(s,length)
	var i: int = _distance_index(distance)
	var j: int = (i+1)%points.size()
	var t: float = (distance-cumulative[i])/(cumulative[i+1]-cumulative[i])
	return {"point":points[i].lerp(points[j],t),"heading":lerp_angle(headings[i],headings[j],t),"curvature":lerpf(curvature[i],curvature[j],t),"speed":lerpf(speeds[i],speeds[j],t),"grip":grips[i],"drag":resistance[i],"lower":lower[i]-offsets[i],"upper":upper[i]-offsets[i],"layer":layers[i]}

func project(point: Vector2, route_hint: float) -> float:
	# The native hint preserves the correct crossing/bridge branch. Return
	# actual racing-line metres so prediction does not use centreline distance.
	var index: int = floori(fposmod(route_hint,route_length)/spacing)
	var best: float = INF
	var result: float = cumulative[index]
	var reach: int = ceili(12.0/spacing)
	for offset: int in range(-reach,reach+1):
		var i: int = posmod(index+offset,points.size())
		var edge: Vector2 = points[(i+1)%points.size()]-points[i]
		var t: float = clampf((point-points[i]).dot(edge)/maxf(edge.length_squared(),0.00001),0.0,1.0)
		var distance: float = point.distance_squared_to(points[i]+edge*t)
		if distance < best: best = distance; result = lerpf(cumulative[i],cumulative[i+1],t)
	return result

func serialize() -> Dictionary:
	var rows: Array = []
	for i: int in range(points.size()):
		rows.append([points[i].x,points[i].y,headings[i],curvature[i],speeds[i],grips[i],resistance[i],lower[i]-offsets[i],upper[i]-offsets[i],layers[i]])
	return {"version":VERSION,"key":cache_key,"safe_reference":safe_reference,"length":length,"route_length":route_length,"spacing":spacing,"reference_seconds":reference_seconds,"curvature_before":curvature_before,"curvature_after":curvature_after,"blocked_samples":blocked_samples,"strategy":strategy,"pilot_ticks":pilot_ticks,"pilot_candidates":pilot_candidates,"rows":rows}

func restore(data: Dictionary, track: NativeTrack, config: HandlingConfig) -> bool:
	if data.get("version") != VERSION or data.get("key") != identity(track,config) or not data.get("rows") is Array: return false
	if data.get("strategy") not in ["minimum_curvature","smoothing","center","minimum_time","short_line"] or not data.get("pilot_candidates") is Array: return false
	if data.pilot_candidates.size() > 5 or (not data.get("pilot_ticks") is int and not data.get("pilot_ticks") is float): return false
	if not is_finite(float(data.pilot_ticks)) or float(data.pilot_ticks) < 0.0 or float(data.pilot_ticks) > 15000.0: return false
	var rows: Array = data.rows
	if rows.size() < 16 or rows.size() > MAX_SAMPLES: return false
	for key: String in ["length","route_length","spacing","reference_seconds","curvature_before","curvature_after","blocked_samples"]:
		if not data.get(key) is float and not data.get(key) is int: return false
		if not is_finite(float(data[key])) or float(data[key]) < 0.0: return false
	if float(data.length) <= 0.0 or absf(float(data.route_length)-track.route_length) > 0.00001 or absf(float(data.spacing)*rows.size()-track.route_length) > 0.00001: return false
	for row: Variant in rows:
		if not row is Array or row.size() != 10: return false
		for value: Variant in row:
			if (not value is float and not value is int) or not is_finite(float(value)): return false
		if float(row[4]) <= 0.0 or float(row[5]) <= 0.0 or float(row[7]) > 0.0 or float(row[8]) < 0.0 or (float(row[9]) != 0.0 and float(row[9]) != 1.0): return false
	if not data.get("safe_reference",false) is bool: return false
	safe_reference = bool(data.get("safe_reference",false))
	cache_key = data.key; route_length = data.route_length; spacing = data.spacing
	strategy = str(data.get("strategy","unknown")); pilot_ticks = int(data.get("pilot_ticks",0)); pilot_candidates = data.get("pilot_candidates",[])
	reference_seconds = data.reference_seconds; curvature_before = data.curvature_before; curvature_after = data.curvature_after; blocked_samples = int(data.blocked_samples)
	points.resize(rows.size()); headings.resize(rows.size()); curvature.resize(rows.size()); speeds.resize(rows.size()); grips.resize(rows.size()); resistance.resize(rows.size()); lower.resize(rows.size()); upper.resize(rows.size()); offsets.resize(rows.size()); layers.resize(rows.size())
	offsets.fill(0.0)
	for i: int in range(rows.size()):
		var row: Array = rows[i]
		points[i] = Vector2(row[0],row[1]); headings[i] = row[2]; curvature[i] = row[3]; speeds[i] = row[4]; grips[i] = row[5]; resistance[i] = row[6]; lower[i] = row[7]; upper[i] = row[8]; layers[i] = int(row[9])
	_measure_distance()
	if absf(length-float(data.length)) > 0.00001: return false
	return true
