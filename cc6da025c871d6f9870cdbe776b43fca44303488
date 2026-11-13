from pathlib import Path
import difflib
import hashlib
import json
import re
import shutil

ROOT = Path.cwd()
OUT = ROOT / 'docs/evidence/editor-experience-2026-10-28'
walk = json.loads((OUT / 'mobile/walkthrough.json').read_text(encoding='utf-8'))
selection = json.loads((OUT / 'mobile/selection.json').read_text(encoding='utf-8'))
atlas = json.loads((OUT / 'mobile/atlas.json').read_text(encoding='utf-8'))
executions = {p.name: json.loads(p.read_text(encoding='utf-8')) for p in OUT.glob('review*.json')
              if not p.name.endswith('-pid.json')}
findings = [
    dict(id='UXR01', title='Opening object options resets size, placement or variant', kind='reproduced defect', evidence=['reopen_object_options', 'reopen_variant_options', 'reopen_placement_options']),
    dict(id='UXR02', title='A nearby later-added object can win over a direct hit', kind='reproduced defect', evidence=['selection_neighbour']),
    dict(id='UXR03', title='First-use guidance and tool state are under-explained', kind='walkthrough assessment', evidence=['first_curve', '01-first-entry.png', '02-first-curve.png', '08-hairpin-selection.png']),
    dict(id='UXR04', title='Dense overview loses object identity', kind='controlled native comparison', evidence=['dense_default', '09-dense-normal-overview.png', '10-dense-full-comparison.png']),
    dict(id='UXR05', title='Fine positioning and bulk editing are limited', kind='workflow/source assessment'),
    dict(id='UXR06', title='Previews and material names do not always describe the chosen result', kind='walkthrough/source assessment'),
    dict(id='UXR07', title='Surface controls are insufficiently contextual', kind='walkthrough/source assessment'),
    dict(id='UXR08', title='Text, popup sizing and background detail weaken hierarchy', kind='visual assessment'),
]
assert walk['failures'] == 0 and len(walk['observations']) == 17
assert walk['source_before'] == walk['source_after']
assert selection['source_before'] == selection['source_after']
assert atlas['journal']['atlas']['variants'] == atlas['journal']['atlas']['completed'] == 55
assert walk['journal']['reopen_object_options']['scale_before'] == 1.5
assert walk['journal']['reopen_object_options']['scale_after'] == 1.0
assert selection['journal']['selection_neighbour']['selected'] == 1
assert all(row['exit'] == 0 and row.get('script_errors', 0) == 0 for row in executions.values())
for observation in walk['observations']:
    assert (OUT / 'mobile' / (observation['capture'] + '.png')).exists()

sources = {}
for relative in walk['source_after']:
    path = ROOT / 'game' / relative
    destination = OUT / 'reviewed-sources/game' / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, destination)
    sources['game/' + relative] = hashlib.sha256(path.read_bytes()).hexdigest()
report = dict(date='2026-10-28', timezone='Europe/Helsinki', scope='UX/UI and visual review only',
              engine='4.7.2.stable.official.ed1daf0bf', renderer='desktop Vulkan Mobile / RTX 3090',
              findings=findings, walkthrough=walk, selection=selection, atlas=atlas, executions=executions,
              reviewed_source_hashes_at_packaging=sources, source_freeze_claim=False,
              no_production_edits_by_review=True, device_test_performed=False,
              notes=['Night authoring has improved in concurrent work; earlier darkness is not a current-default finding.',
                     'Initial/second runs retain a concurrent history compilation failure.',
                     'Third run engine was clean; console output encoding failed after receipts were saved.',
                     'Final walkthrough has distinct inspection filenames, 17 captures and zero script errors.',
                     'Studio thumbnails are enlarged 2x; map inspection uses the original editor camera.',
                     'Expert visual judgments and scripted walkthroughs are not a human usability study.'])
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

doc = ROOT / 'docs/TRACK_EDITOR_UX_UI_REVIEW_2026_10_28.md'
for target in re.findall(r'\]\(([^)]+)\)', doc.read_text(encoding='utf-8')):
    assert (doc.parent / re.sub(r':\d+$', '', target)).exists(), target
names = ['docs/TRACK_EDITOR_UX_UI_REVIEW_2026_10_28.md',
         'game/tests/review_editor_experience_2026_10_28.gd',
         'docs/evidence/editor-experience-2026-10-28/run_probe.py',
         'docs/evidence/editor-experience-2026-10-28/assemble_report.py']
if (ROOT / 'game/tests/review_editor_experience_2026_10_28.gd.uid').exists():
    names.append('game/tests/review_editor_experience_2026_10_28.gd.uid')
patch = []
for name in names:
    patch.append('diff --git a/' + name + ' b/' + name + '\nnew file mode 100644\n')
    patch.extend(difflib.unified_diff([], (ROOT/name).read_text(encoding='utf-8').splitlines(keepends=True),
                                     fromfile='/dev/null', tofile='b/' + name))
(OUT / 'review-only.patch').write_text(''.join(patch), encoding='utf-8')
print(json.dumps(dict(findings=8, variants=55, walkthrough_captures=17, contact_sheets=3,
                      sources_stable_within_final_runs=True, script_errors=0, report_links_valid=True)))
