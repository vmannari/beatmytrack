extends RefCounted
## Presentation and authoring defaults. Canonical sampling stays in RoadPieces.
const KINDS: Array[String] = ["straight","taper","curve","s_bend","hairpin","bridge","spline"]
const DESCRIPTORS: Dictionary = {
	"straight":{"title":"Straight","length":28.0,"radius":16.0,"handles":["width"]},
	"taper":{"title":"Taper","length":28.0,"radius":16.0,"handles":["width","narrow_width","length"]},
	"curve":{"title":"Curve","length":0.0,"radius":16.0,"handles":["width","curvature","angle"]},
	"s_bend":{"title":"S-bend","length":2.0,"radius":16.0,"handles":["width","radius","height"]},
	"hairpin":{"title":"Hairpin","length":0.0,"radius":12.0,"handles":["width","radius","length"]},
	"bridge":{"title":"Bridge","length":48.0,"radius":16.0,"handles":["length","width","heading"]},
	"spline":{"title":"Spline","length":0.0,"radius":16.0,"handles":[]}
}

static func title(kind: String) -> String:
	return str(DESCRIPTORS[kind].title)

static func handles(kind: String) -> Array[String]:
	var result: Array[String] = []
	result.assign(DESCRIPTORS[kind].handles)
	return result
