extends RefCounted
## One pointer transaction. Tool domains define the exact rollback boundary.
enum Phase { IDLE, POINTER, EDIT, NAVIGATION }
const DOMAINS: Dictionary = {
	"road":["pieces","start_line"], "objects":["objects","hidden_scenery"],
	"place":["objects","hidden_scenery"], "run":["objects","hidden_scenery"],
	"start":["practice_start"], "start_line":["start_line"], "paint":["paint"],
	"move":["points","widths","corners"], "add":["points","widths","corners"]
}
var phase: Phase = Phase.IDLE
var before: Dictionary = {}
var absent: Array[String] = []
var ghost: Dictionary = {}

func begin(preview: Dictionary, navigation: bool) -> void:
	clear()
	ghost = preview.duplicate(true)
	phase = Phase.NAVIGATION if navigation else Phase.POINTER

func capture(document: Dictionary, tool: String) -> void:
	if not before.is_empty() or not absent.is_empty(): return
	var keys: Array = ["route_override"]+DOMAINS.get(tool,[])
	for key: String in keys:
		if not document.has(key): absent.append(key); continue
		var value: Variant = document[key]
		before[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	phase = Phase.EDIT

func rollback(document: Dictionary) -> bool:
	var restored: bool = not before.is_empty() or not absent.is_empty()
	for key: String in absent: document.erase(key)
	for key: String in before:
		var value: Variant = before[key]
		document[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	phase = Phase.NAVIGATION
	return restored

func clear() -> void:
	before.clear(); absent.clear(); ghost.clear(); phase = Phase.IDLE
