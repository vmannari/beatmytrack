from dataclasses import replace

import pytest
from test_product_analytics import AT, observed, product, send  # noqa: F401

from bmt_backend import shader_profiles, telemetry


def sample():
    return {"schema_version":1, "context":"a"*64, "biome":"pine", "renderer":"gl_compatibility",
            "car":"compact", "simple":False,
            "graphics":{"shadow_quality":"auto","render_resolution":"auto","anti_aliasing":"auto"},
            "status":"matched", "observed":100, "missing":1, "dropped":0, "late_compile_us":1200,
            "misses":[{"key":"b"*64, "shader":"c"*64, "variant":1, "specialization":"0000000000000000",
                       "reason":"unlisted", "phase":"driving", "compile_phase":"driving", "compile_us":1200}]}


def test_valid_event_through_ingestion_properties():
    assert telemetry.properties("shader_profile", sample()) == sample()


@pytest.mark.parametrize("field,value", [("context","bad"),("biome",[]),("renderer","mobile"),
    ("status","approved"),("observed",True),("missing",101),("late_compile_us",-1),
    ("dropped",1000001),("schema_version",True),("misses",None)])
def test_invalid_envelope(field,value):
    data=sample();data[field]=value
    with pytest.raises(ValueError): shader_profiles.validate(data)


@pytest.mark.parametrize("field,value", [("key","raw-source"),("phase","menu"),
    ("compile_phase",[]),("compile_us",60000001),("compile_us",True)])
def test_invalid_miss(field,value):
    data=sample();data["misses"][0][field]=value
    with pytest.raises(ValueError): shader_profiles.validate(data)


def test_no_extra_data_or_duplicate_details():
    data=sample();data["serial"]="forbidden"
    with pytest.raises(ValueError): shader_profiles.validate(data)
    data=sample();data["missing"]=2;data["misses"]*=2
    with pytest.raises(ValueError): shader_profiles.validate(data)
    data=sample();data["misses"][0]["source"]="forbidden"
    with pytest.raises(ValueError): shader_profiles.validate(data)


def test_ingestion_gate_and_idempotency(product):  # noqa: F811
    app, client, _auth, _player = product
    event = observed("shader_profile", properties=sample())
    assert send(product, [event]).json()["events"][0]["status"] == "rejected"
    app.state.settings = replace(app.state.settings, client_quality_enabled=True)
    event = observed("shader_profile", properties=sample())
    assert send(product, [event]).json()["events"][0]["status"] == "accepted"
    assert send(product, [event]).json()["events"][0]["status"] == "duplicate"
    assert client.get('/v1/admin/shader-profiles').status_code == 401
    headers = {"Authorization": "Bearer " + "a" * 40}
    query = f'/v1/admin/shader-profiles?since={AT-3600}&until={AT+1}'
    response = client.get(query, headers=headers)
    assert response.status_code == 200
    assert len(response.json()['items']) == 1
    assert response.json()['items'][0]['missing'] == 1
    assert 'player_id' not in response.json()['items'][0]
    assert client.get(query+'&limit=501', headers=headers).status_code == 422
    assert client.get(query+'&biome=winter', headers=headers).json()['items'] == []


def test_index_migration_preserves_receipts():
    import importlib

    import sqlalchemy as sa
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    migration = importlib.import_module('bmt_backend.migrations.versions.0074_shader_profile_receipts')
    engine = sa.create_engine('sqlite://')
    with engine.connect() as connection:
        connection.execute(sa.text('CREATE TABLE product_events (id TEXT, source TEXT, name TEXT, occurred_at INTEGER)'))
        connection.execute(sa.text("INSERT INTO product_events VALUES ('retained','client','race_finished',1)"))
        connection.commit()
        previous = migration.op
        migration.op = Operations(MigrationContext.configure(connection))
        try:
            migration.upgrade()
            assert sa.inspect(connection).get_indexes('product_events')[0]['name'] == 'ix_product_shader_profiles'
            assert connection.scalar(sa.text('SELECT count(*) FROM product_events')) == 1
            connection.commit()
            migration.downgrade()
            assert not sa.inspect(connection).get_indexes('product_events')
            assert connection.scalar(sa.text('SELECT id FROM product_events')) == 'retained'
        finally:
            migration.op = previous
    engine.dispose()
