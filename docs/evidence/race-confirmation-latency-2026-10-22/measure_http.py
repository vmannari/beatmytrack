"""Actual loopback HTTP and a separate worker process, disposable PostgreSQL only.

Real native geometry and the retained five-lap path exercise the unchanged race
checker. A fixture-only identity override avoids external identity services.
The old worker/poll cadence and new wake/wait path use identical scoring code.
"""
import argparse
import importlib.util
import json
import logging
import socket
import statistics
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

import httpx
import uvicorn
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.runs import board_manifest
from bmt_backend.security import current_player
from bmt_backend.track_models import (
    Board,
    OperationState,
    Track,
    TrackVersion,
    digest,
    new_id,
    now,
)
from bmt_backend.verifier import GodotVerifier
from bmt_backend.worker import process_one
from bmt_backend.worker_lifecycle import WorkerControl, run_worker
from fastapi import HTTPException, Request
from sqlalchemy import create_engine
from sqlalchemy.engine import make_url

HERE = Path(__file__).resolve().parent
DATA = json.loads(Path('/task/native-fixture.json').read_text())
RAW_URL = next(line.split('=', 1)[1].strip() for line in Path('/task/db.env').read_text().splitlines()
               if line.startswith('BMT_TEST_DATABASE_URL='))
URL = make_url(RAW_URL).set(host='127.0.0.1', port=5432)


def make_app(schema, folder, original):
    engine = create_engine(URL, hide_parameters=True, pool_size=4, max_overflow=0,
        connect_args={'options': '-c search_path=' + schema + ' -c statement_timeout=10000', 'connect_timeout': 3})
    settings = Settings(environment='test', database_url=URL.render_as_string(hide_password=False),
        object_dir=str(folder / 'objects'), rate_limit_per_minute=10000, write_limit_per_minute=10000)
    verifier = GodotVerifier(settings)
    verifier._versions = DATA['active']

    def forbidden(*_args, **_kwargs):
        raise AssertionError('Warm native geometry fixture attempted engine execution')

    verifier._invoke = forbidden
    app = create_app(settings, verifier=verifier, engine=engine)
    logging.getLogger('bmt').setLevel(logging.ERROR)
    if original:
        app.state.run_signals.publish = lambda *_args, **_kwargs: None
    return app


def worker(schema, folder, original):
    app = make_app(schema, folder, original)
    control = WorkerControl()
    sequence = 0

    def job(active):
        nonlocal sequence
        if (folder / 'stop').exists():
            control.request_stop()
            return False
        worked = process_one(active)
        if not worked:
            sequence += 1
            temporary = folder / 'idle.pending'
            temporary.write_text(json.dumps({'sequence': sequence, 'at': time.monotonic()}))
            temporary.replace(folder / 'idle.json')
        return worked

    runner = run_worker
    if original:
        spec = importlib.util.spec_from_file_location('bmt_backend.confirmation_original_lifecycle', HERE / 'before/worker_lifecycle.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        runner = module.run_worker
    runner(app, job, control=control)


def benchmark(label, original, count):
    admin = create_engine(URL, hide_parameters=True)
    schema = 'test_confirmation_' + new_id().replace('-', '')
    with admin.begin() as db:
        db.exec_driver_sql('CREATE SCHEMA ' + schema)
    samples = []
    with tempfile.TemporaryDirectory(prefix='bmt-confirmation-') as temporary:
        folder = Path(temporary)
        app = make_app(schema, folder, original)
        process = thread = server = None
        try:
            upgrade(app.state.engine)
            content_hash = app.state.blobs.put_json(DATA['document'])
            with app.state.session_factory() as db:
                player = Player(display_name='Owned HTTP latency fixture')
                db.add(player); db.flush()
                track = Track(owner_id=player.id)
                db.add(track); db.flush()
                version = TrackVersion(track_id=track.id, number=1, name='HTTP latency fixture', content_hash=content_hash,
                    manifest=DATA['geometry']['manifest'], state='published', published_at=now())
                db.add(version); db.flush()
                pinned = board_manifest(version, 'compact')
                db.add(Board(id=digest({'version_id': version.id, **pinned}), version_id=version.id,
                    vehicle_id='compact', manifest=pinned))
                db.add(OperationState(id='geom:' + content_hash, updated_at=now(), details=DATA['geometry']))
                db.commit()
                owner, version_id = player.id, version.id

            def identity(request: Request):
                if request.headers.get('x-fixture-player') != owner:
                    raise HTTPException(401, 'Fixture identity required')
                with app.state.session_factory() as db:
                    return db.get(Player, owner)

            app.dependency_overrides[current_player] = identity
            listener = socket.socket()
            listener.bind(('127.0.0.1', 0))
            listener.listen(128)
            port = listener.getsockname()[1]
            server = uvicorn.Server(uvicorn.Config(app, log_level='error', access_log=False))
            thread = threading.Thread(target=server.run, kwargs={'sockets': [listener]}, daemon=True)
            thread.start()
            deadline = time.monotonic() + 15
            while not server.started:
                assert thread.is_alive() and time.monotonic() < deadline
                time.sleep(0.01)
            with (HERE / (label + '-worker.log')).open('w') as log:
                command = [sys.executable, __file__, '--worker', '--schema', schema, '--folder', str(folder)]
                if original:
                    command.append('--original')
                process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
                base = 'http://127.0.0.1:' + str(port) + '/v1'
                with httpx.Client(timeout=8, headers={'x-fixture-player': owner}) as client:
                    last_sequence = 0
                    for index in range(count + 1):
                        issued = client.post(base + '/run-tickets', json={'version_id': version_id, 'vehicle_id': 'compact'},
                            headers={'Idempotency-Key': new_id()})
                        assert issued.status_code == 201, issued.text
                        ticket = issued.json()['ticket_id']
                        deadline = time.monotonic() + 15
                        while True:
                            assert process.poll() is None and time.monotonic() < deadline
                            ready = json.loads((folder / 'idle.json').read_text()) if (folder / 'idle.json').exists() else {}
                            if ready.get('sequence', 0) > last_sequence:
                                last_sequence = ready['sequence']
                                break
                            time.sleep(0.005)
                        # Sample different arrival phases in the old one-second idle cycle.
                        time.sleep((0.03, 0.20, 0.45, 0.70)[index % 4])
                        started = time.perf_counter()
                        uploaded = client.post(base + '/runs', json={'ticket_id': ticket, 'replay': DATA['replay']},
                            headers={'Idempotency-Key': new_id()})
                        acknowledged = time.perf_counter()
                        assert uploaded.status_code == 202, uploaded.text
                        run_id = uploaded.json()['run_id']
                        requests = 1
                        if original:
                            time.sleep(1)
                            result = client.get(base + '/runs/' + run_id)
                        else:
                            result = client.get(base + '/runs/' + run_id + '/wait?timeout_ms=2000')
                        requests += 1
                        while result.status_code == 200 and result.json()['status'] in ('queued', 'verifying'):
                            time.sleep(1)
                            result = client.get(base + '/runs/' + run_id)
                            requests += 1
                        confirmed = time.perf_counter()
                        assert result.status_code == 200, result.text
                        assert result.json()['status'] == 'verified', result.text
                        assert result.json()['time_ticks'] == 12757
                        assert result.json()['lap_ticks'] == [2634, 2532, 2531, 2530, 2530]
                        if index:
                            samples.append({'upload_to_confirmation_ms': (confirmed-started)*1000,
                                'upload_ack_ms': (acknowledged-started)*1000, 'http_requests': requests})
                (folder / 'stop').touch()
                assert process.wait(timeout=10) == 0
                process = None
            summary = {key: statistics.median(row[key] for row in samples) for key in samples[0]}
            report = {'label': label, 'original': original, 'samples': samples, 'medians': summary,
                'scope': 'Actual loopback HTTP; real checker/native descriptor; separate idle worker process; isolated PostgreSQL schema/local objects; fixture-only authentication',
                'excluded': 'Cloud network/storage, real identity authentication, phone rendering and sustained production load',
                'policy': 'Same current scoring/atomic rewards; original worker idle cadence and one-second client polling versus new notifications and one bounded result wait'}
            (HERE / (label + '.json')).write_text(json.dumps(report, indent=2) + '\n')
            print(label, json.dumps(summary), flush=True)
        finally:
            (folder / 'stop').touch()
            if process is not None:
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.terminate()
                    process.wait(timeout=5)
            if server:
                server.should_exit = True
            if thread:
                thread.join(timeout=10)
            app.state.engine.dispose()
            with admin.begin() as db:
                db.exec_driver_sql('DROP SCHEMA ' + schema + ' CASCADE')
            admin.dispose()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--worker', action='store_true')
    parser.add_argument('--original', action='store_true')
    parser.add_argument('--schema')
    parser.add_argument('--folder')
    parser.add_argument('--count', type=int, default=8)
    args = parser.parse_args()
    if args.worker:
        worker(args.schema, Path(args.folder), args.original)
    else:
        for pair in (1, 2):
            benchmark('original-http-pair' + str(pair), True, args.count)
            benchmark('final-http-pair' + str(pair), False, args.count)
