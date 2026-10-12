"""Vendor the pinned MIT flag-icons artwork; never used by the running game."""
import hashlib
import io
import json
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TAG = "v7.3.2"
URL = f"https://codeload.github.com/lipis/flag-icons/zip/refs/tags/{TAG}"


def main():
    archive = urllib.request.urlopen(URL, timeout=60).read()
    bundle = zipfile.ZipFile(io.BytesIO(archive))
    prefix = bundle.namelist()[0]
    countries = json.loads(bundle.read(prefix + "country.json"))
    # Upstream explicitly distinguishes ISO countries/territories from regional flags.
    countries = [row for row in countries if row.get("iso", True)]
    output = ROOT / "game/assets/countries"
    output.mkdir(parents=True, exist_ok=True)
    catalog = []
    for row in countries:
        code = row["code"].upper()
        assert len(code) == 2 and code.isascii() and code.isalpha()
        data = bundle.read(prefix + f"flags/4x3/{code.lower()}.svg")
        (output / f"{code.lower()}.svg").write_bytes(data)
        catalog.append({"code": code, "name": row["name"]})
    catalog.sort(key=lambda row: row["name"].casefold())
    encoded = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    (output / "countries.json").write_text(encoded, encoding="utf-8")
    (ROOT / "backend/bmt_backend/countries.json").write_text(encoded, encoding="utf-8")
    (output / "LICENSE-flag-icons.txt").write_bytes(bundle.read(prefix + "LICENSE"))
    (ROOT / "backend/bmt_backend/LICENSE-countries.txt").write_bytes(bundle.read(prefix + "LICENSE"))
    (output / "PROVENANCE.md").write_text(
        f"# Country flags\n\nVendored from [lipis/flag-icons {TAG}](https://github.com/lipis/flag-icons/tree/{TAG}), "
        "MIT license (retained in LICENSE-flag-icons.txt). Original 4:3 SVG artwork; "
        "ISO countries and territories only. No runtime requests or library dependency.\n\n"
        f"Archive: {URL}\n\nArchive SHA-256: `{hashlib.sha256(archive).hexdigest()}`\n\n"
        f"Reproduce: `python scripts/vendor_country_flags.py`. {len(catalog)} entries. "
        "The neutral unset-country icon is original project SVG. Tracked Godot import settings limit "
        "each image to 64 pixels with mipmaps, keeping the entire picker under 5 MiB of RGBA textures.\n",
        encoding="utf-8",
    )
    print(f"Vendored {len(catalog)} country flags; archive SHA-256 {hashlib.sha256(archive).hexdigest()}")


if __name__ == "__main__":
    main()
