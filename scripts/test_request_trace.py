"""Serve only fictional loopback responses while the real pinned Godot client runs."""
import os
import subprocess
import threading
import time
from datetime import datetime, timedelta, timezone
from email.utils import format_datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            status, body = 200, b'{"value":1}'
            if self.path.endswith("trace-slow"):
                time.sleep(0.3)
                body = b'{"value":"cancelled-old-request"}'
            elif self.path.endswith("trace-fresh"):
                body = b'{"value":"fresh-request"}'
            if self.path.endswith("trace-error"):
                status, body = 429, b'{"detail":"RATE_LIMITED"}'
            elif self.path.endswith("trace-invalid"):
                body = b'{"invalid":'
            elif self.path.endswith("trace-cached") and self.headers.get("If-None-Match") == '"fixture"':
                status, body = 304, b''
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Request-ID", "private-header" if self.path.endswith("trace-bad-id") else "6BA7B810-9DAD-41D1-80B4-00C04FD430C8")
            if self.path.endswith("trace-cached"):
                self.send_header("ETag", '"fixture"')
            if status == 429:
                self.send_header("Retry-After", format_datetime(datetime.now(timezone.utc)+timedelta(seconds=75), usegmt=True))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                pass  # The disposable cancellation fixture closes this socket.
        def log_message(self, *_args):
            pass
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever)
    thread.start()
    env = dict(os.environ, BMT_TRACE_TEST_URL=f"http://127.0.0.1:{server.server_port}")
    try:
        result = subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/dev.ps1',
                                 '-Action','TestScript','-ScriptPath','res://tests/test_request_trace.gd',
                                 '-CommandTimeoutSeconds','60'],cwd=ROOT,env=env,capture_output=True,text=True,
                                timeout=90,check=False)
        output = result.stdout+result.stderr
        folder = ROOT/'docs/evidence/communication-l1-l3-2026-10-13'
        folder.mkdir(parents=True,exist_ok=True)
        (folder/'request-trace-native.log').write_text(output,encoding='utf-8')
        print(output)
        return result.returncode
    finally:
        server.shutdown(); server.server_close(); thread.join(timeout=5)


if __name__ == '__main__':
    raise SystemExit(main())
