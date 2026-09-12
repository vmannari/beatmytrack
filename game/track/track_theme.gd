class_name TrackTheme
extends RefCounted
## Allowlisted original art palettes shared by native scenery and creator previews.
## Surface IDs retain the same driving meaning in every theme.

const IDS: Array[String] = ["pine", "coast", "desert"]
const PINE: Array[Color] = [Color("333e41"), Color("46563f"), Color("948266"), Color("32565e"), Color("717b72"), Color("bdbdab"), Color("577c7e"), Color("786f5c")]
const COAST: Array[Color] = [Color("374348"), Color("64745e"), Color("af9b77"), Color("315e69"), Color("889084"), Color("c5c4b3"), Color("648e91"), Color("948c77")]
const DESERT: Array[Color] = [Color("3e4140"), Color("82775a"), Color("b29874"), Color("3b6165"), Color("9a8870"), Color("c7bc9e"), Color("718c85"), Color("948063")]


static func normalized(theme: String) -> String:
	return theme if theme in IDS else "pine"


static func title(theme: String) -> String:
	match normalized(theme):
		"coast": return "Coastal heath"
		"desert": return "Desert mesa"
	return "Pine country"


static func palette(theme: String) -> Array[Color]:
	match normalized(theme):
		"coast": return COAST.duplicate()
		"desert": return DESERT.duplicate()
	return PINE.duplicate()


static func foliage(theme: String) -> Color:
	match normalized(theme):
		"coast": return Color("536750")
		"desert": return Color("646950")
	return Color("344d3e")


static func stone(theme: String) -> Color:
	match normalized(theme):
		"coast": return Color("a4ab99")
		"desert": return Color("a88a67")
	return Color("7b8275")
