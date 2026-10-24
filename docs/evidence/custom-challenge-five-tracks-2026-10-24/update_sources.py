from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def edit(path, changes):
    if path.startswith("backend/"):
        return  # Already applied before the UI source guard interrupted this script.
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    for before, after in changes:
        assert before in text, (path, before)
        text = text.replace(before, after)
    file.write_text(text, encoding="utf-8", newline="\n")


edit("backend/bmt_backend/challenges.py", [
    ('min_length=3, max_length=3)', 'min_length=2, max_length=5)'),
    ('elif self.version_ids is not None:\n            raise ValueError("Multiple tracks require 3x3")',
     'elif self.version_ids is not None:\n            if (len(set(self.version_ids)) != len(self.version_ids)\n                    or self.version_ids[0] != self.version_id or any(len(v) != 36 for v in self.version_ids)):\n                raise ValueError("Choose two to five distinct tracks, starting with the opening track")'),
    ('challenge.mode == "3x3"', 'challenge.is_series'),
    ('challenge.mode != "3x3"', 'not challenge.is_series'),
    ('if payload.mode == "3x3" else []', 'if payload.version_ids else []'),
    ('len(set(track_ids)) != 3', 'len(set(track_ids)) != len(boards)'),
    ('"Choose three distinct tracks"', '"Choose distinct tracks"'),
    ('attempt_limit=payload.attempt_limit, ends_at=', 'attempt_limit=payload.attempt_limit, track_count=len(boards) or 1, ends_at='),
    ('le=2)', 'le=4)'),
    ('if challenge.mode == "beat" and player.id == challenge.creator_id:', 'if challenge.mode == "beat" and not challenge.is_series and player.id == challenge.creator_id:'),
    ('"Choose one of the three tracks"', '"Choose one of the challenge tracks"'),
    ('"Create a new 3x3 challenge to race again"', '"Create a new multi-track challenge to race again"'),
    ('if not series:\n        query = query.where(Challenge.mode != "3x3")',
     'if not series:\n        query = query.where(Challenge.mode != "3x3")\n    if request.query_params.get("custom_tracks") != "1":\n        query = query.where(or_(Challenge.track_count == 1, Challenge.mode == "3x3"))'),
    ('"visibility": challenge.visibility, "capacity":', '"track_count": challenge.track_count, "visibility": challenge.visibility, "capacity":'),
    ('if value["mode"] == "3x3" else html.escape(value["entry"]["name"])', 'if value.get("stages") else html.escape(value["entry"]["name"])'),
    ('target = "3 tracks - 3 tries each" if value["mode"] == "3x3" else', 'target = f\'{len(value["stages"])} tracks - lowest total time wins\' if value.get("stages") else'),
    ('tries = "3 tries per track" if value["mode"] == "3x3" else f"{value[\'attempt_limit\']} tries per driver" if value["attempt_limit"] is not None else "Unlimited tries"',
     'limit = value["stages"][0]["attempt_limit"] if value.get("stages") else value["attempt_limit"]\n    tries = (f"{limit} tries"+(" per track" if value.get("stages") else " per driver")) if limit is not None else "Unlimited tries"'),
])
edit("backend/bmt_backend/app.py", [('"challenge_series_version": 1,', '"challenge_series_version": 1,\n            "challenge_custom_tracks_version": 1,')])

edit("game/ui/challenge_create.gd", [
    ('var attempt_limit: int = 0', 'var custom_track_count: int = 1\nvar attempt_limit: int = 0'),
    ('var _slot_row: HBoxContainer', 'var _slot_row: GridContainer'),
    ('func _required_tracks() -> int: return 3 if selected_format == "three" else 1', 'func _required_tracks() -> int: return 3 if selected_format == "three" else custom_track_count if selected_format == "custom" else 1'),
    ('_chosen_car = VehicleCatalog.valid_id(initial_vehicle)', 'custom_track_count = clampi(int(initial_configuration.get("track_count",1)),1,5)\n\t_chosen_car = VehicleCatalog.valid_id(initial_vehicle)'),
    ('_slot_row = HBoxContainer.new()', '_slot_row = GridContainer.new()'),
    ('_slot_row.add_theme_constant_override("separation",12)', '_slot_row.add_theme_constant_override("h_separation",12)\n\t_slot_row.add_theme_constant_override("v_separation",8)'),
    ('_slot_row.visible = _required_tracks() == 3\n\tif _required_tracks() == 3:\n\t\tfor index: int in range(3):', '_slot_row.visible = _required_tracks() > 1\n\t_slot_row.columns = _required_tracks() if size.x >= 720 else mini(2,_required_tracks())\n\tif _required_tracks() > 1:\n\t\tfor index: int in range(_required_tracks()):'),
    ('"tries":attempt_limit,"visibility":adapter.creation_visibility}', '"tries":attempt_limit,"visibility":adapter.creation_visibility,"tracks":custom_track_count}'),
    ('_rule_choices("Challenge duration",', '_rule_choices("Number of tracks",[[1,"1"],[2,"2"],[3,"3"],[4,"4"],[5,"5"]],"tracks","ChallengeTrackCount_")\n\t_rule_choices("Challenge duration",'),
    ('_rule_choices("Tries per driver",', '_rule_choices("Tries per track",'),
    ('if _chosen_entries.size() > 1: _chosen_entries.resize(1)', 'custom_track_count = int(_draft_rules.tracks)\n\tif _chosen_entries.size() > custom_track_count: _chosen_entries.resize(custom_track_count)'),
    ('_step = CAR if _rules_return == CAR else TRACKS', '_step = CAR if _rules_return == CAR and _chosen_entries.size() == _required_tracks() else TRACKS'),
    ('if locked_result() and _required_tracks() == 3:', 'if locked_result() and _required_tracks() > 1:'),
    ('else "CHOOSE THREE TRACKS" if _required_tracks() == 3 else "CHOOSE YOUR TRACK"', 'else "CHOOSE THREE TRACKS" if selected_format == "three" else "CHOOSE YOUR TRACKS" if _required_tracks() > 1 else "CHOOSE YOUR TRACK"'),
    ('(selected_format == "three" and not adapter.series_supported())', '((_required_tracks() > 1) and not (adapter.series_supported() if selected_format == "three" else adapter.custom_tracks_supported()))'),
    ('elif _step == CAR:\n\t\t_rule_details.text = days+', 'elif _step == CAR:\n\t\t_rule_details.text = days+'),
    ('("3 tries on each track" if selected_format == "three" else tries)+" · "+("Lowest total time wins" if selected_format == "three" else "Best time wins")', '("3 tries on each track" if selected_format == "three" else ("Unlimited tries" if attempt_limit == 0 else str(attempt_limit)+" tries on each track") if _required_tracks() > 1 else tries)+" · "+("Lowest total time wins" if _required_tracks() > 1 else "Best time wins")'),
    ('_formats.columns = 3 if size.x >= 720 else 1', '_formats.columns = 3 if size.x >= 720 else 1\n\t_slot_row.columns = _required_tracks() if size.x >= 720 else mini(2,_required_tracks())'),
    ('if selected_format == "three":\n\t\tpayload.version_ids', 'if _required_tracks() > 1:\n\t\tpayload.version_ids'),
    ('"format":selected_format,"tracks":_chosen_entries.duplicate(true),"step":CAR}', '"format":selected_format,"tracks":_chosen_entries.duplicate(true),"track_count":custom_track_count,"step":CAR}'),
    ('if selected_format == "three" and not adapter.series_supported(): _notice.text = "3×3 needs the updated online service."', 'if _required_tracks() > 1 and not (adapter.series_supported() if selected_format == "three" else adapter.custom_tracks_supported()): _notice.text = "Multi-track challenges need the updated online service."'),
])

edit("game/backend/challenges_client.gd", [
    ('func race_stage() -> Dictionary:', 'func custom_tracks_supported() -> bool:\n\tvar capabilities: Variant = client.get("_capabilities")\n\treturn capabilities is Dictionary and int(capabilities.get("challenge_custom_tracks_version",0)) == 1\n\nstatic func is_series(value: Dictionary) -> bool:\n\treturn value.get("stages") is Array and not value.stages.is_empty()\n\nfunc race_stage() -> Dictionary:'),
    ('selected.get("mode") == "3x3"', 'is_series(selected)'),
    ('index > 2 or selected.get("mode") != "3x3"', 'not is_series(selected) or index >= selected.stages.size()'),
    ('if value.mode == "beat" and (', 'if value.mode == "beat" and not is_series(value) and ('),
    ('var limit: Variant = value.attempt_limit', 'var limit: Variant = value.attempt_limit\n\t\tvar track_count: int = value.stages.size() if is_series(value) else 1'),
    ('_whole(limit,1,9) or int(limit) not in ([9] if value.mode == "3x3" else [1,3,5])', '_whole(limit,1,25) or int(limit) not in ([9] if value.mode == "3x3" else [track_count,3*track_count,5*track_count])'),
    ('if value.mode == "3x3":', 'if value.mode == "3x3" or is_series(value):'),
    ('if value.get("scoring") != "total_best_time" or not value.get("stages") is Array or value.stages.size() != 3 or value.get("attempt_limit") != 9: return false\n\t\tvar versions: Dictionary = {}\n\t\tfor index: int in range(3):', 'if value.get("scoring") != "total_best_time" or not is_series(value) or value.stages.size() < 2 or value.stages.size() > 5: return false\n\t\tif value.mode == "3x3" and (value.stages.size() != 3 or value.get("attempt_limit") != 9): return false\n\t\tvar versions: Dictionary = {}\n\t\tvar tracks: Dictionary = {}\n\t\tvar stage_limit: Variant = value.stages[0].get("attempt_limit") if value.stages[0] is Dictionary else -1\n\t\tif stage_limit == null:\n\t\t\tif value.get("attempt_limit") != null: return false\n\t\telif not preload("res://backend/backend_client.gd")._whole(stage_limit,1,5) or int(stage_limit) not in [1,3,5] or value.get("attempt_limit") != int(stage_limit)*value.stages.size(): return false\n\t\tfor index: int in range(value.stages.size()):'),
    ('stage.index != index or stage.attempt_limit != 3', 'stage.index != index or stage.attempt_limit != stage_limit'),
    ('single.erase("stages")', 'single.erase("stages")\n\t\t\tsingle.erase("track_count")'),
    ('if not valid_snapshot(single) or versions.has(str(stage.entry.version_id)): return false', 'if not valid_snapshot(single) or versions.has(str(stage.entry.version_id)) or tracks.has(str(stage.entry.track_id)): return false\n\t\t\ttracks[str(stage.entry.track_id)] = true'),
    ('_whole(row.get("completed_tracks"),0,3)', '_whole(row.get("completed_tracks"),0,value.stages.size())'),
    ('count != 3', 'count != value.stages.size()'),
    ('count == 3', 'count == value.stages.size()'),
    ('648000 if value.mode == "3x3" else 216000', '216000*value.stages.size() if is_series(value) else 216000'),
    ('if series_supported(): path += "&series=1"', 'if series_supported(): path += "&series=1"\n\tif custom_tracks_supported(): path += "&custom_tracks=1"'),
])
