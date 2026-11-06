extends RefCounted
## Candidate: remove only block bodies guarded by a leading false constant.
static func reduce(source: String) -> String:
	var masked: String = mask(source)
	var constants: Dictionary = {}
	var declarations := RegEx.new(); declarations.compile("\\bconst\\s+bool\\s+(\\w+)\\s*=\\s*(true|false)\\s*;")
	for found: RegExMatch in declarations.search_all(masked): constants[found.get_string(1)] = found.get_string(2) == "true"
	var guards := RegEx.new(); guards.compile("\\bif\\s*\\(\\s*(!?)\\s*(\\w+)\\s*(?=\\)|&&)")
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
		var disjunction: bool = false
		while index < masked.length() and depth > 0:
			var char: String = masked[index]
			if char == "(": depth += 1
			elif char == ")": depth -= 1
			elif depth == 1 and (char == "|" or char == "?"): disjunction = true
			index += 1
		if depth != 0 or disjunction: continue
		while index < masked.length() and masked[index] in [" ","\t","\n","\r"]: index += 1
		if index >= masked.length() or masked[index] != "{": continue
		open = index; depth = 1; index += 1
		while index < masked.length() and depth > 0:
			if masked[index] == "{": depth += 1
			elif masked[index] == "}": depth -= 1
			index += 1
		if depth != 0: continue
		# Preserve condition, braces, else and declarations outside this block.
		edits.append(Vector2i(open+1,index-1)); until = index
	for edit: Vector2i in reversed(edits): source = source.substr(0,edit.x)+source.substr(edit.y)
	return source

static func reversed(values: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = values.duplicate(); result.reverse(); return result

static func mask(source: String) -> String:
	var bytes: PackedByteArray = source.to_utf8_buffer()
	# Author shaders use ASCII syntax. Replace comment/string characters with
	# spaces in a same-length character mask, keeping offsets in String units.
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
