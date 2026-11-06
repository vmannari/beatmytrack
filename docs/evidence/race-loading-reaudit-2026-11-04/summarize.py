"""Derive stage tables and keep every attempt's status/source limitations."""
import json
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
summary = {'runs': {}, 'race_rows': [], 'cpu_rows': []}
pairs = {
    'roads_ms': ('roads_begin', 'roads_end'),
    'game_ms': ('game_begin', 'game_end'),
    'world_ms': ('graphics_begin', 'graphics_end'),
    'effects_ms': ('effects_begin', 'effects_end'),
}
for receipt_path in sorted(EVIDENCE.glob('*-receipt.json')):
    label = receipt_path.name.removesuffix('-receipt.json')
    receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
    result_path = EVIDENCE / (label + '.json')
    result = json.loads(result_path.read_text(encoding='utf-8')) if result_path.exists() else {}
    log = (EVIDENCE / (label + '.log')).read_text(encoding='utf-8', errors='replace')
    summary['runs'][label] = {
        'exit_code': receipt['exit_code'],
        'elapsed_seconds': receipt['elapsed_seconds'],
        'changed_sources': receipt['changed_sources'],
        'checks': result.get('checks', 0), 'failures': result.get('failures', 0),
        'diagnostics': [line for line in log.splitlines() if any(word in line for word in ('ERROR:', 'WARNING:', 'SCRIPT ERROR:'))],
    }
    for row in result.get('samples', []):
        marks = {mark['name']: mark['us'] for mark in row['marks']}
        values = {name: round((marks[end] - marks[start]) / 1000, 3) for name, (start, end) in pairs.items()}
        summary['race_rows'].append({
            'run': label, **{key: row.get(key) for key in (
                'theme', 'cycle', 'wall_ms', 'max_frame_ms', 'retry_ms',
                'draw_groups', 'world_cache_bytes', 'effect_counts')}, **values,
        })
    if label == 'frozen-cpu':
        summary['cpu_rows'] = result['rows']
    if label == 'frozen-gate-stages':
        summary['gate_stages'] = result
    if label == 'frozen-feature-resources':
        summary['feature_resources'] = result['rows']
accepted = [label for label, run in summary['runs'].items()
            if label.startswith('frozen-') and run['exit_code'] == 0
            and not run['changed_sources'] and run['failures'] == 0]
summary['stable_successful_runs'] = accepted
summary['stable_checks'] = sum(summary['runs'][label]['checks'] for label in accepted)
summary['stable_failures'] = sum(summary['runs'][label]['failures'] for label in accepted)
(EVIDENCE / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'runs': summary['runs'], 'stable_checks': summary['stable_checks']}, indent=2))
