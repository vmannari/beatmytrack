"""Bundle the race-menu concept into one offline, double-clickable HTML file."""
import base64
import hashlib
import json
import mimetypes
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ASSETS = {
    "body_font": "game/assets/fonts/Barlow-Regular.ttf",
    "display_font": "game/assets/fonts/BarlowCondensed-SemiBold.ttf",
    "scenery": "game/assets/menu/discovery-biomes.png",
    "workshop": "game/assets/menu/discovery-workshop.png",
    "compact": "game/assets/news/vehicles/compact.png",
    "classic": "game/assets/news/vehicles/classic.png",
    "pickup": "game/assets/news/vehicles/pickup.png",
    "formula": "game/assets/news/vehicles/formula.png",
    "kart": "game/assets/news/vehicles/kart.png",
    "electric": "game/assets/menu/electric_illustration_v1.png",
    "forklift": "game/assets/menu/forklift_illustration_v1.png",
    "duel": "game/assets/menu/challenges/one-to-one-v3.png",
    "group": "game/assets/menu/challenges/group-race-v3.png",
    "series": "game/assets/menu/challenges/three-by-three-v6.png",
}


def main():
    cache = HERE / "embedded-assets"
    cache_manifest_path = HERE / "optimized-assets.json"
    cached = json.loads(cache_manifest_path.read_text()) if cache_manifest_path.exists() else {}
    if "--optimize" in sys.argv:
        from playwright.sync_api import sync_playwright

        cache.mkdir(exist_ok=True)
        with sync_playwright() as driver:
            browser = driver.chromium.launch(headless=True, executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
            page = browser.new_page()
            for name, relative in ASSETS.items():
                if relative.endswith(".ttf"):
                    continue
                data = (ROOT / relative).read_bytes()
                uri = "data:image/png;base64," + base64.b64encode(data).decode("ascii")
                optimized = page.evaluate("""async ({uri, limit}) => {
                    const image = new Image(); image.src = uri; await image.decode();
                    const scale = Math.min(1, limit / Math.max(image.width, image.height));
                    const canvas = document.createElement('canvas');
                    canvas.width = Math.round(image.width * scale); canvas.height = Math.round(image.height * scale);
                    canvas.getContext('2d').drawImage(image, 0, 0, canvas.width, canvas.height);
                    return canvas.toDataURL('image/webp', .88).split(',')[1];
                }""", {"uri": uri, "limit": 1536 if name == "scenery" else 1000})
                (cache / f"{name}.webp").write_bytes(base64.b64decode(optimized))
                cached[name] = {"source_sha256": hashlib.sha256(data).hexdigest()}
            browser.close()
        cache_manifest_path.write_text(json.dumps(cached, indent=2) + "\n", encoding="utf-8")
    source = (HERE / "index.template.html").read_text(encoding="utf-8")
    manifest = {}
    for name, relative in ASSETS.items():
        original = (ROOT / relative).read_bytes()
        original_hash = hashlib.sha256(original).hexdigest()
        optimized_path = cache / f"{name}.webp"
        use_cache = optimized_path.exists() and cached.get(name, {}).get("source_sha256") == original_hash
        data = optimized_path.read_bytes() if use_cache else original
        mime = "image/webp" if use_cache else mimetypes.guess_type(relative)[0] or "application/octet-stream"
        uri = f"data:{mime};base64,{base64.b64encode(data).decode('ascii')}"
        source = source.replace("@@" + name + "@@", uri)
        manifest[name] = {"source": relative, "source_sha256": original_hash, "embedded_sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
    if "@@" in source:
        raise ValueError("Unresolved asset placeholder")
    (HERE / "index.html").write_text(source, encoding="utf-8")
    (HERE / "assets.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Built {HERE / 'index.html'} ({len(source.encode('utf-8')):,} bytes)")


if __name__ == "__main__":
    main()
