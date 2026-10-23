"""Owned-schema worker measurements with the real checker and native geometry.

Upload, HTTP, cloud object latency and production capacity are outside this probe.
The seed command uses the pinned native engine once; timed runs forbid engine IO.
"""
import argparse
import importlib.util
import json
import logging
import os
import statistics
import tempfile
import time
from pathlib import Path

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.economy_models import CoinReward, CoinWallet
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import (
    Board,
    OperationState,
    Run,
    RunTicket,
    Track,
    TrackVersion,
    digest,
    new_id,
    now,
)
from bmt_backend.verifier import GodotVerifier
from sqlalchemy import create_engine, event
from sqlalchemy.engine import make_url

HERE = Path(__file__).resolve().parent
ROOT = next((p for p in HERE.parents if (p / 'backend/bmt_backend').is_dir()), Path('/task'))


def seed():
    settings = Settings(environment='test', database_url='sqlite://',
        godot_bin='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe',
        game_project=str(ROOT / 'build/race-verification-2026-10-22/optimised-ea803f8b-5b76-4430-8390-9f1d100c406d/game'),
        persistent_verifier=True)
    verifier = GodotVerifier(settings)
    try:
        document = json.loads((ROOT / 'backend/tests/fixtures/verified_oval.json').read_text())['document']
        source = json.loads((ROOT / 'build/verification-speed-2026-10-09/proof.json').read_text())
        proof = {'schema': 'bmt-race-path-v1', 'samples': [[s[0], s[1], s[2], s[6]] for s in source['samples']]}
        geometry = verifier.race_geometry(document)
        replay = {'schema': 'bmt-trajectory-v1', 'input_count': 12757, 'race_proof': proof}
        result = verifier.verify_run(document, replay, 'compact', geometry=geometry, capture_ghost=False)
        assert result['time_ticks'] == 12757 and result['lap_ticks'] == [2634, 2532, 2531, 2530, 2530]
        (HERE / 'native-fixture.json').write_text(json.dumps({'document': document, 'replay': replay,
            'geometry': geometry, 'active': verifier.manifest()}), encoding='utf-8')
        print('Pinned native geometry and exact five-lap proof saved.')
    finally:
        verifier.close()


def original_functions():
    """Patch only this probe process; runtime files and services are untouched."""
    from bmt_backend import worker
    for name, functions in {'worker': ('process_one', 'finalize'), 'economy': ('accept_verified', 'previous_bests'),
                            'rivalry': ('accept_verified',), 'challenges': ('accept_verified',),
                            'achievements': ('capture_race',)}.items():
        target = __import__('bmt_backend.' + name, fromlist=[name])
        spec = importlib.util.spec_from_file_location('bmt_backend.sql_probe_original_' + name, HERE / 'before' / (name + '.py'))
        original = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(original)
        for function in functions:
            setattr(target, function, getattr(original, function))
    return worker


def benchmark(args):
    from bmt_backend import worker
    if args.original:
        worker = original_functions()
    data = json.loads((HERE / 'native-fixture.json').read_text())
    url = None
    admin = engine = None
    schema = 'test_race_sql_' + new_id().replace('-', '')
    if args.postgres:
        raw = next(line.split('=', 1)[1].strip() for line in Path('/task/db.env').read_text().splitlines()
                   if line.startswith('BMT_TEST_DATABASE_URL='))
        url = make_url(raw).set(host='127.0.0.1', port=5432)
        os.environ['BMT_TEST_DATABASE_URL'] = url.render_as_string(hide_password=False)
        admin = create_engine(url, hide_parameters=True)
        with admin.begin() as db:
            db.exec_driver_sql('CREATE SCHEMA ' + schema)
        engine = create_engine(url, hide_parameters=True, connect_args={'options': '-c search_path=' + schema,
            'connect_timeout': 5}, pool_size=4, max_overflow=0)
    logging.getLogger('bmt').setLevel(logging.ERROR)
    with tempfile.TemporaryDirectory(prefix='bmt-race-sql-') as folder:
        settings = Settings(environment='test', database_url=url.render_as_string(hide_password=False) if url else 'sqlite://',
            object_dir=folder)
        verifier = GodotVerifier(settings)
        verifier._versions = data['active']

        def forbidden(*_args, **_kwargs):
            raise AssertionError('Measured verification attempted native engine IO')

        verifier._invoke = forbidden
        app = create_app(settings, verifier=verifier, engine=engine)
        logging.getLogger('bmt').setLevel(logging.ERROR)
        try:
            upgrade(app.state.engine)
            document_hash = app.state.blobs.put_json(data['document'])
            replay_hash = app.state.blobs.put_json(data['replay'])
            with app.state.session_factory() as db:
                player = Player(display_name='Owned SQL performance fixture')
                db.add(player); db.flush()
                track = Track(owner_id=player.id)
                db.add(track); db.flush()
                version = TrackVersion(track_id=track.id, number=1, name='SQL fixture', content_hash=document_hash,
                    manifest=data['geometry']['manifest'], state='published', published_at=now())
                db.add(version); db.flush()
                pinned = board_manifest(version, 'compact')
                board = Board(id=digest({'version_id': version.id, **pinned}), version_id=version.id,
                    vehicle_id='compact', manifest=pinned)
                db.add(board)
                db.add(OperationState(id='geom:' + document_hash, updated_at=now(), details=data['geometry']))
                db.commit()
                player_id, board_id = player.id, board.id
            queries = []
            stages = {}
            actual_finalize = worker.process_one.__globals__['finalize']
            actual_verify = verifier.verify_run

            def finalization(*positional, **named):
                started, count = time.perf_counter_ns(), len(queries)
                try:
                    return actual_finalize(*positional, **named)
                finally:
                    stages['finalization_ms'] = (time.perf_counter_ns() - started) / 1e6
                    stages['finalization_sql'] = len(queries) - count

            def verification(*positional, **named):
                started = time.perf_counter_ns()
                try:
                    return actual_verify(*positional, **named)
                finally:
                    stages['checker_ms'] = (time.perf_counter_ns() - started) / 1e6

            worker.process_one.__globals__['finalize'] = finalization
            verifier.verify_run = verification

            def statement(_conn, _cursor, query, *_args):
                queries.append(query)
                if args.roundtrip_ms:
                    time.sleep(args.roundtrip_ms / 1000)

            event.listen(app.state.engine, 'before_cursor_execute', statement)
            samples = []
            try:
                for index in range(args.iterations + 2):
                    with app.state.session_factory() as db:
                        ticket = RunTicket(player_id=player_id, board_id=board_id, expires_at=now() + 3600)
                        db.add(ticket); db.flush()
                        run = Run(player_id=player_id, board_id=board_id, ticket_id=ticket.id, replay_hash=replay_hash)
                        db.add(run); db.commit()
                        run_id = run.id
                    queries.clear(); stages.clear()
                    started = time.perf_counter_ns()
                    assert worker.process_one(app)
                    elapsed = (time.perf_counter_ns() - started) / 1e6
                    captured = list(queries)
                    with app.state.session_factory() as db:
                        run = db.get(Run, run_id)
                        reward = db.get(CoinReward, run_id)
                        wallet = db.get(CoinWallet, player_id)
                        assert run.status == 'verified', (run.status, run.failure_code)
                        assert (run.time_ticks, run.lap_ticks) == (12757, [2634, 2532, 2531, 2530, 2530])
                        assert reward.amount == (100 if index == 0 else 50)
                        assert wallet.balance == 100 + index * 50
                    if index >= 2:
                        samples.append({'worker_ms': elapsed, 'sql_statements': len(captured), **stages})
                report = {'label': args.label, 'postgres': args.postgres, 'original': args.original,
                    'iterations': args.iterations, 'injected_roundtrip_ms': args.roundtrip_ms,
                    'medians': {key: statistics.median(sample[key] for sample in samples) for key in samples[0]},
                    'samples': samples, 'representative_queries': captured,
                    'asserted': 'Exact native-proof ticks/laps; one reward per race; exact cumulative wallet; no native IO',
                    'scope': 'Warmed worker claim through atomic finalization; isolated schema/local objects; excludes upload/HTTP/cloud IO'}
                (HERE / (args.label + '.json')).write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
                print(json.dumps(report['medians']))
            finally:
                event.remove(app.state.engine, 'before_cursor_execute', statement)
        finally:
            verifier.close()
            app.state.engine.dispose()
            if admin:
                with admin.begin() as db:
                    db.exec_driver_sql('DROP SCHEMA ' + schema + ' CASCADE')
                admin.dispose()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--seed', action='store_true')
    parser.add_argument('--postgres', action='store_true')
    parser.add_argument('--original', action='store_true')
    parser.add_argument('--label', default='baseline')
    parser.add_argument('--iterations', type=int, default=40)
    parser.add_argument('--roundtrip-ms', type=float, default=0)
    options = parser.parse_args()
    seed() if options.seed else benchmark(options)
