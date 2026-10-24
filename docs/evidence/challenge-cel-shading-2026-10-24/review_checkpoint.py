"""Record this artwork-only change against its captured working-tree baseline."""
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(*args, cwd=None, codes=(0,)):
    result = subprocess.run(args, cwd=cwd, capture_output=True)
    if result.returncode not in codes:
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace'))
    return result.stdout


manifest_path = ROOT/'game/assets/menu/challenges/cel-shading-v3.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
base_files = ['game/ui/challenge_create.gd', 'game/ui/challenges_page.gd',
              'docs/CHALLENGE_PAGE.md', 'licenses/ASSETS.md']
files = base_files + ['game/assets/menu/challenges/cel-shading-v3.json']
for asset in manifest['assets']:
    files.extend([asset['path'], asset['path']+'.import'])
    assert sha(ROOT/asset['path']) == asset['sha256']
    assert sha(ROOT/asset['source']) == asset['source_sha256']
    assert sha(Path(asset['provider_output'])) == asset['sha256']
    settings = (ROOT/(asset['path']+'.import')).read_text(encoding='utf-8')
    assert all(s in settings for s in ('mipmaps/generate=true',
               'process/size_limit=1024', 'compress/mode=0'))

for path in base_files[:2]:
    before = (EVIDENCE/'task-base'/path).read_bytes()
    after = (ROOT/path).read_bytes()
    expected = before
    for asset in manifest['assets']:
        old = Path(asset['source']).stem.encode()
        new = Path(asset['path']).stem.encode()
        expected = expected.replace(old, new)
    assert after == expected, f'Unexpected runtime change in {path}'

results = []
for test in ('test_challenge_cards', 'test_challenge_entry'):
    for mode in ('headless', 'gl_compatibility', 'mobile'):
        log = EVIDENCE/f'{test}-{mode}.log'
        text = log.read_text(encoding='utf-8', errors='replace')
        matches = re.findall(r'CHALLENGE(?:_CARDS| ENTRY): (\d+) checks, (\d+) failures', text)
        assert len(matches) == 1, f'Missing result: {log}'
        count, failures = map(int, matches[0])
        assert failures == 0, f'Failed assertions: {log}'
        errors = [line for line in text.splitlines() if re.search(r'ERROR:|FAIL:', line)]
        assert all('Failed to read the root certificate store.' in line for line in errors), errors
        results.append({'test': test, 'mode': mode, 'checks': count, 'failures': failures,
                        'log': log.name, 'command': 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File '
                        'docs/evidence/challenge-cel-shading-2026-10-24/run_validation.ps1 '
                        f'-Test {test} -Mode {mode}'})

for path in files:
    destination = EVIDENCE/'task-final'/path
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT/path, destination)
patch = run('git', '-c', 'core.autocrlf=false', 'diff', '--no-index', '--binary', '--src-prefix=a/', '--dst-prefix=b/',
            'task-base', 'task-final', cwd=EVIDENCE, codes=(1,))
for prefix in (b'a/task-base/', b'a/task-final/', b'b/task-base/', b'b/task-final/'):
    patch = patch.replace(prefix, prefix[:2])
patch_path = EVIDENCE/'checkpoint.patch'
patch_path.write_bytes(patch)
verify = ROOT/'build/challenge-cel-shading-2026-10-24/checkpoint-verify'
attempt = 1
while verify.exists():
    attempt += 1
    verify = ROOT/f'build/challenge-cel-shading-2026-10-24/checkpoint-verify-{attempt}'
shutil.copytree(EVIDENCE/'task-base', verify)
run('git', 'init', '-q', cwd=verify)
run('git', 'config', 'core.autocrlf', 'false', cwd=verify)
run('git', 'apply', '--check', str(patch_path), cwd=verify)
run('git', 'apply', str(patch_path), cwd=verify)
for path in files:
    assert sha(verify/path) == sha(ROOT/path), path

captures = {str(p.relative_to(EVIDENCE)).replace('\\', '/'): sha(p)
            for p in sorted(EVIDENCE.glob('Windows-*/*.png'))}
report = {
    'date': '2026-10-24',
    'requirements': {
        'CCS01': 'Retain the accepted composition of all five challenge menu pictures.',
        'CCS02': 'Move the style toward mature cel-shaded 3D with matte planes, stepped light and selective contours.',
        'CCS03': 'Integrate versioned lossless mipmapped 1024px imports with exact edit provenance.',
        'R01': 'Preserve layout, crop, captions, Garage models, challenge rules and account/result behavior.',
        'G01': 'Review real native menu captures in Compatibility and desktop Mobile at existing test sizes.',
        'Q01': 'Retain commands, results, hashes, original artwork, working-tree baseline and scoped binary Git checkpoint.'
    },
    'engine': (ROOT/'godot-version.txt').read_text().strip(),
    'changed_files': [{'path': p, 'sha256': sha(ROOT/p), 'bytes': (ROOT/p).stat().st_size} for p in files],
    'runtime_scope': 'Only three format-poster paths and two entry-poster names change; source bytes otherwise match captured task baseline.',
    'artwork': manifest['assets'],
    'import': {'exit_code': 0, 'log': 'import-headless.log',
               'command': 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/evidence/challenge-cel-shading-2026-10-24/run_validation.ps1 -Test import'},
    'validation': results,
    'captures': captures,
    'checkpoint': {'patch': 'checkpoint.patch', 'sha256': sha(patch_path),
                   'git_apply_check': 'pass', 'applied_files_sha256': 'all 15 files exactly match final workspace'},
    'attempts_and_diagnostics': [
        'Default PowerShell execution policy prevented direct dev.ps1 invocation; subsequent commands use process-local ExecutionPolicy Bypass.',
        'The required dev.ps1 import entry point stopped at the existing Windows sandbox root-certificate-store diagnostic; the pinned engine was then verified and invoked by the retained runner. No TLS check was disabled.',
        'An initial combined text patch failed verification on the existing one-line asset-license entry. No partial source edit was applied; the corrected patch adds a separate provenance entry.',
        'The initial scoped checkpoint applied with Windows core.autocrlf conversion, changing line endings. Disable autocrlf for the isolated diff/verification repository; the final applied checkpoint is byte-exact for every included file.',
        'All native logs retain the sandbox root-certificate-store diagnostic. It is the only ERROR line permitted in the engine log files by this evidence review; assertions and resource/shader errors are not suppressed.',
        'Mobile entry completed 92 assertions with zero failures and process exit 0, then reported six ObjectDB instances and two resources still in use during teardown. The engine log omits those final lines; actual tool output is retained in observed-mobile-entry-shutdown.txt. No clean-shutdown or cause-attribution claim is made.'
    ],
    'limitations_and_acceptance': [
        'Pictures are raster art with a cel-shaded 3D appearance, not newly introduced live 3D scenes.',
        'Original v1/v2 artwork and provenance remain; no exact pixel identity is claimed between style-transfer versions.',
        'Mobile here is the desktop Vulkan renderer on an RTX 3090, not a phone or tablet test.',
        'No phone/tablet attachment check or physical-device test was performed. No APK, install, live account/backend write, social send or deployment.',
        'Client reload and owner visual/device acceptance remain; existing owner game/editor processes and concurrent work are preserved.',
        'No repository-wide regression pass or clean Mobile entry-fixture shutdown is claimed for this artwork-only change.'
    ]
}
(EVIDENCE/'report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'checks': results, 'captures': len(captures), 'checkpoint_files': len(files),
                  'checkpoint_verified': True}, indent=2))
