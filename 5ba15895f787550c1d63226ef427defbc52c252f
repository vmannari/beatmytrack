"""Retain the final coherent bake, native acceptance and exact source controls."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BAKE = ROOT/"build/challenger-hellcat-guarded-assets"
read = lambda p: json.loads(p.read_text(encoding="utf-8-sig"))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
commands = {}
for p in sorted(BAKE.glob("*-command.json")):
    receipt = read(p)
    assert receipt["exit_code"] == 0 and receipt["script_errors"] == 0, p
    commands[p.stem.removesuffix("-command")] = receipt
(OUT/"assets-commands.json").write_text(json.dumps(commands,indent=2),encoding="utf-8")
for name in ("source-receipt.json","identity-before.json","client-build-identity.json","prepared.log","picture-preflight.log"):
    shutil.copyfile(BAKE/name,OUT/("assets-"+name))
fence = read(BAKE/"source-receipt.json")
assert fence["before"] == fence["after"] and not fence["changed"]
for f,digest in fence["after"].items(): assert sha(ROOT/f) == digest, f
assert read(BAKE/"identity-before.json")["modular_car_sha256"] == read(BAKE/"client-build-identity.json")["modular_car_sha256"]
labels = ["final-design","fitted-final","car-wash-final","wash-final","driving","parser","modules-guarded","physics-guarded",
          "opaque-gl-guarded","opaque-mobile-guarded","app-gl-final","app-mobile-final","licence-probe","licence-native","final-import"]
checks = {label:read(OUT/(label+"-command.json")) for label in labels}
assert all(r["exit_code"] == 0 and r["script_errors"] == 0 for r in checks.values())
images = read(OUT/"pictures-before-guarded-bake.json")
image_controls = {f:{"before":digest,"after":sha(ROOT/f),"exact":digest == sha(ROOT/f)} for f,digest in images.items()}
assert all(r["exact"] for r in image_controls.values())
(OUT/"unrelated-picture-controls.json").write_text(json.dumps(image_controls,indent=2),encoding="utf-8")
old = read(ROOT/"docs/evidence/super-rally-restraint-2026-11-09/final/gl_compatibility/geometry.json")
current = read(OUT/"final/gl_compatibility/geometry.json")
assert old["compact"] == current["compact"]
acceptance = {"prepared_source_inputs":len(fence["before"]),"all_inputs_still_exact":True,
    "final_command_receipts":checks,"rally_geometry":{"before":old["compact"],"after":current["compact"],"exact":True},
    "opacity":{renderer:read(OUT/"opaque"/renderer/"acceptance.json") for renderer in ("gl_compatibility","mobile")},
    "actual_app":{renderer:read(OUT/"app"/renderer/"acceptance.json") for renderer in ("gl_compatibility","mobile")},
    "licences_broad_retained_failure":"545/1: pre-existing Kart notice CRLF versus RichTextLabel LF; task-start text identical. Original assertion retained.",
    "limits":"Desktop proof only; no device/APK/install/live/backend/owner-save/process/main-index operation."}
assert all(r["failures"] == 0 for group in (acceptance["opacity"],acceptance["actual_app"]) for r in group.values())
(OUT/"final-acceptance.json").write_text(json.dumps(acceptance,indent=2),encoding="utf-8")
print("CHALLENGER_FINAL:",len(fence["before"]),"stable bake inputs;",len(commands),"asset commands;",len(checks),"acceptance commands; exact Rally and",len(images),"picture controls")
