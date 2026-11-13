"""Matched original/fixed Profile component probes against fully migrated SQLite."""
import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'backend'))
from bmt_backend.migrate import upgrade
from bmt_backend.tracks import my_tracks
from sqlalchemy import create_engine

source = OUT.parent / 'backend-performance-cost-review-2026-11-06/request/probe_requests.py'
spec = importlib.util.spec_from_file_location('profile_component_probe', source)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def make():
    engine = create_engine('sqlite:///:memory:')
    upgrade(engine)
    return engine


snapshot = OUT / 'before/backend__bmt_backend__tracks.py'
before_spec = importlib.util.spec_from_file_location('bmt_backend._profile_before', snapshot)
before = importlib.util.module_from_spec(before_spec)
before_spec.loader.exec_module(before)
probe.make = make
results = {'scope': 'Matched local component probes, fully migrated SQLite; not production latency'}
for name, implementation in (('before', before.my_tracks), ('fixed', my_tracks)):
    probe.my_tracks = implementation
    results[name] = [probe.own_tracks(size) for size in (0, 50000)]
(OUT / 'profile-comparison.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
print(json.dumps({name: [{'unrelated': row['unrelated_tracks'], 'median_ms': row['median_ms'],
                         'sql_count': row['sql_count_including_one_auth_player_get'],
                         'track_gets': row['track_gets']} for row in rows]
                  for name, rows in results.items() if isinstance(rows, list)}))
