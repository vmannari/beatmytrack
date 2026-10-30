"""Audit observed exploration results, including expected usability failures."""
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SESSION = ROOT / "single-instance"
states = {int(p.name[:3]): json.loads(p.read_text(encoding="utf-8"))
          for p in SESSION.glob("[0-9][0-9][0-9]-*.json")}
checks = []


def check(name, value):
    checks.append({"observation": name, "confirmed": bool(value)})


def control(step, text=None, name=None):
    return next(c for c in states[step]["controls"]
                if (text is None or c.get("text") == text)
                and (name is None or c["name"] == name))


def overlap(a, b):
    x, y, w, h = a["rect"]
    xx, yy, ww, hh = b["rect"]
    return max(0, min(x+w, xx+ww)-max(x, xx)) * max(0, min(y+h, yy+hh)-max(y, yy))


ids = {s["document"]["id"] for s in states.values() if s["document"]}
pids = {s["pid"] for s in states.values()}
check("All 35 clean-run captures belong to one process", len(states) == 35 and len(pids) == 1)
check("Exactly one authored track identity", len(ids) == 1)
doc = states[33]["document"]
check("Six-piece circuit: two straights and four curves",
      [p["kind"] for p in doc["pieces"]] == ["straight", "curve", "curve", "straight", "curve", "curve"])
check("Closed loop enables Test", not control(9, text="Test")["disabled"])
check("Explicit start line placed", doc["start_line"]["heading"] == 0)
check("Width drag changes 10m to 14.5m", states[11]["document"]["pieces"][3]["width"] == 10
      and states[12]["document"]["pieces"][3]["width"] == 14.5)
check("Undo restores exact pre-drag document", states[11]["document"] == states[13]["document"])
check("Initially selected Rock trap reproduced: no placement after three ground clicks",
      states[15]["canvas"]["mode"] == "objects" and not states[15]["document"]["objects"])
check("Choosing another asset first enables placement", [o["kind"] for o in states[17]["document"]["objects"]]
      == ["pebbles", "rock", "rock"])
check("Five distinct jump cards visible in Props", len([c for c in states[18]["controls"]
      if c["name"].startswith("Asset_jump_")]) == 5)
check("Rounded bump and three scenery objects retained", len(doc["objects"]) == 4
      and doc["objects"][-1]["jump_profile"] == "roller_v1")
check("One freehand water stroke retained", len(doc["paint"]) == 1)
check("960x540 Map fully covers Undo", overlap(control(20, text="Undo"), control(20, text="Map")) > 2600)
check("960x540 Save covers most of Redo", overlap(control(20, text="Redo"), control(20, name="EditorSaveAction")) > 2500)
check("Clicking Undo position opens Map and leaves document unchanged", states[20]["document"] == states[21]["document"]
      and any(c["name"] == "NewTrack" for c in states[21]["controls"]))
movement = math.dist(states[25]["game"]["position"], states[30]["game"]["position"])
check("Throttle and brake inputs move actual practice car", movement > 8)
check("Returned to editor after practice", "game" not in states[31] and "canvas" in states[31])
check("Reopened saved document is exact", states[24]["document"] == doc)
saved = SESSION / "storage" / "tracks" / (doc["id"] + ".json")
check("Only one saved track file in clean storage", len(list(saved.parent.glob("*.json"))) == 1)
(ROOT / "dust_bowl_usability.json").write_bytes(saved.read_bytes())

report = {
    "date": "2026-10-28", "requirements": ["EU01: create through editor inputs", "EU02: evaluate usability", "EU03: isolate owner data"],
    "method": "Godot viewport mouse/keyboard events, incremental native screenshots, inspected UI bounds and saved documents; source-aware instrumented exploration, not a naive human usability study",
    "engine": "4.7.2.stable.official.ed1daf0bf", "renderer": "gl_compatibility", "gpu": "NVIDIA GeForce RTX 3090",
    "viewports": [[1280, 720], [960, 540]], "process_ids": sorted(pids), "authored_track_ids": sorted(ids),
    "evidence_checks": checks, "confirmed_observations": sum(c["confirmed"] for c in checks), "total_observations": len(checks),
    "track": {"file": "dust_bowl_usability.json", "sha256": hashlib.sha256(saved.read_bytes()).hexdigest(),
              "name": doc["name"], "road_pieces": len(doc["pieces"]), "objects": len(doc["objects"]), "paint_strokes": len(doc["paint"])},
    "findings": [
        {"id": "EU-U01", "priority": "high", "title": "960x540 header overlays Undo/Redo", "reproduction": "Resize to 960x540. Map occupies Undo's rectangle; Save covers most of Redo. Click Undo's centre: Map opens and document is unchanged.", "evidence": ["single-instance/020-compact-object-properties.png", "single-instance/021-compact-undo-click-opens-map.png"], "recommendation": "Give narrow layouts a compact or second-row header, retaining visible Undo/Redo targets."},
        {"id": "EU-U02", "priority": "medium", "title": "Highlighted Rock does not enable placement on entry", "reproduction": "Enter Objects. Rock is already highlighted. Click Rock, then three empty infield points: zero objects, mode still objects. Select Pebbles, then Rock: placement works.", "evidence": ["single-instance/014-objects-palette.png", "single-instance/015-three-rocks-in-infield.json", "single-instance/017-object-placement-workaround.png"], "recommendation": "Selecting a palette card should always enable placement; use the separate controls to adjust properties."},
        {"id": "EU-U03", "priority": "medium", "title": "Tool overlays consume the track at small sizes", "evidence": ["single-instance/020-compact-object-properties.png", "single-instance/007-first-curve-snapped-preview.png"], "observation": "At 960x540, the palette and size strip cover much of the fitted circuit. At 1280x720, confirmation and dimension labels crowd the curve. This is a visual usability judgment, not a demonstrated data-loss bug.", "recommendation": "Fit roads into the usable canvas above palettes and offset confirmation and dimension labels."},
        {"id": "EU-P01", "priority": "medium", "title": "Preparation interrupts the edit/test loop", "observed_return_to_editor_ms": states[31]["total_ms"], "measurement_limit": "14577ms end-to-end command includes a 1s explicit wait, a 0.6s screenshot settling delay and input frames; not pure UI latency. First-practice timing is not claimed because its initial readiness helper failed.", "evidence": ["single-instance/031-settled-return-to-editor.json", "single-instance/engine.log"]},
        {"id": "EU-R01", "priority": "investigate", "title": "Scenery coroutine accesses a freed node", "observation": "One clean-run engine log occurrence: Cannot call method get_children on a previously freed instance, desert_road_relief.gd:178, during object placement. Authoring continued. Root cause and independent reproduction are not established.", "evidence": ["single-instance/engine.log"]}
    ],
    "actual_commands": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_editor_usability_session.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 3600",
        "Same preferred launcher with workspace APPDATA and 1800s bound; initial instances exited 1 after completion, not accepted as clean evidence",
        "Workspace APPDATA; pinned Godot --path game --script res://tests/capture_editor_usability_session.gd --rendering-method gl_compatibility --audio-driver Dummy --log-file <single-instance/engine.log>; exit 0",
        "Pinned Godot --headless --path game --script res://tests/capture_editor_usability_session.gd --check-only --log-file <helper-check.log>; exit 0",
        "python docs/evidence/editor-usability-session-2026-10-28/analyze.py"
    ],
    "limitations": [
        "Initial attempt accidentally ran two instances in shared temporary storage; all root-level 000..030 captures excluded. The clean evidence set is single-instance, PID 19092, one track identity, one saved track.",
        "Clean run readiness helper called CanvasLayer.is_visible_in_tree incorrectly. Commands 25..29 are retained; failed queued targets are not game failures. Settled commands 30..33 prove car movement, return, one-track browser and exact reopen.",
        "The final reusable helper corrects the readiness predicate, embedded-window coordinates and defaults to a PID-specific output directory. Its syntax check passes; these helper corrections were not claimed to have driven the recorded run. Exact executed helper is single-instance/executed-bridge.gd.txt.",
        "Offline sandbox root certificate store warning remains in native log. No real authentication or backend operation performed.",
        "No lap completed, sustained FPS benchmark, naive-user study, audio evaluation, mobile-renderer comparison or physical-device test.",
        "Active shared workspace was not frozen. Preferred launcher refreshed generated build metadata; concurrent metadata/source work was preserved. No game behavior fix, owner-save change, deployment, staging, commit or merge."
    ],
    "remaining_acceptance": ["Fix and retest narrow header", "Fix highlighted-asset placement", "Owner touch-device usability and responsiveness", "Investigate scenery error and frame hitches"],
    "changed_files": ["game/tests/capture_editor_usability_session.gd", "docs/evidence/editor-usability-session-2026-10-28/* (owned captures, commands, isolated saves, report and audit)"]
}
(ROOT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(f"Confirmed {report['confirmed_observations']}/{len(checks)} evidence observations; this includes reproduced defects, not a claim that the UI passed all tests.")
print(f"Practice movement: {movement:.3f}m. Saved/reopened document exact. Track: {saved.name}")
if not all(c["confirmed"] for c in checks):
    raise SystemExit(1)
