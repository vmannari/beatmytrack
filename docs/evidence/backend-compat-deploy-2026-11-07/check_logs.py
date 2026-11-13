"""Bounded error check; cloud log messages remain private."""
import json
import deploy as r

assert r.s.get('promoted')
revisions = [r.s['route_' + role]['revisionName'] for role in ('main', 'studio', 'preview')]
worker = r.service.describe('worker', r.service.n['worker'])
revision = worker.get('status', {}).get('latestReadyRevisionName')
if revision:
    revisions.append(revision)
filters = ' OR '.join('resource.labels.revision_name="' + item + '"' for item in revisions)
query = '(' + filters + ') AND timestamp>="' + r.s['rollout_started'] + '" AND (severity>=ERROR OR httpRequest.status>=500)'
entries = json.loads(r.service.call('logging', 'read', query, '--limit=100', '--format=json'))
r.d.write(r.WORK / 'release-errors.private.json', entries)
result = {'checked_revisions': revisions, 'since': r.s['rollout_started'], 'error_entries': len(entries), 'log_messages_exported': False}
r.d.write(r.OUT / 'release-errors.json', result)
assert not entries, 'Matching release has cloud errors; inspect the private bounded log before completion'
print(json.dumps(result), flush=True)
