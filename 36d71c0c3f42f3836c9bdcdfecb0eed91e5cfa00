"""Native resource lifecycle and local-generation recovery on synthetic input."""
import json
import os
import time
from pathlib import Path
from types import SimpleNamespace

import pytest

from bmt_backend.test_driver_generator import generate
from bmt_backend.verifier import GodotVerifier

pytestmark = pytest.mark.godot


@pytest.fixture
def native(tmp_path):
    fixture = Path(os.environ.get('BMT_ACCEPTANCE_FIXTURE', '/opt/bmt/acceptance/verified_oval.json'))
    binary = os.environ.get('BMT_GODOT_BIN')
    project = os.environ.get('BMT_GAME_PROJECT')
    if not fixture.is_file() or not binary or not project:
        pytest.skip('Run with the exact image and its bundled synthetic acceptance fixture')
    settings = SimpleNamespace(godot_bin=binary, game_project=project, verifier_timeout_seconds=90,
        persistent_verifier=True, verifier_idle_seconds=1, object_dir=str(tmp_path/'cache'/'objects'))
    return settings, json.loads(fixture.read_text())['document']


def test_native_engine_restarts_after_idle_with_exact_contract_and_validation(native):
    settings, document = native
    verifier = GodotVerifier(settings)
    try:
        manifest = verifier.manifest()
        validated = verifier.validate_track(document)
        first = verifier._service
        assert first is not None and first.poll() is None
        assert not verifier.retire_idle()
        verifier._last_engine_use = time.monotonic()-2
        assert verifier.retire_idle() and first.poll() is not None
        assert verifier.manifest() == manifest and verifier._service is None
        assert verifier.validate_track(document) == validated
        assert verifier._service is not first and verifier._service.poll() is None
    finally:
        verifier.close()


def test_native_prepared_checkpoint_survives_interrupted_drive_and_reuses_exact_inputs(native):
    settings, document = native
    traits = {'version':'test-driver-1','seed':1,'skill':.5,'consistency':1.,'aggression':.5,'learning':.5,'strengths':{}}
    class InterruptAfterPlanning:
        def is_set(self):
            return any((Path(settings.object_dir).parent/'driver-trajectories').glob('*.json'))
    with pytest.raises(RuntimeError, match='stopped'):
        generate(settings, document, 'compact', traits, stop_event=InterruptAfterPlanning())
    warm = generate(settings, document, 'compact', traits)
    assert warm['diagnostics']['cache_hit']
    cache = next((Path(settings.object_dir).parent/'driver-trajectories').glob('*.json'))
    cache.unlink()
    cold = generate(settings, document, 'compact', traits)
    assert not cold['diagnostics']['cache_hit']
    assert warm['replay'] == cold['replay'] and warm['time_ticks'] == cold['time_ticks']
    verifier = GodotVerifier(settings)
    try:
        result = verifier.verify_run(document, warm['replay'], 'compact')
        assert result['time_ticks'] == warm['time_ticks'] and len(result['lap_ticks']) == 5
    finally:
        verifier.close()


def test_native_local_batch_uses_normal_http_upload_and_independent_worker_verification(native,tmp_path):
    from fastapi.testclient import TestClient
    from test_backend_resource_optimisation import HEADERS, KEY, LocalAPI

    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.local_artificial_races import run_pass
    from bmt_backend.migrate import upgrade
    from bmt_backend.official_tracks import seed_documents
    from bmt_backend.worker import process_one
    engine,document=native
    settings=Settings(environment='development',dev_auth_enabled=True,dev_auth_key=KEY,test_drivers_enabled=True,
        database_url='sqlite:///'+(tmp_path/'native.sqlite').as_posix(),object_dir=str(tmp_path/'objects'),
        godot_bin=engine.godot_bin,game_project=engine.game_project,persistent_verifier=True,
        auth_limit_per_minute=1000,write_limit_per_minute=1000)
    app=create_app(settings);upgrade(app.state.engine)
    try:
        with TestClient(app) as client:
            client.post('/v1/auth/developer',headers=HEADERS).raise_for_status()
            seed_documents(app.state.session_factory,app.state.blobs,app.state.verifier,[document])
            preview=client.get('/v1/dev/test-drivers/batches/preview',headers=HEADERS).json()
            response=client.post('/v1/dev/test-drivers/batches',headers=HEADERS,json={'seed':41,'count':1,
                'vehicle_id':'compact','clear_test_records':False,'inventory_digest':preview['inventory_digest']})
            assert response.status_code==200,response.text
            batch=response.json()['batch_id'];api=LocalAPI(SimpleNamespace(app=app,client=client))
            result=run_pass(api,settings,tmp_path/'local'/'state.json',batch)
            assert result['results']==['submitted'] and api.uploads==1
            assert process_one(app)
            view=client.get('/v1/dev/test-drivers/batches/'+batch,headers=HEADERS).json()
            assert view['complete'] and view['jobs']=={'verified':1}
            assert client.get('/v1/track-versions/'+preview['tracks'][0]['version_id']+'/leaderboard?vehicle_id=compact').json()['population']==0
    finally:
        app.state.verifier.close();app.state.engine.dispose()
