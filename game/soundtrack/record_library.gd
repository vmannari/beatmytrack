extends RefCounted
## Authored complete mixes supplied for the menu soundtrack.
const DEFAULT_ID: String = "blacktop_thunder"
const CATALOG: Array[Dictionary] = [
	{"id":"blacktop_thunder","title":"Blacktop Thunder","asset":"res://assets/audio/soundtrack_2026_v1/01-blacktop-thunder.mp3","palette":["20232b","eec477"],"design":0},
	{"id":"saltwater_turns","title":"Saltwater Turns","asset":"res://assets/audio/soundtrack_2026_v1/02-saltwater-turns.mp3","palette":["184758","f0d59c"],"design":1},
	{"id":"copper_mile","title":"Copper Mile","asset":"res://assets/audio/soundtrack_2026_v1/03-copper-mile.mp3","palette":["453329","e6a86f"],"design":2},
	{"id":"dust_and_daybreak","title":"Dust And Daybreak","asset":"res://assets/audio/soundtrack_2026_v1/04-dust-and-daybreak.mp3","palette":["5a3932","f5cf91"],"design":3},
	{"id":"sparkplug_riot","title":"Sparkplug Riot","asset":"res://assets/audio/soundtrack_2026_v1/05-sparkplug-riot.mp3","palette":["302b32","ec7750"],"design":4},
	{"id":"sunstruck_avenue","title":"Sunstruck Avenue","asset":"res://assets/audio/soundtrack_2026_v1/06-sunstruck-avenue.mp3","palette":["b96a49","ffe3a8"],"design":5},
	{"id":"circuit_bounce","title":"Circuit Bounce","asset":"res://assets/audio/soundtrack_2026_v1/07-circuit-bounce.mp3","palette":["1b5550","f8ce77"],"design":6},
	{"id":"sidewalk_smiles","title":"Sidewalk Smiles","asset":"res://assets/audio/soundtrack_2026_v1/08-sidewalk-smiles.mp3","palette":["db995e","fff1c5"],"design":7},
	{"id":"midnight_palms","title":"Midnight Palms","asset":"res://assets/audio/soundtrack_2026_v1/09-midnight-palms.mp3","palette":["1c334b","e9a394"],"design":8},
	{"id":"afterglow_run","title":"Afterglow Run","asset":"res://assets/audio/soundtrack_2026_v1/10-afterglow-run.mp3","palette":["674251","ffd5a0"],"design":9},
	{"id":"electric_trail","title":"Electric Trail","asset":"res://assets/audio/soundtrack_2026_v1/11-electric-trail.mp3","palette":["223a57","8de5d0"],"design":10},
	{"id":"windward_roads","title":"Windward Roads","asset":"res://assets/audio/soundtrack_2026_v1/12-windward-roads.mp3","palette":["3e686b","e9d5a8"],"design":11},
	{"id":"kickstart_junction","title":"Kickstart Junction","asset":"res://assets/audio/soundtrack_2026_v1/13-kickstart-junction.mp3","palette":["a04e37","ffe3ac"],"design":12},
	{"id":"redline_ramble","title":"Redline Ramble","asset":"res://assets/audio/soundtrack_2026_v1/14-redline-ramble.mp3","palette":["4b2e30","f5b16f"],"design":13},
]
static var covers: Dictionary = {}

static func entries(_settings: Dictionary = {}) -> Array[Dictionary]:
	return CATALOG.duplicate(true)

static func entry(id: String) -> Dictionary:
	for item: Dictionary in CATALOG:
		if item.id == id: return item.duplicate(true)
	return {}

static func playable(id: String) -> bool:
	var item: Dictionary = entry(id)
	return not item.is_empty() and not item.asset.is_empty()

static func selected(settings: Dictionary) -> Dictionary:
	var id: Variant = settings.get("music_record",DEFAULT_ID)
	return entry(id) if id is String and playable(id) else entry(DEFAULT_ID)

static func asset(item: Dictionary) -> String:
	var authored: Dictionary = entry(str(item.get("id","")))
	return authored.get("asset","")

static func stream(item: Dictionary) -> AudioStream:
	var path: String = asset(item)
	return null if path.is_empty() else load(path) as AudioStream

static func valid_id(value: Variant) -> bool:
	return value is String and not entry(value).is_empty()

static func valid_playlist(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size() > CATALOG.size(): return false
	var seen: Dictionary = {}
	for id: Variant in value:
		if not valid_id(id) or seen.has(id): return false
		seen[id] = true
	return true

static func playlist(settings: Dictionary) -> Array[Dictionary]:
	var ids: Variant = settings.get("music_playlist")
	if not valid_playlist(ids): return entries()
	var result: Array[Dictionary] = []
	for item: Dictionary in CATALOG:
		if item.id in ids: result.append(item.duplicate(true))
	return result

static func next_record(settings: Dictionary, current: String, direction: int = 1) -> Dictionary:
	var collection: Array[Dictionary] = playlist(settings)
	var index: int = -1
	for i: int in range(CATALOG.size()):
		if CATALOG[i].id == current: index = i; break
	for step: int in range(1,CATALOG.size()+1):
		var candidate: Dictionary = CATALOG[posmod(index+step*direction,CATALOG.size())]
		for item: Dictionary in collection:
			if item.id == candidate.id: return item
	return collection[0]

static func palette(id: String) -> Array[Color]:
	var item: Dictionary = entry(id)
	if item.is_empty(): item = entry(DEFAULT_ID)
	return [Color(item.palette[0]),Color(item.palette[1])]

static func cover(id: String) -> Texture2D:
	if covers.has(id): return covers[id]
	if entry(id).is_empty(): return cover(DEFAULT_ID)
	var texture: Texture2D = load("res://assets/music_covers_v2/" + id + ".png") as Texture2D
	covers[id] = texture
	return texture
