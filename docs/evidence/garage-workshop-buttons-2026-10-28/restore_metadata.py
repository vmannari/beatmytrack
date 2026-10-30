import hashlib
import json
from pathlib import Path
import re

EVIDENCE = Path(__file__).resolve().parent
ROOT = next(p for p in EVIDENCE.parents if (p / "godot-version.txt").exists())
log = (EVIDENCE / "app-final-mobile/run.log").read_text(encoding="utf-8")
expected = re.search(r"Client build: ([^\s]+)", log)[1]
identity = ROOT / "game/core/build_identity.gd"
project = ROOT / "game/project.godot"
current_identity = identity.read_bytes()
current_project = project.read_bytes()
(EVIDENCE / "build_identity.after-tests.gd.txt").write_bytes(current_identity)
(EVIDENCE / "project.after-tests.godot.txt").write_bytes(current_project)
restored = False
if f'const ID: String = "{expected}"' in current_identity.decode("utf-8-sig") and f'config/version="{expected}"' in current_project.decode("utf-8-sig"):
    old_project = (EVIDENCE / "project.before.godot.txt").read_bytes()
    old_version = re.search(rb'(?m)^config/version="[^\r\n]*"', old_project)[0]
    identity.write_bytes((EVIDENCE / "build_identity.before.gd.txt").read_bytes())
    project.write_bytes(re.sub(rb'(?m)^config/version="[^\r\n]*"', lambda _: old_version, current_project, count=1))
    restored = True
report = {"restored": restored, "test_build_id": expected,
          "identity_sha256": hashlib.sha256(identity.read_bytes()).hexdigest(),
          "project_sha256": hashlib.sha256(project.read_bytes()).hexdigest()}
(EVIDENCE / "metadata-restoration.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report))
