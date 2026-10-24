extends RefCounted
## Reusable route artwork; authority and volatile metadata still arrive in every page.
var cache = preload("res://backend/menu_snapshot_cache.gd").new()

func configure(directory: String, scope: String) -> void:
	cache.max_entries = 64
	cache.max_age_seconds = 31536000
	cache.configure(directory.path_join(scope.sha256_text()+".json") if not directory.is_empty() else "",scope)

func known() -> Array:
	var result: Array = []
	var keys: Array = cache.entries.keys()
	keys.reverse()
	for key: String in keys:
		if not cache.read(key).is_empty(): result.append(key)
		if result.size() == 32: break
	return result

func restore(page: Dictionary) -> bool:
	if not page.get("items") is Array: return false
	for item: Variant in page.items:
		if not item is Dictionary: return false
		var hash: String = str(item.get("preview_hash",""))
		if hash.is_empty(): continue
		if hash.length() != 64 or not hash.is_valid_hex_number(): return false
		if not item.has("points"):
			var saved: Dictionary = cache.read(hash)
			if not saved.get("points") is Array: return false
			item.points = saved.points
		elif not item.points is Array or item.points.size() > 96:
			return false
		else:
			cache.remember(hash,{"points":item.points})
	return true
