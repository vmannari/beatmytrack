"""Disposable HTTP/DB/worker load lab. Never targets or resets a deployed API.

python -m bmt_backend.loadtest --players 10000 --clients 12 --duration 30
Use BMT_LOAD_DATABASE_URL or --database-env for an isolated PostgreSQL schema.
"""
from __future__ import annotations

import argparse
import asyncio
import ctypes
import gzip
import json
import math
import multiprocessing
import os
import platform
import random
import secrets
import socket
import statistics
import tempfile
import threading
import time
import uuid
from collections import Counter
from pathlib import Path
from urllib.parse import urlsplit

import httpx
import uvicorn
from fastapi import Header, HTTPException
from sqlalchemy import create_engine, event, select, text

from .app import create_app
from .config import Settings
from .db import make_engine
from .load_fixtures import SyntheticVerifier, golden_fixture, pack_replay, seed
from .migrate import upgrade
from .track_models import QueueCapacity, Run, now
from .verifier import GodotVerifier


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    return ordered[min(len(ordered)-1,math.ceil(len(ordered)*fraction)-1)]


def rss_bytes(pid=None):
    pid = pid or os.getpid()
    if os.name != "nt":
        try:
            for line in Path(f"/proc/{pid}/status").read_text().splitlines():
                if line.startswith("VmRSS:"):
                    return int(line.split()[1])*1024
        except (OSError,ValueError):
            return None
    else:
        class Counters(ctypes.Structure):
            _fields_ = [("cb",ctypes.c_ulong),("PageFaultCount",ctypes.c_ulong)]+[(name,ctypes.c_size_t) for name in
                ("PeakWorkingSetSize","WorkingSetSize","QuotaPeakPagedPoolUsage","QuotaPagedPoolUsage",
                 "QuotaPeakNonPagedPoolUsage","QuotaNonPagedPoolUsage","PagefileUsage","PeakPagefileUsage")]
        kernel = ctypes.WinDLL("kernel32",use_last_error=True)
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        psapi = ctypes.WinDLL("psapi",use_last_error=True)
        psapi.GetProcessMemoryInfo.argtypes = [ctypes.c_void_p,ctypes.c_void_p,ctypes.c_ulong]
        handle = kernel.OpenProcess(0x0400|0x0010,False,pid)
        if not handle:
            return None
        data = Counters(); data.cb = ctypes.sizeof(data)
        try:
            return int(data.WorkingSetSize) if psapi.GetProcessMemoryInfo(handle,ctypes.byref(data),data.cb) else None
        finally:
            kernel.CloseHandle(handle)


class SQLMetrics:
    def __init__(self, engine):
        self.lock, self.counts, self.durations, self.waits = threading.Lock(), Counter(), [], []
        self.pool_peak = 0
        event.listen(engine,"before_cursor_execute",self.before)
        event.listen(engine,"after_cursor_execute",self.after)
        original = engine.pool._do_get
        def timed_get():
            start = time.perf_counter()
            try:
                return original()
            finally:
                with self.lock:
                    self.waits.append((time.perf_counter()-start)*1000)
                    if len(self.waits)>100000:
                        self.waits.pop(0)
        engine.pool._do_get = timed_get
        if hasattr(engine.pool,"checkedout"):
            def checkout(*_args):
                with self.lock:
                    self.pool_peak = max(self.pool_peak,engine.pool.checkedout())
            event.listen(engine,"checkout",checkout)

    def before(self, _connection, _cursor, statement, _parameters, context, _many):
        context._load_started = time.perf_counter()
        with self.lock:
            self.counts[statement.lstrip().split(None,1)[0].upper()] += 1

    def after(self, _connection, _cursor, _statement, _parameters, context, _many):
        with self.lock:
            self.durations.append((time.perf_counter()-context._load_started)*1000)
            if len(self.durations)>100000:
                self.durations.pop(0)

    def snapshot(self):
        with self.lock:
            return {"statements":dict(self.counts),"sql_p95_ms":percentile(self.durations,.95),
                "pool_wait_p95_ms":percentile(self.waits,.95),"pool_wait_max_ms":max(self.waits,default=0),"pool_peak":self.pool_peak}


def app_for(config):
    settings = Settings(**config["settings"])
    engine = make_engine(settings.database_url,settings,schema=config["schema"])
    verifier = GodotVerifier(settings) if config["canonical"] else SyntheticVerifier(golden_fixture())
    return create_app(settings,engine=engine,verifier=verifier)


def server_process(config, port, stop, token, metrics_file, log_file):
    # The diagnostic endpoint exists only in this isolated, loopback load process.
    with open(log_file,"w",encoding="utf8",buffering=1) as output:
        import sys
        sys.stdout,sys.stderr = output,output
        app = app_for(config)
        metrics = SQLMetrics(app.state.engine)
        peak = [rss_bytes() or 0]
        @app.get("/__load/metrics")
        def diagnostics(x_load_token: str = Header(default="")):
            if not secrets.compare_digest(x_load_token,token):
                raise HTTPException(404,"NOT_FOUND")
            peak[0] = max(peak[0],rss_bytes() or 0)
            return {**metrics.snapshot(),"rss_bytes":rss_bytes(),"rss_peak_bytes":peak[0]}
        server = uvicorn.Server(uvicorn.Config(app,host="127.0.0.1",port=port,log_level="warning",
            access_log=False,limit_concurrency=24,timeout_keep_alive=5))
        def monitor():
            while not stop.wait(.1):
                peak[0] = max(peak[0],rss_bytes() or 0)
            server.should_exit = True
        thread = threading.Thread(target=monitor,daemon=True);thread.start()
        try:
            server.run()
        finally:
            Path(metrics_file).write_text(json.dumps({**metrics.snapshot(),"rss_peak_bytes":peak[0]}))
            if hasattr(app.state.verifier,"close"):
                app.state.verifier.close()
            app.state.engine.dispose()


def worker_process(config, stop, log_file, metrics_file):
    from .worker import process_worker_job
    with open(log_file,"w",encoding="utf8",buffering=1) as output:
        import sys
        sys.stdout,sys.stderr = output,output
        app = app_for(config)
        peaks={"python_rss_peak_bytes":0,"canonical_rss_peak_bytes":0}
        metric_stop=threading.Event()
        def sample():
            while not metric_stop.wait(.1):
                peaks["python_rss_peak_bytes"]=max(peaks["python_rss_peak_bytes"],rss_bytes() or 0)
                engine_pid=getattr(app.state.verifier,"engine_pid",None)
                if engine_pid:
                    peaks["canonical_rss_peak_bytes"]=max(peaks["canonical_rss_peak_bytes"],rss_bytes(engine_pid) or 0)
        sampler=threading.Thread(target=sample,daemon=True);sampler.start()
        try:
            while not stop.is_set():
                try:
                    if not process_worker_job(app):
                        stop.wait(.05)
                except Exception as error:  # noqa: BLE001 - exercise fenced worker recovery
                    print("load_worker_failure",type(error).__name__,flush=True)
                    stop.wait(.1)
        finally:
            metric_stop.set();sampler.join(timeout=2)
            Path(metrics_file).write_text(json.dumps(peaks))
            if hasattr(app.state.verifier,"close"):
                app.state.verifier.close()
            app.state.engine.dispose()


def new_key():
    return f"v2.{now()}.{secrets.token_hex(24)}"


async def exercise(origins, data, args):
    """Closed loop or bounded open loop; scheduled latency catches generator queuing."""
    deadline, start = time.perf_counter()+args.duration,time.perf_counter()
    samples, codes, requests_by_kind, upload_bytes = [], Counter(), Counter(), []
    etags, tickets, submitted, duplicate_bodies = {}, {}, {}, {}
    fixture = data["fixture"]
    replay = pack_replay(fixture["replay"])
    capacity = asyncio.Semaphore(args.clients)
    actor_locks = [asyncio.Lock() for _ in range(data["actors"])]
    dropped = 0
    invalid_responses = 0
    accepted_runs = set()
    joined_actors = set()
    async with httpx.AsyncClient(timeout=15,limits=httpx.Limits(max_connections=args.clients,max_keepalive_connections=args.clients)) as client:
        async def perform(index, scheduled):
            nonlocal dropped, invalid_responses
            actor = index%data["actors"]
            origin = origins[index%len(origins)]
            headers = {"Authorization":"Bearer "+data["access"][actor],"Accept-Encoding":"gzip"}
            kind = ("discovery","top","around","histogram","rivalry","current")[index%6]
            path = {"discovery":"/v1/tracks?limit=20","top":f"/v1/boards/{data['boards'][0]}?limit=20",
                "around":f"/v1/boards/{data['boards'][0]}/around-me","histogram":f"/v1/boards/{data['boards'][0]}/histogram",
                "rivalry":f"/v1/rivalry/{data['groups'][actor//20]}" if data["groups"] else "/v1/rivalry/current?vehicle_id=compact",
                "current":"/v1/rivalry/current?vehicle_id=compact"}[kind]
            if args.ghosts and data["groups"] and index%12==6:
                kind="ghost"
                path=f"/v1/rivalry/{data['groups'][actor//20]}/tracks/0/ghosts/{data['players'][actor]}"
            body,method = None,"GET"
            # Actor locks below prevent two clients from replacing one outbox job.
            if args.scenario=="mixed" and random.Random(42+index).randrange(100)<15:
                if actor not in tickets:
                    kind,path,method = "ticket","/v1/run-tickets","POST"
                    body={"version_id":data["versions"][0],"vehicle_id":"compact"}
                elif actor not in submitted:
                    kind,path,method = "upload","/v1/runs","POST"
                    body={"ticket_id":tickets[actor],"replay":replay}
                else:
                    kind,path = "status",f"/v1/runs/status?ids={submitted[actor]}"
            elif args.scenario=="joins":
                kind,path,method,body = "join" if actor in joined_actors else "first_join","/v1/rivalry/join","POST",{"vehicle_id":"compact"}
            encoded = b""
            if body is not None:
                key = new_key()
                if kind=="upload":
                    key = duplicate_bodies.setdefault(actor,key)
                headers["Idempotency-Key"],headers["Content-Type"] = key,"application/json"
                encoded = json.dumps(body,separators=(",",":")).encode()
                if len(encoded)>1024:
                    encoded=gzip.compress(encoded,compresslevel=3,mtime=0);headers["Content-Encoding"]="gzip"
            cache_key = (actor,path)
            if method=="GET" and cache_key in etags:
                headers["If-None-Match"] = etags[cache_key]
            begun=time.perf_counter()
            try:
                async with client.stream(method,origin+path,headers=headers,content=encoded) as response:
                    wire = b"".join([chunk async for chunk in response.aiter_raw()])
                    code=response.status_code
                    try:
                        decoded = gzip.decompress(wire) if response.headers.get("content-encoding")=="gzip" else wire
                        value = json.loads(decoded) if decoded else {}
                    except (ValueError,OSError):
                        value = {}
                        if code < 400:
                            invalid_responses += 1
                    if response.headers.get("etag"):
                        etags[cache_key]=response.headers["etag"]
                    if code==201 and kind=="ticket":
                        tickets[actor]=value["ticket_id"]
                    if code==202 and kind=="upload":
                        submitted[actor]=value["run_id"]
                        accepted_runs.add(value["run_id"])
                        upload_bytes.append(len(encoded))
                    if code==200 and kind in ("join","first_join"):
                        joined_actors.add(actor)
                    if code==200 and kind=="status" and value.get("items") and value["items"][0]["status"] in ("verified","failed","rejected"):
                        submitted.pop(actor,None);tickets.pop(actor,None);duplicate_bodies.pop(actor,None)
            except (httpx.HTTPError,ValueError,KeyError):
                code,wire=0,b""
            samples.append({"kind":kind,"status":code,"latency_ms":(time.perf_counter()-begun)*1000,
                "scheduled_latency_ms":(time.perf_counter()-scheduled)*1000,"request_bytes":len(encoded),"response_bytes":len(wire)})
            codes[code]+=1;requests_by_kind[kind]+=1
        tasks=set();index=0
        async def bounded(index, scheduled):
            try:
                async with actor_locks[index%data["actors"]]:
                    await perform(index,scheduled)
            finally:
                capacity.release()
        while time.perf_counter()<deadline and len(samples)<args.max_requests:
            scheduled = start+index/args.arrival_rate if args.arrival_rate else time.perf_counter()
            if args.arrival_rate and scheduled>time.perf_counter():
                await asyncio.sleep(min(scheduled-time.perf_counter(),max(0,deadline-time.perf_counter())))
            if time.perf_counter()>=deadline:
                break
            if args.arrival_rate and capacity.locked():
                dropped+=1;index+=1;continue
            await capacity.acquire()
            task=asyncio.create_task(bounded(index,scheduled));tasks.add(task);task.add_done_callback(tasks.discard)
            index+=1
        if tasks:
            await asyncio.gather(*tasks)
    elapsed=time.perf_counter()-start
    by_kind={}
    for kind in requests_by_kind:
        rows=[row for row in samples if row["kind"]==kind]
        latencies=[row["latency_ms"] for row in rows]
        by_kind[kind]={"requests":len(rows),"p50_ms":percentile(latencies,.5),"p95_ms":percentile(latencies,.95),
            "p99_ms":percentile(latencies,.99),"response_bytes_mean":statistics.mean(r["response_bytes"] for r in rows),
            "request_bytes_mean":statistics.mean(r["request_bytes"] for r in rows)}
    return {"elapsed_seconds":elapsed,"requests":len(samples),"rps":len(samples)/elapsed,"status_codes":dict(codes),
        "generator_dropped":dropped,"scheduled_p95_ms":percentile([r["scheduled_latency_ms"] for r in samples],.95),
        "request_body_wire_bytes":sum(r["request_bytes"] for r in samples),"response_body_wire_bytes":sum(r["response_bytes"] for r in samples),
        "by_kind":by_kind,"accepted_uploads":len(accepted_runs),"upload_wire_bytes":upload_bytes,"invalid_success_responses":invalid_responses}


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1",0))
        return sock.getsockname()[1]


def database_url(args):
    value=os.environ.get("BMT_LOAD_DATABASE_URL","")
    if args.database_env:
        entries=dict(line.split("=",1) for line in Path(args.database_env).read_text().splitlines() if "=" in line and not line.startswith("#"))
        value=entries.get("BMT_LOAD_DATABASE_URL",entries.get("BMT_TEST_DATABASE_URL",""))
    if value and (not value.startswith("postgresql+psycopg://") or urlsplit(value).hostname not in ("localhost","127.0.0.1","::1")):
        raise ValueError("Use a disposable loopback PostgreSQL database; live API/database targets are forbidden")
    return value


def explain(app, data):
    if app.state.engine.dialect.name!="postgresql":
        return {"status":"not_postgresql"}
    from .identity_models import Player
    from .rivalry import eligible_query
    from .track_models import BoardTimeCount, PersonalBest
    statements={"top":select(PersonalBest).join(Player).where(PersonalBest.board_id==data["boards"][0],
            Player.disabled.is_(False),Player.is_test_driver.is_(False)).order_by(PersonalBest.time_ticks,PersonalBest.player_id).limit(20),
        "tick_range":select(BoardTimeCount).where(BoardTimeCount.board_id==data["boards"][0],BoardTimeCount.time_ticks<13000),
        "eligibility":eligible_query(app.state.verifier.manifest(),"compact").limit(5)}
    with app.state.engine.connect() as connection:
        connection.execute(text("ANALYZE"))
        return {key:connection.exec_driver_sql("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) "+str(statement.compile(
            dialect=connection.dialect,compile_kwargs={"literal_binds":True}))).scalar() for key,statement in statements.items()}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-env")
    parser.add_argument("--players",type=int,default=1000)
    parser.add_argument("--tracks",type=int,default=100)
    parser.add_argument("--clients",type=int,default=8)
    parser.add_argument("--actors",type=int,default=40)
    parser.add_argument("--replicas",type=int,default=1)
    parser.add_argument("--workers",type=int,default=1)
    parser.add_argument("--duration",type=float,default=15)
    parser.add_argument("--arrival-rate",type=float,default=0)
    parser.add_argument("--max-requests",type=int,default=50000)
    parser.add_argument("--scenario",choices=("reads","mixed","joins"),default="mixed")
    parser.add_argument("--canonical",action="store_true")
    parser.add_argument("--ghosts",action="store_true",help="Include representative 20 Hz derived ghost reads")
    parser.add_argument("--godot-bin",default=os.environ.get("BMT_GODOT_BIN",r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"))
    parser.add_argument("--output",type=Path,default=Path("build/backend-scalability/load-report.json"))
    parser.add_argument("--p95-budget-ms",type=float,default=0)
    parser.add_argument("--latency-budgets",type=Path,help="Optional JSON object mapping endpoint kinds to p95 milliseconds")
    parser.add_argument("--max-error-fraction",type=float,default=.01)
    parser.add_argument("--drain-seconds",type=float,default=15)
    parser.add_argument("--queue-age-budget-seconds",type=float,default=0)
    parser.add_argument("--require-drained",action="store_true")
    parser.add_argument("--tie-every",type=int,default=0)
    args=parser.parse_args()
    if (not 5<=args.tracks<=100000 or not 5<=args.players<=1000000 or not 1<=args.clients<=128
            or not 1<=args.replicas<=8 or not 0<=args.workers<=32 or not 0<args.duration<=3600 or args.actors<1
            or args.arrival_rate<0 or not 1<=args.max_requests<=500000 or not 0<=args.max_error_fraction<=1
            or not 0<=args.drain_seconds<=300 or args.queue_age_budget_seconds<0):
        parser.error("Invalid or excessive fixture/load bounds")
    url=database_url(args)
    budgets=json.loads(args.latency_budgets.read_text()) if args.latency_budgets else {}
    if type(budgets) is not dict or any(type(v) not in (int,float) or not 0<v<=60000 for v in budgets.values()):
        parser.error("Latency budgets must map endpoint names to positive milliseconds")
    context=multiprocessing.get_context("spawn")
    stop=context.Event();processes=[];admin=None;schema=""
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bmt-load-") as folder:
        root=Path(folder)
        settings=Settings(environment="test",database_url=url or f"sqlite:///{(root/'load.sqlite').as_posix()}",
            object_dir=str(root/"objects"),godot_bin=args.godot_bin,dev_auth_enabled=False,
            rate_limit_per_minute=600,edge_limit_per_minute=12000,write_limit_per_minute=90)
        if url:
            schema="bmt_load_"+uuid.uuid4().hex
            admin=create_engine(url,pool_size=1,max_overflow=0,pool_timeout=3,connect_args={"connect_timeout":3})
            with admin.begin() as connection:
                connection.exec_driver_sql(f'CREATE SCHEMA "{schema}"')
        config={"settings":{name:getattr(settings,name) for name in settings.__dataclass_fields__},"schema":schema,"canonical":args.canonical}
        app=app_for(config)
        try:
            upgrade(app.state.engine)
            print(f"Seeding {args.players} synthetic players / {args.tracks} versions in disposable {'PostgreSQL schema' if url else 'SQLite file'}",flush=True)
            data=seed(app,players=args.players,tracks=args.tracks,actors=args.actors,tie_every=args.tie_every,memberships=args.scenario!="joins")
            # Seed preparation is outside request timing, like PB construction.
            # Real requests must exercise stored histograms, never build them.
            from .histogram_snapshots import refresh_all_for_diagnostics
            refresh_all_for_diagnostics(app)
            plans=explain(app,data)
            ports=[free_port() for _ in range(args.replicas)]
            token=secrets.token_hex(24)
            for i,port in enumerate(ports):
                child=context.Process(target=server_process,args=(config,port,stop,token,str(root/f"api-{i}.json"),str(args.output.with_suffix(f".api-{i}.log"))))
                child.start();processes.append(child)
            for i in range(args.workers):
                child_config=copy_config(config,pool=2)
                child=context.Process(target=worker_process,args=(child_config,stop,str(args.output.with_suffix(f".worker-{i}.log")),str(root/f"worker-{i}.json")))
                child.start();processes.append(child)
            origins=[f"http://127.0.0.1:{port}" for port in ports]
            for origin in origins:
                deadline=time.perf_counter()+30
                while True:
                    try:
                        if httpx.get(origin+"/healthz",timeout=1).status_code==200:
                            break
                    except httpx.HTTPError:
                        pass
                    if time.perf_counter()>deadline:
                        raise RuntimeError("Disposable API did not start")
                    time.sleep(.1)
            print(f"Running {args.scenario}: {args.clients} clients, {args.replicas} APIs, {args.workers} {'canonical' if args.canonical else 'synthetic'} workers",flush=True)
            monitoring=[]
            monitor_stop=threading.Event()
            def monitor():
                while not monitor_stop.wait(.5):
                    try:
                        with app.state.session_factory() as session:
                            depth=session.scalar(select(QueueCapacity.pending).where(QueueCapacity.id==1))
                            oldest=session.scalar(select(func_min(Run.created_at)).where(Run.status.in_(("queued","verifying"))))
                        monitoring.append({"at":time.perf_counter(),"depth":depth,"oldest_age_seconds":max(0,now()-oldest) if oldest else 0,
                            "worker_rss_bytes":[rss_bytes(p.pid) for p in processes[len(ports):]]})
                    except Exception as error:  # noqa: BLE001 - retain diagnostic even after DB failure
                        monitoring.append({"at":time.perf_counter(),"error":type(error).__name__})
            monitor_thread=threading.Thread(target=monitor,daemon=True);monitor_thread.start()
            workload_start=now()
            report=asyncio.run(exercise(origins,data,args))
            recovery=[]
            for origin in origins:
                begun=time.perf_counter()
                response=httpx.get(origin+"/v1/tracks?limit=20",timeout=5)
                recovery.append({"status":response.status_code,"latency_ms":(time.perf_counter()-begun)*1000})
            report["post_load_recovery"]=recovery
            deadline=time.perf_counter()+args.drain_seconds
            while time.perf_counter()<deadline:
                with app.state.session_factory() as session:
                    if session.scalar(select(QueueCapacity.pending).where(QueueCapacity.id==1))==0:
                        break
                time.sleep(.2)
            monitor_stop.set();monitor_thread.join(timeout=2)
            api_metrics=[httpx.get(origin+"/__load/metrics",headers={"X-Load-Token":token},timeout=5).json() for origin in origins]
            with app.state.session_factory() as session:
                from sqlalchemy import func
                outcomes=dict(session.execute(select(Run.status,func.count()).where(Run.created_at>=workload_start).group_by(Run.status)).all())
                queue_end=session.scalar(select(QueueCapacity.pending).where(QueueCapacity.id==1))
            report.update({"fixture":{"players":args.players,"tracks":args.tracks,"database":"postgresql" if url else "sqlite",
                    "synthetic_seed":True,"verification":"canonical" if args.canonical else "synthetic_adapter",
                    "clients":args.clients,"api_replicas":args.replicas,"workers":args.workers,"arrival_rate":args.arrival_rate},
                "api_processes":api_metrics,"queue_samples":monitoring,"queue_end":queue_end,"load_run_statuses":outcomes,
                "postgres_explain":plans,"connection_budget":{"api":args.replicas*4,"workers":args.workers*2,"harness":4,
                    "admin":1,"total_max":args.replicas*4+args.workers*2+4+1},
                "limits":"Loopback laboratory; excludes proxy/TLS/mobile/NAS. Response bytes are compressed bodies, excluding HTTP/TLS overhead."})
            report["host"]={"platform":platform.platform(),"python":platform.python_version(),"logical_cpus":os.cpu_count()}
            errors=sum(count for code,count in report["status_codes"].items() if int(code) in (0,429) or int(code)>=500)
            violations=[]
            if errors/max(1,report["requests"])>args.max_error_fraction or report["invalid_success_responses"]:
                violations.append("server/transport error fraction")
            if any(budgets.get(kind,args.p95_budget_ms) and value["p95_ms"]>budgets.get(kind,args.p95_budget_ms)
                   for kind,value in report["by_kind"].items()):
                violations.append("p95 latency budget")
            report["latency_budgets_ms"]={kind:budgets.get(kind,args.p95_budget_ms) for kind in report["by_kind"]}
            if report["generator_dropped"]:
                violations.append("load generator concurrency saturated")
            if args.require_drained and queue_end:
                violations.append("verification queue did not drain")
            if args.queue_age_budget_seconds and max((row.get("oldest_age_seconds",0) for row in monitoring),default=0)>args.queue_age_budget_seconds:
                violations.append("verification queue age budget")
            report["budget_violations"]=violations
            stop.set()
            for child in processes[len(ports):]:
                child.join(timeout=30)
            report["worker_processes"]=[json.loads((root/f"worker-{i}.json").read_text())
                if (root/f"worker-{i}.json").exists() else {"error":"worker failed to report/shut down"} for i in range(args.workers)]
            args.output.write_text(json.dumps(report,indent=2),encoding="utf8")
            print(f"Completed {report['requests']} requests / {report['rps']:.1f} RPS; codes {report['status_codes']}; queue end {queue_end}; violations {violations}",flush=True)
        finally:
            stop.set()
            for child in processes:
                child.join(timeout=30)
                if child.is_alive():
                    child.terminate();child.join(timeout=5)
            if hasattr(app.state.verifier,"close"):
                app.state.verifier.close()
            app.state.engine.dispose()
            if admin:
                with admin.begin() as connection:
                    connection.exec_driver_sql(f'DROP SCHEMA "{schema}" CASCADE')
                admin.dispose()
    raise SystemExit(1 if report["budget_violations"] else 0)


def func_min(column):
    from sqlalchemy import func
    return func.min(column)


def copy_config(config, pool):
    return {**config,"settings":{**config["settings"],"database_pool_size":pool}}


if __name__ == "__main__":
    main()
