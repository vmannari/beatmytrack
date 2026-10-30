class_name GameText
extends RefCounted
## Translate complete messages before inserting names/counts. Bindings refresh in place.
const GROUP: String = "localized_messages"
const META: String = "localized_message"
static var _named: RegEx = RegEx.create_from_string("\\{([a-zA-Z_][a-zA-Z0-9_]*)\\}")

static func message(source: String, values: Dictionary = {}, context: String = "") -> String:
	var translated: String = TranslationServer.translate(source,context)
	if TranslationServer.pseudolocalization_enabled and source.contains("{"):
		translated = _pseudo_named(source,"",0,context)
	return translated if values.is_empty() else _substitute(translated,values)

static func plural(one: String, many: String, count: int, values: Dictionary = {}, context: String = "") -> String:
	var arguments: Dictionary = values.duplicate()
	arguments["count"] = count
	var translated: String = TranslationServer.translate_plural(one,many,count,context)
	if TranslationServer.pseudolocalization_enabled and one.contains("{"):
		translated = _pseudo_named(one,many,count,context)
	return _substitute(translated,arguments)

static func _substitute(template: String, values: Dictionary) -> String:
	# Scan only the translated template. A name such as "{count}" must never
	# become another placeholder after it has been inserted into the message.
	var result: String = ""
	var offset: int = 0
	for matched: RegExMatch in _named.search_all(template):
		result += template.substr(offset,matched.get_start()-offset)
		result += str(values.get(matched.get_string(1),matched.get_string()))
		offset = matched.get_end()
	return result+template.substr(offset)

static func _pseudo_named(source: String, many: String, count: int, context: String) -> String:
	# The pinned engine's pseudo mode protects printf tokens, but accents {names}.
	# Read the untranslated template and expand only literal spans. Values stay intact.
	var catalog: Translation = TranslationServer.get_translation_object(TranslationServer.get_locale())
	var template: String = ""
	if catalog != null:
		template = catalog.get_message(source,context) if many.is_empty() else catalog.get_plural_message(source,many,count,context)
	if template.is_empty(): template = source if many.is_empty() or count == 1 else many
	var pattern := RegEx.create_from_string("\\{[a-zA-Z_][a-zA-Z0-9_]*\\}")
	var result: String = ""
	var offset: int = 0
	for matched: RegExMatch in pattern.search_all(template):
		if matched.get_start() > offset: result += String(TranslationServer.pseudolocalize(template.substr(offset,matched.get_start()-offset)))
		result += matched.get_string()
		offset = matched.get_end()
	if offset < template.length(): result += String(TranslationServer.pseudolocalize(template.substr(offset)))
	return result

static func bind(control: Control, source: String, values: Dictionary = {}, many: String = "", count: int = 0, context: String = "") -> void:
	control.set_meta(META,{"source":source,"values":values.duplicate(),"many":many,"count":count,"context":context})
	control.add_to_group(GROUP)
	# Never translate substituted player names or a formatted message a second time.
	control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var entered: Callable = _entered.bind(weakref(control))
	if not control.tree_entered.is_connected(entered): control.tree_entered.connect(entered)
	update(control)

static func update(control: Control) -> void:
	if not control.has_meta(META): return
	var data: Dictionary = control.get_meta(META)
	control.set("text",message(data.source,data.values,data.context) if str(data.many).is_empty() else plural(data.source,data.many,data.count,data.values,data.context))

static func _entered(reference: WeakRef) -> void:
	var control: Control = reference.get_ref()
	if is_instance_valid(control): update(control)

static func refresh(tree: SceneTree) -> void:
	for control: Node in tree.get_nodes_in_group(GROUP):
		if control is Control: update(control)

static func user_text(control: Control) -> void:
	control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED

