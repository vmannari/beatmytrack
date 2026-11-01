"""Check task-local Godot import checksums against their copied source files.

This checks recorded MD5s, not visual equivalence or runtime GPU state.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("project", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    root = args.project
    rows = []
    for metadata in sorted(root.rglob("*.import")):
        relative_parts = metadata.relative_to(root).parts
        if ".godot" in relative_parts or relative_parts[:2] == ("android", "build"):
            continue
        text = metadata.read_text(encoding="utf-8", errors="replace")
        source_match = re.search(r'^source_file="res://([^"]+)"', text, re.M)
        output_matches = re.findall(r'^path(?:\.[^=]+)?="res://\.godot/imported/([^"]+)"', text, re.M)
        if not source_match or not output_matches:
            rows.append({"import": str(metadata.relative_to(root)), "status": "unsupported_metadata"})
            continue
        source = root / source_match.group(1)
        outputs = [root / ".godot/imported" / name for name in output_matches]
        checksum_stem = re.sub(r'\.(s3tc|etc2|bptc|astc)$', '', outputs[0].stem)
        checksum = outputs[0].with_name(checksum_stem + ".md5")
        if not source.is_file() or any(not output.is_file() for output in outputs) or not checksum.is_file():
            rows.append({"import": str(metadata.relative_to(root)), "status": "missing_source_or_output"})
            continue
        content = checksum.read_text(encoding="utf-8", errors="replace")
        expected = re.search(r'^source_md5="([0-9a-f]{32})"', content, re.M)
        if not expected:
            rows.append({"import": str(metadata.relative_to(root)), "status": "missing_source_checksum"})
            continue
        actual = hashlib.md5(source.read_bytes()).hexdigest()
        if expected.group(1) != actual:
            rows.append({"import": str(metadata.relative_to(root)), "status": "source_checksum_mismatch",
                         "expected": expected.group(1), "actual": actual})
            continue
        expected_output = re.search(r'^dest_md5="([0-9a-f]{32})"', content, re.M)
        output_digest = hashlib.md5()
        for output in outputs:
            with output.open("rb") as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    output_digest.update(block)
        if not expected_output:
            rows.append({"import": str(metadata.relative_to(root)), "status": "missing_output_checksum"})
            continue
        if output_digest.hexdigest() != expected_output.group(1):
            rows.append({"import": str(metadata.relative_to(root)), "status": "output_checksum_mismatch"})
            continue
        rows.append({"import": str(metadata.relative_to(root)), "status": "checksums_match"})
    counts = {}
    for row in rows:
        counts[row["status"]] = counts.get(row["status"], 0) + 1
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"counts": counts, "rows": rows}, indent=2), encoding="utf-8")
    print(json.dumps(counts))
    if any(row["status"] != "checksums_match" for row in rows):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
