"""Summarize measured phases, source changes, and read-only asset eligibility."""
import json
from pathlib import Path

evidence = Path(__file__).resolve().parent
summary = {'runs': {}, 'race_phases_ms': [], 'assets': {}}
for receipt_path in sorted(evidence.glob('*-receipt.json')):
    label = receipt_path.name.removesuffix('-receipt.json')
    receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
    output = evidence/(label+'.json')
    result = json.loads(output.read_text(encoding='utf-8')) if output.exists() else {}
    log = (evidence/(label+'.log')).read_text(encoding='utf-8')
    summary['runs'][label] = {
        'exit_code': receipt['exit_code'], 'changed_sources': receipt['changed_sources'],
        'checks': result.get('checks'), 'failures': result.get('failures'),
        'errors': [line for line in log.splitlines() if 'ERROR:' in line or 'TIMEOUT' in line],
        'measurements': {key: value for key, value in result.items()
                         if key.endswith('_ms') or key in ('header_captures','header_disk_hits','picture_renders','picture_disk_hits','writes_drained','preload_draws','progressive_entry')},
        'phase_observations': [json.loads(line.split(' ',1)[1]) for line in log.splitlines()
                               if line.startswith(('LOADING_PHASE ', 'GARAGE_WORKLOAD '))]}
    if 'samples' in result:
        for row in result['samples']:
            marks = {mark['name']:mark['us'] for mark in row['marks']}
            phases = {phase:(marks[end]-marks[begin])/1000 for phase, begin, end in (
                ('roads','roads_begin','roads_end'), ('installation','game_begin','game_end'),
                ('graphics','graphics_begin','graphics_end'), ('effects','effects_begin','effects_end'))}
            summary['race_phases_ms'].append(dict(run=label,theme=row['theme'],cycle=row['cycle'],
                wall_ms=row['wall_ms'],retry_ms=row['retry_ms'],max_frame_ms=row['max_frame_ms'],
                draw_groups=row['draw_groups'],**phases))
    if label == 'asset-eligibility':
        for kind in ('modular','garage','header'):
            rows = [row for row in result['rows'] if row['kind']==kind]
            good = [row for row in rows if row['key_matches'] and row['sources_match']]
            summary['assets'][kind] = dict(total=len(rows),valid=len(good),rejected=len(rows)-len(good))
(evidence/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,indent=2))
