"""Bundle existing trusted official documents; runtime reuse requires an exact hash."""
import argparse
import hashlib
import json
from pathlib import Path

from bmt_backend.storage import canonical_json
from bmt_backend.usernames import DEVELOPER_NAME

ROOT = Path(__file__).resolve().parents[2]


def build(catalog, destination):
    source = catalog.read_bytes()
    documents = json.loads(source)["documents"]
    if not isinstance(documents, list) or len(documents) > 256:
        raise ValueError("Expected a bounded official document catalogue")
    outputs = {}
    destination.mkdir(parents=True, exist_ok=True)
    for document in documents:
        if not isinstance(document, dict) or document.get("creator") != DEVELOPER_NAME or document.get("schema") != "creator-track-v5":
            raise ValueError("Only current trusted official documents may seed the install cache")
        body = canonical_json(document)
        if len(body) > 1024*1024:
            raise ValueError("Bundled track exceeds the current document limit")
        identity = hashlib.sha256(body).hexdigest()
        (destination / (identity+".json")).write_bytes(body)
        outputs[identity] = identity+".json"
    index = {"schema": "bmt-bundled-tracks-v1", "source_sha256": hashlib.sha256(source).hexdigest(), "documents": outputs}
    (destination / "index.json").write_bytes(canonical_json(index))
    return {"documents": len(outputs), "bytes": sum((destination/name).stat().st_size for name in outputs.values()),
            "source_sha256": index["source_sha256"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=ROOT / "backend/bmt_backend/lab_tracks.json")
    parser.add_argument("--output", type=Path, default=ROOT / "game/resources/cloud_tracks")
    args = parser.parse_args()
    print(json.dumps(build(args.catalog, args.output), indent=2))


if __name__ == "__main__":
    main()
