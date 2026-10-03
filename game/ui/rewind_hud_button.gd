class_name RewindHUDButton
extends Button
## Compact race-HUD rewind action with the current resource shown as a badge.

const AD_ICON: Texture2D = preload("res://ui/icons/rewarded_ad.svg")
const REWIND_ICON: Texture2D = preload("res://ui/icons/rewind.svg")
var banked: int = 0
var use_ad: bool = true
var race_remaining: int = 3

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2(60,60)
	tooltip_text = "Rewind up to 10 seconds"

func show_resource(wallet: Dictionary, used: int) -> void:
	banked = maxi(0,int(wallet.get("balance",0)))
	use_ad = banked == 0
	race_remaining = maxi(0,3-used)
	tooltip_text = "Race rewind limit reached" if race_remaining == 0 else ("Rewind up to 10 seconds · %d banked" % banked if banked > 0 else "Rewind up to 10 seconds · ad resume")
	queue_redraw()

func _draw() -> void:
	var ink := Color("eef6fb")
	if disabled: ink.a = 0.32
	draw_texture_rect(REWIND_ICON,Rect2(size*0.5-Vector2(26,26),Vector2(52,52)),false,ink)
	var badge_center := Vector2(size.x-7,size.y-5)
	if use_ad:
		# The artwork has its own readable video/AD outline; no extra badge ring.
		draw_texture_rect(AD_ICON,Rect2(badge_center-Vector2(18,15),Vector2(36,30)),false,Color(1,1,1,0.32 if disabled else 1.0))
	else:
		var badge_fill := Color("172129")
		badge_fill.a = 0.9 if not disabled else 0.72
		draw_circle(badge_center,13,badge_fill)
		draw_arc(badge_center,13,0,TAU,32,ink,1.5,true)
		var label := str(banked)
		var width := RaceHUDStyle.DISPLAY.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		draw_string(RaceHUDStyle.DISPLAY,badge_center+Vector2(-width*0.5,5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
