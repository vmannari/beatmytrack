class_name AchievementBadge
extends Control
## Shared original vector artwork: forty emblems, five fixed metal states.
const ATLAS: Texture2D = preload("res://assets/achievements/medals.svg")
const METALS: Array[Color] = [Color("475760"),Color("b98759"),Color("bdcbd0"),Color("e3be67"),Color("d4eee8")]
static var _textures: Dictionary = {}
var tier: int = 0
var prestige: bool = false
var motif: int = 0
var family_id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(72,80)

static func region(index: int, level: int) -> Rect2:
	return Rect2(Vector2((index%10)*128,(index/10)*640+clampi(level,0,4)*128),Vector2(128,128))

static func texture(index: int, level: int) -> AtlasTexture:
	var key: int = index*5+clampi(level,0,4)
	if not _textures.has(key):
		var result := AtlasTexture.new()
		result.atlas = ATLAS
		result.region = region(index,level)
		result.filter_clip = true
		_textures[key] = result
	return _textures[key]

func _draw() -> void:
	var index: int = motif
	var honor: bool = prestige
	if not family_id.is_empty():
		for i: int in range(AchievementProgress.catalog().families.size()):
			if AchievementProgress.catalog().families[i].id == family_id:
				index = i
				honor = bool(AchievementProgress.catalog().families[i].prestige)
				break
	var width: float = minf(size.x,size.y)
	draw_texture_rect(texture(index,3 if honor and tier > 0 else tier),Rect2((size-Vector2.ONE*width)*0.5,Vector2.ONE*width),false)
