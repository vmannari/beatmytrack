"""One-time, explicitly scoped rejection cleanup with byte-exact archive guards."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
ARCHIVE = OUT/'rejected-candidate'


def digest(data): return hashlib.sha256(data).hexdigest()


def main():
    recorded = json.loads((OUT/'final-sources.json').read_text())
    restore = ['game/ui/rivalry_victory_car.gd','game/ui/weekly_rivalry_page.gd']
    remove = ['game/ui/rivalry_cached_podium.gd','game/ui/rivalry_podium_pictures.gd',
              'game/tests/profile_podium_loading_half.gd',
              'game/tests/test_rivalry_podium_pictures.gd',
              'game/tests/test_rivalry_podium_picture_storage.gd',
              'game/tests/test_loading_half_rivalry_live.gd',
              'game/tests/test_loading_half_rivalry_ready.gd']
    retain = ['game/ui/player_profile.gd']
    assert set(recorded) == set(restore+remove+retain)
    assert not ARCHIVE.exists(), 'Archive must not overwrite an earlier receipt'
    candidate = {name:(ROOT/name).read_bytes() for name in recorded}
    assert all(digest(data)==recorded[name] for name,data in candidate.items()), 'Concurrent source changes: abort before mutation'
    before = {name:(OUT/'before'/name).read_bytes() for name in restore}
    fixture = ROOT/'game/tests/profile_loading_half.gd'
    fixture_hash = digest(fixture.read_bytes())
    rows = []
    # Complete and verify the archive before restoring or removing any source.
    for name,data in candidate.items():
        target = ARCHIVE/name
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)
        assert target.read_bytes() == data
    for name in restore:
        assert (ROOT/name).read_bytes()==candidate[name]
        (ROOT/name).write_bytes(before[name])
        assert (ROOT/name).read_bytes()==before[name]
        rows.append({'path':name,'action':'restored_before_bytes','candidate_sha256':recorded[name],'final_sha256':digest(before[name])})
    for name in remove:
        target = (ROOT/name).resolve()
        assert target.is_relative_to((ROOT/'game').resolve()) and target.read_bytes()==candidate[name]
        target.unlink()
        assert not target.exists()
        rows.append({'path':name,'action':'archived_then_removed','candidate_sha256':recorded[name]})
    for name in retain:
        assert (ROOT/name).read_bytes()==candidate[name]
        rows.append({'path':name,'action':'retained_independent_lazy_dependency','final_sha256':recorded[name]})
    assert digest(fixture.read_bytes())==fixture_hash
    receipt = {'utc':datetime.now(timezone.utc).isoformat(),'authorization':'Root task: archive and remove shipping podium candidate; retain player_profile lazy load and profile_loading_half fixture.',
               'archive':str(ARCHIVE),'candidate_hashes_verified':10,'byte_exact_archive_files':10,
               'actions':rows,'retained_profile_loading_half_sha256':fixture_hash,
               'main_index_written':False,'runtime_or_timing_tests_run':False}
    (OUT/'rejected-candidate-cleanup.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))


if __name__ == '__main__': main()
