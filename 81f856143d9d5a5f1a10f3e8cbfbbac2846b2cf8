"""A deploy can add a matching build without changing an existing day's targets."""
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from types import SimpleNamespace

import pytest
from test_daily_standings import auth, auth_app, feature, finish  # noqa: F401
from test_daily_standings import daily as daily_fixture

from bmt_backend import daily_fixed_limits, daily_standings, track_of_day
from bmt_backend.discovery_models import TrackOfDay
from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.track_models import TrackVersion

daily = daily_fixture


def new_version(db, old, *, extra_car=False):
    manifest = deepcopy(old.manifest)
    manifest['physics_version'] = 'test-new-build'
    if extra_car:
        manifest['vehicles']['hovercraft'] = {'handling_version':'test-hover','config_hash':'hover-test'}
    version = TrackVersion(track_id=old.track_id, number=2, name=old.name,
        content_hash=old.content_hash, manifest=manifest, discovery=old.discovery,
        state='published', published_at=old.published_at)
    db.add(version); db.flush()
    return version


def test_variant_preserves_original_limits_and_daily_results(daily, monkeypatch):
    d = daily
    feature(d)
    finish(d, 120, 'Alice')
    assert track_of_day.step(d.factory, clock=d.day*86400+10)
    old_params = {'day':d.day, 'version_id':d.version.id, 'vehicle_id':'compact'}
    old_limits = d.client.get('/v1/track-of-the-day/limits', params=old_params).json()
    old_standings = d.client.get('/v1/track-of-the-day/standings', params=old_params).json()
    with d.factory() as db:
        old = db.get(TrackVersion,d.version.id)
        version = new_version(db,old)
        variant_id = version.id
        monkeypatch.setattr(daily_fixed_limits,'lap_population',
            lambda *args: HistogramPopulation.from_rows([('test', 99)]))
        assert daily_fixed_limits.publish_build_variant(db,d.day,version,version.manifest,d.day*86400+20)
        db.commit()
    new_params = {**old_params,'version_id':variant_id}
    assert d.client.get('/v1/track-of-the-day').json()['track']['version_id'] == variant_id
    new_limits = d.client.get('/v1/track-of-the-day/limits', params=new_params).json()
    assert all(c['lap_ticks']==99 for c in new_limits['cutoffs'])
    old_again = d.client.get('/v1/track-of-the-day/limits', params=old_params).json()
    assert all(old_again[k] == old_limits[k] for k in ('cutoffs','generation','limits_set_at','manifest'))
    assert d.client.get('/v1/track-of-the-day/standings', params=old_params).json()['items'] == old_standings['items']
    assert d.client.get('/v1/track-of-the-day/standings', params=new_params).json()['population'] == 0
    with d.factory() as db:
        variant = db.get(TrackVersion,variant_id)
        assert not daily_fixed_limits.publish_build_variant(db,d.day,variant,variant.manifest,d.day*86400+50)
        chosen = db.get(TrackOfDay,d.day)
        assert chosen.version_id == d.version.id
        assert chosen.lap_limits['build_variant']['limits']['set_at'] == d.day*86400+20
        ticket = SimpleNamespace(created_at=d.day*86400+30, player_id=d.identities['Alice']['player']['id'])
        board = SimpleNamespace(version_id=variant_id, manifest={'laps':5})
        assert daily_standings.eligible_day(db,ticket,board,d.day*86400+31) == d.day
        board.version_id = d.version.id
        assert daily_standings.eligible_day(db,ticket,board,d.day*86400+31) == d.day


def test_variant_waits_for_every_car_and_rejects_changed_geometry(daily, monkeypatch):
    d=daily
    feature(d)
    assert track_of_day.step(d.factory,clock=d.day*86400+10)
    with d.factory() as db:
        original=db.get(TrackVersion,d.version.id)
        variant=new_version(db,original,extra_car=True)
        monkeypatch.setattr(daily_fixed_limits,'lap_population',
            lambda session, version, vehicle, manifest, artificial: HistogramPopulation.from_rows(
                [('one', 100)] if vehicle=='compact' else []))
        with pytest.raises(daily_fixed_limits.LimitsPending):
            daily_fixed_limits.publish_build_variant(db,d.day,variant,variant.manifest,d.day*86400+20)
        assert 'build_variant' not in db.get(TrackOfDay,d.day).lap_limits
        variant.content_hash = 'different'
        with pytest.raises(ValueError):
            daily_fixed_limits.publish_build_variant(db,d.day,variant,variant.manifest,d.day*86400+20)


def test_concurrent_variant_publication_selects_once(daily, monkeypatch):
    d=daily
    if d.app.state.engine.dialect.name != 'postgresql':
        pytest.skip('PostgreSQL row locking is required for this concurrency check')
    feature(d)
    assert track_of_day.step(d.factory,clock=d.day*86400+10)
    with d.factory() as db:
        version=new_version(db,db.get(TrackVersion,d.version.id)); variant_id=version.id; db.commit()
    computations=[]
    def population(*args):
        computations.append(args[2])
        return HistogramPopulation.from_rows([('one',100)])
    monkeypatch.setattr(daily_fixed_limits,'lap_population',population)
    def publish(_):
        with d.factory() as db:
            variant=db.get(TrackVersion,variant_id)
            result=daily_fixed_limits.publish_build_variant(db,d.day,variant,variant.manifest,d.day*86400+20)
            db.commit()
            return result
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(publish,range(2)))
    assert sorted(results)==[False,True] and computations==['compact']
