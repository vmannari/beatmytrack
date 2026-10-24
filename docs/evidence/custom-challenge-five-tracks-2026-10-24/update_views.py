from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]


def edit(path, changes):
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    for before, after in changes:
        assert before in text, (path, before)
        text = text.replace(before, after)
    file.write_text(text, encoding="utf-8", newline="\n")


edit("game/ui/challenges_page.gd", [
    ('selected.get("mode") != "3x3"', 'not ChallengesClient.is_series(selected)'),
    ('selected.get("mode") == "3x3"', 'ChallengesClient.is_series(selected)'),
    ('parent.add_child(MenuStyle.label("3 TRACKS · 3 TRIES EACH · LOWEST TOTAL TIME WINS",16,true))',
     'parent.add_child(MenuStyle.label(str(selected.stages.size())+" TRACKS · LOWEST TOTAL TIME WINS",16,true))'),
    ('+str(stage.attempts_remaining)+" tries left"', '+("Unlimited tries" if stage.attempts_remaining == null else str(stage.attempts_remaining)+" tries left")'),
    ('"TIME ATTACK" if selected.mode == "beat" else "3×3 SERIES" if selected.mode == "3x3" else "GROUP RACE"', '"3×3 SERIES" if selected.mode == "3x3" else "CUSTOM CHALLENGE" if ChallengesClient.is_series(selected) else "TIME ATTACK" if selected.mode == "beat" else "GROUP RACE"'),
    ('"Time to beat" if selected.mode == "beat" else "Leading total" if selected.mode == "3x3" and target != null else "Leading time" if target != null else "3×3 total" if selected.mode == "3x3" else "Group challenge"', '"Leading total" if ChallengesClient.is_series(selected) and target != null else "Combined best time" if ChallengesClient.is_series(selected) else "Time to beat" if selected.mode == "beat" else "Leading time" if target != null else "Group challenge"'),
    ('+"/3 tracks" if selected.mode == "3x3"', '+"/"+str(selected.stages.size())+" tracks" if ChallengesClient.is_series(selected)'),
    ('winning and selected.mode != "3x3"', 'winning and not ChallengesClient.is_series(selected)'),
    ('int(own.rank) == 1 if selected.mode != "beat"', 'int(own.rank) == 1 if selected.mode != "beat" or ChallengesClient.is_series(selected)'),
    ('selected.mode == "beat" and selected.creator_id == selected.self_id', 'selected.mode == "beat" and not ChallengesClient.is_series(selected) and selected.creator_id == selected.self_id'),
    ('if item.mode == "beat": return item.get("target_ms")', 'if item.mode == "beat" and not ChallengesClient.is_series(item): return item.get("target_ms")'),
])
edit("game/ui/challenge_ready_dialog.gd", [
    ('"3×3 CHALLENGE" if snapshot.get("mode") == "3x3" else str(snapshot.entry.name)', '"3×3 CHALLENGE" if snapshot.get("mode") == "3x3" else "CUSTOM CHALLENGE" if ChallengesClient.is_series(snapshot) else str(snapshot.entry.name)'),
    ('if snapshot.get("mode") == "3x3":', 'if ChallengesClient.is_series(snapshot):'),
    ('if snapshot.get("mode") == "3x3" else', 'if ChallengesClient.is_series(snapshot) else'),
    ('if ChallengesClient.is_series(snapshot): limit = 3', 'if ChallengesClient.is_series(snapshot): limit = int(snapshot.stages[0].attempt_limit) if snapshot.stages[0].attempt_limit != null else 0'),
])
edit("game/ui/challenge_race_card.gd", [
    ('"TIME ATTACK" if item.mode == "beat" else "3×3 SERIES" if item.mode == "3x3" else "GROUP RACE"', '"3×3 SERIES" if item.mode == "3x3" else "CUSTOM CHALLENGE" if ChallengesClient.is_series(item) else "TIME ATTACK" if item.mode == "beat" else "GROUP RACE"'),
    ('"3 tracks" if item.mode == "3x3"', 'str(item.stages.size())+" tracks" if ChallengesClient.is_series(item)'),
])
# This file already contains unrelated owner work. Only this sharing branch changes.
edit("game/core/app.gd", [
    ('if value.get("mode") == "3x3":', 'if ChallengesClient.is_series(value):'),
    ('text = "3×3 · 3 tracks · 3 tries each · Lowest total time wins\\n"+',
     'var limit: Variant = value.stages[0].attempt_limit\n\t\tvar tries: String = "Unlimited tries" if limit == null else str(int(limit))+" tries each"\n\t\ttext = ("3×3" if value.get("mode") == "3x3" else "Custom challenge")+" · "+str(value.stages.size())+" tracks · "+tries+" · Lowest total time wins\\n"+'),
])
edit("backend/bmt_backend/challenges.py", [
    ('source.time_ticks if source and payload.mode == "beat" else None', 'source.time_ticks if source and payload.mode == "beat" and not boards else None'),
])

path = ROOT / "docs/schemas/challenge-create-v1.schema.json"
schema = json.loads(path.read_text())
schema["properties"]["version_ids"].update(minItems=2, maxItems=5)
schema["allOf"][0]["then"]["properties"]["version_ids"].update(minItems=3, maxItems=3)
schema["allOf"][0].pop("else")
path.write_text(json.dumps(schema, indent=2)+"\n", encoding="utf-8")
path = ROOT / "docs/schemas/challenge-v1.schema.json"
schema = json.loads(path.read_text())
props = schema["properties"]
props["track_count"] = {"type":"integer", "minimum":1, "maximum":5}
props["attempt_limit"] = {"enum":[None,1,2,3,4,5,6,9,10,12,15,20,25]}
props["standings"]["items"]["properties"]["ticks"]["maximum"] = 1080000
props["standings"]["items"]["properties"]["completed_tracks"]["maximum"] = 5
props["stages"].update(minItems=2,maxItems=5)
stage = props["stages"]["items"]["properties"]
stage["index"]["maximum"] = 4
stage["attempt_limit"] = {"enum":[None,1,3,5]}
stage["attempts_used"].pop("maximum")
stage["attempts_remaining"] = {"type":["integer","null"],"minimum":0,"maximum":5}
condition = schema["allOf"][0]
condition["then"]["properties"]["stages"] = {"minItems":3,"maxItems":3,"items":{"properties":{"attempt_limit":{"const":3}}}}
condition.pop("else")
schema["allOf"].append({"if":{"required":["stages"]},"then":{"required":["scoring","attempt_limit","attempts_used","attempts_remaining"]},"else":{"properties":{"attempt_limit":{"enum":[None,1,3,5]},"standings":{"$ref":"#/$defs/stageStandings"}}}})
path.write_text(json.dumps(schema, indent=2)+"\n", encoding="utf-8")
