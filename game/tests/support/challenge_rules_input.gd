extends RefCounted
## Test input adapter for current Challenge controls; owns no production policy.
static func choose(sheet: ChallengeCreate, choices: Dictionary) -> void:
	var was_format: bool = sheet._step == ChallengeCreate.FORMAT
	if not sheet.results_only:
		var open: Button = sheet._custom_button if was_format else sheet._rules_button
		open.pressed.emit()
	for key: String in choices:
		var prefix: String = {"mode":"ChallengeResultMode_" if sheet.results_only else "ChallengeCustomMode_","duration":"ChallengeDuration_","tries":"ChallengeTries_"}[key]
		var button: Button = sheet.find_child(prefix+str(choices[key]),true,false)
		assert(button != null and not button.disabled)
		button.pressed.emit()
	if not sheet.results_only:
		sheet.get_ok_button().pressed.emit()
		if was_format: (sheet.find_child("CloseChallengeCreate",true,false) as Button).pressed.emit()
