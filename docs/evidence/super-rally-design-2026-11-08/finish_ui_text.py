"""Repair the task's UTF-8 round-trip error; prove every asset identity is unchanged."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
QUALIFIED = ROOT / "build/super-rally-c3-qualified-assets"
assert (QUALIFIED / "picture-preflight-command.json").exists(), "Finish the coherent bake first"
assert json.loads((QUALIFIED / "picture-preflight-command.json").read_text())["exit_code"] == 0
path = ROOT / "game/ui/garage_page.gd"
old = (OUT / "before/game/ui/garage_page.gd").read_text(encoding="utf-8-sig")
expected = old.replace("VehicleCatalog.model_id(vehicle_id)", "VehicleCatalog.chassis_id(vehicle_id)")
live = path.read_text(encoding="utf-8-sig")
fixed = live.replace("\u00c2\u00b7", "\u00b7").replace("\u00c3\u2014", "\u00d7").replace("\u00c2\u00b0", "\u00b0")
assert fixed == expected, "Unexpected concurrent Garage edits; preserve them and inspect"
(OUT / "garage-text-roundtrip-before.txt").write_text(live, encoding="utf-8", newline="\n")
path.write_text(fixed, encoding="utf-8", newline="\n")
before = json.loads((QUALIFIED / "client-build-identity.json").read_text(encoding="utf-8-sig"))
target = ROOT / "build/super-rally-c3-ui-correction"
target.mkdir(exist_ok=True)
command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
           ". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path 'build/super-rally-c3-ui-correction'"]
with (target / "identity.log").open("w", encoding="utf-8") as log:
    result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=120)
assert result.returncode == 0
after = json.loads((target / "client-build-identity.json").read_text(encoding="utf-8-sig"))
keys = ["modular_car_sha256", "garage_preview_vehicle_sha256", "garage_preview_sha256", "header_preview_sha256"]
same = {key: before[key] == after[key] for key in keys}
(OUT / "garage-text-correction.json").write_text(json.dumps({
    "file": path.relative_to(ROOT).as_posix(),
    "before_sha256": hashlib.sha256(live.encode()).hexdigest(),
    "after_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    "repair": "Restore all original non-ASCII UI strings; only three intended chassis-entitlement substitutions differ from task-start source.",
    "identity_command": command, "identity_exit_code": result.returncode,
    "asset_identities_unchanged": same,
}, indent=2), encoding="utf-8")
assert all(same.values()), "Asset fingerprints changed; regenerate affected artifacts"
print("GARAGE_TEXT: original Unicode restored; all asset fingerprints exact", flush=True)
raise SystemExit(subprocess.call([sys.executable, "scripts/prepare_car_assets.py", "--verify",
                                 "--output", "build/super-rally-c3-final-verification"], cwd=ROOT))
