"""Refresh only explicitly pinned versions using official PyPI wheel SHA256s."""
import argparse
import concurrent.futures
import json
import re
import ssl
import urllib.request
from pathlib import Path

PIN = re.compile(r"^([A-Za-z0-9](?:[A-Za-z0-9_.-]*[A-Za-z0-9])?)==([A-Za-z0-9][A-Za-z0-9_.+-]*)$")


def canonical_name(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def pinned_versions(text):
    result = {}
    for line in text.splitlines():
        words = line.strip().split()
        if not words or words[0].startswith(("#", "--", "\\")):
            continue
        match = PIN.fullmatch(words[0])
        if match is None:
            raise ValueError("Every requirement must have one explicit version")
        name, version = match.groups()
        if canonical_name(name) in {canonical_name(n) for n in result}:
            raise ValueError("Duplicate package pin")
        result[name] = version
    return result


def metadata(name, version, context):
    with urllib.request.urlopen("https://pypi.org/pypi/" + name + "/" + version + "/json",
                                context=context, timeout=30) as response:
        value = json.load(response)
    wheels = sorted((row["filename"], row["digests"]["sha256"]) for row in value["urls"]
                    if row["packagetype"] == "bdist_wheel" and not row.get("yanked", False))
    if not wheels or any(not re.fullmatch(r"[0-9a-f]{64}", digest) for _, digest in wheels):
        raise ValueError("No valid published wheel hashes for " + name)
    return {"name": name, "version": version, "source": "https://pypi.org/pypi/" + name + "/" + version + "/json",
            "wheels": [{"filename": filename, "sha256": digest} for filename, digest in wheels]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lock", type=Path, default=Path(__file__).resolve().parents[1] / "requirements.lock")
    parser.add_argument("--add", action="append", default=[], help="Explicit name==version to add or replace")
    parser.add_argument("--cert", type=Path)
    parser.add_argument("--receipt", type=Path, required=True)
    args = parser.parse_args()
    pins = pinned_versions(args.lock.read_text())
    for value in args.add:
        match = PIN.fullmatch(value)
        if match is None:
            raise ValueError("--add requires an explicit name==version")
        existing = next((name for name in pins if canonical_name(name) == canonical_name(match[1])), match[1])
        pins[existing] = match[2]
    pins = dict(sorted(pins.items(), key=lambda item: item[0].lower()))
    context = ssl.create_default_context(cafile=str(args.cert) if args.cert else None)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        records = list(pool.map(lambda item: metadata(*item, context), pins.items()))
    lines = ["# Explicit versions and official PyPI wheel hashes; refresh with deploy/lock_dependencies.py.",
             "# Includes platform alternatives; source distributions are intentionally disallowed.",
             "--only-binary=:all:", "--require-hashes", ""]
    for record in records:
        hashes = sorted({row["sha256"] for row in record["wheels"]})
        lines.append(record["name"] + "==" + record["version"] + " \\")
        lines.extend("    --hash=sha256:" + digest + (" \\" if index < len(hashes)-1 else "")
                     for index, digest in enumerate(hashes))
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.receipt.write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
    # No mutation happens until every package has valid metadata.
    temporary = args.lock.with_name(args.lock.name + ".tmp")
    temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    temporary.replace(args.lock)
    print("Locked", len(records), "packages with", sum(len(row["wheels"]) for row in records), "published wheel hashes")


if __name__ == "__main__":
    main()
