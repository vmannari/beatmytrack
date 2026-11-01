"""Compare packaged game assets and engine libraries between probe APKs.

Reports unexpected differences and exits nonzero; binary manifest/signature
and Gradle metadata differ by package and are outside this content check.
"""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path


ALLOWED = {"assets/project.binary", "assets/core/build_identity.gdc"}


def inventory(path):
    output = {}
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            if info.is_dir() or not info.filename.startswith(("assets/", "lib/")):
                continue
            name = re.sub(r"^assets/\.godot/exported/\d+/", "assets/.godot/exported/<variant>/", info.filename)
            if name in output:
                raise ValueError("normalized duplicate path: " + name)
            digest = hashlib.sha256()
            with archive.open(info) as source:
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(block)
            output[name] = {"size": info.file_size, "sha256": digest.hexdigest()}
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("compatibility", type=Path)
    parser.add_argument("mobile", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    first, second = inventory(args.compatibility), inventory(args.mobile)
    changed = sorted(name for name in set(first) | set(second) if first.get(name) != second.get(name))
    unexpected = sorted(set(changed) - ALLOWED)
    result = {"compatibility_entries": len(first), "mobile_entries": len(second),
              "changed": changed, "allowed": sorted(ALLOWED), "unexpected": unexpected,
              "scope": "uncompressed assets and native libraries; not manifest, signatures, actual renderer or visual output"}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({key: result[key] for key in ["compatibility_entries", "mobile_entries", "changed", "unexpected"]}, indent=2))
    if unexpected:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
