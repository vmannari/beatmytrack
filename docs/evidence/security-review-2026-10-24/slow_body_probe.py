"""23 unfinished tiny requests against a disposable loopback-only Uvicorn process."""
import http.client
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
WORK = ROOT / 'build/security-review-20261024/slow-body'


def application():
    sys.path.insert(0, str(ROOT / 'backend'))
    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.migrate import upgrade
    WORK.mkdir(parents=True, exist_ok=True)
    app = create_app(Settings(database_url='sqlite:///' + (WORK / 'isolated.sqlite').as_posix(),
        object_dir=str(WORK / 'objects')))
    upgrade(app.state.engine)
    return app


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    environment = {k: v for k, v in os.environ.items() if not k.startswith('BMT_')}
    environment['PYTHONPATH'] = str(OUT) + os.pathsep + str(ROOT / 'backend')
    command = [sys.executable, '-m', 'uvicorn', 'slow_body_probe:application', '--factory',
        '--host', '127.0.0.1', '--port', str(port), '--limit-concurrency', '24',
        '--no-proxy-headers', '--no-access-log', '--timeout-keep-alive', '5']

    def health():
        connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
        try:
            connection.request('GET', '/healthz', headers={'Connection': 'close'})
            response = connection.getresponse()
            response.read()
            return response.status
        finally:
            connection.close()

    held = []
    started = time.monotonic()
    with (OUT / 'slow-body-server.log').open('wb') as log:
        process = subprocess.Popen(command, env=environment, cwd=ROOT, stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 30
            while True:
                try:
                    initial = health()
                    if initial == 200:
                        break
                except (OSError, http.client.HTTPException):
                    pass
                if process.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError('Disposable server did not start')
                time.sleep(.1)
            for _ in range(23):
                connection = socket.create_connection(('127.0.0.1', port), timeout=3)
                connection.sendall(b'POST /v1/auth/google/challenge HTTP/1.1\r\nHost: localhost\r\n'
                    b'Content-Type: application/json\r\nContent-Length: 2\r\n\r\n{')
                held.append(connection)
                time.sleep(.04)
            time.sleep(.4)
            saturated = [health() for _ in range(3)]
            for connection in held:
                connection.close()
            held.clear()
            time.sleep(.5)
            recovered = health()
            result = {'scope': 'isolated local SQLite/Uvicorn, default 24-connection cap; no live requests',
                'initial_health_status': initial, 'unfinished_small_bodies': 23,
                'health_status_while_held': saturated, 'health_after_disconnect': recovered,
                'elapsed_seconds': round(time.monotonic() - started, 3),
                'body_deadline_seconds_in_source': 30}
            (OUT / 'slow-body.json').write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps(result))
            assert initial == recovered == 200 and saturated == [503] * 3
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
