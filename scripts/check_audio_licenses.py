"""Offline integrity check for the four reviewed ambience recording licences.

No audio is rebuilt. Original downloads stay in ignored build storage; use
--require-originals on the source workstation to verify those private originals.
"""
import argparse
import hashlib
import json
from pathlib import Path

from audio_license_records import REGISTRY, ROOT, source_license

ORIGINALS = {
    "rain": "build/storm_rain_sources/owner-rain-331497.mp3",
    "thunder": "build/storm_thunder_sources/owner-thunder-29190.mp3",
    "desert-wind": "build/desert_owner_wind/sources/wind.mp3",
    "winter-wind": "build/winter_owner_wind/sources/blizzard.mp3",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-originals", action="store_true")
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--output", type=Path,
                        default=ROOT / "build/audio-license-clearance-2026-10-16/validation.json")
    args = parser.parse_args()
    checks = []

    def check(ok, name):
        checks.append({"check": name, "passed": bool(ok)})

    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    evidence = json.loads((ROOT / registry["evidence"]).read_text(encoding="utf-8"))
    compressed = json.loads((ROOT / "game/assets/audio/compressed/manifest.json").read_text(encoding="utf-8"))
    compression = {item["master"]: item for item in compressed["outputs"]}
    check(sha(REGISTRY) == evidence["registry_sha256"], "registry matches retained evidence")
    check(len(registry["sources"]) == 4, "four reviewed original recordings")
    for item in evidence["source_observations"]:
        check(sha(ROOT / item["path"]) == item["sha256"], "source observation intact: " + item["path"])
    check(registry["commercial_use"] and registry["modification_allowed"], "commercial incorporation and editing recorded")
    original_count = master_count = encoded_count = 0
    for source in registry["sources"]:
        source_id = source["id"]
        observation = json.loads((ROOT / "docs/evidence/audio-license-clearance-2026-10-16/sources" / (source_id + ".json")).read_text(encoding="utf-8"))
        excerpts = " ".join(line["text"] for line in observation["excerpts"])
        check(str(source["provider_asset_id"]) in observation["requested_url"], source_id + " provider asset ID")
        check(source["title"] in excerpts and "Pixabay Content License" in excerpts, source_id + " source title and licence observed")
        original = ROOT / ORIGINALS[source_id]
        if original.exists():
            original_count += 1
            check(sha(original) == source["source_sha256"], source_id + " preserved original SHA-256")
        else:
            check(not args.require_originals, source_id + " private original not required on this checkout")
        expected = source_license(source_id, source["source_sha256"])
        manifests = {}
        for filename in source["manifests"]:
            path = ROOT / filename
            manifest = json.loads(path.read_text(encoding="utf-8"))
            metadata = manifest.get("owner_source", manifest)
            check(all(metadata.get(k) == v for k, v in expected.items()), source_id + " metadata: " + filename)
            if path.name != "storm_rumble_manifest.json":
                check(metadata.get("source_sha256", metadata.get("sha256")) == source["source_sha256"], source_id + " manifest original identity")
            for clip in manifest.get("clips", [manifest]):
                name = clip.get("filename", clip.get("file"))
                manifests[(path.parent / name).relative_to(ROOT).as_posix()] = clip
        for filename in source["masters"]:
            master_count += 1
            master = ROOT / filename
            digest = sha(master)
            check(digest == manifests[filename]["sha256"], "edited master identity: " + filename)
            record = next(item for item in evidence["derivatives"] if item["path"] == filename)
            check(digest == record["sha256"], "reviewed master unchanged: " + filename)
            if filename in compression:
                encoded_count += 1
                item = compression[filename]
                check(digest == item["master_sha256"], "compression input: " + filename)
                encoded = ROOT / item["encoded"]
                check(sha(encoded) == item["encoded_sha256"], "compression output: " + item["encoded"])
                check(sha(encoded) == record["encoded_sha256"], "reviewed encoded derivative unchanged: " + item["encoded"])
            else:
                check(filename == "game/assets/audio/storm_thunder.wav", "only short thunder cue remains PCM")
    rumble = json.loads((ROOT / "game/assets/audio/storm_rumble_manifest.json").read_text(encoding="utf-8"))
    check(rumble["source_sha256"] == sha(ROOT / "game/assets/audio/storm_thunder.wav"), "rumble derives from the pinned thunder master")
    try:
        source_license("rain", "0" * 64)
    except ValueError:
        check(True, "different original refused by licence binding")
    else:
        check(False, "different original refused by licence binding")
    preset = (ROOT / "game/export_presets.cfg").read_text(encoding="utf-8")
    for filename in ("assets/audio/ambience/NOTICE.txt", "assets/audio/ambience/source_licenses.json"):
        check(filename in preset.split('include_filter="', 1)[1].split('"', 1)[0].split(","), "Android includes " + filename)
    check(not list((ROOT / "game/assets/audio").rglob("*.mp3")), "original MP3 downloads stay outside game resources")
    if args.baseline:
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
        for filename, before in baseline.items():
            check(sha(ROOT / filename) == before["sha256"], "audio unchanged: " + filename)
    failures = [item for item in checks if not item["passed"]]
    result = {"schema": "bmt-audio-license-check-v1", "checks": len(checks), "failures": len(failures),
              "originals_verified": original_count, "edited_masters_verified": master_count,
              "encoded_derivatives_verified": encoded_count, "results": checks}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for failure in failures:
        print("FAIL:", failure["check"])
    print("AUDIO_LICENSES:", len(checks), "checks,", len(failures), "failures;",
          original_count, "originals,", master_count, "masters,", encoded_count, "encoded derivatives")
    raise SystemExit(bool(failures))


if __name__ == "__main__":
    main()
