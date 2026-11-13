"""Aggregate request methods and timing only; never save raw URL or identities."""
import json
from collections import Counter
from datetime import datetime, timedelta, timezone
from itertools import pairwise
from statistics import median

from read_cloud import OUT, read

end = datetime.now(timezone.utc)
start = end - timedelta(hours=24)
rows = read(['logging', 'read',
             'resource.type="cloud_run_revision" AND resource.labels.service_name="bmt-stg-e7a444ab-api" '
             'AND timestamp>="' + start.isoformat() + '" AND httpRequest.status=422 '
             'AND httpRequest.requestUrl:"/v1/me/appearances"', '--limit=2500',
             '--format=json(timestamp,httpRequest.requestMethod,httpRequest.latency,resource.labels.revision_name)'])
result = {'start_utc': start.isoformat(), 'end_utc': end.isoformat(), 'limit': 2500}
if isinstance(rows, list):
    methods = Counter(row.get('httpRequest', {}).get('requestMethod') for row in rows)
    times = sorted(datetime.fromisoformat(row['timestamp'].replace('Z', '+00:00')) for row in rows)
    gaps = [(b - a).total_seconds() for a, b in pairwise(times)]
    latencies = [float(row['httpRequest']['latency'].removesuffix('s')) * 1000
                 for row in rows if row.get('httpRequest', {}).get('latency')]
    result.update({'rows': len(rows), 'possibly_truncated': len(rows) == 2500, 'methods': dict(methods),
                   'first_utc': times[0].isoformat() if times else None,
                   'last_utc': times[-1].isoformat() if times else None,
                   'median_gap_seconds': median(gaps) if gaps else None,
                   'gaps_29_to_31_seconds': sum(29 <= value <= 31 for value in gaps),
                   'median_service_latency_ms': median(latencies) if latencies else None,
                   'revisions': dict(Counter(row.get('resource', {}).get('labels', {}).get('revision_name') for row in rows)),
                   'qualification': 'Cross-request gaps do not identify a particular client or account.'})
else:
    result['read_error'] = rows
(OUT / 'appearance-request-summary.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
