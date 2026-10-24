"""Retain evidence and a scoped reverse-checkable patch without staging mixed work."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).parent


def read(path):
    return path.read_text(encoding='utf-8-sig')


def function(source,name):
    node=next(n for n in ast.parse(source).body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)) and n.name==name)
    return ''.join(source.splitlines(keepends=True)[node.lineno-1:node.end_lineno])


def replace_function(source,name,value):
    return source.replace(function(source,name),value,1)


def xml_result(name):
    root=ET.parse(OUT/name).getroot()
    tests=list(root.iter('testcase'))
    return {'artifact':name,'passed':sum(not any(c.tag in ('failure','error','skipped') for c in t) for t in tests),
        'failed':sum(t.find('failure') is not None for t in tests),'errors':sum(t.find('error') is not None for t in tests),
        'skipped':sum(t.find('skipped') is not None for t in tests)}


def checkpoint():
    captured=json.loads(read(OUT/'baseline.json'))
    paths=['backend/bmt_backend/discovery_v3.py','backend/bmt_backend/discovery_projection.py',
        'backend/bmt_backend/discovery_models.py','backend/bmt_backend/middleware.py',
        'game/backend/discovery_windows.gd','game/tests/test_discovery_windows.gd',
        'backend/bmt_backend/migrations/versions/0053_discovery_short_search.py','backend/tests/test_discovery_hardening.py',
        'AGENTS.md','DEVELOPMENT_STATUS.md','backend/README.md']
    refs={}
    for path in paths:
        refs[path]=read(OUT/'before'/captured[path]['copy']) if path in captured else ''
    # Reverse only discovery read/index/ingress/maintenance changes in the shared
    # files. Retain concurrent resource guards/retention/telemetry as the review
    # baseline; never restore those files from their task-start snapshots.
    p=paths[0];current=read(ROOT/p);original=refs[p];reference=current
    for name in ('boundary','conditions','base','fetch','choose'):
        reference=replace_function(reference,name,function(original,name))
    before=function(original,'new_session');now=function(current,'new_session')
    split='    if query.section == "saved"'
    reverted=before[:before.index(split)]+now[now.index(split):]
    old_tail=before[before.index('    db.execute(insert(db, DiscoverySession)'):]
    tail_at=reverted.index('    view = db.scalar(insert(db, DiscoverySession)')
    reverted=reverted[:tail_at]+old_tail
    reference=replace_function(reference,'new_session',reverted).replace('import re\n','',1)
    refs[p]=reference
    p=paths[1];current=read(ROOT/p);reference=current
    old_health=function(refs[p],'health')
    new_health=function(current,'health')
    if '                "storage_backfill_ready":' in new_health:
        tail=new_health[new_health.index('                "storage_backfill_ready":'):]
        old_health=old_health.rstrip('\n')[:-1]+',\n'+tail
    reference=replace_function(reference,'health',old_health)
    reference=reference.replace('DiscoveryDriver.expires_at < stamp).order_by(DiscoveryDriver.expires_at).limit(BATCH)))',
        'DiscoveryDriver.expires_at < stamp).order_by(DiscoveryDriver.expires_at,\n                DiscoveryDriver.track_id, DiscoveryDriver.player_id).limit(BATCH)))')
    block=function(reference,'cleanup')
    block=block.replace('            if retention.erase_members(db, expired, keys):\n                removed += len(keys)',
                        '            retention.erase_members(db, expired, keys)')
    block=''.join(line for line in block.splitlines(keepends=True) if not line.strip().startswith(('removed =','removed +=','return removed')))
    reference=replace_function(reference,'cleanup',block.rstrip('\n'))
    reference=reference.replace('        removed = cleanup(db, stamp)','        cleanup(db, stamp)').replace(' or removed)',')')
    refs[p]=reference
    p=paths[2];refs[p]=read(ROOT/p).replace('Index("ix_discovery_driver_expire", "partition", "expires_at")',
        'Index("ix_discovery_driver_expire", "partition", "expires_at", "track_id", "player_id")',1)
    p=paths[3];reference=read(ROOT/p)
    import re
    reference=re.sub(r'^DISCOVERY_BODY_STALL_SECONDS = .*\n','',reference,flags=re.M)
    reference=re.sub(r'^        self.discovery_(receivers|receiving_keys|small_parsers) = .*\n','',reference,flags=re.M)
    reference=reference.replace('        discovery_receiving = False\n','').replace('        discovery_receive_key = None\n','')
    start=reference.index('            small_discovery = ');end=reference.index('            elif upload:',start)
    reference=reference[:start]+'            if upload:'+reference[end+len('            elif upload:'):]
    reference=reference.replace('time.monotonic() + (5 if small_discovery else 30)','time.monotonic() + 30')
    reference=reference.replace('min(DISCOVERY_BODY_STALL_SECONDS, remaining) if discovery else remaining','remaining')
    start=reference.index('            if small_discovery:');end=reference.index('            if body:',start)
    reference=reference[:start]+reference[end:]
    reference=reference.replace('            if discovery_receiving:\n                self.discovery_receivers.release()\n                self.discovery_receiving_keys.discard(discovery_receive_key)\n','')
    refs[p]=reference
    # Documentation deltas retain every other task's current additions.
    summary=json.loads(read(OUT/'doc-fragment.json'))['summary']
    for p in ('AGENTS.md','DEVELOPMENT_STATUS.md'):
        text=read(ROOT/p);fragment=summary+'\n\n'
        if p=='AGENTS.md':fragment='## Discovery availability, short search and cost hardening override (2026-10-23)\n'+fragment
        refs[p]=text.replace(fragment,'',1)
    p='backend/README.md';text=read(ROOT/p)
    start=text.index('Discovery hardening (`0053_discovery_short_search`')
    end=text.index('Local priority scalability fixes (2026-10-23',start)
    refs[p]=text[:start]+text[end:]
    patch=[];metadata={}
    ref_folder=OUT/'checkpoint-baseline';ref_folder.mkdir(exist_ok=True)
    for p in paths:
        reference=refs[p];current=read(ROOT/p)
        if p.endswith('.py') and reference:ast.parse(reference)
        snapshot=p.replace('/','__');(ref_folder/snapshot).write_text(reference,encoding='utf-8',newline='\n')
        metadata[p]={'current_sha256':hashlib.sha256((ROOT/p).read_bytes()).hexdigest(),
            'reference_sha256':hashlib.sha256(reference.encode()).hexdigest(), 'reference':str(Path('checkpoint-baseline')/snapshot)}
        patch.extend(difflib.unified_diff(reference.splitlines(keepends=True),current.splitlines(keepends=True),
            fromfile='a/'+p if reference else '/dev/null',tofile='b/'+p,n=3))
    (OUT/'task-source.patch').write_text(''.join(patch),encoding='utf-8',newline='\n')
    dependencies=['backend/bmt_backend/discovery_guard.py','backend/bmt_backend/discovery_retention.py',
        'backend/bmt_backend/migrations/versions/0057_discovery_resource_guards.py','backend/bmt_backend/config.py',
        'backend/bmt_backend/client_address.py']
    value={'kind':'Task-scoped patch against reconstructed current baseline, preserving concurrent guard/retention/telemetry work; no mixed-tree commit',
        'patch':'task-source.patch','files':metadata,'shared_dependencies':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in dependencies},
        'notes':['Task-start originals remain in before/. Reconstructed references retain current concurrent work before reversing only this task changes.',
            'Integrated request admission and its durable credit/retention policy remain shared dependencies; this checkpoint does not claim exclusive authorship of those concurrent changes.']}
    (OUT/'source-checkpoint.json').write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
    return value


def main():
    primary=json.loads(read(OUT/'profile-results.json'))
    guarded=json.loads(read(OUT/'profile-guarded-results.json'))
    pairs=json.loads(read(OUT/'pair-cost-results.json'))
    checkpoint_data=checkpoint()
    report={'date':'2026-10-23','status':'Implemented and locally verified; not deployed',
        'requirements':{'DHF01':'Decouple bounded body ingress from bounded discovery query capacity; reject stalled/body-owner abuse.',
            'DHF02':'Stop failed-page automatic retry amplification; preserve cards, honor Retry-After and reset retry ownership.',
            'DHF03':'Schedule bounded cleanup as work and expose receipt/rank/pair/retention lag.',
            'DHF04':'One freshness round trip, narrow frozen keys, INSERT RETURNING and single sampled-slot query.',
            'DHF05':'Accelerate short exact substring searches without changing matches; preserve authority/deadline/Random contracts.',
            'DHF06':'Profile physical PostgreSQL index/heap/WAL costs and compact the exact pair-expiry work index.',
            'R01':'Preserve current authority, private scopes, frozen pages, uniform Random, driving and concurrent work.',
            'Q01':'Retain actual commands, results, baseline/control corrections, rollout limits and a scoped checkpoint.'},
        'verification':{'core':xml_result('postgres.xml'),'guarded_current':xml_result('guarded.xml'),
            'expiry_final':xml_result('expiry.xml'),'integrated':xml_result('final-integrated.xml'),
            'native_http':xml_result('http-integrated.xml'),
            'native':{'headless':82,'compatibility':85,'desktop_mobile':85,'legacy_pages':269,'free_race_list':233,
                'challenge_discovery':68,'app':141,'parser_scripts':939,'failures':0},
            'note':'Suites overlap. Core71 precedes the final compact expiry and shared guard integration; guarded17 and expiry2 cover final relevant behavior.'},
        'behavior_probe':json.loads(read(OUT/'backend-result.json')),
        'retry_probe':{'before':'../discovery-followup-2026-10-23/retry-result.json','after':json.loads(read(OUT/'retry-result.json'))},
        'measurements':{'guarded_100001':guarded,'earlier_100001_and_million':primary,'pair_storage_and_wal':pairs,
            'reader_notes':['Primary million probe measures stable optimized read core before later shared admission refinements and compact pair-expiry change.',
                'Guarded100001 comparison holds shared durable admission guards in both arms and reverses only discovery read methods in the control. Its recorded source files did not change during the run.',
                '25 successive local TestClient cursor pages, two-CPU/2GiB PostgreSQL17 container,128MiB shared buffers,fsync on; not concurrent HTTPS p95/p99.',
                'Synthetic source/projection is explicitly seeded with10000 creators. Seed/index-build time is excluded; resumable worker backfill throughput is not measured.',
                'Primary worker bursts are unthrottled step loops and exclude verification/HTTP/daemon sleeps. Checkpoint/heap layout differ between sequential phases; their WAL differences are observations, not attributed savings.',
                'Pair-cost probe separately uses fresh matched200000-row tables, checkpoint before WAL intervals, spread and tied timestamps. Bulk SQL is not worker or DAU throughput.']},
        'corrections_and_controls':['Initial new ASGI cursor tests used a different anonymous peer from TestClient and correctly received INVALID_CURSOR. The final fixtures preserve peer scope.',
            'Concurrent migration0054 first collided with a current-model index; subsequent concurrent revisions briefly had multiple/missing heads. Retained initial logs show these errors. The current single chain through0057 and matching migration fixes pass.',
            'The compact-expiry fixture gave all actors the same display name; the canonical username hook correctly rejected duplicates. Unique actual fixture names fix setup; exact128-row batch/counter assertions remain.',
            'A concurrent native compiler edit temporarily supplied six arguments to a four-argument method; final matching signatures pass all939 parser checks.',
            'The challenge UI fixture temporarily expected a removed visibility node during a concurrent approved redesign. The updated current fixture and an isolated task-original discovery-adapter control both pass68 checks; this task did not weaken that fixture.',
            'Project test entrypoint requires process execution-policy bypass on this host. Sandboxed native runs without an explicit log path hit Access denied; successful owned native/HTTP reruns and direct pinned-binary log-path checks are retained.',
            'Integrated overlapping admission changes initially duplicated a query semaphore acquisition. One shared bounded acquisition/release now serves both body classes; a dedicated simultaneous small/bulk regression passes.'],
        'rollout_and_remaining_acceptance':['Not deployed. Apply0053 before matching discovery API/worker; coordinate the current complete migration chain, shared resource guards and client update.',
            'Measure a representative-copy migration/backup/restore and plan live index locks, statement timeout, disk/WAL headroom and worker drain. Empty initial projection is the ordinary migration path; populated hosts need a reviewed maintenance/concurrent-index cutover.',
            'Load/soak with realistic concurrent authenticated users,500million-account index cardinality, large distinct seven-day pairs, retained changes/personal collections, hot-track skew, deletes and failure recovery. Measure p95/p99,retry rates,pool saturation,peak RSS,WAL/vacuum and oldest-work ages.',
            'Arbitrary filter combinations and exact selective Random retain explicit bounded retry responses; indexes do not guarantee every search is sublinear.',
            'No phone attachment check, physical-device test,APK,live backend/account/queue mutation or deployment. Owner/device and production capacity acceptance remain.'],
        'commands':['.tools/backend-secure-venv/Scripts/python.exe docs/evidence/discovery-hardening-2026-10-23/postgres_lab.py',
            '.tools/backend-secure-venv/Scripts/python.exe docs/evidence/discovery-hardening-2026-10-23/postgres_lab.py --cost-only --focused-expiry',
            '.tools/backend-secure-venv/Scripts/python.exe docs/evidence/discovery-hardening-2026-10-23/postgres_lab.py --guarded-small',
            '.tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_attack_resistance.py backend/tests/test_community_safety.py backend/tests/test_communication_boundary.py backend/tests/test_scalability_admission.py backend/tests/test_request_trace.py backend/tests/test_gcp_staging.py -q --tb=short -k "not postgres" --junitxml=docs/evidence/discovery-hardening-2026-10-23/final-integrated.xml',
            'PYTHONPATH=backend python -m pytest backend/tests/test_community_safety_http.py backend/tests/test_privacy_http.py -q --tb=short',
            'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_discovery_windows.gd -Graphical -RenderingMethod gl_compatibility (also mobile)',
            'Pinned Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/{test_discovery_windows,test_discovery_pages,test_free_race_list,test_challenge_discovery,test_app,test_script_parse}.gd --log-file <task-specific absolute file>',
            'python backend_probe.py; native retry_probe.gd and challenge_baseline_probe.gd; scoped Ruff; git apply --reverse --check task-source.patch'],
        'source_checkpoint':'source-checkpoint.json','source_file_count':len(checkpoint_data['files'])}
    (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Evidence report and scoped checkpoint written')


if __name__=='__main__':main()
