"""Fetch only the CC0 recordings used by the original 2026-10-07 score.

Offline development tool. Immutable upstream revision and source hashes; never a
runtime download. Existing recordings are checked, not silently overwritten.
"""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "build/music/score-v1/sources"
REVISION = "440300901dfe9275fd84e0b7763af1f8443ae62e"
BASE = f"https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{REVISION}/"


def selection():
    paths = ["LICENSE", "Readme.txt"]
    for note in ["C2", "G2", "C3", "G3", "C4", "G4", "C5"]:
        for rr in [1, 2]:
            if rr == 2 and note in ["C2", "G2"]:
                continue
            paths.append(f"Keys/Upright Nr1/UR1_{note}_pp_RR{rr}.wav")
    for note in ["D2", "F2", "A2", "C3", "E3", "G3"]:
        paths.append(f"Strings/Cello Section/susvib/susvib_{note}_v1_1.wav")
    for note in ["D3", "A3", "C4", "E4", "G4"]:
        paths.append(f"Strings/Violin Section/susVib/VlnEns_susVib_{note}_v1.wav")
    for note in ["C2", "G2", "D3", "F3", "A3", "C4", "E4"]:
        paths.append(f"Strings/Viola Section/susvib/ViolaEns_susvib_{note}_v1_1.wav")
    for note in ["B3", "C3", "D4", "F4", "A4", "C5"]:
        paths.append(f"Strings/Harp/KSHarp_{note}_mf.wav")
    for note in ["C3", "C4", "E4", "A4"]:
        paths.append(f"Woodwinds/Flute/susNV/LDFlute_susNV_{note}_v1_1.wav")
    for note in ["C3", "D4", "F4"]:
        paths.append(f"Brass/F Horn/sus/MOHorn_sus_{note}_v1_1.wav")
    paths += [
        "Percussion/LogDrumLo_MedM_v1_rr1_Sum.wav",
        "Percussion/LogDrumLo_MedM_v1_rr2_Sum.wav",
        "Percussion/Conga-Tap1_v1_rr1_Sum.wav",
        "Percussion/Conga-Tap1_v1_rr2_Sum.wav",
        "Percussion/BDrumNewhit_v1_rr1_Sum.wav",
        "Percussion/BDrumNewhit_v1_rr2_Sum.wav",
    ]
    return paths


def fetch(path):
    local = DEST / path
    url = BASE + urllib.parse.quote(path, safe="/")
    if not local.exists():
        request = urllib.request.Request(url, headers={"User-Agent": "Beat-my-track-offline-score"})
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read()
        if path.endswith(".wav") and data[:4] not in (b"RIFF", b"RF64"):
            raise ValueError("Expected a recorded WAV: " + path)
        local.parent.mkdir(parents=True, exist_ok=True)
        local.write_bytes(data)
    data = local.read_bytes()
    return {"path": path, "url": url, "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(), "license": "CC0-1.0"}


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    index_path = DEST.parent / "vsco-tree.json"
    if not index_path.exists():
        request = urllib.request.Request(f"https://api.github.com/repos/sgossner/VSCO-2-CE/git/trees/{REVISION}?recursive=1",
                                         headers={"User-Agent": "Beat-my-track-offline-score"})
        with urllib.request.urlopen(request, timeout=60) as response: index_path.write_bytes(response.read())
    index = json.loads(index_path.read_text())
    if index["sha"] != REVISION: raise ValueError("Source index must match the immutable tree revision")
    available = {x["path"] for x in index["tree"]}
    paths = selection()
    missing = set(paths) - available
    if missing:
        raise ValueError("Paths absent from pinned source index: " + str(sorted(missing)))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        records = list(pool.map(fetch, paths))
    manifest_path = DEST / "manifest.json"
    if manifest_path.exists():
        previous = json.loads(manifest_path.read_text())
        if previous["sources"] != records:
            raise ValueError("Pinned source bytes changed; preserve and investigate")
    manifest_path.write_text(json.dumps({"revision": REVISION, "repository": "https://github.com/sgossner/VSCO-2-CE",
        "license": "CC0-1.0", "sources": records}, indent=2) + "\n", encoding="utf-8")
    print(f"Fetched/checked {len(records)} cleared sources, {sum(x['bytes'] for x in records):,} bytes")


if __name__ == "__main__":
    main()
