"""Offline SQL capacity probe. Only owns a newly labelled disposable database.

Not shipping ranking code: dense synthetic inputs, compact numeric work keys,
one SQL stage at a time, no traffic or verification. No existing service access.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import secrets
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def estimates(n):
    return {
        "weekly_complete_finishers": n,
        "weekly_qualifying_track_bests": 5 * n,
        "dense_26_week_awards": 26 * n,
        "annual_award_rows": 52 * n,
        "average_minimum_completed_races_per_second": 5 * n / 604800,
        "average_races_per_second_if_20_per_finisher": 20 * n / 604800,
        "monthly_page_requests_if_10_per_week": 10 * n * 52 / 12,
        "weekly_sort_work_proxy": 9 * n * math.log2(max(2, n)),
    }


def run(populations, history_limit):
    docker = json.loads((ROOT / ".tools/gcp-staging/config.json").read_text())["docker"]
    label = "world-ranking-capacity-" + secrets.token_hex(12)
    name = "bmt-ranking-probe-" + secrets.token_hex(6)

    def call(*args, input=None, timeout=240, check=True):
        result = subprocess.run([*docker, *args], input=input, text=True,
                                capture_output=True, timeout=timeout, check=False)
        if check and result.returncode:
            raise RuntimeError(result.stderr[-3000:] + result.stdout[-3000:])
        return result

    image = call("image", "inspect", "postgres:17", "--format", "{{.Id}}")
    call("run", "-d", "--rm", "--name", name, "--label", "bmt.task=" + label,
         "--network", "none", "--cpus", "1", "--memory", "1g", "--shm-size", "256m",
         "-e", "POSTGRES_HOST_AUTH_METHOD=trust", "postgres:17",
         "-c", "shared_buffers=128MB", "-c", "work_mem=16MB",
         "-c", "max_parallel_workers_per_gather=0", "-c", "max_connections=12",
         "-c", "statement_timeout=180000", "-c", "max_wal_size=1GB")
    report = {"scope": __doc__, "image_id": image.stdout.strip(), "cases": [],
              "model": [estimates(n) for n in populations], "cleanup": False,
              "limits": ["Dense five-track complete field, same accounts each week.",
                         "Numeric work IDs and typed arrays, not production ORM objects.",
                         "Freshly generated data; not a controlled cold-cache experiment.",
                         "One database CPU and 1GiB container memory; 16MiB work_mem per operation.",
                         "No concurrent HTTP, PB updates, eligibility joins, corrections or failover.",
                         "Statement EXPLAIN time is not end-to-end publication latency."]}
    try:
        for _ in range(60):
            if call("exec", name, "pg_isready", "-U", "postgres", check=False).returncode == 0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError("Owned database did not become ready")

        def sql(value):
            return call("exec", "-i", name, "psql", "-U", "postgres", "-X", "-q",
                        "-t", "-A", "-v", "ON_ERROR_STOP=1", "-f", "-", input=value).stdout.strip()

        def stage(case, title, query):
            begun = time.perf_counter()
            value = json.loads(sql("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + query))[0]
            item = {"stage": title, "execution_ms": value["Execution Time"],
                    "wrapper_wall_seconds": time.perf_counter() - begun,
                    "temp_read_blocks": value["Plan"].get("Temp Read Blocks", 0),
                    "temp_written_blocks": value["Plan"].get("Temp Written Blocks", 0)}
            case["stages"].append(item)
            (OUT / f"plan-{case['population']}-{title}.json").write_text(json.dumps(value, indent=2))
            print(json.dumps({"population": case["population"], **item}), flush=True)

        report["postgres_version"] = sql("SELECT version();")
        sql("""CREATE FUNCTION points(r bigint) RETURNS smallint LANGUAGE sql IMMUTABLE AS $$
          SELECT CASE WHEN r=1 THEN 1000 WHEN r=2 THEN 850 WHEN r=3 THEN 775
          ELSE greatest(1, floor(sqrt(floor(56250000::numeric/(r+96)))))::int END::smallint
        $$;""")
        for n in populations:
            case = {"population": n, "stages": [], "history_measured": n <= history_limit}
            report["cases"].append(case)
            sql("DROP SCHEMA IF EXISTS probe CASCADE; CREATE SCHEMA probe;")
            begun = time.perf_counter()
            sql(f"""CREATE TABLE probe.bests AS
                SELECT p::bigint player_id, s::smallint slot,
                  (10000+mod(p*7919+s*104729,{max(5000, n // 2)}))::int ticks
                FROM generate_series(1,{n}) p CROSS JOIN generate_series(1,5) s;
                ANALYZE probe.bests;""")
            case["input_generation_wall_seconds"] = time.perf_counter() - begun
            stage(case, "track-places", """CREATE TABLE probe.track_places AS
                SELECT player_id,slot,ticks,
                  (2*rank() OVER (PARTITION BY slot ORDER BY ticks)
                   +count(*) OVER (PARTITION BY slot,ticks)-1)::int place2
                FROM probe.bests""")
            stage(case, "combine-tracks", """CREATE TABLE probe.circuit AS
                SELECT player_id,sum(place2)::bigint sum2,
                  array_agg(place2 ORDER BY place2) countback
                FROM probe.track_places GROUP BY player_id""")
            stage(case, "weekly-awards", """CREATE TABLE probe.awards AS
                SELECT player_id,weekly_place,points(weekly_place) award
                FROM (SELECT player_id,rank() OVER (ORDER BY sum2,countback) weekly_place
                      FROM probe.circuit) c""")
            if n <= history_limit:
                begun = time.perf_counter()
                sql(f"""CREATE TABLE probe.history AS
                  SELECT ((p-1)*26+w+1)::bigint result_id,p::bigint player_id,w::smallint week,
                    points(1+mod(p*7919+w*104729,{n})) award,
                    (1+mod(p*7919+w*104729,{n}))::int weekly_place
                  FROM generate_series(1,{n}) p CROSS JOIN generate_series(0,24) w
                  UNION ALL SELECT (player_id*26)::bigint,player_id,25::smallint,award,weekly_place::int
                    FROM probe.awards;
                  CREATE UNIQUE INDEX history_player_week ON probe.history(player_id,week);
                  ANALYZE probe.history;""")
                case["history_generation_and_index_wall_seconds"] = time.perf_counter() - begun
                stage(case, "rolling-best12", """CREATE TABLE probe.rolling AS
                  SELECT player_id,sum(award)::int total,
                    array_agg(award ORDER BY award DESC) point_key,
                    array_agg(weekly_place ORDER BY weekly_place) place_key,
                    array_agg(result_id ORDER BY award DESC,weekly_place,week DESC) counting_ids
                  FROM (SELECT *,row_number() OVER
                    (PARTITION BY player_id ORDER BY award DESC,weekly_place,week DESC) rn
                    FROM probe.history) h WHERE rn<=12 GROUP BY player_id""")
                stage(case, "world-country", """CREATE TABLE probe.entries AS
                  SELECT *,rank() OVER (ORDER BY total DESC,point_key DESC,place_key) world_rank,
                    rank() OVER (PARTITION BY mod(player_id,200)
                        ORDER BY total DESC,point_key DESC,place_key) country_rank,
                    mod(player_id,200)::smallint country
                  FROM probe.rolling""")
                stage(case, "season-best6", """CREATE TABLE probe.season AS
                  SELECT *,rank() OVER (ORDER BY total DESC,point_key DESC,place_key) season_rank
                  FROM (SELECT player_id,sum(award)::int total,
                    array_agg(award ORDER BY award DESC) point_key,
                    array_agg(weekly_place ORDER BY weekly_place) place_key
                    FROM (SELECT *,row_number() OVER
                      (PARTITION BY player_id ORDER BY award DESC,weekly_place,week DESC) rn
                      FROM probe.history WHERE week>=13) h WHERE rn<=6 GROUP BY player_id) s""")
                begun = time.perf_counter()
                sql("""CREATE UNIQUE INDEX entries_player ON probe.entries(player_id);
                    CREATE INDEX entries_world ON probe.entries(world_rank,player_id);
                    CREATE INDEX entries_country ON probe.entries(country,country_rank,player_id);
                    ANALYZE probe.entries;""")
                case["snapshot_index_wall_seconds"] = time.perf_counter() - begun
                stage(case, "page50", """SELECT player_id,total,world_rank FROM probe.entries
                    WHERE (world_rank,player_id)>(5000,0) ORDER BY world_rank,player_id LIMIT 50""")
                stage(case, "personal", f"SELECT total,world_rank,country_rank FROM probe.entries WHERE player_id={n//2}")
                counts = json.loads(sql("""SELECT json_build_object(
                  'history',(SELECT count(*) FROM probe.history),
                  'entries',(SELECT count(*) FROM probe.entries),
                  'counted',(SELECT min(cardinality(counting_ids)) FROM probe.entries),
                  'max_total',(SELECT max(total) FROM probe.entries),
                  'season_max',(SELECT max(total) FROM probe.season))"""))
                assert counts["history"] == 26*n and counts["entries"] == n
                assert counts["counted"] == 12 and counts["max_total"] <= 12000
                assert counts["season_max"] <= 6000
                case["bounds"] = counts
            case["relation_bytes"] = json.loads(sql("""SELECT json_object_agg(c.relname,
              pg_total_relation_size(c.oid)) FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace
              WHERE ns.nspname='probe' AND c.relkind='r'"""))
            case["classification_execution_seconds"] = sum(s["execution_ms"] for s in case["stages"][:3])/1000
            case["all_measured_stages_execution_seconds"] = sum(s["execution_ms"] for s in case["stages"])/1000
            (OUT / "probe.json").write_text(json.dumps(report, indent=2))

        # A wider fact sample estimates row/index bytes using current 36-character
        # identity strings, source references, a contract hash, and typed columns.
        sql("""CREATE TABLE probe.fact_sample (
          result_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, week int,
          player_id varchar(36), source_run_ids text[], ticks int[], track_places int[],
          weekly_place int, points smallint, contract varchar(64), revision int,
          UNIQUE(week,player_id));
          INSERT INTO probe.fact_sample(week,player_id,source_run_ids,ticks,track_places,
             weekly_place,points,contract,revision)
          SELECT 25,md5(p::text)::uuid::text,
            ARRAY(SELECT md5(p::text||':'||s)::uuid::text FROM generate_series(1,5) s),
            ARRAY[10001,10002,10003,10004,10005],ARRAY[2,4,6,8,10],p,points(p),repeat('a',64),1
          FROM generate_series(1,100000) p;
          CREATE INDEX fact_player_week ON probe.fact_sample(player_id,week);
          ANALYZE probe.fact_sample;""")
        report["fact_storage_sample"] = json.loads(sql("""SELECT json_build_object(
          'rows',count(*),'average_heap_tuple_bytes',avg(pg_column_size(f)),
          'total_heap_and_index_bytes',pg_total_relation_size('probe.fact_sample'),
          'table_bytes',pg_table_size('probe.fact_sample')) FROM probe.fact_sample f"""))
        report["source_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        report["limits"].append("Fact storage sample uses typed arrays; JSON storage or duplicated source payloads can be larger.")
        print(json.dumps({"completed_cases": len(report["cases"]), "fact_storage_sample": report["fact_storage_sample"]}), flush=True)
    finally:
        value = call("inspect", name, "--format", "{{json .Config.Labels}}", check=False)
        if value.returncode == 0 and json.loads(value.stdout).get("bmt.task") == label:
            call("stop", "--time", "5", name)
            report["cleanup"] = True
        else:
            raise RuntimeError("Owned database label not verified; no cleanup attempted")
        (OUT / "probe.json").write_text(json.dumps(report, indent=2))
        print(json.dumps({"cleanup": report["cleanup"]}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--populations", nargs="+", type=int, default=[10000, 100000, 1000000])
    parser.add_argument("--history-limit", type=int, default=100000)
    args = parser.parse_args()
    assert all(128 <= n <= 1000000 for n in args.populations)
    assert 0 <= args.history_limit <= 1000000
    run(args.populations, args.history_limit)
