"""Fetch pinned public, attributed dictionaries; never used at runtime."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import urllib.request

REPO = "LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words"
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "backend/bmt_backend/name_filter_data"
LANGUAGES = "ar cs da de en eo es fa fi fil fr hi hu it ja kab ko nl no pl pt ru sv th tr zh".split()


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Beat-my-track-name-filter"})
    with urllib.request.urlopen(request, timeout=25) as response:
        return response.read()


if __name__ == "__main__":
    commit = json.loads(fetch("https://api.github.com/repos/" + REPO + "/commits/master"))["sha"]
    DEST.mkdir(parents=True, exist_ok=True)

    def download(name):
        data = fetch("https://raw.githubusercontent.com/" + REPO + "/" + commit + "/" + name)
        destination = DEST / ("LICENSE.txt" if name == "LICENSE" else name + ".txt")
        destination.write_bytes(data)
        return name, {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data),
                      "lines": len(data.decode("utf-8").splitlines())}

    with ThreadPoolExecutor(max_workers=4) as pool:
        sources = dict(pool.map(download, [*LANGUAGES, "LICENSE"]))
    manifest = {"repository": "https://github.com/" + REPO, "commit": commit,
                "copyright": "Shutterstock, Inc.", "license": "CC-BY-4.0", "sources": sources}
    (DEST / "sources.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"commit": commit, "languages": len(LANGUAGES),
                      "entries": sum(sources[name]["lines"] for name in LANGUAGES)}))
