"""Record the local checkpoint without staging or committing concurrent work."""
import difflib
import hashlib
import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sources = [
    "backend/bmt_backend/app.py", "backend/bmt_backend/challenge_models.py",
    "backend/bmt_backend/challenge_series.py", "backend/bmt_backend/challenges.py",
    "backend/bmt_backend/migrations/versions/0063_custom_challenge_tracks.py",
    "backend/tests/test_custom_challenge_tracks.py", "game/backend/challenges_client.gd",
    "game/core/app.gd", "game/ui/challenge_create.gd", "game/ui/challenge_ready_dialog.gd",
    "game/ui/challenge_race_card.gd", "game/ui/challenges_page.gd", "game/ui/track_browser.gd",
    "game/tests/test_custom_challenge_tracks.gd", "game/tests/fixtures/custom_challenge_five_tracks_v1.json",
    "docs/schemas/challenge-create-v1.schema.json", "docs/schemas/challenge-v1.schema.json",
]
patches = []
checkpoint = ROOT / "build/custom-five-tracks/checkpoint-check"
for path in sources:
    current = (ROOT / path).read_text(encoding="utf-8").splitlines(keepends=True)
    original = HERE / "task-base" / path
    before = original.read_text(encoding="utf-8").splitlines(keepends=True) if original.exists() else []
    if original.exists():
        target = checkpoint / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("".join(before), encoding="utf-8", newline="\n")
    diff = list(difflib.unified_diff(before, current,
        fromfile="a/"+path if original.exists() else "/dev/null", tofile="b/"+path))
    if path in ["game/core/app.gd", "game/ui/challenges_page.gd"] and diff:
        # Other owner tasks changed these shared files during this run. Keep
        # only hunks with this task's series/generalized sharing additions.
        header, hunks = diff[:2], []
        chunk = []
        for line in diff[2:]+["@@ END @@\n"]:
            if line.startswith("@@"):
                if chunk:
                    additions = "".join(line for line in chunk if line.startswith("+"))
                    if "ChallengesClient.is_series(" in additions or (path.endswith("app.gd") and "var limit: Variant = value.stages[0]" in additions):
                        hunks.extend(chunk)
                chunk = [line]
            else:
                chunk.append(line)
        diff = header+hunks if hunks else []
    patches.extend(diff)
    target = HERE / "task-final" / path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / path, target)
(HERE / "scoped-change.patch").write_text("".join(patches), encoding="utf-8", newline="\n")
check = subprocess.run(["git","apply","--check","--directory=build/custom-five-tracks/checkpoint-check",
    str(HERE / "scoped-change.patch")],cwd=ROOT,capture_output=True,text=True)

logs = HERE / "logs"
logs.mkdir(exist_ok=True)
markers = ["CUSTOM_CHALLENGE_TRACKS:","CHALLENGE_SERIES:","CHALLENGE_CARDS: 223", "CHALLENGES: 216",
           "CHALLENGE_CREATE_RACE:","FREE_RACE_LIST", "SCRIPT_PARSE: 1067"]
captured = []
for path in (ROOT / "build/logs").glob("TestScript-*/test-script.log"):
    text = path.read_text(encoding="utf-8", errors="replace")
    if not any(marker in text for marker in markers):
        continue
    # Preserve task-start-and-later logs, including the initial layout failure.
    if path.stat().st_mtime < (HERE / "update_sources.py").stat().st_mtime:
        continue
    name = path.parent.name+".log"
    shutil.copy2(path,logs / name)
    captured.append({"log":"logs/"+name,"summaries":re.findall(r"(?:CUSTOM_CHALLENGE_TRACKS|CHALLENGE_SERIES|CHALLENGE_CARDS|CHALLENGES|CHALLENGE_CREATE_RACE|SCRIPT_PARSE):[^\n]+",text)})

def junit(name):
    path = HERE / name
    if not path.exists():
        return None
    suite = next(ET.parse(path).getroot().iter("testsuite"))
    return {key:suite.attrib.get(key) for key in ["tests","failures","errors","skipped","time"]}

report = {
    "date":"2026-10-24", "requirements":{
        "CCT01":"Custom rules choose one through five distinct pinned tracks, with transactional Back/Next and an exact finished opening track.",
        "CCT02":"All selected tracks reach authoritative creation, per-track starts/ghosts and best-only summed completion; one-to-one/group and unlimited/1/3/5 tries remain supported.",
        "CCT03":"Five track slots, invitations, sharing and standings expose actual track counts at desktop and narrow sizes.",
        "R01":"Idempotent starts, account fences, immutable versions and existing formats retained.",
        "Q01":"Matching schema/API/worker/client rollout and physical-device acceptance remain."
    },
    "changes":sources+["docs/CHALLENGES.md"],
    "source_sha256":{path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in sources+["docs/CHALLENGES.md"]},
    "checkpoint":{"patch":"scoped-change.patch","base":"task-base/","final":"task-final/", "git_apply_check_exit":check.returncode,"git_apply_check_output":check.stdout+check.stderr,
        "shared_files":"Only this task's added series/sharing hunks are included for App and ChallengesPage. Full snapshots retain concurrent changes for context; no files were staged or committed."},
    "tests":{
        "backend_custom_sqlite":junit("backend-custom-sqlite.xml"),
        "backend_scoped_final":junit("backend-scoped-final.xml"),
        "native_http_final":junit("native-http-final.xml"),
        "original_control":junit("backend-original-control.xml"),
        "native":"Custom 55 headless / 65 Compatibility / 65 desktop Mobile, existing series30, cards223, integrated216, creation-race8, FreeRace233 and parser1067.",
        "ruff":"Focused Python Ruff check passes.", "logs":captured
    },
    "commands":[
        ".tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_custom_challenge_tracks.py -k sqlite -q --tb=short",
        ".tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_custom_challenge_tracks.py backend/tests/test_challenge_series.py backend/tests/test_challenges.py backend/tests/test_challenge_discovery.py -k 'not postgres and not additive_attempt_migration' -q --tb=short --disable-warnings",
        "APPDATA=<workspace>/build/custom-five-tracks/http-userdata; .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenges_http.py -q --tb=short --disable-warnings",
        "APPDATA=<workspace>/build/custom-five-tracks/<isolated-run>; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_custom_challenge_tracks.gd [-Graphical -RenderingMethod gl_compatibility|mobile] -CommandTimeoutSeconds 120",
        "Same dev.ps1 TestScript entry point: test_challenge_series.gd, test_challenge_cards.gd, test_challenges.gd, test_challenge_create_race.gd, test_free_race_list.gd, test_script_parse.gd",
        "PYTHONPATH=<workspace>/build/custom-five-tracks/original-control; .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenges.py -k 'additive_attempt_migration and sqlite' -q --tb=short --disable-warnings",
        ".tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/challenges.py backend/bmt_backend/challenge_series.py backend/bmt_backend/challenge_models.py backend/bmt_backend/migrations/versions/0063_custom_challenge_tracks.py backend/tests/test_custom_challenge_tracks.py",
        "git diff --check; git apply --check --directory=build/custom-five-tracks/checkpoint-check docs/evidence/custom-challenge-five-tracks-2026-10-24/scoped-change.patch"
    ],
    "initial_results_and_corrections":[
        "PowerShell required process-scoped execution-policy Bypass. Godot logs initially used protected ordinary userdata; subsequent runs use workspace APPDATA. Local Godot tests required approved Windows root certificate access.",
        "Initial custom native run:47 checks/2 failures; initial Compatibility run:55 checks/2 failures. A pre-existing fixed-width picker action row forced the entire portrait picker beyond the viewport. Selection-only actions now wrap in a responsive grid; ordinary Free Race retains its action layout.",
        "First broad backend run:32 passed/2 skipped/1 rollback failure/35 PostgreSQL setup timeouts. Custom combined run:7 passed/7 PostgreSQL setup timeouts. PostgreSQL localhost:55439 is unavailable; no PostgreSQL pass claimed.",
        "Broader SQLite/native-HTTP attempt:46 passed/2 skipped/3 failures. One rollback guard failure is reproduced by isolated original challenge modules:0054 requires drained creator achievement events. Two canonical HTTP failures were retried using workspace userdata and approved certificate access.",
        "Native HTTP retry:ordinary challenge integration passes; source-race integration completes52 checks with one retained stale assertion requiring CreateResultChallenge. Concurrent CRA01/CRA02 deliberately uses ContinueResultChallenge for that exact source-race context; the other51 checks, including the source-race return to creation, pass. See game/tests/test_challenges_http.gd:108 and docs/evidence/challenge-result-action-2026-10-24/report.json. No broad native HTTP pass is claimed.",
        "A focused Ruff SIM102 finding was corrected without changing validation. All failing invariant assertions are retained."
    ],
    "limitations":[
        "No phone/tablet attachment check or physical-device test, APK export/install, production mutation or deployment.",
        "Matching 0063 migration, API, worker and client rollout plus client restart remain. Five-track creation is disabled against an API missing challenge_custom_tracks_version:1.",
        "Server/worker verification here uses disposable SQLite; focused totals use the existing PosedVerifier fixture. The existing native HTTP tests separately exercise the pinned canonical verifier.",
        "Owner acceptance of the track-count selection and physical-device layout/touch remains.",
        "Broader checks retain the existing0054 rollback-guard failure and a source-race HTTP assertion that expects the retired creation action name during concurrent challenge-continuation work.",
        "Concurrent result-screen, ads, Garage, Desert, configuration, security deployment and cost-analysis work and owner processes are preserved."
    ],
    "screenshots":[str(path.relative_to(HERE)).replace('\\','/') for path in HERE.glob("Windows-*/*.png")],
}
(HERE/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"checkpoint_exit":check.returncode,"backend":report['tests']['backend_scoped_final'],"http":report['tests']['native_http_final'],"screenshots":len(report['screenshots'])}))
if check.returncode:
    print(check.stdout+check.stderr)
    raise SystemExit(check.returncode)
