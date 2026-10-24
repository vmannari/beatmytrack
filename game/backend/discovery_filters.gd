extends RefCounted
## Current discovery filter contract, shared by cursor windows and search.

static func ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		if str(value).begins_with("cloud_"): result.append(str(value).trim_prefix("cloud_"))
	result.sort()
	return result

static func payload(filters: Dictionary, favorites: Array = [], raced: Array = []) -> Dictionary:
	var body: Dictionary = {"search":str(filters.get("search","")),"search_kind":int(filters.get("search_kind",0)),
		"theme":str(filters.get("theme","all")),"minimum_rating":float(filters.get("minimum_rating",0.0)),
		"age_days":int(filters.get("age_days",0)),"race_count":str(filters.get("race_count","any")),
		"race_history":str(filters.get("race_history","any")),"section":str(filters.get("section","all")),
		"feed":str(filters.get("feed","recommended")),"sort":str(filters.get("sort","recommended"))}
	if body.feed not in ["recommended","new","popular","trending","rated"]: body.feed = "recommended"
	if body.sort not in ["recommended","name","creator","score","plays","new"]: body.sort = "recommended"
	if body.section == "favorites": body.ids = ids(favorites)
	if body.race_history != "any": body.raced_ids = ids(raced)
	return body

