"""Bounded aggregate logs and read-only billing SELECT; credentials stay in memory."""
import json
import re
import subprocess
from collections import Counter
from datetime import datetime, timedelta, timezone
from urllib.parse import urlsplit

import requests
from read_cloud import CONFIG, ENV, OUT, ROOT, read


def main():
    end = datetime.now(timezone.utc)
    start = end - timedelta(hours=24)
    result = {'captured_at_utc': end.isoformat(), 'log_start_utc': start.isoformat()}
    query = ('resource.type="cloud_run_revision" AND resource.labels.service_name="bmt-stg-e7a444ab-api" '
             'AND timestamp>="' + start.isoformat() + '" AND httpRequest.status>=400')
    rows = read(['logging', 'read', query, '--limit=2500',
                 '--format=json(timestamp,httpRequest.status,httpRequest.requestUrl,httpRequest.latency,resource.labels.revision_name)'])
    if isinstance(rows, list):
        groups = Counter()
        for row in rows:
            http = row.get('httpRequest', {})
            path = urlsplit(http.get('requestUrl', '')).path
            path = re.sub(r'[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}', '{id}', path)
            groups[(http.get('status'), path)] += 1
        result['errors'] = {'rows': len(rows), 'limit': 2500, 'possibly_truncated': len(rows) == 2500,
                            'groups': [{'status': key[0], 'path': key[1], 'count': count}
                                       for key, count in groups.most_common()]}
    else:
        result['errors'] = rows
    token_result = subprocess.run([*CONFIG['gcloud'], '--project=' + CONFIG['project'],
                                   'auth', 'print-access-token', '--quiet'],
                                  env=ENV, capture_output=True, text=True, timeout=40, check=False)
    if token_result.returncode:
        result['billing'] = {'inspection_error': 'authentication unavailable'}
    else:
        headers = {'Authorization': 'Bearer ' + token_result.stdout.strip()}
        verify = str(ROOT / '.tools/gcp-staging/windows-trust.pem')
        details = json.loads((OUT / 'cloud-details.json').read_text())
        table = details['studio']['flags']['BMT_STUDIO_USAGE_BILLING_TABLE']
        project, dataset, name = table.split('.')
        url = f'https://bigquery.googleapis.com/bigquery/v2/projects/{project}/datasets/{dataset}/tables/{name}'
        response = requests.get(url, headers=headers, verify=verify, timeout=(5, 30))
        metadata = response.json()
        billing = {'metadata_status': response.status_code,
                   'metadata': {key: metadata.get(key) for key in ('numRows', 'numBytes', 'lastModifiedTime', 'timePartitioning')}}
        if response.ok:
            # Only project aggregates; at most 100 MiB billed, no source tables modified.
            sql = f'''SELECT DATE(usage_start_time) AS day, currency, service.description AS service,
 SUM(CAST(cost AS NUMERIC)) AS charges,
 SUM((SELECT COALESCE(SUM(CAST(c.amount AS NUMERIC)),0) FROM UNNEST(credits) c)) AS credits,
 COUNT(*) AS source_rows
 FROM `{table}`
 WHERE project.id = @project AND usage_start_time >= TIMESTAMP('2026-10-27')
 AND usage_start_time < TIMESTAMP('2026-11-07')
 GROUP BY day,currency,service ORDER BY day,service'''
            payload = {'query': sql, 'useLegacySql': False, 'location': 'EU', 'timeoutMs': 20000,
                       'maxResults': 500, 'maximumBytesBilled': '104857600', 'parameterMode': 'NAMED',
                       'queryParameters': [{'name': 'project', 'parameterType': {'type': 'STRING'},
                                            'parameterValue': {'value': CONFIG['project']}}]}
            response = requests.post(f'https://bigquery.googleapis.com/bigquery/v2/projects/{project}/queries',
                                     headers=headers, json=payload, verify=verify, timeout=(5, 30))
            data = response.json()
            fields = [field['name'] for field in data.get('schema', {}).get('fields', [])]
            billing['query'] = {'status': response.status_code, 'job_complete': data.get('jobComplete'),
                                'total_bytes_processed': data.get('totalBytesProcessed'),
                                'cache_hit': data.get('cacheHit'), 'total_rows': data.get('totalRows'),
                                'has_page_token': bool(data.get('pageToken')),
                                'error_status': data.get('error', {}).get('status'),
                                'rows': [dict(zip(fields, [value.get('v') for value in row['f']]))
                                         for row in data.get('rows', [])]}
        result['billing'] = billing
    (OUT / 'cloud-usage.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
