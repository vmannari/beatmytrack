"""Reconstruct only the pinned, hash-verified local review inputs; no network."""
from pathlib import Path
import argparse
import hashlib
import json
import os

parser = argparse.ArgumentParser()
parser.add_argument("--cache", type=Path)
parser.add_argument("--drafts", type=Path)
parser.add_argument("--check-only", action="store_true")
args = parser.parse_args()
evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
lab = Path(os.environ["APPDATA"]) / "Circuit01Lab"
cache = args.cache or lab / "cloud/166f57396bcc750da426bf322777f9361f3815cbbf3c091202d7f10ede7e2573"
drafts = args.drafts or lab / "tracks/wip"
target = root / "build/catalog-road-review-2026-10-16"
catalog = json.loads((evidence / "manifest.json").read_text(encoding="utf-8"))
local = json.loads((evidence / "local-inventory.json").read_text(encoding="utf-8"))


def pinned(source: Path, expected: str, relative: str) -> None:
    payload = source.read_bytes()
    if hashlib.sha256(payload).hexdigest() != expected:
        raise ValueError(f"Changed source rejected: {source}")
    if not args.check_only:
        output = root / relative.removeprefix("res://../")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(payload)


for entry in catalog["entries"]:
    pinned(cache / (entry["document_sha256"] + ".json"), entry["document_sha256"], entry["path"])
supplemental = {"entries": local["supplemental_review"]}
for entry in supplemental["entries"]:
    identity = next(row["id"] for row in local["drafts"] if row["document_sha256"] == entry["document_sha256"])
    pinned(drafts / (identity + ".json"), entry["document_sha256"], entry["path"])
builtin = root / "game/resources/tracks/starter_circuit.json"
if hashlib.sha256(builtin.read_bytes()).hexdigest() != local["builtin_starter"]["sha256"]:
    raise ValueError("Built-in Starter Circuit differs from the reviewed source")

if not args.check_only:
    target.mkdir(parents=True, exist_ok=True)
    (target / "manifest.json").write_text(json.dumps(catalog, indent=2), encoding="utf-8")
    (target / "supplemental-manifest.json").write_text(json.dumps(supplemental, indent=2), encoding="utf-8")
    baseline = evidence / "baseline"
    baseline.mkdir(exist_ok=True)
    old = (evidence.parent / "ajorata-road-2026-10-16/before-source/shoulder_mesh.gd").read_text(encoding="utf-8")
    (baseline / "shoulder_mesh.gd").write_text(old.replace("class_name ShoulderMesh", ""), encoding="utf-8")
    union = (evidence / "before-source/desert_road_union.gd").read_text(encoding="utf-8")
    union = union.replace("var clipping := ShoulderMesh.new()", 'var clipping := preload("res://../docs/evidence/catalog-road-review-2026-10-16/baseline/shoulder_mesh.gd").new()')
    (baseline / "desert_road_union.gd").write_text(union, encoding="utf-8")

print(f"Verified {len(catalog['entries'])} cached documents, {len(supplemental['entries'])} authored drafts and the built-in Starter source; check_only={args.check_only}")
