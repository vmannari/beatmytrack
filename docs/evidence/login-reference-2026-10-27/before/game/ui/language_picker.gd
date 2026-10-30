extends VBoxContainer
## The same immediate, saved choice is available before sign-in and in Settings.
var picker: OptionButton
var status: Label
var codes: Array[String] = []
var language: Node
var show_label: bool = true

func _ready() -> void:
	language = GameLanguage.instance()
	name = "LanguagePicker"
	add_theme_constant_override("separation",6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	add_child(row)
	if show_label: row.add_child(MenuStyle.label("Language",20))
	picker = OptionButton.new()
	picker.name = "LanguageChoice"
	picker.custom_minimum_size = Vector2(220,48)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	picker.accessibility_name = tr("Language")
	picker.item_selected.connect(_selected)
	row.add_child(picker)
	status = MenuStyle.label("",16,true)
	status.name = "LanguageSaveStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.hide()
	add_child(status)
	language.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	picker.clear()
	codes = ["system"]
	picker.add_item(tr("System default"))
	for code: String in language.locales:
		codes.append(code)
		picker.add_item(language.locales[code])
	picker.select(maxi(0,codes.find(language.preference)))
	picker.accessibility_name = tr("Language")

func _selected(index: int) -> void:
	if index < 0 or index >= codes.size(): return
	var error: Error = language.choose(codes[index])
	status.text = "Could not save the language. Please try again." if error != OK else ""
	status.visible = error != OK
	_refresh()

