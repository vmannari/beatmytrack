"""Opt-in production-pipeline probe, exclusively in a disposable PostgreSQL schema.

Synthetic times/awards; real migrations, SQL settlement, HTTP reads and race worker.
This is capacity evidence, not cloud DAU or canonical-engine throughput certification.
"""
import json
import os
import threading
import time
from collections import defaultdict
from dataclasses import replace
from pathlib import Path

import pytest
from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import sessionmaker
from test_domains import domain as _domain_fixture
from test_domains import public_course, race
from test_world_ranking import LAUNCH

from bmt_backend import world_ranking_build as build
from bmt_backend.world_ranking_models import Circuit, RankingBranch, RankingControl, RankingSnapshot
from bmt_backend.world_ranking_rules import POLICY, WEEK

N = int(os.environ.get("BMT_RANKING_SCALE_PLAYERS", "0"))
ranking_domain = _domain_fixture
pytestmark = pytest.mark.skipif(N == 0, reason="Explicit disposable scale probe only")


def test_large_population_pipeline_and_foreground(ranking_domain, monkeypatch):
    if not ranking_domain.postgres:
        pytest.skip("PostgreSQL scale probe")
    assert 1000 <= N <= 1000000
    import resource
    domain, app = ranking_domain, ranking_domain.app
    settings = replace(app.state.settings, world_ranking_launch_week=LAUNCH,
                       world_ranking_batch_size=2000, world_ranking_statement_ms=30000)
    app.state.settings = settings
    version, _ = public_course(domain)
    monkeypatch.setattr(build, "now", lambda: LAUNCH-1)
    build.initialize(domain.factory, LAUNCH)
    with domain.factory() as db:
        schema = db.scalar(text("SELECT current_schema()"))
        assert schema.startswith("test_domains_")
        branch = db.scalar(select(RankingBranch))
        circuits = []
        for week in range(26):
            circuit = Circuit(week_start=LAUNCH+week*WEEK, contract_key="a"*64, policy=POLICY, tracks=[])
            db.add(circuit)
            db.flush()
            circuits.append(circuit.id)
        old = RankingSnapshot(branch_id=branch.id, circuit_id=circuits[-2],
            week_start=LAUNCH+24*WEEK, field_size=N, ranked_count=N, state="complete", published_at=LAUNCH+25*WEEK)
        db.add(old)
        db.flush()
        snapshot = RankingSnapshot(branch_id=branch.id, circuit_id=circuits[-1],
            week_start=LAUNCH+25*WEEK, field_size=N, previous_id=old.id)
        db.add(snapshot)
        db.flush()
        db.get(RankingControl, 1).published_id = old.id
        branch.next_week, branch.last_snapshot, branch.snapshot_id, branch.phase = snapshot.week_start, old.id, snapshot.id, "track0"
        old_id, target_id, branch_id = old.id, snapshot.id, branch.id
        db.commit()
    # Seed on the test connection only. All production stages retain their 30s limit.
    with app.state.engine.begin() as connection:
        connection.exec_driver_sql("SET LOCAL statement_timeout = 180000")
        connection.execute(text("""INSERT INTO players
          (id,display_name,username_key,country_code,needs_username,disabled,analytics_enabled,is_test_driver,created_at)
          SELECT '10000000-0000-0000-0000-'||lpad(i::text,12,'0'), 'ScaleDriver'||i,
                 'scaledriver'||i, CASE WHEN i%2=0 THEN 'FI' ELSE 'SE' END,false,false,false,false,:launch
          FROM generate_series(1,:n) i"""), {"n": N, "launch": LAUNCH})
        connection.execute(text("""INSERT INTO world_ranking_players (key,player_id)
          SELECT i,'10000000-0000-0000-0000-'||lpad(i::text,12,'0') FROM generate_series(1,:n) i"""), {"n": N})
        connection.execute(text("""INSERT INTO world_ranking_standings
          (snapshot_id,player_key,total,world_rank,country,country_rank,season_points,season_rank)
          SELECT :sid,i,12000-(i%1000),i,CASE WHEN i%2=0 THEN 'FI' ELSE 'SE' END,
                 (i+1)/2,6000-(i%1000),i FROM generate_series(1,:n) i"""), {"sid": old_id, "n": N})
        connection.execute(text("""INSERT INTO world_work_inputs (snapshot_id,player_key,t0,t1,t2,t3,t4,country)
          SELECT :sid,i,1000+i,1000+(i*17)%:n,1000+(i*37)%:n,1000+(i*53)%:n,1000+(i*79)%:n,
                 CASE WHEN i%2=0 THEN 'FI' ELSE 'SE' END FROM generate_series(1,:n) i"""), {"sid": target_id, "n": N})
    for circuit_id in circuits[:-1]:
        with app.state.engine.begin() as connection:
            connection.exec_driver_sql("SET LOCAL statement_timeout = 180000")
            connection.execute(text("""INSERT INTO world_ranking_awards (branch_id,circuit_id,player_key,points,weekly_place)
              SELECT :branch,:circuit,i,CASE WHEN i=1 THEN 1000 ELSE greatest(1,floor(sqrt(56250000.0/(i+96)))) END,
                     i FROM generate_series(1,:n) i"""), {"branch":branch_id,"circuit":circuit_id,"n":N})
    with app.state.engine.begin() as connection:
        for table in ("world_ranking_awards", "world_work_inputs", "world_ranking_standings", "players", "world_ranking_players"):
            connection.exec_driver_sql("ANALYZE "+table)
    probe_id = "10000000-0000-0000-0000-000000000001"
    probe_headers = {"x-test-player":probe_id}
    # Dedicated one-connection worker engine, matching production's independent pool.
    worker_engine = create_engine(str(app.state.engine.url), pool_size=1, max_overflow=0,
        connect_args={"options":f"-c search_path={schema} -c statement_timeout=30000"})
    factory = sessionmaker(worker_engine, expire_on_commit=False)
    foreground, baseline, phases, failures = defaultdict(list), defaultdict(list), defaultdict(list), []
    seen = set()
    stop = threading.Event()
    samples = []
    report_path = Path("/evidence") / f"scale-{N}.json"
    progress = Path("/evidence") / f"scale-{N}-progress.json"

    def reads(destination):
        for path in ("/v1/me", "/v1/ranking/me", "/v1/ranking", "/v1/ranking?scope=country", "/v1/ranking?around=true"):
            start = time.perf_counter()
            response = domain.client.get(path, headers=probe_headers)
            destination[path].append((time.perf_counter()-start)*1000)
            assert response.status_code == 200, (path, response.status_code, response.text[:200])
            if path == "/v1/ranking":
                assert len(response.json()["items"]) == 50
                seen.add(response.json()["snapshot_id"])

    def foreground_loop():
        try:
            while not stop.is_set():
                reads(foreground)
                # Exercise existing race submission, PB acceptance and result polling.
                start = time.perf_counter()
                result = race(domain, version, player="Alice", frames=30+len(samples)%20)
                assert result["status"] == "verified"
                samples.append((time.perf_counter()-start)*1000)
                stop.wait(.2)
        except Exception as exc:  # noqa: BLE001 - report thread failures in the main assertion
            failures.append(repr(exc))
            stop.set()

    for _ in range(5):
        reads(baseline)
    rss_start = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    start = time.perf_counter()
    thread = threading.Thread(target=foreground_loop)
    thread.start()
    complete = False
    try:
        for steps in range(20000):
            assert not failures, failures
            with factory() as db:
                phase = db.get(RankingBranch, branch_id).phase
            if phase == "idle":
                complete = True
                break
            tick = time.perf_counter()
            build.step(factory, app.state.blobs, settings)
            phases[phase].append(time.perf_counter()-tick)
            if steps%50 == 0:
                progress.write_text(json.dumps({"steps":steps,"phase":phase,"seconds":time.perf_counter()-start}))
            time.sleep(.025)
        assert complete
    finally:
        stop.set()
        thread.join(30)
        worker_engine.dispose()
    assert not failures and not thread.is_alive(), failures
    reads(foreground)
    assert seen <= {old_id,target_id} and target_id in seen
    with domain.factory() as db:
        assert db.get(RankingControl,1).published_id == target_id
        assert db.get(RankingSnapshot,target_id).ranked_count == N
        assert db.scalar(text("SELECT count(*) FROM world_ranking_awards")) == 26*N
        assert db.scalar(text("SELECT count(*) FROM world_work_inputs")) == 0
        assert db.scalar(text("SELECT count(*) FROM world_work_places")) == 0
        storage = list(db.execute(text("""SELECT relname,pg_total_relation_size(relid)
          FROM pg_catalog.pg_statio_user_tables WHERE schemaname=current_schema() AND relname LIKE 'world_%'
          ORDER BY relname""")))
        temporary_bytes = db.scalar(text("SELECT temp_bytes FROM pg_stat_database WHERE datname=current_database()"))
    def distribution(values):
        ordered = sorted(values)
        return {"n":len(ordered),"median_ms":ordered[len(ordered)//2],
                "p95_ms":ordered[min(len(ordered)-1,int(len(ordered)*.95))],"max_ms":max(ordered)}
    report = {"players":N,"award_rows":26*N,"seconds":time.perf_counter()-start,
        "steps":steps,"worker_connections":1,"database_cpu_limit":1,"database_memory_limit_gib":2,
        "work_mem_mib":16,"statement_limit_seconds":30,"pause_ms":25,
        "baseline":{k:distribution(v) for k,v in baseline.items()},
        "foreground":{k:distribution(v) for k,v in foreground.items()},
        "race_fake_verifier":distribution(samples),"seen_snapshots":sorted(seen),
        "phase_seconds":{k:{"steps":len(v),"total":sum(v),"max":max(v)} for k,v in phases.items()},
        "process_rss_start_kib":rss_start,"process_peak_rss_kib":resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        "relation_bytes":dict(storage),"database_temp_bytes":temporary_bytes,
        "limits":"Local synthetic inputs; FakeVerifier, in-process HTTP, no cloud/network/mobile/DAU claim"}
    report_path.write_text(json.dumps(report,indent=2))
    print(json.dumps(report))


def test_large_career_retention(ranking_domain,monkeypatch):
    """Three interleaved generations must prune linearly, preserving inactive facts."""
    if not ranking_domain.postgres: pytest.skip("PostgreSQL scale probe")
    assert 1000 <= N <= 1000000
    app,domain = ranking_domain.app,ranking_domain
    settings = replace(app.state.settings,world_ranking_launch_week=LAUNCH,world_ranking_batch_size=2000)
    monkeypatch.setattr(build,"now",lambda:LAUNCH-1)
    build.initialize(domain.factory,LAUNCH)
    with domain.factory() as db:
        branch = db.scalar(select(RankingBranch))
        circuit = Circuit(week_start=LAUNCH,contract_key="a"*64,policy=POLICY,tracks=[])
        db.add(circuit)
        db.flush()
        snapshots = []
        for week in range(3):
            row = RankingSnapshot(branch_id=branch.id,circuit_id=circuit.id,week_start=LAUNCH+week*WEEK)
            db.add(row)
            db.flush()
            snapshots.append(row.id)
        target = db.get(RankingSnapshot,snapshots[-1])
        target.previous_id = snapshots[-2]
        branch.phase,branch.snapshot_id = "cleanup6",target.id
        control = db.get(RankingControl,1)
        control.published_id,control.previous_id = target.id,target.previous_id
        branch_id = branch.id
        db.commit()
    for generation in snapshots:
        with app.state.engine.begin() as connection:
            connection.exec_driver_sql("SET LOCAL statement_timeout = 180000")
            connection.execute(text("""INSERT INTO world_ranking_careers
              (branch_id,player_key,generation,peak_rank,peak_week,peak_field,weeks_top100,weeks_no1,victories,season_titles)
              SELECT :branch,i,:generation,1,:launch,:n,8,2,3,1 FROM generate_series(1,:n) i"""),
              {"branch":branch_id,"generation":generation,"launch":LAUNCH,"n":N})
    with app.state.engine.begin() as connection:
        connection.execute(text("""INSERT INTO world_ranking_careers
          (branch_id,player_key,generation,peak_rank,peak_week,peak_field,weeks_top100,weeks_no1,victories,season_titles)
          VALUES (:branch,:key,:generation,9,:launch,:n,8,2,3,1)"""),
          {"branch":branch_id,"key":N+1,"generation":snapshots[0],"launch":LAUNCH,"n":N})
        connection.exec_driver_sql("ANALYZE world_ranking_careers")
    monkeypatch.setattr(build,"now",lambda:LAUNCH+3*WEEK)
    start = time.perf_counter()
    for step in range(2*N//2000+20):
        build.step(domain.factory,app.state.blobs,settings)
        with domain.factory() as db:
            if db.get(RankingBranch,branch_id).phase != "cleanup6": break
    else: raise AssertionError("Career pruning did not advance through bounded key ranges")
    elapsed = time.perf_counter()-start
    with domain.factory() as db:
        assert db.scalar(text("SELECT count(*) FROM world_ranking_careers")) == 2*N+1
        assert db.scalar(text("SELECT count(*) FROM world_ranking_careers WHERE generation=:g AND player_key<=:n"),
            {"g":snapshots[0],"n":N}) == 0
        assert db.scalar(text("SELECT weeks_top100 FROM world_ranking_careers WHERE player_key=:key"),{"key":N+1}) == 8
    Path(f"/evidence/career-retention-{N}.json").write_text(json.dumps({"players":N,"initial_rows":3*N+1,
        "retained_rows":2*N+1,"seconds":elapsed,"steps":step+1,"batch_size":2000,
        "limits":"One CPU / 2 GiB disposable PostgreSQL; real phase cleanup6; no cloud/DAU claim"},indent=2))
