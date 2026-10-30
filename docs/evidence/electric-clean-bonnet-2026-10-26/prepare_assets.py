"""Retain byte-identical old resources after checking all serialized geometry."""
import hashlib
import json
from pathlib import Path
import re
import shutil

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
old = E / "before/electric_coachwork_v9"
new = ROOT / "game/assets/vehicles/electric_coachwork_v10"
read = lambda p: json.loads(p.read_text(encoding="utf-8-sig"))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
previous = {m["part"]: m for m in read(old / "manifest.json")["meshes"]}
current = {m["part"]: m for m in read(new / "manifest.json")["meshes"]}
identifier = re.compile(rb"local://ArrayMesh_[a-z0-9]{5}\x00")
reused = []
for part in previous.keys() & current.keys():
    a, b = old / previous[part]["file"], new / current[part]["file"]
    if identifier.sub(b"local://ArrayMesh_FIXED\x00", a.read_bytes()) == identifier.sub(b"local://ArrayMesh_FIXED\x00", b.read_bytes()):
        shutil.copy2(a, b)
        reused.append({"part": part, "sha256": sha(b)})
reused_names = {m["part"] for m in reused}
retained_other = {p for p in previous if not p.startswith(("Hood", "ClamshellHood"))}
assert retained_other <= reused_names, retained_other - reused_names
expected = {m["file"] for m in current.values()}
obsolete = []
for path in new.glob("*.res"):
    if path.name not in expected:
        obsolete.append({"file": path.name, "sha256": sha(path)})
        path.unlink()
result = {"previous": len(previous), "current": len(current), "exact_originals": len(reused),
          "changed_shared": len((previous.keys() & current.keys()) - reused_names),
          "new": len(current.keys() - previous.keys()), "retired": len(previous.keys() - current.keys()),
          "exact_non_bonnet_resources": len(retained_other), "resources": sorted(reused, key=lambda v: v["part"]),
          "obsolete_bake_outputs_removed": obsolete,
          "comparison": "Only the random five-character serialized local ArrayMesh identifier is normalized for comparison; every other byte must match before restoring the exact original binary."}
(E / "resource-reuse.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print({k: v for k, v in result.items() if k not in ["resources", "obsolete_bake_outputs_removed"]})
