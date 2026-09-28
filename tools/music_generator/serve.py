#!/usr/bin/env python3
"""Loopback music workbench with a bounded local Magenta generation API."""
from __future__ import annotations
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import shutil
import socket
import secrets
from pathlib import Path
from urllib.parse import unquote, urlsplit
import webbrowser
from workbench import Workbench

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
                # Owner explicitly rejected this high, short acoustic opening.
                # Retain source files, but never offer it in the active audition catalog.
                if job.get('family') in ('shared_road_r3', 'evolving_r4') and job.get('state_index') == 0 and job.get('program') == 24:
                    continue
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
        if path == '/api/workbench':
            self.json_reply({**self.server.workbench.snapshot(), 'token': self.server.token})
            return
        if path == "/api/catalog":
            result = catalog()
            library = self.server.workbench.snapshot()
            saved = {i['id']: i for i in library['tracks']}
            # Only saved workbench takes enter the advanced mix catalog.
            result['items'] = [{**i, **saved.get(i['id'], {}), 'source_state_index': i.get('state_index')} for i in result['items']
                               if not i['id'].startswith('workbench/') or i['id'] in saved]
            self.json_reply(result)
            return
        if path.startswith("/audio/"):
            target = (ASSETS / path[len("/audio/"):]).resolve()
            if not target.is_relative_to(ASSETS.resolve()) or target.suffix.lower() not in (".wav", ".ogg", ".mp3", ".flac"):
                self.send_error(403)
                return
        elif path not in ("/", "/index.html", "/app.js", "/style.css", "/studio.js", "/studio.css", "/lab.html", "/favicon.ico"):
            self.send_error(404)
            return
        super().do_GET()

    def json_reply(self, value, status=200):
        data = json.dumps(value, allow_nan=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            length = 0
        if not 0 < length <= 16384:
            self.close_connection = True
            self.json_reply({'error': 'Expected a small JSON request.'}, 400)
            return
        # Drain the bounded body before a rejection to avoid a Windows TCP reset
        # hiding the actionable JSON error from the browser.
        raw = self.rfile.read(length)
        # Browser-local capability + exact origin blocks cross-site GPU/disk writes.
        expected = f'http://127.0.0.1:{self.server.server_port}'
        if (self.headers.get('X-Workbench-Token') != self.server.token or
                self.headers.get('Origin', expected) != expected or
                self.headers.get('Host') != expected.removeprefix('http://')):
            self.close_connection = True
            self.json_reply({'error': 'Reload the workbench to reconnect securely.'}, 403)
            return
        try:
            if self.headers.get_content_type() != 'application/json':
                raise ValueError('Expected a small JSON request.')
            data = json.loads(raw)
            if not isinstance(data, dict):
                raise ValueError('Expected a JSON object.')
            action = {'/api/generate': self.server.workbench.start, '/api/save': self.server.workbench.save,
                      '/api/discard': self.server.workbench.discard}.get(self.path)
            if not action:
                self.json_reply({'error': 'Unknown action.'}, 404)
                return
            self.json_reply(action(data))
        except (ValueError, TypeError) as error:
            self.close_connection = True
            self.json_reply({'error': str(error)}, 400)
        except RuntimeError as error:
            self.json_reply({'error': str(error)}, 409)
        except OSError:
            self.json_reply({'error': 'Could not write music data. Check disk space and folder permissions.'}, 500)

    def translate_path(self, path):
        path = unquote(urlsplit(path).path)
        if path.startswith("/audio/"):
            return str((ASSETS / path[len("/audio/"):]).resolve())
        return str(UI / ("index.html" if path in ('/', '/index.html') else path.lstrip("/")))

    # HEAD is deliberately unsupported; all file reads use the checked GET path.
    def do_HEAD(self):
        self.send_error(405)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=18765)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.token = secrets.token_urlsafe(32)
    server.workbench = Workbench(ROOT, ASSETS, catalog)
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
