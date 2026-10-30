from pathlib import Path
import difflib
import hashlib
import json
import shutil

ROOT = Path.cwd()
OUT = ROOT / 'docs/evidence/track-editor-review-2026-10-28'
helpers = [
    'game/tests/audit_track_editor_2026_10_28.gd',
    'game/tests/profile_track_editor_2026_10_28.gd',
    'game/tests/profile_track_editor_history_2026_10_28.gd',
    'game/tests/review_editor_practice_control_2026_10_28.gd',
    'game/tests/review_track_editor_2026_10_28.gd',
]
reviewed = [
    'game/core/app.gd', 'game/editor/editor_canvas.gd', 'game/editor/editor_world.gd',
    'game/editor/editor_session.gd', 'game/editor/editor_history.gd',
    'game/editor/track_document.gd', 'game/editor/creator_limits.gd',
    'game/editor/road_update.gd', 'game/track/track_theme.gd',
]
sources = {}
for name in reviewed:
    source = ROOT / name
    target = OUT / 'reviewed-sources' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    sources[name] = hashlib.sha256(source.read_bytes()).hexdigest()

finding_rows = [
    ('TER-C01', 'P1', 'correctness', 'Accepted edits can exceed global limits and fail WIP recovery',
     ['game/editor/editor_canvas.gd:741', 'game/editor/editor_canvas.gd:1385'],
     ['paint_global_limit', 'road_global_limit']),
    ('TER-C02', 'P2', 'correctness', 'Cancelled drags are committed and autosaved',
     ['game/editor/editor_canvas.gd:186', 'game/editor/editor_canvas.gd:578', 'game/core/app.gd:5101'],
     ['cancelled_object_touch', 'cancel_gesture_after_drag', 'escape_during_object_drag']),
    ('TER-C03', 'P2', 'usability/correctness', 'Road acceptance can reverse the start direction',
     ['game/editor/editor_canvas.gd:310', 'game/editor/editor_canvas.gd:1133', 'game/editor/editor_canvas.gd:1355'],
     ['road_accept_start_flip_overlap', 'native/*/03-selected-road-1280.png']),
    ('TER-U01', 'P2', 'usability', 'Night authoring has insufficient visibility',
     ['game/editor/editor_world.gd:358', 'game/track/track_theme.gd:52'],
     ['native/*/20-theme-night_city.png', 'native/*/22-night-with-authored-lights.png']),
    ('TER-P01', 'P2', 'performance', 'Final geometry and cold practice preparation remain slow',
     ['game/core/app.gd:3955', 'game/editor/road_update.gd:8'],
     ['performance/gl_compatibility/results-gl_compatibility.json']),
    ('TER-P02', 'P2', 'performance', 'Synchronous history consumes a substantial large-track input budget',
     ['game/editor/editor_session.gd:15', 'game/editor/editor_history.gd:8'],
     ['history-profile.json']),
    ('TER-U02', 'P2', 'usability', 'Some rejected edits only update an invisible label',
     ['game/core/app.gd:3573', 'game/core/app.gd:3268'], ['invalid_parameter_feedback']),
    ('TER-C04', 'P2', 'correctness/usability', 'Sharing bypasses pending-road resolution',
     ['game/core/app.gd:3986'], ['share_pending_road']),
]
findings = [dict(id=i, priority=p, category=c, title=t, source=s, evidence=e)
            for i, p, c, t, s, e in finding_rows]
executions = {}
for path in OUT.glob('direct-*.json'):
    if path.stem.endswith('-pid'):
        continue
    executions[path.name] = json.loads(path.read_text(encoding='utf-8'))
native = {}
for path in (OUT / 'native').glob('*/observations.json'):
    data = json.loads(path.read_text(encoding='utf-8'))
    native[path.parent.name] = dict(captures=len(data['observations']), failures=data['failures'],
                                   sources_stable_within_run=data['source_before'] == data['source_after'])
report = dict(
    date='2026-10-28', timezone='Europe/Helsinki', scope='review only',
    requirements={'TER01': 'usability', 'TER02': 'performance', 'TER03': 'correctness',
                  'TER04': 'overall quality', 'TER-Q01': 'reproducible evidence'},
    engine='4.7.2.stable.official.ed1daf0bf',
    findings=findings, audit=json.loads((OUT / 'audit-headless.json').read_text()),
    history=json.loads((OUT / 'history-profile.json').read_text()), native=native,
    executions=executions,
    original_practice=dict(checks=39, failures=4, laps=0, ticks=28800, contacts=27678,
                           following_diagnostic='nil access after absent normal finish', resolved=False),
    current_creator_practice_control=dict(checks=53, failures=0, laps=6, ticks=15259, contacts=0,
                                         note='Different current creator fixture; does not replace original failure'),
    wrapper_attempts='checks.json; all attempted tests hit sandbox diagnostics; no wrapper pass claim',
    limitations=[
        'Desktop RTX 3090; no device query/test or phone FPS/latency claim',
        'No whole-tree freeze: concurrent App, vehicle, input, localization, fixture and backend changes',
        'Certificate-store errors retained even in successful direct controls',
        'Forced 960x540 logical layout differs from production 1280x720 scaling',
        'No production source fix, deployment, external share, authentication, purchase, or owner-save change',
        'Initial policy/profile/wrapper/process-inspection failures and incomplete probes retained',
        'Tracked capacity-test result archived and restored; newer concurrent build identity preserved',
    ],
    reviewed_source_hashes=sources, helper_files=helpers,
    production_edits_by_review=[],
)
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

patch_names = ['docs/TRACK_EDITOR_REVIEW_2026_10_28.md'] + helpers
patch_names += [n + '.uid' for n in helpers if (ROOT / (n + '.uid')).exists()]
patch_names += ['docs/evidence/track-editor-review-2026-10-28/' + name
                for name in ['run_checks.py', 'run_probe.py', 'assemble_report.py']]
chunks = []
for name in patch_names:
    content = (ROOT / name).read_text(encoding='utf-8')
    chunks.append('diff --git a/' + name + ' b/' + name + '\nnew file mode 100644\n')
    chunks.extend(difflib.unified_diff([], content.splitlines(keepends=True),
                                     fromfile='/dev/null', tofile='b/' + name))
(OUT / 'review-only.patch').write_text(''.join(chunks), encoding='utf-8')
print(json.dumps(dict(findings=len(findings), executions=len(executions), native=native,
                      review_helpers=len(helpers), patch_files=len(patch_names))))
