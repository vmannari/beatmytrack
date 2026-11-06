extends RefCounted
## Remove unreachable bodies before Godot records native shader feature usage.
## Conditions, else branches, public uniforms and active arithmetic stay intact.
static func reduce(source: String, names: Array[String]) -> String:
	if source.is_empty(): return source
	var masked: String = _mask(source)
	var constants: Dictionary = {}
	var declarations := RegEx.new()
	declarations.compile("(?m)^\\s*const\\s+bool\\s+(\\w+)\\s*=\\s*(true|false)\\s*;")
	for found: RegExMatch in declarations.search_all(masked):
		var name: String = found.get_string(1)
		if name not in names: continue
		var prefix: String = masked.substr(0,found.get_start())
		if prefix.count("{") != prefix.count("}"): continue
		# A local variable/parameter or a second conditional declaration makes
		# the name ambiguous. Keep its original branches in that case.
		var bindings := RegEx.new()
		bindings.compile("\\bbool\\s+"+name+"\\b")
		if bindings.search_all(masked).size() != 1: continue
		bindings.compile("\\bbool\\s+[^;{}]*,\\s*"+name+"\\b")
		if bindings.search(masked) != null: continue
		var macros := RegEx.new()
		macros.compile("(?m)^\\s*#\\s*(define|undef)\\s+"+name+"\\b")
		if macros.search(masked) != null: continue
		constants[name] = found.get_string(2) == "true"
	var guards := RegEx.new()
	guards.compile("\\bif\\s*\\(\\s*(!?)\\s*(\\w+)\\s*(?=\\)|&&)")
	var edits: Array[Vector2i] = []
	var until: int = -1
	for found: RegExMatch in guards.search_all(masked):
		if found.get_start() < until: continue
		var flag: String = found.get_string(2)
		if not constants.has(flag): continue
		var value: bool = constants[flag]
		if found.get_string(1) == "!": value = not value
		if value: continue
		var open: int = masked.find("(",found.get_start())
		var depth: int = 1
		var index: int = open+1
		var ambiguous: bool = false
		while index < masked.length() and depth > 0:
			var char: String = masked[index]
			if char == "(": depth += 1
			elif char == ")": depth -= 1
			elif char == "#" or (depth == 1 and char in ["|","^","?",","]): ambiguous = true
			index += 1
		if depth != 0 or ambiguous: continue
		while index < masked.length() and masked[index] in [" ","\t","\n","\r"]: index += 1
		if index >= masked.length() or masked[index] != "{": continue
		open = index; depth = 1; index += 1
		while index < masked.length() and depth > 0:
			if masked[index] == "{": depth += 1
			elif masked[index] == "}": depth -= 1
			index += 1
		if depth != 0: continue
		# Preprocessor directives can affect text outside a runtime-false body.
		if masked.substr(open+1,index-open-2).contains("#"): continue
		edits.append(Vector2i(open+1,index-1))
		until = index
	# Reverse offsets keep nested and adjacent removals independent.
	for edit_index: int in range(edits.size()-1,-1,-1):
		var edit: Vector2i = edits[edit_index]
		source = source.substr(0,edit.x)+source.substr(edit.y)
	return source

static func _mask(source: String) -> String:
	# A same-length character mask keeps Unicode offsets valid while excluding
	# comments and quoted include paths from brace and declaration matching.
	var result: PackedStringArray = source.split("")
	var index: int = 0
	while index < result.size():
		if source.substr(index,2) == "//":
			while index < result.size() and source[index] != "\n": result[index] = " "; index += 1
		elif source.substr(index,2) == "/*":
			var end: int = source.find("*/",index+2)
			end = source.length() if end < 0 else end+2
			while index < end: result[index] = " "; index += 1
		elif source[index] == '"':
			result[index] = " "; index += 1
			while index < result.size():
				var char: String = source[index]; result[index] = " "; index += 1
				if char == "\\" and index < result.size(): result[index] = " "; index += 1
				elif char == '"': break
		else: index += 1
	return "".join(result)
