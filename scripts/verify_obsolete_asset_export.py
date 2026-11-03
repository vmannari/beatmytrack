"""Check paired content ZIPs remove only the explicitly retired asset revisions."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile


ROOT = Path(__file__).resolve().parents[1]


def sha(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def classes(data: bytes) -> dict:
    text = data.decode("utf-8")
    assert text.startswith("list=")
    entries = json.loads(text[len("list="):].replace('&"', '"'))
    result = {entry["class"]: entry for entry in entries}
    assert len(result) == len(entries), "duplicate class declarations"
    return result


def uids(data: bytes) -> dict[int, str]:
    count = struct.unpack_from("<I", data)[0]
    position, result = 4, {}
    for _ in range(count):
        key, length = struct.unpack_from("<QI", data, position)
        position += 12
        value = data[position:position + length].decode("utf-8")
        position += length
        assert key not in result, "duplicate UID declarations"
        result[key] = value
    assert position == len(data), "UID cache format/length mismatch"
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=ROOT / "scripts/obsolete_export_assets.json")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    bank_prefixes = tuple(f"assets/vehicles/{bank}/" for bank in manifest["vehicle_banks"])
    poster_entries = set(manifest["challenge_posters"])
    import_destinations = {}
    for source in manifest["challenge_posters"] + manifest["retained_challenge_posters"]:
        sidecar = Path(source + ".import")
        content = (args.project / sidecar).read_text(encoding="utf-8")
        destinations = set(re.findall(r'"res://(\.godot/imported/[^\"]+)"', content))
        import_destinations[source] = destinations
        if source in manifest["challenge_posters"]:
            poster_entries.add(sidecar.as_posix())
            poster_entries.update(destinations)
    failures = []
    with zipfile.ZipFile(args.before) as before, zipfile.ZipFile(args.after) as after:
        old = {entry.filename: entry for entry in before.infolist()}
        new = {entry.filename: entry for entry in after.infolist()}
        expected = {name for name in old if name.startswith(bank_prefixes) or name in poster_entries}
        removed = set(old) - set(new)
        unexpected_removed = sorted(removed - expected)
        remaining_obsolete = sorted(expected & set(new))
        added = sorted(set(new) - set(old))
        changed = [name for name in sorted(set(old) & set(new)) if before.read(name) != after.read(name)]
        metadata = {}
        class_path = ".godot/global_script_class_cache.cfg"
        if class_path in changed:
            left, right = classes(before.read(class_path)), classes(after.read(class_path))
            metadata["global_classes"] = {"before": len(left), "after": len(right), "equal_declarations": left == right}
            if left == right:
                changed.remove(class_path)
        uid_path = ".godot/uid_cache.bin"
        if uid_path in changed:
            left, right = uids(before.read(uid_path)), uids(after.read(uid_path))
            expected_uid_removals = {key for key, path in left.items()
                                     if path.removeprefix("res://").startswith(bank_prefixes)
                                     or path.removeprefix("res://") in manifest["challenge_posters"]}
            removed_uids = set(left) - set(right)
            retained_equal = all(left[key] == right[key] for key in set(left) & set(right))
            exact = removed_uids == expected_uid_removals and not set(right) - set(left) and retained_equal
            metadata["uids"] = {"before": len(left), "after": len(right), "exact_expected_removals": exact,
                                 "retained_mappings_equal": retained_equal,
                                 "removed_resources": sorted(left[key] for key in removed_uids)}
            if exact:
                changed.remove(uid_path)
        for label, values in [("unexpected removed", unexpected_removed), ("obsolete retained", remaining_obsolete),
                              ("unexpected added", added), ("retained bytes changed", changed)]:
            if values:
                failures.append({"kind": label, "entries": values})
        for label, archive in [("before", before), ("after", after)]:
            bad = archive.testzip()
            if bad:
                failures.append({"kind": f"{label} CRC", "entry": bad})
        retained_banks = {}
        for bank in manifest["retained_vehicle_banks"]:
            names = [name for name in new if name.startswith(f"assets/vehicles/{bank}/")]
            retained_banks[bank] = len(names)
            if not names:
                failures.append({"kind": "active bank absent", "bank": bank})
        for source in manifest["retained_challenge_posters"]:
            if source + ".import" not in new or not import_destinations[source].issubset(new):
                failures.append({"kind": "active poster absent", "source": source})
        legal = [name for name in old if name.startswith("legal/") and name.endswith(".txt")]
        if not legal:
            failures.append({"kind": "baseline legal texts absent"})
        for bank in manifest["vehicle_banks"]:
            if not any(name.startswith(f"assets/vehicles/{bank}/") for name in expected):
                failures.append({"kind": "candidate bank missing from control", "bank": bank})
        report = {
            "before": {"bytes": args.before.stat().st_size, "sha256": sha(args.before), "entries": len(old)},
            "after": {"bytes": args.after.stat().st_size, "sha256": sha(args.after), "entries": len(new)},
            "saved_zip_bytes": args.before.stat().st_size - args.after.stat().st_size,
            "removed_payload_bytes": sum(old[name].compress_size for name in removed),
            "removed_uncompressed_bytes": sum(old[name].file_size for name in removed),
            "removed_entries": len(removed),
            "retained_byte_exact_entries": sum(before.read(name) == after.read(name) for name in set(old) & set(new)),
            "validated_generated_metadata": metadata,
            "retained_vehicle_banks": retained_banks,
            "retained_challenge_posters": manifest["retained_challenge_posters"],
            "retained_legal_texts": legal,
            "candidate_vehicle_banks": manifest["vehicle_banks"],
            "candidate_challenge_posters": manifest["challenge_posters"],
            "failures": failures,
            "limits": "Paired Android content ZIPs from one isolated source snapshot; no APK/AAB or device test.",
        }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
