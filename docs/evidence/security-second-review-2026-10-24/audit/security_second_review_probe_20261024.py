"""Bounded review probes against a disposable loopback server only."""
import http.client
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/security-second-review-2026-10-24'
WORK = ROOT / 'build/security-second-review-2026-10-24'

def application():
    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.migrate import upgrade
    app = create_app(Settings(database_url='sqlite://', object_dir=str(WORK/'objects'),
                              google_client_ids=('review-fixture.apps.googleusercontent.com',)))
    upgrade(app.state.engine)
    return app

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    env = {k:v for k,v in os.environ.items() if not k.startswith('BMT_')}
    env['PYTHONPATH'] = str(ROOT/'.tools') + os.pathsep + str(ROOT/'backend')
    command = [sys.executable, '-m', 'uvicorn', 'security_second_review_probe_20261024:application',
               '--factory', '--host', '127.0.0.1', '--port', str(port), '--limit-concurrency', '24',
               '--no-proxy-headers', '--no-access-log', '--timeout-keep-alive', '5']
    def request(path='/healthz', method='GET', body=None):
        connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
        try:
            connection.request(method, path, body, {'Connection':'close','Content-Type':'application/json'})
            response = connection.getresponse()
            response.read()
            return response.status
        finally:
            connection.close()
    held = []
    with (OUT/'incomplete-headers-server.log').open('wb') as log:
        process = subprocess.Popen(command, env=env, cwd=ROOT, stdout=log, stderr=log)
        try:
            for _ in range(150):
                try:
                    if request() == 200:
                        break
                except (OSError, http.client.HTTPException):
                    pass
                if process.poll() is not None:
                    raise RuntimeError('Owned disposable server exited')
                time.sleep(.1)
            else:
                raise RuntimeError('Owned disposable server startup timed out')
            baseline = request()
            for _ in range(23):
                connection = socket.create_connection(('127.0.0.1', port), timeout=3)
                connection.sendall(b'GET /healthz HTTP/1.1\r\nHost: localhost\r\nX-Unfinished: ')
                held.append(connection)
                time.sleep(.02)
            immediate = [request() for _ in range(3)]
            time.sleep(6.2)  # Exceed the configured five-second keep-alive timeout.
            delayed = [request() for _ in range(3)]
            auth = request('/v1/auth/google/challenge', 'POST', '{}')
            for connection in held:
                connection.close()
            held.clear()
            time.sleep(.3)
            after = request()
            result = {'scope':'disposable loopback Uvicorn only; no live attack',
                      'held_connections':23, 'baseline':baseline, 'immediate_health':immediate,
                      'after_6_2_seconds_health':delayed, 'ordinary_auth':auth, 'released_health':after,
                      'configured_limit_concurrency':24, 'configured_keep_alive_seconds':5}
            (OUT/'incomplete-headers.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
            print(json.dumps(result))
            assert baseline == after == 200
            assert immediate == delayed == [503]*3 and auth == 503
        finally:
            for connection in held:
                connection.close()
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)

if __name__ == '__main__':
    main()
