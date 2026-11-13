"""Summarize actual tablet receipts without mixing desktop fixture timings."""
import json
from pathlib import Path
from statistics import median

OUT = Path(__file__).resolve().parent


def read(name):
    return json.loads((OUT/name).read_text())


def span(events, first, last):
    a = next((e['us'] for e in events if e['label']==first),None)
    b = next((e['us'] for e in events if e['label']==last),None)
    return (b-a)/1000 if a is not None and b is not None else None


def main():
    results = [read(name+'.json') for name in ['profile-startup-a','profile-startup-b','profile-menus-a','profile-menus-b','profile-races-a','profile-races-b']]
    startup, menus, races = [], [], []
    checks = 0
    for value in results:
        report = value['report']
        assert not report['failures'] and not report['dropped_events']
        assert next(row for row in report['rows'] if row['kind']=='startup')['screen']!='restoring'
        checks += report['checks']
        events = report['events']
        extra = span(events,'app_ready_end','initial_content_ready')
        startup.append({'run':report['run'],
                        'app_ready_ms':value['startup']['launch_request_to_app_ready_log_ms'],
                        'launch_to_content_ms':value['startup']['launch_request_to_app_ready_log_ms']+extra,
                        'after_app_ready_ms':extra,
                        'app_setup_ms':span(events,'app_ready_begin','app_local_setup_end'),
                        'account_wait_ms':span(events,'account_wait_begin','account_wait_end'),
                        'bootstrap_ms':span(events,'bootstrap_begin','bootstrap_end'),
                        'session_ms':span(events,'session_begin','session_end'),
                        'writer':report['menu_snapshot_writer'],
                        'network':[e for e in events if e['label']=='network_http' and e['scope']=='startup']})
        for row in report['rows']:
            if row['kind']=='menu': menus.append({'run':report['run'],**row})
            if row['kind']=='race':
                scoped = [e for e in events if e['scope']=='race/'+row['fixture']+'/'+row['theme']+'/'+str(row['cycle'])]
                phases = {name:span(scoped,name+'_begin',name+'_end') for name in ['selected_wait','roads','game','graphics','effects']}
                races.append({'run':report['run'],**row,'phases_ms':phases,
                              'feature_loads':[e['detail'] for e in scoped if e['label']=='feature_end']})
    grouped = {}
    for page in sorted({r['page'] for r in menus}):
        grouped[page] = {str(cycle):{'samples':len(rows),'median_ready_ms':median(r['ready_ms'] for r in rows),
                                   'ready_ms':[r['ready_ms'] for r in rows],
                                   'largest_frame_ms':max(r['frames'].get('max_ms',0) for r in rows)}
                         for cycle in [0,1] if (rows := [r for r in menus if r['page']==page and r['cycle']==cycle])}
    summary = {'checks':checks,'startup':startup,'menus':grouped,'menu_rows':menus,'races':races,
               'temperatures_c':[r['after']['battery_temperature_c'] for r in results],
               'thermal_statuses':[r['after']['thermal_status'] for r in results],
               'cache_state':'Existing app and driver caches retained; fresh process per run; local diagnostic road/layout directory retained across race runs.'}
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({'checks':checks,'startup_ms':[r['launch_to_content_ms'] for r in startup],
                      'menus':grouped,'races':[{'run':r['run'],'fixture':r['fixture'],'theme':r['theme'],'cycle':r['cycle'],'ready_ms':r['ready_ms'],'compile_ms':r['compile_ms'],'phases_ms':r['phases_ms']} for r in races]},indent=2))


if __name__=='__main__': main()
