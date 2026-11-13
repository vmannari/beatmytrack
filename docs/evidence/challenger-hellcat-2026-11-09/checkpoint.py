"""Source-only task delta and immutable original/canonical controls. No index writes."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BASE = OUT / "before"
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
changed = [
    "game/vehicle/super_rally_model.gd", "game/vehicle/car_visual.gd",
    "game/vehicle/livery_catalog.gd", "game/vehicle/vehicle_weathering.gd",
    "game/vehicle/prepared_asset_dependencies.json", "game/ui/garage_customisation_camera.gd",
    "game/legal/third_party_notices.gd", "game/tests/test_super_rally_design.gd",
    "game/tests/test_super_rally_c3_kits.gd", "game/tests/test_super_rally.gd",
]
new = [
    "scripts/prepare_challenger.py", "game/tests/bake_challenger_hellcat.gd",
    "game/tests/bake_challenger_hellcat.gd.uid", "game/tests/test_challenger_hellcat.gd",
    "game/tests/test_challenger_hellcat.gd.uid", "game/legal/challenger_hellcat_notices.txt",
]
delta = []
for f in changed + new:
    delta.append(f"diff --git a/{f} b/{f}\n")
    if f in new: delta.append("new file mode 100644\n")
    old = [] if f in new else (BASE/f).read_text(encoding="utf-8").splitlines(True)
    current = (ROOT/f).read_text(encoding="utf-8").splitlines(True)
    lines = list(difflib.unified_diff(old, current, fromfile="/dev/null" if f in new else "a/"+f,
                                    tofile="b/"+f))
    for line in lines:
        delta.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
patch = OUT/"source-only.patch"
patch.write_text("".join(delta), encoding="utf-8", newline="\n")
result = subprocess.run(["git", "apply", "--check", "--reverse", "--whitespace=nowarn", str(patch.relative_to(ROOT))],
    cwd=ROOT, capture_output=True, text=True)
assert result.returncode == 0, result.stderr
initial = json.loads((OUT/"start-sources.json").read_text(encoding="utf-8"))
controls = {f:{"before":digest,"after":sha(ROOT/f)} for f,digest in initial["sources"].items() if f not in changed}
assert all(v["before"] == v["after"] for v in controls.values())
original = initial["owner_model"]
assert sha(Path(original["path"])) == original["sha256"]
assets = {p.relative_to(ROOT).as_posix():{"sha256":sha(p),"bytes":p.stat().st_size}
          for p in (ROOT/"game/assets/vehicles/challenger_hellcat_v1").glob("*") if p.suffix in (".res",".json")}
receipt = {"authored_sources":{f:sha(ROOT/f) for f in changed+new},"unchanged_controls":controls,
           "original_model_unchanged":True,"owner_model_sha256":original["sha256"],
           "native_assets":assets,"source_only_patch":{"files":len(changed+new),"sha256":sha(patch),
           "reverse_check":result.returncode,"exclusions":"Generated scenes, binaries, metadata, documentation and unrelated concurrent work.",
           "baseline_limits":"Physics test baseline reconstructs the one changed livery assertion; dependency manifest was snapshotted before adding the native mesh rule."}}
(OUT/"source-receipt.json").write_text(json.dumps(receipt,indent=2),encoding="utf-8")
print("CHALLENGER_CHECKPOINT:",len(changed+new),"sources;",len(controls),"exact controls;",len(assets),"native resources; reverse check passes")
