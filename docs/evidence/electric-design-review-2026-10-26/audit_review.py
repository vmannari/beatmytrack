"""Audit this review's captured evidence; never edit runtime or shared Git state."""
from pathlib import Path
from html.parser import HTMLParser
import difflib
import hashlib
import json
import subprocess
import tempfile

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


before = json.loads((EVIDENCE / "before-hashes.json").read_text(encoding="utf-8-sig"))
sources = {rel: {"before_sha256": value, "after_sha256": sha(ROOT / rel),
                 "unchanged": value == sha(ROOT / rel)} for rel, value in before.items()}
concurrent = "game/resources/cars/electric.tres"
assert all(s["unchanged"] for rel, s in sources.items() if rel != concurrent)
if not sources[concurrent]["unchanged"]:
    diff = difflib.unified_diff((EVIDENCE / "before" / concurrent).read_text().splitlines(True),
                                (ROOT / concurrent).read_text().splitlines(True),
                                fromfile=concurrent + " [review start]", tofile=concurrent + " [concurrent current]")
    (EVIDENCE / "concurrent-handling.diff").write_text("".join(diff))

manifest_path = ROOT / "game/assets/vehicles/electric_coachwork_v10/manifest.json"
manifest = json.loads(manifest_path.read_text())
assert manifest["source_sha256"] == sources["game/vehicle/electric_coachwork.gd"]["after_sha256"]
assert manifest["model_sha256"] == sources["game/vehicle/electric_car_model.gd"]["after_sha256"]
renderers = {name: json.loads((EVIDENCE / name / "capture-report.json").read_text())
             for name in ["native", "desktop-mobile"]}
for name, data in renderers.items():
    assert data["failures"] == 0 and len(data["captures"]) == 22
    assert data["source_sha256"] == manifest["source_sha256"]
    assert data["model_sha256"] == manifest["model_sha256"]
    for capture in data["captures"]:
        image = EVIDENCE / name / (capture["name"] + ".png")
        assert capture["save_error"] == 0 and image.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
    log = "compatibility.log" if name == "native" else "desktop-mobile.log"
    assert "ELECTRIC_DESIGN_REVIEW: 22 captures, 0 save failures" in (EVIDENCE / "logs" / log).read_text()
assert renderers["native"]["geometry"] == renderers["desktop-mobile"]["geometry"]
geometry = renderers["native"]["geometry"]

refs = {
    "lucid-air-front.webp": "https://images.ctfassets.net/5ky6szwjj7ya/gdK5kHYZJAXzxJnqnqaff/572c41c9051d5be4b6a209728f7d5c89/lucid-motors-lucid-air-desktop-04.webp?q=50",
    "lucid-air-side.webp": "https://images.ctfassets.net/5ky6szwjj7ya/2mRWuxvehv2XOmeE8ApMYN/08ed593a5b562d95f1309e2ac01ed483/lucid-air-desktop-13_2x.webp?q=50",
    "lucid-air-street.webp": "https://images.ctfassets.net/5ky6szwjj7ya/6rLyJ8NGZ19o55kjrmqWR7/96b77f19d9163b01aedf4e17699885e0/lucid-motors-lucid-air-desktop-02.webp?q=50",
    "lucid-air-dimensions.svg": "https://images.ctfassets.net/5ky6szwjj7ya/air-tech-specs-desktop.svg/971bc86f0fe70260fdd83131be446352/air-tech-specs-desktop.svg?q=50",
    "taycan-side.webp": "https://compare.porsche.com/assets/taycan.webp",
    **{f"ioniq6-{n}.jpg": f"https://www.hyundai.com/content/dam/hyundai/ww/en/images/newsroom/news-image/2025/04/0403-2/media-kit/mk-thumbnail-0403-{n}.jpg" for n in [1, 3, 5]},
}
pages = ["https://lucidmotors.com/air",
         "https://newsroom.porsche.com/en_US/products/taycan/exterior-design-18551.html",
         "https://www.hyundai.com/worldwide/en/newsroom/detail/hyundai-motor-unveils-the-new-ioniq-6-and-ioniq-6-n-line-under-%E2%80%98pure-flow%2C-refined%E2%80%99-concept-0000000928"]
findings = [
    ("DR01", "high", "Angular cabin and roof against rounded body"),
    ("DR02", "high", "Bonnet/wing/nose need a shared broad form; retain clean taper"),
    ("DR03", "high", "Flat-looking glazing and strong renderer-dependent material response"),
    ("DR04", "medium", "Rear window/deck/lamp/bumper remain visually separate"),
    ("DR05", "medium", "Soft twisted spokes and weak wheel/brake material hierarchy"),
    ("DR06", "medium", "Generic panel cuts, attached-looking sill, oval mirrors and stripe-like lamps"),
    ("DR07", "medium", "Deck-edge slivers and stepped/open-looking bumper ends; mesh cause unconfirmed"),
]
report = {
    "requirements": "EDR01-EDR03/R01/Q01", "date": "2026-10-26",
    "scope": "Review only; findings remain unfixed", "engine": "4.7.2.stable.official.ed1daf0bf",
    "production_sources": sources, "unchanged_source_count": sum(s["unchanged"] for s in sources.values()),
    "concurrent_configuration_excluded": concurrent,
    "prepared_asset_manifest": {"path": manifest_path.relative_to(ROOT).as_posix(),
                                "sha256": sha(manifest_path), "author_and_assembly_match": True},
    "geometry": geometry, "full_triangle_cap": 170000,
    "full_wheel_triangle_percentage": geometry["full"]["groups"]["wheels"] / geometry["full"]["triangles"] * 100,
    "findings": [{"id": i, "priority": p, "finding": f} for i, p, f in findings],
    "captures": 44, "save_failures": 0, "visual_quality_acceptance_assertions": 0,
    "commands": [
        {"command": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_electric_design.gd -Graphical -RenderingMethod " + method + " -TestArgument '--evidence-root=res://../docs/evidence/electric-design-review-2026-10-26/" + folder + "' -CommandTimeoutSeconds 150",
         "exit_code": 0, "captures": 22, "log": "logs/" + log, "source_log": source}
        for method, folder, log, source in [
            ("gl_compatibility", "native", "compatibility.log", "build/logs/TestScript-9744/test-script.log"),
            ("mobile", "desktop-mobile", "desktop-mobile.log", "build/logs/TestScript-34204/test-script.log")]],
    "initial_attempts": ["Direct dev.ps1 invocation blocked by shell execution policy; standard process-scoped retry completed without changing system policy",
                         "Initial retention audit detected concurrent electric-13 to electric-14 configuration; diff inspected, retained and excluded without reverting it"],
    "source_pages": pages,
    "references": [{"file": "references/" + name, "url": url, "sha256": sha(EVIDENCE / "references" / name),
                    "bytes": (EVIDENCE / "references" / name).stat().st_size} for name, url in refs.items()],
    "reference_filename_notes": {"lucid-air-side.webp": "Front/three-quarter charging photo, despite download filename", "ioniq6-5.jpg": "Interior image retained, not used to judge our external design"},
    "limitations": ["Manufacturer photos have different cameras and lighting; not registered overlays",
                    "Design judgments; capture-save successes are not quality acceptance passes",
                    "RTX 3090 desktop; Mobile renderer is not a physical-device test",
                    "Default production camera over diagnostic studio, not an actual race scene",
                    "No model/material/config/resource/photo edits by this review",
                    "No physical-device attachment check/test, APK, live mutation, deployment, staging, commit or owner-process restart"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, indent=2) + "\n")


class LocalLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.targets = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        for key in ["src", "href"]:
            value = values.get(key, "")
            if value and not value.startswith(("http:", "https:", "#")):
                self.targets.append(value)


parser = LocalLinks()
parser.feed((EVIDENCE / "comparison.html").read_text())
for target in parser.targets:
    assert (EVIDENCE / target).exists(), target
views = ["front-quarter", "side", "front", "rear-quarter", "rear", "top", "bonnet", "roof", "wheel", "tail-detail", "production-camera-studio"]
for renderer in renderers:
    for detail in ["full", "simple"]:
        for view in views:
            assert (EVIDENCE / renderer / (detail + "-" + view + ".png")).is_file()

prefix = EVIDENCE.relative_to(ROOT).as_posix() + "/"
new_files = ["game/tests/review_electric_design.gd", "docs/ELECTRIC_DESIGN_REVIEW_2026_10_26.md"] + [prefix + name for name in ["comparison.html", "report.json", "audit_review.py"]]
docs = ["AGENTS.md", "DEVELOPMENT_STATUS.md"]
patch = []
for rel in docs + new_files:
    old = (EVIDENCE / "before-docs" / rel).read_text(encoding="utf-8-sig").splitlines(True) if rel in docs else []
    final_path = EVIDENCE / "after-docs" / rel if rel in docs else ROOT / rel
    new = final_path.read_text(encoding="utf-8-sig").splitlines(True)
    patch.append("diff --git a/" + rel + " b/" + rel + "\n")
    if not old:
        patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(old, new, fromfile="a/" + rel if old else "/dev/null", tofile="b/" + rel, n=3))
patch_path = EVIDENCE / "review.patch"
patch_path.write_text("".join(patch), encoding="utf-8", newline="\n")
with tempfile.TemporaryDirectory(prefix="bmt-electric-review-") as temp_dir:
    temp = Path(temp_dir)
    for rel in docs:
        (temp / rel).write_text((EVIDENCE / "before-docs" / rel).read_text(encoding="utf-8-sig"), encoding="utf-8", newline="\n")
    for args in [["--check"], []]:
        result = subprocess.run(["git", "apply", "--no-index"] + args + [str(patch_path)], cwd=temp, capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
    for rel in docs + new_files:
        expected = EVIDENCE / "after-docs" / rel if rel in docs else ROOT / rel
        assert (temp / rel).read_text(encoding="utf-8") == expected.read_text(encoding="utf-8-sig"), rel
inventory = {p.relative_to(EVIDENCE).as_posix(): {"sha256": sha(p), "bytes": p.stat().st_size}
             for p in EVIDENCE.rglob("*") if p.is_file() and p.name not in ["file-hashes.json", "checkpoint.json"]}
(EVIDENCE / "file-hashes.json").write_text(json.dumps(inventory, indent=2) + "\n")
checkpoint = {"text_patch": "review.patch", "patch_sha256": sha(patch_path),
              "isolated_git_apply_check": True, "isolated_apply_content_match": True,
              "changed_text_paths": docs + new_files, "shared_git_index_modified": False,
              "local_links_validated": len(parser.targets), "dynamic_capture_paths_validated": 44,
              "unchanged_source_count": sum(s["unchanged"] for s in sources.values()),
              "excluded_concurrent_config": concurrent, "evidence_file_count": len(inventory),
              "evidence_bytes": sum(v["bytes"] for v in inventory.values())}
(EVIDENCE / "checkpoint.json").write_text(json.dumps(checkpoint, indent=2) + "\n")
print(json.dumps(checkpoint, indent=2))
