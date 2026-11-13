extends RefCounted
## Account-scoped cumulative lifetimes. Eviction starts a new source, never resets
## counters under an old source ID. The outbox persists sources with their events.
const FIELDS: Array[String] = ["dropped_events","rejected_events","persistence_failures"]
const MAX_SCOPES: int = 32
var sources: Dictionary = {}
var cursor: Array[int] = [0,0,0]

func capture(scope: String, current: Array[int]) -> bool:
	var changes: Array[int] = []
	for index: int in range(3): changes.append(maxi(0,current[index]-cursor[index]))
	cursor = current.duplicate()
	if scope == "guest" or changes == [0,0,0]: return false
	var source: Dictionary = sources.get(scope,{"counter_id":"","dropped_events":0,"rejected_events":0,"persistence_failures":0})
	for index: int in range(3): source[FIELDS[index]] = mini(1000000,int(source[FIELDS[index]])+changes[index])
	sources.erase(scope)
	sources[scope] = source
	while sources.size() > MAX_SCOPES: sources.erase(sources.keys()[0])
	return true

func clear(current: Array[int]) -> void:
	sources.clear()
	cursor = current.duplicate()

func restore(saved: Variant, current: Array[int]) -> void:
	# Newly observed startup losses precede completion of the asynchronous read.
	var pending: Dictionary = sources
	sources = {}
	var scope_pattern := RegEx.create_from_string("^[a-f0-9]{64}$")
	var id_pattern := RegEx.create_from_string("^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$")
	if saved is Dictionary:
		for scope: Variant in saved:
			if not scope is String or scope_pattern.search(scope) == null: continue
			var source: Variant = saved[scope]
			if not source is Dictionary or not source.get("counter_id") is String: continue
			if not source.counter_id.is_empty() and id_pattern.search(source.counter_id) == null: continue
			var safe: Dictionary = {"counter_id":source.counter_id}
			for field: String in FIELDS:
				var count: Variant = source.get(field)
				if not (count is int or count is float) or not is_finite(float(count)) or count != int(count) or count < 0 or count > 1000000: break
				safe[field] = int(count)
			if safe.size() == 4: sources[scope] = safe
			if sources.size() >= MAX_SCOPES: break
	for scope: String in pending:
		var source: Dictionary = sources.get(scope,pending[scope].duplicate())
		if sources.has(scope):
			for field: String in FIELDS: source[field] = mini(1000000,int(source[field])+int(pending[scope][field]))
		sources.erase(scope)
		sources[scope] = source
	while sources.size() > MAX_SCOPES: sources.erase(sources.keys()[0])
	cursor = current.duplicate()
