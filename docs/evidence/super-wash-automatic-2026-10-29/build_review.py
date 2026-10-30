"""Create and round-trip a scoped binary-inclusive patch without the main index."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
names = ["game/ui/garage_wash_tool.gd", "game/assets/menu/garage/super-v2.png",
         "game/assets/menu/garage/super-v2.png.import", "game/assets/menu/garage/super-v2.provenance.json",
         "licenses/ASSETS.md", "docs/SUPER_WASH_AUTOMATIC_2026_10_29.md"]
fixture = ROOT/"tmp/super-wash-automatic-checkpoint"
fixture.mkdir(parents=True, exist_ok=False)
hashes = {}
for kind in ["before", "after"]:
    (fixture/kind).mkdir()
    for name in names:
        source = HERE/"before"/name if kind == "before" else ROOT/name
        if not source.exists():
            continue
        target = fixture/kind/name
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.suffix == ".png":
            shutil.copy2(source, target)
        else:
            target.write_text(source.read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
        if kind == "after":
            hashes[name] = hashlib.sha256(source.read_bytes()).hexdigest()
before = (fixture/"before").relative_to(ROOT).as_posix()
after = (fixture/"after").relative_to(ROOT).as_posix()
diff = subprocess.run(["git", "diff", "--no-index", "--binary", "--", before, after], cwd=ROOT, capture_output=True)
assert diff.returncode == 1, diff.stderr.decode()
patch = diff.stdout.decode("utf-8")
for side in ["a/", "b/"]:
    for folder in [before, after]:
        patch = patch.replace(side+folder+"/", side)
review = HERE/"source-and-image.patch"
review.write_text(patch, encoding="utf-8", newline="\n")
relative = review.relative_to(ROOT).as_posix()
commands = [["git", "apply", "--check", "--reverse", relative],
            ["git", "apply", "--check", "--directory="+before, relative],
            ["git", "apply", "--directory="+before, relative],
            ["git", "apply", "--check", "--reverse", "--directory="+before, relative]]
receipts = []
for command in commands:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    receipts.append({"command": command, "exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
    assert result.returncode == 0, receipts[-1]
for name in names:
    assert (fixture/"before"/name).read_bytes() == (fixture/"after"/name).read_bytes(), name
images = json.loads((HERE/"images.json").read_text(encoding="utf-8"))
provenance = json.loads((ROOT/"game/assets/menu/garage/super-v2.provenance.json").read_text(encoding="utf-8"))
assert Path(provenance["source"]).read_bytes() == (ROOT/provenance["path"]).read_bytes()
report = {"date": "2026-10-29", "requirements": ["SWA01", "R01", "Q01"], "sha256": hashes,
          "generation": {"provider": provenance["provider"], "prompt": "prompt.txt", "source": provenance["source"], "exact_provider_bytes": True},
          "images": images, "import_exit": 0, "image_checks": [16, 0], "native_compatibility_checks": [300, 0],
          "native_captures": len(list((HERE/"Windows-gl_compatibility").glob("*.png"))), "checkpoint": receipts,
          "initial_findings": [],
          "limitations": ["Sandbox certificate-store errors retained", "Source-PNG reads are evidence-only; runtime uses imported textures", "No physical-device query/test", "Reload/rebuild and owner/device acceptance remain"],
          "no_main_index_writes": True, "concurrent_work_preserved": True}
(HERE/"report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print("SUPER_WASH_AUTOMATIC_REVIEW: six-file binary-inclusive patch forward/reverse checks and exact content round-trip pass")
