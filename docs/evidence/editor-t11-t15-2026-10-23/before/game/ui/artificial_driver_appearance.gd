extends RefCounted
## Stable per-account cosmetic variety for artificial drivers without a shared car.
## Presentation only: no random input or tuning enters race contracts.
const PALETTES: Array = [
	["a43f32","e5d6b3","282f38"], ["276982","e5ddc6","d2a558"],
	["52715b","e1d7b9","a9643d"], ["c2a55d","303d4b","e9dfc8"],
	["ded7c4","a03f34","343e49"], ["303b4d","cbb98a","aa4b36"],
	["884739","d1ba86","e5dfd0"], ["7a8992","293c50","d3a950"],
	["596a42","d3bf86","312f30"], ["a86833","eee0c0","344d5a"],
	["5c4965","c9bda8","e1ca80"], ["bcae94","314e57","9d493a"],
	["28565a","d8bb73","e5dfd0"], ["a88648","333744","d8d2c3"],
	["68798c","e8dfca","994e3c"], ["8b3e48","d7c8a0","303f50"]]

static func _choice(identity: String, key: String, count: int) -> int:
	return ("bmt-artificial-car-v1/"+identity+"/"+key).sha256_text().substr(0,8).hex_to_int()%count

static func _pigment(source: String, identity: String, slot: String) -> String:
	var base := Color(source)
	return Color(
		clampi(roundi(base.r*255.0)+_choice(identity,slot+"/r",25)-12,0,255)/255.0,
		clampi(roundi(base.g*255.0)+_choice(identity,slot+"/g",25)-12,0,255)/255.0,
		clampi(roundi(base.b*255.0)+_choice(identity,slot+"/b",25)-12,0,255)/255.0).to_html(false)

static func create(player_id: String, vehicle_id: String) -> Dictionary:
	var identity: String = player_id+"/"+vehicle_id
	var colors: Array = PALETTES[_choice(identity,"palette",PALETTES.size())]
	var livery: Dictionary = VehicleLivery.defaults(vehicle_id)
	livery.colors = {"body":_pigment(colors[0],identity,"body"),"accent":_pigment(colors[1],identity,"accent"),"detail":_pigment(colors[2],identity,"detail")}
	livery.pattern = str(LiveryCatalog.patterns[_choice(identity,"pattern",LiveryCatalog.patterns.size())].id)
	for surface: String in VehicleLivery.SURFACES:
		if surface == "roof" and not LiveryCatalog.has_roof(vehicle_id): continue
		if _choice(identity,surface+"/blank",4) == 0: continue
		var sticker: Dictionary = livery.stickers[surface]
		sticker.id = str(LiveryCatalog.stickers[_choice(identity,surface+"/sticker",LiveryCatalog.stickers.size())].id)
		sticker.size = 0.48+0.04*_choice(identity,surface+"/size",7)
		sticker.rotation = float([-90,0,90][_choice(identity,surface+"/rotation",3)])
	var parts: Dictionary = VehicleCustomisation.defaults()
	if vehicle_id == "compact":
		for category: String in VehicleCustomisation.CATEGORIES:
			var options: Array = VehicleCustomisation.OPTIONS[category]
			parts[category] = str(options[1+_choice(identity,"part/"+category,options.size()-1)][0])
	return {"vehicle_id":vehicle_id,"livery":livery,"customisation":parts}
