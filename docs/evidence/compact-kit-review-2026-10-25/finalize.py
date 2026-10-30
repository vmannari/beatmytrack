"""Record observed review outcomes and make an isolated, additions-only checkpoint."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
CHECKPOINT = REPO / 'build/compact-kit-review/checkpoint-repo'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(args, cwd=REPO):
    result = subprocess.run(['git', *args], cwd=cwd, capture_output=True, check=True)
    return result.stdout.decode('utf-8', errors='replace')


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    expected = {
        'construction-gl_compatibility': ('COMPACT_KIT_CONSTRUCTION', 1354, 0),
        'geometry-gl_compatibility': ('KIT_GEOMETRY', 5223, 0),
        'catalog-gl_compatibility': ('EXPANDED_COMPACT_CATALOG', 1543, 0),
        'aero-gl_compatibility': ('COMPACT_AERO_VARIETY', 836, 0),
        'incremental-gl_compatibility': ('INCREMENTAL_COMPACT_KITS', 346, 0),
        'focus-gl_compatibility': ('CUSTOMISATION_CAROUSEL', 475, 0),
        'workflow-gl_compatibility': ('COMPACT_KITS', 547, 47),
        'parser-gl_compatibility': ('SCRIPT_PARSE', 1200, 0),
    }
    checks = {}
    for job, (marker, count, failures) in expected.items():
        log = (ROOT / f'{job}.log').read_text(encoding='utf-8-sig')
        pattern = re.escape(marker) + rf': {count} (?:checks|scripts), {failures} failures'
        assert re.search(pattern, log), job
        command = read_json(ROOT / f'{job}-command.json')
        assert command['exit_code'] == (1 if failures else 0), job
        checks[job] = {'checks': count, 'failures': failures, 'command': command}
    for job in ('capture-gl_compatibility', 'capture-mobile', 'diagnostic-gl_compatibility', 'diagnostic-mobile'):
        command = read_json(ROOT / f'{job}-command.json')
        assert command['exit_code'] == 0
        checks[job] = {'command': command, 'png_count': len(list((ROOT / job).rglob('*.png')))}
    measurements = read_json(ROOT / 'diagnostic-gl_compatibility/measurements.json')
    assert measurements == read_json(ROOT / 'diagnostic-mobile/measurements.json')
    assert checks['capture-gl_compatibility']['png_count'] == checks['capture-mobile']['png_count'] == 139
    assert checks['diagnostic-gl_compatibility']['png_count'] == checks['diagnostic-mobile']['png_count'] == 12

    # Pin the source inspected by the review, including unchanged old regressions.
    sources = set((REPO / 'game/vehicle').glob('compact_*.gd'))
    for relative in (
        'game/vehicle/car_visual.gd', 'game/vehicle/vehicle_customisation.gd',
        'game/vehicle/racing_car_models.gd', 'game/vehicle/prepared_car_cache.gd',
        'game/vehicle/vehicle_simulation.gd', 'game/vehicle/handling_config.gd',
        'game/ui/car_showroom.gd', 'game/ui/garage_page.gd',
        'game/ui/garage_customisation_camera.gd', 'game/ui/compact_kit_thumbnail.gd',
        'game/resources/compact_fun.tres', 'game/tests/capture_compact_kit_review.gd',
        'game/tests/review_compact_kits.gd', 'game/tests/test_compact_kit_construction.gd',
        'game/tests/test_compact_kit_geometry.gd', 'game/tests/test_expanded_compact_catalog.gd',
        'game/tests/test_compact_aero_variety.gd', 'game/tests/test_incremental_compact_kits.gd',
        'game/tests/test_compact_kits.gd', 'game/tests/test_customisation_carousel.gd',
    ):
        sources.add(REPO / relative)
    source_hashes = {}
    concurrent_changes = []
    for source in sorted(sources):
        relative = source.relative_to(REPO)
        target = ROOT / 'reviewed-source' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            if digest(target) != digest(source):
                # Preserve unrelated ongoing propulsion work, and retain the
                # exact context snapshot rather than silently replacing it.
                assert relative.as_posix() == 'game/vehicle/vehicle_simulation.gd', f'Review source changed: {relative}'
                concurrent_changes.append({'path':relative.as_posix(),'review_snapshot_sha256':digest(target),'current_sha256':digest(source),'disposition':'Concurrent rear-drive launch-slip steering fade; unrelated to prepared kit joins. No claim that physics regressions cover this later edit.'})
        else:
            shutil.copyfile(source, target)
        source_hashes[relative.as_posix()] = digest(target)
    assets = set()
    for folder in ('game/assets/vehicles/compact_kits_v1', 'game/assets/vehicles/compact_coachwork_v3', 'game/assets/vehicles/racing_simple_v1/compact'):
        assets.update(p for p in (REPO / folder).rglob('*') if p.is_file())
    asset_hashes = {p.relative_to(REPO).as_posix(): digest(p) for p in sorted(assets)}
    (ROOT / 'reviewed-source-hashes.json').write_text(json.dumps(source_hashes, indent=2) + '\n', encoding='utf-8')
    (ROOT / 'reviewed-asset-hashes.json').write_text(json.dumps(asset_hashes, indent=2) + '\n', encoding='utf-8')

    added = [
        'game/tests/review_compact_kits.gd',
        'game/tests/review_compact_kits.gd.uid',
        'docs/COMPACT_KIT_REVIEW_2026_10_25.md',
        *[f'docs/evidence/compact-kit-review-2026-10-25/{name}' for name in ('run.ps1','make_sheets.ps1','review_tools.py','finalize.py')],
    ]
    CHECKPOINT.mkdir(parents=True, exist_ok=True)
    if not (CHECKPOINT / '.git').exists():
        git(['init', '--initial-branch=compact-kit-review'], CHECKPOINT)
        git(['config', 'user.name', 'Codex'], CHECKPOINT)
        git(['config', 'user.email', 'codex@local.invalid'], CHECKPOINT)
        git(['config', 'core.autocrlf', 'false'], CHECKPOINT)
    for relative in added:
        destination = CHECKPOINT / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO / relative, destination)
    git(['add', '--', *added], CHECKPOINT)
    has_commit = subprocess.run(['git', 'rev-parse', '--verify', 'HEAD'], cwd=CHECKPOINT, capture_output=True).returncode == 0
    staged = subprocess.run(['git', 'diff', '--cached', '--quiet'], cwd=CHECKPOINT).returncode
    if not has_commit:
        git(['commit', '-m', 'Review compact custom-kit construction and retain native evidence'], CHECKPOINT)
    elif staged:
        git(['commit', '--amend', '--no-edit'], CHECKPOINT)
    commit = git(['rev-parse', 'HEAD'], CHECKPOINT).strip()
    validation = git(['show', '--check', '--oneline', 'HEAD'], CHECKPOINT)
    patch = git(['show', '--binary', '--format=', 'HEAD'], CHECKPOINT)
    (ROOT / 'task-only.patch').write_text(patch, encoding='utf-8', newline='\n')
    reverse = git(['apply', '--reverse', '--check', str(ROOT / 'task-only.patch')])
    (ROOT / 'checkpoint-validation.txt').write_text(validation + reverse, encoding='utf-8')

    report = {
        'date': '2026-10-25',
        'scope': 'Read-only review of all 43 compact custom-kit options; production geometry and old assertions unchanged.',
        'requirements': {'CKR01': 'Roof-lip attachment', 'CKR02': 'Arch-extension attachment', 'CKR03': 'Simplified crown insert clearance', 'R01': 'Retained checks and actual failures', 'G01': 'Native evidence and isolated additions-only checkpoint', 'Q01': 'Review only; correction pending'},
        'findings': [
            {'id':'CKR01','priority':'P2','title':'Roof lip floats above the roof without mounts','source':'game/vehicle/compact_kits.gd:186','evidence':'diagnostic-gl_compatibility/roof-lip-side.png'},
            {'id':'CKR02','priority':'P2','title':'Arch extension returns remain detached from stock panels','options':['rally','club','heritage','wide','endurance','gravel'],'source':'game/vehicle/compact_body_kits.gd:58','evidence':'diagnostic-gl_compatibility/wide-arch.png'},
            {'id':'CKR03','priority':'P2','title':'Simplified Power dome and Vented dome accent patches intersect the hood','source':'game/vehicle/compact_hood_kits.gd:34','evidence':'diagnostic-mobile/simple-combined-insert.png'},
        ],
        'checks': checks,
        'measurements': measurements,
        'renderer_measurements_identical': True,
        'catalog': read_json(ROOT / 'catalog-gl_compatibility/catalog.json'),
        'measurement_limits': ['Unscaled model metres; sampled vertical/lateral clearances, not continuous minimum Euclidean distances.', 'Arch numbers cover positive side at Y>=0.385; absent stock ray hits are excluded and counted.', 'Detailed insert clearances are positive; the confirmed insert intersections concern simplified meshes.', 'Successful diagnostic exit means execution, not absence of findings.'],
        'legacy_workflow_failures': {'total':47,'pre_category_camera_equalities':46,'bounds_of_hidden_actions':1,'status':'Preserved; current parts-focus behavior is separately validated. No existing assertion changed.'},
        'unsuccessful_attempts': [
            'Initial sandbox construction run failed certificate-store access. Its uncorrected wrapper falsely recorded exit zero; log is retained and that result is invalid.',
            'Initial and second arch diagnostics selected only left stock nodes through repeated labels. Their approximately 1.77 metre gaps are invalid; final measurements select mesh identities.',
            'Pillow imports failed in the first Python contact-sheet helper and Python39 probe. No packages installed; final sheets use Windows System.Drawing.',
        ],
        'engine': (REPO / 'godot-version.txt').read_text().strip(),
        'source_hashes': 'reviewed-source-hashes.json',
        'concurrent_source_changes': concurrent_changes,
        'asset_hashes': 'reviewed-asset-hashes.json',
        'checkpoint': {'path':CHECKPOINT.relative_to(REPO).as_posix(),'commit':commit,'files':added,'patch':'task-only.patch','show_check':'passed','reverse_apply_check':'passed','shared_index_modified_by_checkpoint':False},
        'device_test_performed': False,
        'device_attachment_checked': False,
        'apk_or_deployment_performed': False,
        'production_model_fixes_performed': False,
        'remaining_acceptance': ['Correct the three model findings in separate authorized work.', 'Owner/device visual, motion and cost acceptance.'],
    }
    evidence = [p for p in ROOT.rglob('*') if p.is_file() and p.name != 'report.json' and 'reviewed-source' not in p.parts]
    report['evidence_sha256'] = {p.relative_to(ROOT).as_posix():digest(p) for p in sorted(evidence)}
    (ROOT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'findings':len(report['findings']),'native_review_views':302,'sources_pinned':len(source_hashes),'asset_files_pinned':len(asset_hashes),'checkpoint':commit,'legacy_ui_failures':47}))


if __name__ == '__main__':
    main()
