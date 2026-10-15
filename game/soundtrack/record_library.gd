extends RefCounted
## Authored LP catalogue. Placeholder sleeves have no audio or file-loading path.
const DEFAULT_ID: String = "exploration"
const DEFAULT_ASSET: String = "res://assets/audio/menu_exploration_v1/exploration_menu_loop.ogg"
const CATALOG: Array[Dictionary] = [
	{"id":"exploration","title":"Exploration","asset":DEFAULT_ASSET,"palette":["203d43","dfbc72"],"design":0},
	{"id":"open_road","title":"Open Road","asset":"","palette":["49343b","e4ab83"],"design":1},
	{"id":"after_hours","title":"After Hours","asset":"","palette":["292c49","c9b2db"],"design":2},
	{"id":"golden_hour","title":"Golden Hour","asset":"","palette":["644231","e7c282"],"design":3},
	{"id":"coastline","title":"Coastline","asset":"","palette":["274c53","a7d0ce"],"design":4},
	{"id":"night_drive","title":"Night Drive","asset":"","palette":["253343","b9c8d9"],"design":5},
	{"id":"workshop_sessions","title":"Workshop Sessions","asset":"","palette":["384739","c7c99e"],"design":6},
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
	return null if path.is_empty() else AudioLoop.prepare(load(path) as AudioStream)

# Read old settings safely, then discard the retired import metadata in LocalRecords.
# Old copied files are never loaded or deleted; there is no import/decode/remove API.
static func legacy_id(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true

static func valid_id(value: Variant) -> bool:
	return value is String and (not entry(value).is_empty() or legacy_id(value))

static func valid_collection(value: Variant) -> bool:
	if not value is Array or value.size()>12: return false
	var ids: Dictionary = {}
	for item: Variant in value:
		if not item is Dictionary or item.size()!=3 or not legacy_id(item.get("id")) or ids.has(item.id): return false
		if item.get("format") not in ["mp3","ogg","wav"]: return false
		var title: Variant = item.get("title")
		if not title is String or title.strip_edges().is_empty() or title.length()>64: return false
		for character: String in title:
			if character.unicode_at(0)<32: return false
		ids[item.id] = true
	return true

static func palette(id: String) -> Array[Color]:
	var item: Dictionary = entry(id)
	if item.is_empty(): item = entry(DEFAULT_ID)
	return [Color(item.palette[0]),Color(item.palette[1])]

static func cover(id: String) -> Texture2D:
	if covers.has(id): return covers[id]
	var item: Dictionary = entry(id)
	if item.is_empty(): return cover(DEFAULT_ID)
	var colors: Array[Color] = palette(id)
	var bg: String = colors[0].to_html(false)
	var ink: String = colors[1].to_html(false)
	var art: String
	match int(item.design):
		0: art = "<g fill='none' stroke='%s' stroke-width='2'><circle cx='132' cy='130' r='90'/><circle cx='132' cy='130' r='72'/><circle cx='132' cy='130' r='54'/><circle cx='132' cy='130' r='36'/></g><path d='M0 202L256 90V158L0 256Z' fill='%s'/>" % [ink,ink]
		1: art = "<path d='M110 256L122 70H139L154 256Z' fill='%s'/><path d='M0 182L116 113V124L0 205ZM256 176L143 108V120L256 204Z' fill='%s'/><circle cx='132' cy='62' r='23' fill='%s'/>" % [ink,ink,ink]
		2: art = "<circle cx='159' cy='115' r='68' fill='%s'/><circle cx='179' cy='94' r='61' fill='%s'/><g stroke='%s' stroke-width='2'><path d='M22 216H234M22 232H234M22 200H234'/></g>" % [ink,bg,ink]
		3: art = "<circle cx='128' cy='111' r='64' fill='%s'/><g stroke='%s' stroke-width='8'><path d='M12 162H244M12 180H244M12 198H244M12 216H244'/></g>" % [ink,ink]
		4: art = "<g fill='none' stroke='%s' stroke-width='5'><path d='M-20 96Q44 48 108 96T236 96T364 96M-20 126Q44 78 108 126T236 126T364 126M-20 156Q44 108 108 156T236 156T364 156M-20 186Q44 138 108 186T236 186T364 186'/></g>" % ink
		5: art = "<g fill='none' stroke='%s' stroke-width='3'><path d='M22 238V104H44V65H67V238M89 238V140H114V100H133V238M159 238V90H186V47H212V238'/></g><circle cx='111' cy='62' r='16' fill='%s'/>" % [ink,ink]
		_: art = "<g fill='none' stroke='%s' stroke-width='4'><circle cx='128' cy='135' r='77'/><circle cx='128' cy='135' r='55'/><circle cx='128' cy='135' r='12'/><path d='M128 58V80M205 135H183M128 212V190M51 135H73'/></g>" % ink
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='256' height='256'><rect width='256' height='256' fill='#%s'/>%s<rect x='18' y='18' width='50' height='5' fill='#%s'/></svg>" % [bg,art.replace("'"+bg+"'","'#"+bg+"'").replace("'"+ink+"'","'#"+ink+"'"),ink]
	var bitmap := Image.new()
	bitmap.load_svg_from_string(svg)
	bitmap.generate_mipmaps()
	var texture := ImageTexture.create_from_image(bitmap)
	covers[id] = texture
	return texture
