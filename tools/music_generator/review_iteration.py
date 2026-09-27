"""Build stage-matched R2 auditions through the project skill's review helper."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import time
import uuid
from generate import ROOT, BUILD, atomic_json, audio_metrics

# Optional local FFmpeg binary; no system install or generation-venv changes.
local_tools = Path.home() / '.local/share/bmt-music-tools'
if (local_tools / 'ffmpeg').is_file():
    os.environ['PATH'] = str(local_tools) + os.pathsep + os.environ.get('PATH', '')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('manifest', type=Path)
    args = parser.parse_args()
    source_manifest = args.manifest.resolve()
    raw = json.loads(source_manifest.read_text())
    jobs = raw['jobs']
    if raw['status'] != 'complete' or len(jobs) != 12:
        raise ValueError('Expected completed six-stage, two-option batch')
    helper = ROOT / '.agents/skills/bmt-adaptive-music/scripts/review_pack.py'
    spec = importlib.util.spec_from_file_location('review_pack', helper)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    out = BUILD / 'review' / ('reference-arc-r2-' + time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6])
    out.mkdir(parents=True)
    result = {'schema':'bmt-music-generation-1', 'status':'preparing', 'approval':'unreviewed',
              'source_manifest':str(source_manifest.relative_to(BUILD)), 'jobs':[],
              'note':'Each stage A/B matched independently. Full mixes; musical compatibility unverified.'}
    for stage in range(6):
        candidates = sorted((j for j in jobs if j['state_index'] == stage), key=lambda j:j['variant'])
        if len(candidates) != 2 or len({j['metrics']['sha256'] for j in candidates}) != 2:
            raise ValueError('Need two distinct recordings at each stage')
        paths = [source_manifest.parent / j['file'] for j in candidates]
        group = out / f'stage-{stage}'
        report = module.build_pack(paths, group, target=-20., ceiling=-2.)
        for job, comparison in zip(candidates, report['candidates']):
            path = group / comparison['audition_file']
            result['jobs'].append({**job, 'name':job['name'] + '_review',
                'family':'night_signal_r2_review', 'file':path.relative_to(out).as_posix(),
                'metrics':audio_metrics(path), 'source_sha256':job['metrics']['sha256'],
                'source_near_full_scale_samples':job['metrics']['near_full_scale_samples'],
                'loudness_comparison':comparison, 'status':'complete'})
        atomic_json(out / 'manifest.json', result)
    result['status'] = 'complete'
    atomic_json(out / 'manifest.json', result)
    print('REVIEW ' + str(out))

if __name__ == '__main__': main()
