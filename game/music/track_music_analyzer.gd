class_name TrackMusicAnalyzer
extends RefCounted
const MUSIC_ENGINE_VERSION: int = 1
var length: float = 0.0
var spacing: float = 2.0
var seed_value: int = 1
var states := PackedVector3Array()
var curvature := PackedFloat32Array()
var expected_speed := PackedFloat32Array()
var widths := PackedFloat32Array()
var bridges := PackedByteArray()
var points := PackedVector2Array()
var semantics := PackedStringArray()
var straight_ahead := PackedFloat32Array()
var biome: String = "pine"
var surface: String = "asphalt"

static func fingerprint(track: NativeTrack) -> int:
	# Explicit musical content excludes title, author, publication date and records.
	var definition: Array = [MUSIC_ENGINE_VERSION, Array(track.route), Array(track.route_widths),
		track.finish_center, track.finish_forward, track.metadata.get("theme","pine"),
		track.metadata.get("creator_document",{}).get("surface","asphalt"), track.creator_bridges,
		track.metadata.get("creator_document",{}).get("pieces",[])]
	return JSON.stringify(definition,"",true,true).sha256_text().substr(0,8).hex_to_int()

func build(track: NativeTrack, profile: MusicProfile) -> void:
	length = track.route_length
	seed_value = fingerprint(track)
	states.clear(); curvature.clear(); expected_speed.clear(); widths.clear(); bridges.clear(); points.clear()
	semantics.clear(); straight_ahead.clear()
	biome = str(track.metadata.get("theme","pine"))
	var document: Dictionary = track.metadata.get("creator_document",{})
	surface = str(document.get("surface","asphalt"))
	# Reuse the editor's road-piece sampler. Spatial buckets keep this loading-only
	# association bounded locally; tangent matching disambiguates at-grade crossings.
	var buckets: Dictionary = {}
	for piece: Dictionary in document.get("pieces",[]):
		var samples: PackedVector2Array = RoadPieces.samples(piece)
		for j: int in range(samples.size()-1):
			var cell := Vector2i(floori(samples[j].x/4.0),floori(samples[j].y/4.0))
			if not buckets.has(cell): buckets[cell] = []
			buckets[cell].append([samples[j],(samples[j+1]-samples[j]).normalized(),str(piece.kind)])
	if length < 1.0 or track.route.size() < 3: return
	var count: int = clampi(ceili(length/profile.sample_spacing),8,16384)
	spacing = length/count
	var hint: int = 0
	for i: int in range(count):
		var d: float = i*spacing
		var p: Vector2 = track._race_route_point(d)
		var incoming: Vector2 = p-track._race_route_point(d-6.0)
		var outgoing: Vector2 = track._race_route_point(d+6.0)-p
		var k: float = incoming.angle_to(outgoing)/6.0
		var semantic: String = ""
		var cell := Vector2i(floori(p.x/4.0),floori(p.y/4.0))
		var best: float = 4.0
		for dx: int in range(-1,2):
			for dy: int in range(-1,2):
				for entry: Array in buckets.get(cell+Vector2i(dx,dy),[]):
					var separation: float = p.distance_squared_to(entry[0])
					if separation<best and absf(outgoing.normalized().dot(entry[1]))>.7:
						best = separation; semantic = entry[2]
		semantics.append(semantic)
		curvature.append(k)
		points.append(p)
		hint = track.nearest_route(p,hint)
		widths.append(track.route_widths[hint] if track.route_widths.size()==track.route.size() else 9.0)
		bridges.append(1 if track.elevated_at(p,hint) else 0)
		expected_speed.append(clampf(sqrt(profile.target_lateral_acceleration/maxf(absf(k),0.005)),8.0,42.0))
		var severity: float = clampf(absf(k)/profile.curvature_full_tension,0.0,1.0)
		if semantic == "s_bend": severity = maxf(severity,0.45)
		if semantic == "hairpin": severity = maxf(severity,0.6)
		states.append(Vector3(0.9-severity*0.3,0.1+severity*0.8,1.0-severity*0.9))
	# Circular convolution smooths piece joins and the lap seam equally.
	var raw: PackedVector3Array = states.duplicate()
	for i: int in range(count):
		var value := Vector3.ZERO
		for offset: int in range(-2,3): value += raw[posmod(i+offset,count)]/5.0
		if bridges[i] != 0: value.x *= 0.88
		states[i] = value
		var straight: float = 0.0
		for ahead: int in range(mini(count,ceili(100.0/spacing))):
			if absf(curvature[(i+ahead)%count])>.018: break
			straight += spacing
		straight_ahead.append(straight)

func sample(distance: float) -> Vector3:
	if states.is_empty(): return Vector3(0.5,0.1,0.5)
	var p: float = fposmod(distance,length)/spacing
	var i: int = floori(p)%states.size()
	return states[i].lerp(states[(i+1)%states.size()],p-floorf(p))

func index_at(distance: float) -> int:
	return floori(fposmod(distance,maxf(length,1.0))/spacing)%maxi(states.size(),1)

func feature(distance: float) -> String:
	if states.is_empty(): return "No route"
	var i: int = index_at(distance)
	if bridges[i] != 0: return "Bridge"
	if semantics[i] == "s_bend": return "S-curve"
	if semantics[i] == "hairpin": return "Hairpin"
	if absf(curvature[i]) > 0.09: return "Hairpin"
	var ahead: int = index_at(distance+12.0)
	if curvature[i]*curvature[ahead] < -0.0004: return "S-curve"
	if absf(curvature[i]) > 0.018: return "Curve"
	return "Straight"
