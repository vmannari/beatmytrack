"""Offline, PID-scoped analysis of an owned phone trace; uploads nothing."""
import argparse
import csv
import io
import json
import re
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--stage", default="cold", choices=("warm", "cold", "primed"))
    parser.add_argument("--tick", type=int, default=2316)
    parser.add_argument("--label", default="")
    args = parser.parse_args()
    if args.label and not re.fullmatch(r"[a-z0-9-]+", args.label):
        parser.error("label must contain only lowercase letters, digits and hyphens")
    output_stem = args.stage + ("-" + args.label if args.label else "")
    root = Path(__file__).resolve().parents[1]
    pid = int(json.loads((args.evidence / f"{args.stage}-process.json").read_text(encoding="utf-8-sig"))["pid"])
    event = None
    for path in args.evidence.glob(f"{args.stage}-race-*.json"):
        capture = json.loads(path.read_text(encoding="utf-8-sig"))
        event = next((row["frame"] for row in capture["events"] if row["frame"]["tick"] == args.tick), None)
        if event:
            break
    queries = [
        "SELECT 'trace_bounds' AS section,start_ts,end_ts FROM trace_bounds",
        "SELECT 'health' AS section,name,idx,severity,value FROM stats WHERE value != 0 AND (severity IN ('error','notice') OR name LIKE '%overwritten%' OR name LIKE '%discard%' OR name LIKE '%lost%' OR name LIKE '%overrun%')",
        "SELECT 'sched_bounds' AS section,MIN(ts) AS start_ts,MAX(ts+dur) AS end_ts FROM sched",
        f"SELECT 'threads' AS section,t.utid,t.tid,t.name FROM thread t JOIN process p USING(upid) WHERE p.pid={pid}",
        f"SELECT 'hitches' AS section,l.ts,l.msg FROM android_logs l JOIN thread t USING(utid) JOIN process p USING(upid) WHERE p.pid={pid} AND l.msg LIKE '%RACE_HITCH%'",
        f"SELECT 'samples' AS section,COUNT(*) AS count,MIN(s.ts) AS start_ts,MAX(s.ts) AS end_ts FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid) WHERE p.pid={pid}",
        f"SELECT 'unwind' AS section,s.unwind_error,COUNT(*) AS count FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid) WHERE p.pid={pid} GROUP BY s.unwind_error",
    ]
    if event:
        frame_ns = round(event["frame_ms"] * 1_000_000)
        bounds = f"""WITH bounds AS (
          SELECT l.ts-{frame_ns} AS start_ts,l.ts AS end_ts
          FROM android_logs l JOIN thread t USING(utid) JOIN process p USING(upid)
          WHERE p.pid={pid} AND l.msg LIKE '% tick={args.tick} countdown=%' LIMIT 1
        )"""
        queries += [
            bounds + " SELECT 'event_bounds' AS section,* FROM bounds",
            bounds + f" SELECT 'event_thread_state' AS section,t.tid,t.name,s.state,ROUND(SUM(MAX(0,MIN(s.ts+s.dur,b.end_ts)-MAX(s.ts,b.start_ts)))/1e6,3) AS ms FROM thread_state s JOIN thread t USING(utid) JOIN process p USING(upid) CROSS JOIN bounds b WHERE p.pid={pid} AND s.ts<b.end_ts AND s.ts+s.dur>b.start_ts GROUP BY t.tid,t.name,s.state ORDER BY t.tid,ms DESC",
            bounds + f" SELECT 'event_slices' AS section,t.tid,s.ts,s.dur,s.name FROM slice s JOIN thread_track tr ON tr.id=s.track_id JOIN thread t ON t.utid=tr.utid JOIN process p USING(upid) CROSS JOIN bounds b WHERE p.pid={pid} AND s.ts<b.end_ts AND s.ts+s.dur>b.start_ts AND s.dur>10000000 ORDER BY s.dur DESC LIMIT 30",
            bounds + f" SELECT 'event_samples' AS section,t.tid,s.unwind_error,COUNT(*) AS count FROM perf_sample s JOIN thread t USING(utid) JOIN process p USING(upid) CROSS JOIN bounds b WHERE p.pid={pid} AND s.ts BETWEEN b.start_ts AND b.end_ts GROUP BY t.tid,s.unwind_error",
            bounds.replace("WITH bounds", "WITH RECURSIVE bounds") + f""",
              frames(sample_id,callsite_id) AS (
                SELECT s.id,s.callsite_id FROM perf_sample s JOIN thread t USING(utid)
                JOIN process p USING(upid) CROSS JOIN bounds b
                WHERE p.pid={pid} AND s.ts BETWEEN b.start_ts AND b.end_ts
                UNION ALL SELECT f.sample_id,c.parent_id FROM frames f
                JOIN stack_profile_callsite c ON c.id=f.callsite_id WHERE c.parent_id IS NOT NULL
              ) SELECT 'event_stack' AS section,COALESCE(symbol.name,frame.name) AS name,
                mapping.name AS mapping,frame.rel_pc,COUNT(DISTINCT f.sample_id) AS samples
              FROM frames f JOIN stack_profile_callsite c ON c.id=f.callsite_id
              JOIN stack_profile_frame frame ON frame.id=c.frame_id
              JOIN stack_profile_mapping mapping ON mapping.id=frame.mapping
              LEFT JOIN stack_profile_symbol symbol ON symbol.symbol_set_id=frame.symbol_set_id
              GROUP BY frame.id,symbol.name ORDER BY samples DESC LIMIT 120""",
        ]
    sql_path = args.trace.parent / f"{output_stem}-analysis.sql"
    sql_path.write_text(";\n".join(queries) + ";\n", encoding="utf-8")
    launcher = root / "build/desert-hitch-2026-10-13/tools/trace_processor.py"
    run = subprocess.run([sys.executable, str(launcher), "query", "-f", str(sql_path), str(args.trace)], capture_output=True, text=True, encoding="utf-8", check=True)
    (args.trace.parent / f"{output_stem}-analysis.csv").write_text(run.stdout, encoding="utf-8")
    tables = {}
    header = None
    for row in csv.reader(io.StringIO(run.stdout)):
        if not row:
            header = None
        elif header is None:
            header = row
        else:
            record = dict(zip(header, row))
            section = record.pop("section")
            tables.setdefault(section, []).append(record)
    result = {"pid": pid, "requested_tick": args.tick, "matching_game_event": event, "tables": tables,
              "limits": "Log timestamps bound an approximate whole-frame wall interval; CPU samples are statistical. Render signals are not GPU execution time. Check trace health and scheduling coverage before attributing any event."}
    destination = args.evidence / f"{output_stem}-analysis.json"
    destination.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(destination), "matching_event": bool(event), "tables": {key: len(value) for key, value in tables.items()}}, indent=2))


if __name__ == "__main__":
    main()
