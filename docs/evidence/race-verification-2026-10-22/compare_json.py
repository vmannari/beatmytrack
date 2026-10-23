"""Compare strict parser semantics and raw timing with the saved original code."""
import importlib.util
import json
import random
import statistics
import time
from pathlib import Path

from bmt_backend.json_data import parse_json

folder=Path(__file__).parent
spec=importlib.util.spec_from_file_location("saved_strict_json",folder/"before/json_data.py")
before=importlib.util.module_from_spec(spec)
spec.loader.exec_module(before)
rng=random.Random(221026)


def value(depth=0):
    scalar=rng.choice([None,True,False,0,9,-10,1.25,1e308,"Caf\u00e9","\ud800",""])
    if depth>6 or rng.randrange(3)==0:
        return scalar
    if rng.randrange(2):
        return [value(depth+1) for _ in range(rng.randrange(5))]
    return {"k"+str(i):value(depth+1) for i in range(rng.randrange(5))}


def outcome(call,body,budget):
    try:
        return "accepted",call(body,maximum_nodes=budget)
    except (ValueError,UnicodeError,RecursionError) as error:
        return type(error).__name__,str(error)


cases=[b'{"x":1,"x":2}',b'{"x":{"a":1,"a":2}}',b'1e400',b'NaN',b'-Infinity',b'"\xff"']
cases += [("["*depth+leaf+"]"*depth).encode() for depth in range(30,36) for leaf in ("0","[]","{}")]
cases += [json.dumps(value()).encode() for _ in range(600)]
checks=0
for body in cases:
    for budget in (0,1,2,7,40,10000):
        assert outcome(before.parse_json,body,budget)==outcome(parse_json,body,budget),(body,budget)
        checks+=1

root=folder.parents[2]
proof=json.loads((root/"build/verification-speed-2026-10-09/proof.json").read_text())
payload=json.dumps({"schema":"bmt-trajectory-v1","input_count":12757,"race_proof":{
    "schema":"bmt-race-path-v1","samples":[[s[0],s[1],s[2],s[6]] for s in proof["samples"]]}},
    separators=(",",":")).encode()
times={"before":[],"after":[]}
for _ in range(100):
    for name,call in (("before",before.parse_json),("after",parse_json)):
        start=time.perf_counter_ns()
        call(payload)
        times[name].append((time.perf_counter_ns()-start)/1e6)
result={"identical_semantic_checks":checks,"payload_bytes":len(payload),"iterations":100,
        "median_ms":{name:statistics.median(rows) for name,rows in times.items()}}
(folder/"json-comparison.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps(result))
