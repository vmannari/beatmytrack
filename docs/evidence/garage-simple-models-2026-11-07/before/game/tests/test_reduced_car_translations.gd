extends SceneTree
## ACM01: project-loaded translations retain the actual UTF-8 description.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/aggressive-car-models-2026-11-07/translation-expectations.json"))
	var original: String=TranslationServer.get_locale()
	var failures: int=0
	for language: String in expected:
		TranslationServer.set_locale(language)
		if GameText.message(expected.en)!=expected[language]:
			failures+=1
			printerr("REDUCED_TRANSLATION_FAIL ",language)
	TranslationServer.set_locale(original)
	print("REDUCED_CAR_TRANSLATIONS ",expected.size()," checks, ",failures," failures")
	quit(1 if failures else 0)
