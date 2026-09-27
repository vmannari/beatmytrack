#!/usr/bin/env python3
"""Standalone loopback-only audition server. Standard library; no generation API."""
from __future__ import annotations
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import shutil
import socket
from pathlib import Path
from urllib.parse import unquote, urlsplit
import webbrowser

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "build/music"
UI = Path(__file__).parent / "ui"

def catalog():
    items, errors = [], []
    for manifest_path in sorted(ASSETS.rglob("manifest.json")):
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            if manifest.get('approval') == 'superseded':
                continue
            for job in manifest.get("jobs", []):
                if job.get("status") != "complete":
                    continue
                path = (manifest_path.parent / job["file"]).resolve()
                if not path.is_relative_to(ASSETS.resolve()) or not path.is_file():
                    continue
                relative = path.relative_to(ASSETS.resolve()).as_posix()
                items.append({**job, "id": relative, "url": "/audio/" + relative,
                    "run": manifest_path.parent.name, "approval": manifest.get("approval", "unreviewed")})
        except (ValueError, KeyError, OSError) as error:
            errors.append(f"{manifest_path.name}: {error}")
    return {"items": items, "errors": errors}

class Handler(SimpleHTTPRequestHandler):
    # Keep local audio transfers on reusable connections (all replies are length-delimited).
    protocol_version = "HTTP/1.1"

    def setup(self):
        super().setup()
        self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    def copyfile(self, source, outputfile):
        shutil.copyfileobj(source, outputfile, length=64 * 1024)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(UI), **kwargs)

    def do_GET(self):
        path = unquote(urlsplit(self.path).path)
        if path == "/api/catalog":
            data = json.dumps(catalog()).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)
            return
        if path.startswith("/audio/"):
            target = (ASSETS / path[len("/audio/"):]).resolve()
            if not target.is_relative_to(ASSETS.resolve()) or target.suffix.lower() not in (".wav", ".ogg", ".mp3", ".flac"):
                self.send_error(403)
                return
        elif path not in ("/", "/index.html", "/app.js", "/style.css", "/favicon.ico"):
            self.send_error(404)
            return
        super().do_GET()

    def translate_path(self, path):
        path = unquote(urlsplit(path).path)
        if path.startswith("/audio/"):
            return str((ASSETS / path[len("/audio/"):]).resolve())
        return str(UI / ("index.html" if path == "/" else path.lstrip("/")))

    # Only GET is supported; don't expose arbitrary local paths through HEAD.
    def do_HEAD(self):
        self.send_error(405)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=18765)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    url = f"http://127.0.0.1:{server.server_port}"
    print("Music workbench: " + url, flush=True)
    if not args.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == "__main__":
    main()
