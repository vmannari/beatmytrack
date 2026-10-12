"""Fetch a bounded, pinned CC0 guitar/bass/acoustic-kit set for offline scoring."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "build/music/locked-in-v1/sources"
LIBRARIES = {
    "guitar": ("karoryfer.black-and-green-guitars", "b3b3249d37dc977a1a297bd2dc053e6d9b6b805c", "LICENSE"),
    "bass": ("karoryfer.black-and-blue-basses", "6e7d674cdb41be7a54dbccb15472401ad01099b9", "license"),
    "drums": ("karoryfer.big-rusty-drums", "f07ce00df34a46b6b08375be56fe116cf15782bc", "LICENSE"),
}


def selections():
    jobs = []
    for kind, (name, revision, licence) in LIBRARIES.items():
        jobs.append((kind, licence, "licence"))
    for note in ["d4", "e4", "gb4", "a4", "b4", "d5", "e5", "gb5", "a5", "d6"]:
        for velocity in ["p", "mf"]:
            for rr in [1, 2]: jobs.append(("guitar", f"Samples/green/ord/twang_{note}_{velocity}_rr{rr}.wav", "guitar"))
    for note in ["d2", "e2", "gb2", "a2", "b2", "d3", "e3", "gb3", "g3", "a3", "b3"]:
        for velocity in ["mp", "mf"]:
            for rr in [1, 2]: jobs.append(("bass", f"Samples/darkblack/reg/darkblack_{note}_{velocity}_rr{rr}.wav", "bass"))
    drum_paths = {
        "kick": ("Samples/kick_24/kick/kick/k", [3, 5]),
        "snare": ("Samples/snare_14/center/top/sn_center", [3, 5]),
        "snare_room": ("Samples/snare_14/center/oh/sn_center", [3, 5]),
        "hat": ("Samples/hihat_14/cl/cl/ht_cl", [2, 4]),
        "hat_open": ("Samples/hihat_14/ho/cl/ht_ho", [3]),
        "tom": ("Samples/tom_14/center/cl/t14", [4]),
        "ride": ("Samples/ride_22/rd/cl/rd", [4]),
        "crash": ("Samples/crash_17/cr/cl/cr", [3]),
    }
    for kind, (prefix, velocities) in drum_paths.items():
        for velocity in velocities:
            for rr in ([1, 2, 3] if kind == "ride" else [1, 2, 3, 4]): jobs.append(("drums", f"{prefix}_vl{velocity}_rr{rr}.flac", kind))
    return jobs


def fetch(job):
    library, path, role = job
    name, revision, _ = LIBRARIES[library]
    source = DEST / library / path
    url = f"https://raw.githubusercontent.com/sfzinstruments/{name}/{revision}/" + urllib.parse.quote(path, safe="/")
    if not source.exists():
        request = urllib.request.Request(url, headers={"User-Agent": "Beat-my-track-offline-band-score"})
        with urllib.request.urlopen(request, timeout=60) as response: data = response.read()
        if path.endswith(".wav") and data[:4] != b"RIFF": raise ValueError("Expected recorded WAV, not a pointer: " + path)
        if path.endswith(".flac") and data[:4] != b"fLaC": raise ValueError("Expected recorded FLAC: " + path)
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_bytes(data)
    data = source.read_bytes()
    return {"path": source.relative_to(DEST).as_posix(), "url": url, "role": role,
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "licence": "CC0-1.0"}


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for name, revision, _ in LIBRARIES.values():
        index_path = DEST / f"{name}-tree.json"
        if not index_path.exists():
            request = urllib.request.Request(f"https://api.github.com/repos/sfzinstruments/{name}/git/trees/{revision}?recursive=1", headers={"User-Agent": "Beat-my-track-offline-band-score"})
            with urllib.request.urlopen(request, timeout=60) as response: index_path.write_bytes(response.read())
    jobs = selections()
    for library, path, _ in jobs:
        name, revision, _ = LIBRARIES[library]
        index = json.loads((DEST / f"{name}-tree.json").read_text())
        assert index["sha"] == revision
        if path not in {row["path"] for row in index["tree"]}: raise ValueError("Missing pinned sample: " + path)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: sources = list(pool.map(fetch, jobs))
    manifest = {"source_family": "Karoryfer recorded band", "licence": "CC0-1.0", "libraries": LIBRARIES, "sources": sources}
    for library, (_, _, path) in LIBRARIES.items():
        assert "CC0 1.0 Universal" in (DEST / library / path).read_text()
    destination = DEST / "manifest.json"
    if destination.exists():
        previous = json.loads(destination.read_text())
        by_path = {row["path"]: row for row in sources}
        assert all(by_path.get(row["path"]) == row for row in previous["sources"]), "Source bytes changed; preserve and investigate"
        if previous != manifest and not (DEST / "manifest-initial.json").exists():
            (DEST / "manifest-initial.json").write_text(json.dumps(previous, indent=2) + "\n")
    destination.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("BAND_SOURCES", len(sources), sum(row["bytes"] for row in sources), "bytes; all CC0")


if __name__ == "__main__": main()
