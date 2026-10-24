"""Measure lean ranking storage in an owned network-isolated PostgreSQL sample."""
import hashlib
import json
import secrets
import struct
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
N = 100000


def main():
    docker = json.loads((ROOT / ".tools/gcp-staging/config.json").read_text())["docker"]
    name = "bmt-ranking-storage-" + secrets.token_hex(6)
    label = "ranking-storage-" + secrets.token_hex(12)

    def call(*args, input=None, check=True):
        result = subprocess.run([*docker, *args], input=input, text=True,
                                capture_output=True, timeout=180, check=False)
        if check and result.returncode:
            raise RuntimeError(result.stderr[-2000:] + result.stdout[-2000:])
        return result

    image = call("image", "inspect", "postgres:17", "--format", "{{.Id}}")
    call("run", "-d", "--rm", "--name", name, "--label", "bmt.task=" + label,
         "--network", "none", "--cpus", "1", "--memory", "1g", "--shm-size", "256m",
         "-e", "POSTGRES_HOST_AUTH_METHOD=trust", "postgres:17",
         "-c", "shared_buffers=128MB", "-c", "work_mem=16MB",
         "-c", "max_parallel_workers_per_gather=0", "-c", "statement_timeout=120000")
    report = {"sample_players": N, "image": image.stdout.strip(), "cleanup": False,
              "requirements": {"WRS01": "Measure minimum score ledger and scalar snapshots.",
                               "WRS02": "Keep reserves and sufficient classification inputs.",
                               "WRS03": "Compare optional packing without promising production capacity.",
                               "R01": "No existing database or runtime changes.",
                               "Q01": "Verify physical sizes, cardinalities and binary round trips."}}
    try:
        for _ in range(60):
            if call("exec", name, "pg_isready", "-U", "postgres", check=False).returncode == 0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError("Owned PostgreSQL startup failed")

        def sql(statement):
            return call("exec", "-i", name, "psql", "-U", "postgres", "-X", "-q",
                        "-t", "-A", "-v", "ON_ERROR_STOP=1", "-f", "-", input=statement).stdout.strip()

        report["postgres_version"] = sql("SELECT version();")
        sql("""CREATE TABLE award (
          player_key bigint NOT NULL, week int NOT NULL, weekly_place int NOT NULL,
          points smallint NOT NULL, PRIMARY KEY(player_key,week)
        ) PARTITION BY RANGE(week);""")
        partitions = "\n".join(f"CREATE TABLE award_{w} PARTITION OF award FOR VALUES FROM ({w}) TO ({w+1});" for w in range(26))
        sql(partitions)
        sql(f"""INSERT INTO award SELECT p::bigint,w,
          (1+mod(p::bigint*7919+w*104729,{N}))::int,
          (1+mod(p::bigint*17+w*23,1000))::smallint
          FROM generate_series(1,{N}) p CROSS JOIN generate_series(0,25) w;
          ANALYZE award;
          CREATE TABLE packed (
            player_key bigint PRIMARY KEY, base_week int NOT NULL,
            presence int NOT NULL, history bytea NOT NULL);
          INSERT INTO packed
            SELECT player_key,0,67108863,
              string_agg(int2send(points)||int4send(weekly_place),''::bytea ORDER BY week)
            FROM award GROUP BY player_key;
          CREATE TABLE snapshot (
            generation int NOT NULL, player_key bigint NOT NULL,
            world_rank int NOT NULL, country_rank int NOT NULL,
            total smallint NOT NULL, country smallint NOT NULL,
            PRIMARY KEY(generation,player_key));
          INSERT INTO snapshot SELECT 1,p::bigint,p,((p-1)/200+1)::int,(mod(p,12000)+1)::smallint,
              mod(p,200)::smallint FROM generate_series(1,{N}) p;
          CREATE INDEX snapshot_world ON snapshot(generation,world_rank,player_key);
          CREATE INDEX snapshot_country ON snapshot(generation,country,country_rank,player_key);
          CREATE TABLE player_map (
            player_key bigint PRIMARY KEY, player_id varchar(36) NOT NULL UNIQUE);
          INSERT INTO player_map SELECT p::bigint,md5(p::text)::uuid::text FROM generate_series(1,{N}) p;
          CREATE TABLE career (
            player_key bigint PRIMARY KEY, peak_rank int, peak_week int, peak_field int,
            weeks_no1 int, weeks_top100 int, circuit_wins int, season_titles int);
          INSERT INTO career SELECT p::bigint,p,25,{N},0,0,0,0 FROM generate_series(1,{N}) p;
          ANALYZE packed; ANALYZE snapshot; ANALYZE player_map; ANALYZE career;""")
        report["sizes"] = json.loads(sql("""SELECT json_build_object(
          'award', (SELECT sum(pg_total_relation_size(relid)) FROM pg_partition_tree('award') WHERE isleaf),
          'packed',pg_total_relation_size('packed'),
          'snapshot',pg_total_relation_size('snapshot'),
          'player_map',pg_total_relation_size('player_map'),
          'career',pg_total_relation_size('career'))"""))
        report["counts"] = json.loads(sql("""SELECT json_build_object(
          'award',(SELECT count(*) FROM award),'packed',(SELECT count(*) FROM packed),
          'snapshot',(SELECT count(*) FROM snapshot),'player_map',(SELECT count(*) FROM player_map),
          'career',(SELECT count(*) FROM career),'min_packed_bytes',(SELECT min(octet_length(history)) FROM packed),
          'max_packed_bytes',(SELECT max(octet_length(history)) FROM packed))"""))
        assert report["counts"]["award"] == 26*N
        assert all(report["counts"][key] == N for key in ("packed", "snapshot", "player_map", "career"))
        assert report["counts"]["min_packed_bytes"] == report["counts"]["max_packed_bytes"] == 156
        packed = bytes.fromhex(sql("SELECT encode(history,'hex') FROM packed WHERE player_key=1"))
        decoded = list(struct.iter_unpack(">HI", packed))
        assert decoded == [(1+(17+w*23)%1000, 1+(7919+w*104729)%N) for w in range(26)]
        report["checks"] = ["26 scores per sampled player", "unique account/week key",
                            "snapshot/map/career cardinality", "156-byte history length",
                            "SQL binary history to Python decoder exact round trip"]
        record = struct.Struct(">Q6IH")
        example = (1,10001,10002,10003,10004,10005,12345,728)
        assert record.size == 34 and record.unpack(record.pack(*example)) == example
        world_record = struct.Struct(">QIH")
        assert world_record.size == 14
        report["archive_record_bytes"] = {"five_ticks_and_player": 28,
                                         "five_ticks_player_place_points": record.size,
                                         "world_player_rank_total": world_record.size}
        report["checks"].append("34-byte weekly result and 14-byte world fact codec sizes")
        rows = []
        prior = json.loads((ROOT / "docs/evidence/world-ranking-backend-2026-10-23/probe.json").read_text())
        old_b = prior["fact_storage_sample"]["total_heap_and_index_bytes"] / prior["fact_storage_sample"]["rows"]
        for n in (10000,100000,1000000):
            scale = n/N
            common = 2*report["sizes"]["snapshot"] + report["sizes"]["player_map"] + report["sizes"]["career"]
            rows.append({
                "steady_weekly_finishers": n,
                "old_26_week_audited_ledger_gib": old_b*26*n/(1024**3),
                "lean_26_week_ledger_gib": report["sizes"]["award"]*scale/(1024**3),
                "lean_db_with_two_snapshots_map_career_gib": (report["sizes"]["award"]+common)*scale/(1024**3),
                "optional_packed_db_same_common_gib": (report["sizes"]["packed"]+common)*scale/(1024**3),
                "26_week_weekly_archive_gib_uncompressed": 26*n*34/(1024**3),
                "annual_full_result_and_world_archive_gib_uncompressed": 52*n*(34+14)/(1024**3),
            })
        report["estimates"] = rows
        report["limits"] = [
            "One 100k-player physical sample, 26 weeks; other populations extrapolate its row/index sizes.",
            "Packed history is an optional storage experiment, not a shipping codec or integration change.",
            "Packed history needs extra slots or generations during publication; 26 slots alone is insufficient for overlapping windows.",
            "Column order, index count, bloat, history buffer and final schema change actual volume requirements.",
            "Binary archive counts are exact record-width arithmetic, excluding shared headers, manifests and revisions; compression is not assumed.",
            "Steady same-player field; rolling population turnover can increase snapshots/map/career/world archive sizes.",
            "No live mutation, deployment, device test or phone attachment check."]
        report["source_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        print(json.dumps({"sizes": report["sizes"], "estimates": rows, "checks": report["checks"]}), flush=True)
    finally:
        value = call("inspect", name, "--format", "{{json .Config.Labels}}", check=False)
        if value.returncode == 0 and json.loads(value.stdout).get("bmt.task") == label:
            call("stop", "--time", "5", name)
            report["cleanup"] = True
        else:
            raise RuntimeError("Owned label not verified; no cleanup attempted")
        (OUT / "probe.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps({"cleanup": report["cleanup"]}), flush=True)


if __name__ == "__main__":
    main()
