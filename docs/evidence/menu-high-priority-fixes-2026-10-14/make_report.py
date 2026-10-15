"""Collect menu-fix receipts without changing the game or Git index."""
from pathlib import Path
import json
import shutil

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
COMMANDS = OUT / 'commands'
COMMANDS.mkdir(exist_ok=True)

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

reports = {
    name: read_json(OUT / folder / 'report.json')
    for name, folder in {
        'compatibility': 'compatibility-native-control',
        'mobile': 'mobile-native-control',
        'headless': 'headless-verified',
    }.items()
}
assert all(r['failures'] == 0 for r in reports.values())
receipts = []
for directory in (ROOT / 'build/logs').iterdir():
    if not directory.is_dir() or directory.stat().st_mtime < OUT.stat().st_ctime:
        continue
    for log in directory.glob('*.log'):
        text = log.read_text(encoding='utf-8-sig', errors='replace')
        if 'MENU_HIGH_PRIORITY ' not in text and 'res://tests/test_menu_high_priority.gd' not in text:
            continue
        destination = COMMANDS / directory.name
        destination.mkdir(exist_ok=True)
        shutil.copy2(log, destination / log.name)
        receipt = {'log': str((destination / log.name).relative_to(OUT)).replace('\\', '/')}
        for line in text.splitlines():
            if line.startswith('MENU_HIGH_PRIORITY '):
                data = json.loads(line.removeprefix('MENU_HIGH_PRIORITY '))
                receipt.update(checks=data['checks'], failures=data['failures'], display=data['display'], renderer=data['renderer'])
                receipt['final'] = any(data == final for final in reports.values())
        receipts.append(receipt)

regressions = [
    ('app', 'TestApp-5988', 'app-tests.log', 'TestApp', '101 checks, 0 failures'),
    ('parser', 'TestScript-18916', 'test-script.log', 'TestScript -ScriptPath res://tests/test_script_parse.gd', '760 scripts, 0 failures'),
    ('challenges', 'TestScript-4828', 'test-script.log', 'TestScript -ScriptPath res://tests/test_challenges.gd', '165 checks, 0 failures'),
    ('swipes', 'TestScript-9420', 'test-script.log', 'TestScript -ScriptPath res://tests/test_menu_page_swipe.gd', '240 checks, 0 failures'),
    ('menu_quality', 'TestScript-37852', 'test-script.log', 'TestScript -ScriptPath res://tests/test_menu_quality.gd', '23 checks, 0 failures'),
    ('menu_loading', 'TestScript-16140', 'test-script.log', 'TestScript -ScriptPath res://tests/test_menu_loading_speed.gd', '27 checks, 0 failures'),
]
checks = []
for name, directory, log, args, expected in regressions:
    source = ROOT / 'build/logs' / directory / log
    assert expected in source.read_text(encoding='utf-8-sig', errors='replace'), source
    destination = COMMANDS / directory
    destination.mkdir(exist_ok=True)
    shutil.copy2(source, destination / log)
    checks.append({'name': name, 'command': 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ' + args + ' -CommandTimeoutSeconds 120', 'result': expected, 'log': str((destination / log).relative_to(OUT)).replace('\\', '/')})

report = {
    'task': 'Fix the two high-priority menu audit findings',
    'date': '2026-10-14',
    'requirements': ['R01', 'G01', 'V03', 'V04', 'V05', 'Q01'],
    'audit': '../menu-review-2026-10-14/review.json',
    'resolved': [
        {
            'id': 'MREV01',
            'change': 'Construct one owner-bound native Garage under the startup/account loading cover and retain it across primary pages, Settings/Profile and ordinary race results/returns. Keep one suspended primary shell; discard it for other flows and owner changes. Attach at most one other primary neighbor per frame, coalescing duplicate callbacks.',
            'preserved': 'Actual car/world/viewport identities, camera/zoom/pose, independently updated local cosmetics, authored control input state, outgoing slides, the six original car showrooms and their existing reflection passes/caps. The raw native_views_retained counter counts showrooms, not subordinate reflection targets. Re-establish explicit reflection viewport parents after tree re-entry. Re-sort the retained content once when its shell becomes visible.',
            'limit': 'The original cold construction cost remains and runs once under loading for each storage owner. This is not a startup-speed, phone-FPS, hitch-free or reduced-memory claim. The retained native scenes remain allocated during racing; their hidden branches stop processing/capture updates.',
        },
        {
            'id': 'MREV02',
            'change': 'Publish folder changes immediately and coalesce pending intent to the latest folder. Snapshot request folder/cursor before emitting UI updates. Drain pending first-page refresh after list/detail/mutation completion; ignore stale rows/cursors and old request/account completions. Returning to the original first-page folder reuses its pending reply.',
            'verification': 'Real Sent-tab signal plus delayed offline services cover rapid switching/backtracking, pagination, errors, overlapping details, mutations and account changes without live requests.',
        },
    ],
    'environment': {
        'engine': '4.7.2.stable.official.ed1daf0bf',
        'entry_point': 'scripts/dev.ps1',
        'graphics': 'Desktop NVIDIA GeForce RTX 3090; Compatibility/OpenGL and Mobile/Vulkan',
        'isolated_appdata': True,
        'live_service_requests': False,
        'phone_test': False,
        'apk_export_install_deployment': False,
        'shared_workspace': 'Concurrent grille, record-player, washing, rivalry and night-preparation edits are preserved and excluded from task-only.patch.',
    },
    'focused': {
        name: {
            'checks': data['checks'], 'failures': data['failures'],
            'raw': {'compatibility': 'compatibility-native-control/report.json', 'mobile': 'mobile-native-control/report.json', 'headless': 'headless-verified/report.json'}[name],
            'menu': data['menu'],
            'settings_pixels': data.get('settings_pixels'),
            'same_world_visibility_control': data.get('same_world_visibility_control'),
            'native_pixels': data.get('native_pixels'),
        }
        for name, data in reports.items()
    },
    'timing_interpretation': 'Final Settings-return synchronous dispatch samples are approximately 0.8-1.7ms; final neighbor callback maxima are 33.115ms Compatibility and 18.021ms desktop Mobile. Original audit batches were 464.627-771.752ms and 1835.481-4376.097ms respectively. These are callback work receipts on a shared, changing desktop, not controlled startup or frame-time/FPS benchmarks. Cold covered construction remains about 1.17s/4.53s in these final samples.',
    'pixel_method': 'Pause soundtrack only in the test fixture to freeze the concurrently added record-player animation. Compare full native frames and both complete reflection images. Record independent fresh/fresh native precision differences; retained/fresh changed-pixel count and total maximum-channel delta must not exceed that contemporaneous original-path control. For same-world Settings returns, compare exact dimensions and every byte against twelve pre-navigation unchanged native hide/show samples, with no fixed tolerance or geometry mask. Final Settings images and all six repeated returns are byte-exact in both renderers; both reflection images are also byte-exact. Independent Mobile rooms retain 12 differing pixels (max channel delta4, sum29) versus original fresh/fresh70 pixels (max2, sum79); do not infer independent full-frame byte identity.',
    'initial_attempts': [
        'Windows restricted startup required approved certificate-store access through the pinned launcher.',
        'Early new-suite fixture issues included RGB/RGBA byte strides and exact independent-world assumptions; raw logs remain in commands/.',
        'Reparenting initially lost the reflection render-target ordering. The tree-entered parent restoration fixes this; complete reflection images now match.',
        'Repeated Settings tests caught a one-pixel native container relayout; the retained content is now explicitly queued for sorting on visibility restoration. Speculative viewport snapping and settled-lerp edits were reverted.',
        'A single colour byte varies by one level in unchanged Compatibility native hide/show controls. The final test measures its pre-navigation byte envelope instead of imposing an unsupported universal exact-frame assertion. Final return captures happen to be exact; the test also rejects changes outside the original observed native samples.',
        'Concurrent Records dependency parse errors interrupted some earlier checks and were corrected by their owning task; that implementation is excluded from this patch.',
    ],
    'regressions': checks,
    'focused_command_template': 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_menu_high_priority.gd -CommandTimeoutSeconds 120',
    'graphical_flags': {'compatibility': '-Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3', 'mobile': '-Graphical -RenderingMethod mobile -RenderingDriver vulkan'},
    'focused_environment': 'BMT_MENU_FIX_OUTPUT selects a receipt subdirectory; APPDATA selects an isolated build/menu-high-priority-fixes-* directory. The suite sets BMT_API_URL empty before app construction and uses an offline in-process delayed Challenges service.',
    'focused_receipts': receipts,
    'checkpoint': {'patch': 'task-only.patch', 'source_hashes': 'source-hashes.json', 'method': 'Before snapshots for app/client/test_app; narrowly reversed own changes for shared garage_page/reflections. No staging or Git commit, and no unrelated working-tree changes reverted. git apply --reverse --check succeeds.', 'whitespace': 'git diff --check on scoped runtime/test files passes.'},
    'remaining_acceptance': ['Owner interaction and physical-phone latency/memory/visual acceptance.', 'Medium and low audit findings are outside this high-priority slice.', 'No full Validate, export, installation or deployment was run for this task.'],
}
mobile = reports['mobile']['native_pixels']
report['pixel_method'] = report['pixel_method'].replace('sum29', 'sum' + str(mobile['total_delta']))
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'focused_checks': {k: r['checks'] for k, r in reports.items()}, 'copied_focused_receipts': len(receipts), 'regressions': len(checks)}))
