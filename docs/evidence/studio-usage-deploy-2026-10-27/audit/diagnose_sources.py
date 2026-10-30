"""Read-only provider response-shape diagnostics under the Studio identity."""
import json
import time

import google.auth
from bmt_backend.config import Settings
from bmt_backend.studio_usage_cloud import ProviderUnavailable, UsageCloud
from google.auth.transport.requests import AuthorizedSession

settings=Settings.from_env()
credentials,_=google.auth.default(scopes=['https://www.googleapis.com/auth/cloud-platform'])


def transport(method,url,**kwargs):
    with AuthorizedSession(credentials) as session:
        response=session.request(method,url,timeout=(3,15),allow_redirects=False,**kwargs)
    body=response.json()
    diagnostic={'event':'usage_provider_diagnostic','host':url.split('/')[2],'http_status':response.status_code,
        'bytes':len(response.content),'keys':sorted(body),'entries':len(body.get('entries',[])),
        'next_page':bool(body.get('nextPageToken')),'error_status':body.get('error',{}).get('status'),
        'error_reason':[v.get('reason') for v in body.get('error',{}).get('details',[]) if v.get('reason')],
        'row_count':sum(len(e.get('jsonPayload',{}).get('rows',[])) for e in body.get('entries',[]))}
    print(json.dumps(diagnostic),flush=True)
    if not response.ok or len(response.content)>4*1024*1024:
        raise ProviderUnavailable('provider_diagnostic')
    return body


try:
    result=UsageCloud(settings,transport=transport).endpoint_summaries(int(time.time()))
    print(json.dumps({'event':'usage_provider_diagnostic','endpoint_status':result['status'],'endpoint_rows':len(result['rows'])}),flush=True)
except Exception as error:  # noqa: BLE001 - report only the provider diagnostic exception type.
    print(json.dumps({'event':'usage_provider_diagnostic','caught_class':type(error).__name__}),flush=True)
