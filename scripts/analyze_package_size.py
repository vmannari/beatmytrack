"""Read-only APK size audit; never exports, edits, signs or installs a game.

Reports ZIP entry payload bytes (not Play download/installed size). Reference
checks are conservative candidates for review, not proof of runtime coverage.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
MIB = 1024**2


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            sha.update(chunk)
    return sha.hexdigest()


def runtime_text() -> tuple[str, dict[str, str]]:
    texts, hashes = [], {}
    for base, dirs, files in os.walk(GAME):
        dirs[:] = [d for d in dirs if d not in {
            ".godot", "android", "assets", "tests", "tmp", "music", "docs"
        } and not d.startswith("recordings-")]
        for name in files:
            path = Path(base) / name
            if path.suffix not in {".gd", ".tscn", ".tres", ".cfg", ".json", ".gdshader", ".godot"}:
                continue
            # An export exclusion names a retired asset without using it at
            # runtime. Keep the preset hash, but do not treat filters as loads.
            if path.name != "export_presets.cfg":
                texts.append(path.read_text(encoding="utf-8-sig"))
            hashes[path.relative_to(ROOT).as_posix()] = digest(path)
    return "\n".join(texts), hashes


def group_key(source: str) -> str:
    parts = source.split("/")
    if source.startswith("assets/"):
        return "/".join(parts[:3] if len(parts) > 3 else parts[:2])
    if source.startswith("lib/"):
        return "/".join(parts[:2])
    if source.endswith(".dex"):
        return "Android Java/Kotlin DEX"
    return "/".join(parts[:2]) if len(parts) > 1 else source


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=Path, default=ROOT / "build/android/circuit01-debug.apk")
    parser.add_argument("--dependencies", type=Path, required=True,
                        help="JSON of ResourceLoader.get_dependencies for current binary assets")
    parser.add_argument("--templates", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    text, hashes = runtime_text()
    deps = json.loads(args.dependencies.read_text(encoding="utf-8"))
    banks = sorted(p.name for p in (GAME / "assets/vehicles").iterdir() if p.is_dir())
    dependency_text = json.dumps(list(deps.values()))
    retained = [bank for bank in banks if bank in text or f"assets/vehicles/{bank}/" in dependency_text]
    candidates = sorted(set(banks) - set(retained))
    posters = sorted(p for p in (GAME / "assets/menu/challenges").glob("*.png"))
    old_posters = [p.relative_to(GAME).as_posix() for p in posters
                   if p.stem not in text and p.relative_to(GAME).as_posix() not in dependency_text]

    # Resolve imported payloads back to authored source paths. Source PNG sizes
    # are not substituted for the actual exported texture/audio/font size.
    import_map = {}
    source_sizes = defaultdict(int)
    source_counts = defaultdict(int)
    for base, dirs, files in os.walk(GAME / "assets"):
        for name in files:
            path = Path(base) / name
            rel = path.relative_to(GAME).as_posix()
            source_sizes[group_key(rel)] += path.stat().st_size
            source_counts[group_key(rel)] += 1
            if path.suffix == ".import":
                content = path.read_text(encoding="utf-8")
                source = re.search(r'^source_file="res://([^"]+)"', content, re.M)
                if source:
                    for dest in re.findall(r'"res://(\.godot/imported/[^"]+)"', content):
                        import_map[dest] = source[1]
    groups = defaultdict(lambda: {"payload_bytes": 0, "uncompressed_bytes": 0, "entries": 0})
    rows, selected, duplicate_groups = [], defaultdict(list), defaultdict(list)
    with zipfile.ZipFile(args.apk) as archive:
        for entry in archive.infolist():
            resource = entry.filename.removeprefix("assets/") if entry.filename.startswith("assets/") else entry.filename
            source = import_map.get(resource, resource)
            group = group_key(source)
            groups[group]["payload_bytes"] += entry.compress_size
            groups[group]["uncompressed_bytes"] += entry.file_size
            groups[group]["entries"] += 1
            row = {"entry": entry.filename, "source": source, "payload_bytes": entry.compress_size,
                   "uncompressed_bytes": entry.file_size, "compression": entry.compress_type}
            rows.append(row)
            if source.startswith("assets/vehicles/") and source.split("/")[2] in candidates:
                selected["old_vehicle_banks"].append(row)
            if source in old_posters:
                selected["old_challenge_posters"].append(row)
            if entry.filename.startswith("lib/x86_64/"):
                selected["x86_64_libraries"].append(row)
            if entry.filename.startswith("assets/tmp/"):
                selected["temporary_scripts"].append(row)
            if source.startswith("assets/vehicles/"):
                sha = hashlib.sha256(archive.read(entry)).hexdigest()
                duplicate_groups[sha].append(row)
        apk_version = None
        # project.binary is an engine Variant container; preserve an ASCII
        # version marker as evidence without pretending to parse the format.
        if "assets/project.binary" in archive.namelist():
            markers = re.findall(rb"0\.3\.0-creator\.[a-zA-Z0-9]+", archive.read("assets/project.binary"))
            apk_version = [marker.decode() for marker in markers]
    opportunities = {
        key: {"payload_bytes": sum(x["payload_bytes"] for x in values),
              "entry_count": len(values), "entries": values}
        for key, values in selected.items()
    }
    def scenario(keys: list[str]) -> dict:
        chosen = {row["entry"]: row for key in keys for row in selected[key]}
        reduction = sum(row["payload_bytes"] for row in chosen.values())
        return {"categories": keys, "payload_bytes_removed": reduction,
                "apk_bytes_less_payload_only": args.apk.stat().st_size - reduction,
                "entries_removed": len(chosen)}
    scenarios = {
        "asset_cleanup": scenario(["old_vehicle_banks", "old_challenge_posters"]),
        "asset_cleanup_arm64": scenario(["old_vehicle_banks", "old_challenge_posters", "x86_64_libraries"]),
    }
    templates = {}
    if args.templates:
        for filename in ["android_debug.apk", "android_release.apk"]:
            path = args.templates / filename
            with zipfile.ZipFile(path) as z:
                templates[filename] = {"sha256": digest(path), "file_bytes": path.stat().st_size,
                                       "engine_libraries": [
                    {"entry": i.filename, "bytes": i.file_size, "zip_payload_bytes": i.compress_size}
                    for i in z.infolist() if i.filename.endswith("libgodot_android.so")
                ]}
    duplicates = [values for values in duplicate_groups.values() if len(values) > 1]
    duplicate_redundancy = sum(sum(x["payload_bytes"] for x in values)
                               - min(x["payload_bytes"] for x in values) for values in duplicates)
    unknown = [row for row in rows if row["source"].startswith(".godot/imported/")]
    report = {
        "requirements": ["PKS01: measure existing APK", "PKS02: identify size drivers",
                         "PKS03: quantify optimization candidates without changing shipping content"],
        "audit_utc": datetime.now(timezone.utc).isoformat(),
        "apk": {"path": str(args.apk.resolve()), "sha256": digest(args.apk),
                "bytes": args.apk.stat().st_size,
                "modified_utc": datetime.fromtimestamp(args.apk.stat().st_mtime, timezone.utc).isoformat(),
                "version_markers": apk_version, "entry_count": len(rows),
                "entry_payload_bytes": sum(row["payload_bytes"] for row in rows),
                "entry_uncompressed_bytes": sum(row["uncompressed_bytes"] for row in rows)},
        "groups": dict(sorted(groups.items(), key=lambda pair: -pair[1]["payload_bytes"])),
        "largest_entries": sorted(rows, key=lambda row: -row["payload_bytes"])[:40],
        "current_source_groups": {key: {"bytes": value, "files": source_counts[key]}
                                  for key, value in sorted(source_sizes.items(), key=lambda pair: -pair[1])},
        "reference_check": {"runtime_text_files": len(hashes), "binary_resources": len(deps),
                            "binary_resources_with_dependencies": sum(bool(v) for v in deps.values()),
                            "retained_vehicle_banks": retained, "candidate_vehicle_banks": candidates,
                            "candidate_challenge_posters": old_posters,
                            "unmapped_import_entries": unknown,
                            "binary_dependency_report_sha256": digest(args.dependencies)},
        "opportunities": opportunities,
        "scenarios": scenarios,
        "vehicle_byte_duplicates": {"groups": len(duplicates), "redundant_payload_bytes": duplicate_redundancy,
                                    "note": "Overlaps old-bank cleanup. No automatic deduplication: paths and resource identity matter.",
                                    "largest_groups": sorted(duplicates, key=lambda values: -sum(x["payload_bytes"] for x in values))[:20]},
        "templates": templates,
        "source_hashes": hashes,
        "limits": ["Existing debug APK compared with current workspace; not a fresh export.",
                   "Reference absence is a removal candidate, not exported gameplay validation.",
                   "Savings are ZIP entry payload sums; headers, alignment, signatures and sparse pack indexes change on rebuild.",
                   "No APK/AAB built, no device query/test, no owner save/process change or deployment."]
    }
    report["apk"]["container_overhead_bytes"] = report["apk"]["bytes"] - report["apk"]["entry_payload_bytes"]
    assert sum(g["entries"] for g in groups.values()) == len(rows)
    assert report["apk"]["container_overhead_bytes"] >= 0
    assert not set(candidates) & set(retained)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"apk_mib": report["apk"]["bytes"] / MIB,
                      "opportunities_mib": {k: v["payload_bytes"] / MIB for k, v in opportunities.items()},
                      "scenarios": scenarios, "unmapped_import_entries": len(unknown),
                      "duplicate_vehicle_payload_mib": duplicate_redundancy / MIB,
                      "report": str(args.output)}, indent=2))


if __name__ == "__main__":
    main()
