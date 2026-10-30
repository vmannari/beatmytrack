"""Record and independently apply the electric-4 tuning delta."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
REL=OUT.relative_to(ROOT)
META=["AGENTS.md","DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md"]
COMMON=["game/resources/cars/electric.tres","game/tests/test_electric_power.gd","game/tests/test_electric_turning.gd","backend/tests/fixtures/verified_oval.json"]
NEW=["game/tests/test_electric_steering_response.gd","game/tests/test_electric_steering_response.gd.uid","docs/ELECTRIC_STEERING_RESPONSE_2026_10_25.md"]

def write(path: Path,data: bytes) -> None:
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(data)

def sha(path: Path) -> str: return hashlib.sha256(path.read_bytes()).hexdigest()

def run(args: list[str],cwd: Path,code: int=0) -> bytes:
    p=subprocess.run(args,cwd=cwd,capture_output=True)
    assert p.returncode==code,(args,p.stderr.decode(errors="replace"))
    return p.stdout

def main() -> None:
    cutoff=(OUT/"before/game__resources__cars__electric.tres.txt").stat().st_mtime
    for p in (ROOT/"build/logs").glob("TestScript-*/test-script.log"):
        if p.stat().st_mtime<cutoff: continue
        text=p.read_text(errors="replace")
        own=any(s in text for s in ["ELECTRIC_","ONE_PEDAL:"])
        own|='"values"' in text and '"turn48"' in text
        own|=p.parent.name=="TestScript-17904"
        if own: write(OUT/"logs"/(p.parent.name+".log"),p.read_bytes())
    write(OUT/"logs/Import-3684.log",(ROOT/"build/logs/Import-3684/import.log").read_bytes())
    assert "ERROR" not in (OUT/"logs/Import-3684.log").read_text(errors="replace")
    log=(OUT/"backend.log").read_bytes()
    backend=log.decode("utf-16" if log.startswith(b"\xff\xfe") else "utf-8-sig")
    assert "72 passed, 2 deselected" in backend
    write(OUT/"backend.log",backend.encode())
    results={}
    for name in ["response","turning","power","handling","one-pedal"]:
        result=json.loads((OUT/(name+".json")).read_text())
        assert result["failures"]==0
        results[name]=result
    manifest=json.loads((OUT/"manifest.json").read_text())
    old_manifest=json.loads((OUT/"before/backend__tests__fixtures__verified_oval.json.txt").read_text())["expected_manifest"]
    unchanged_cars=[k for k,v in manifest["vehicles"].items() if k!="electric" and v==old_manifest["vehicles"][k]]
    assert len(unchanged_cars)==6
    frozen={}
    for name in ["game/vehicle/handling_config.gd","game/vehicle/vehicle_simulation.gd","game/vehicle/electric_coachwork.gd"]:
        old=OUT/"before"/(name.replace("/","__")+".txt")
        assert old.read_bytes()==(ROOT/name).read_bytes(),name
        frozen[name]=sha(old)

    rows=[]
    for key in ["12.0/0.45","24.0/0.45","36.0/0.45","48.0/0.45"]:
        value=results["response"]["metrics"][key]
        a,b=value["before"],value["after"]
        rows.append(f'<tr><td>{float(key.split("/")[0])*3.6:.1f} km/h</td><td>{a["seconds"]:.3f} s</td><td>{b["seconds"]:.3f} s</td><td>{a["radius"]:.2f} m</td><td>{b["radius"]:.2f} m</td></tr>')
    html='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Electric steering response</title><style>body{font:17px/1.5 system-ui;background:#172129;color:#edf1f3;max-width:1000px;margin:28px auto;padding:0 20px}table{border-collapse:collapse;width:100%}th,td{padding:12px;text-align:left;border-bottom:1px solid #4b5b63}a{color:#e4e9cf}img{width:100%;height:auto}strong{color:#ffdb75}</style><h1>Electric-4 steering / 2026-10-25</h1><p><strong>95% steering lock: 83.3 → 41.7 ms.</strong> Opposite-steering travel response: 133.3 → 75 ms. Actual direction changes more than twice as far in the first 100 ms across all twelve speed/pedal cases.</p><p>Full steering / 45% pedal, measured velocity paths:</p><table><tr><th>Entry</th><th>Old time</th><th>New time</th><th>Old radius</th><th>New radius</th></tr>'+''.join(rows)+'</table><p>Same strong acceleration and complete regenerative stop. Established power-corner slip is 16.54° versus 17.58° before. All fifteen regression laps report zero contacts; actual five-lap replay verifies independently.</p><p>Native response86 / turning61 / power19 / replay60 / one-pedal63 / laps6 / Garage-race59+59 and backend72 checks pass. Desktop Mobile is not phone feel acceptance. Reload and matching online verifier rollout remain.</p><a href="native/race.png"><img src="native/race.png" alt="Current actual electric race controls"></a><p><a href="report.json">Evidence and checkpoint report</a></p></html>'
    write(OUT/"review.html",html.encode())
    block=("<!-- ELECTRIC-STEERING-RESPONSE-20261025 -->\n## Faster electric steering response override (2026-10-25)\n"
           "2026-10-25 ESR01-ESR04/R01/Q01: Electric-4 halves steering-lock time83.3to41.7ms, "
           "more than doubles actual first100ms travel-direction response and catches opposite steering75ms versus133ms. "
           "All twelve speed/pedal quarter turns are at least12% faster/tighter than accepted electric-3; "
           "45%-pedal cases15to22% sooner, with full-power corner slip16.54deg versus17.58deg before. "
           "Strong launch and exact72km/h regeneration stop1.8s/17.842m, no handbrake and saved-position D/R remain. "
           "Response86/turn61/power19/electric60/one-pedal63/laps6/Garage-race59Compatibility/59desktopMobile, "
           "backend72pass/2explicit exclusions, real server13103input five-lap replay and parser1163/import pass. "
           "Initial different-duration speed comparisons and genuine full-power scrub failure remain recorded; "
           "equal-time five-percent tolerance and all slip/stop assertions are retained. Configf70168e4, "
           "physics0.68 and six other car config hashes/model/shared math remain unchanged except the versioned EV tune. "
           "Commands, native evidence, hashes and task-only Git-checked checkpoint: docs/ELECTRIC_STEERING_RESPONSE_2026_10_25.md "
           "and docs/evidence/electric-steering-response-2026-10-25/report.json. Client reload, matching online verifier/config "
           "rollout and owner/device feel acceptance remain; no attachment/device test, APK, live mutation, "
           "purchase, deployment or owner-process restart. Concurrent work preserved.\n"
           "<!-- /ELECTRIC-STEERING-RESPONSE-20261025 -->\n\n")
    for name in META:
        old=re.sub(rb"<!-- ELECTRIC-STEERING-RESPONSE-20261025 -->.*?<!-- /ELECTRIC-STEERING-RESPONSE-20261025 -->\r?\n\r?\n",b"",(ROOT/name).read_bytes(),flags=re.S)
        write(OUT/"checkpoint-base"/name,old)
        write(ROOT/name,block.encode()+old)
    for name in COMMON:
        write(OUT/"checkpoint-base"/name,(OUT/"before"/(name.replace("/","__")+".txt")).read_bytes())
    report={"date":"2026-10-25","recorded_utc":datetime.now(timezone.utc).isoformat(),
            "requirements":{"ESR01":"quicker steering and chassis onset","ESR02":"tighter/faster actual paths with calm breakaway","ESR03":"preserve one-pedal/RWD/stop/strong launch","ESR04":"version and verify competitive tune"},
            "version":manifest["vehicles"]["electric"],"physics_version":manifest["physics_version"],
            "results":results,"other_checks":{"laps":6,"compatibility_ui":59,"desktop_mobile_ui":59,"backend_pass":72,"backend_deselected":2,"parser_scripts":1163,"normal_import":"pass"},
            "canonical_verification":json.loads((OUT/"canonical-verification.json").read_text()),
            "unchanged_other_car_configs":unchanged_cars,"unchanged_source_sha256":frozen,
            "initial_outcomes":["Original exit-speed comparison reported three low-speed failures because turn completion times differed; compare at the same elapsed tick with the same five-percent bound","Equal-time comparison then exposed one real full-power mid-speed momentum loss; final bounded-yaw, reduced throttle rotation and reduced-scrub tune passes without changing tolerance","Exploratory calibration logs have no assertions and are not acceptance passes"],
            "commands_document":"docs/ELECTRIC_STEERING_RESPONSE_2026_10_25.md","changed_files":COMMON+NEW+META,
            "limits":["Client reload and matching online verifier/configuration rollout required","Owner/device steering feel remains","No phone/tablet attachment check or physical-device test","No APK, live mutation, purchase, deployment or owner-process restart","Manual-stepping native hitch diagnostics are not a performance benchmark","Unavailable PostgreSQL and known historical physics-050 ghost defect explicitly excluded"],
            "checkpoint":{"path":str(REL/"checkpoint.patch").replace("\\","/"),"baseline":"task-start shared sources, current concurrent metadata with only this task marker removed","git_apply_check":False,"byte_exact":False}}
    evidence=[str(p.relative_to(ROOT)).replace("\\","/") for p in OUT.rglob("*") if p.is_file() and p.name not in ["checkpoint.patch","report.json"] and "__pycache__" not in p.parts]
    files=sorted(set(COMMON+NEW+META+evidence))
    report["sha256"]={name:sha(ROOT/name) for name in files}
    record=OUT/"report.json"
    write(record,(json.dumps(report,indent=2)+"\n").encode())
    number=1
    while (ROOT/f"build/electric-response-checkpoint-{number}").exists(): number+=1
    stage=ROOT/f"build/electric-response-checkpoint-{number}"
    before,after=stage/"before",stage/"after"
    for name in COMMON+META: write(before/name,(OUT/"checkpoint-base"/name).read_bytes())
    paths=files+[str(REL/"report.json").replace("\\","/")]
    for name in paths: write(after/name,(ROOT/name).read_bytes())
    patch=OUT/"checkpoint.patch"
    def make_patch() -> None:
        diff=run(["git","-c","core.autocrlf=false","diff","--no-index","--no-renames","--binary","--","before","after"],stage,1)
        lines=[]
        for line in diff.splitlines(keepends=True):
            if line.startswith((b"diff --git ",b"--- ",b"+++ ")):
                for a,b in [(b"a/before/",b"a/"),(b"b/after/",b"b/"),(b"a/after/",b"a/"),(b"b/before/",b"b/")]: line=line.replace(a,b)
            lines.append(line)
        patch.write_bytes(b"".join(lines))
    def verify(label: str) -> None:
        target=stage/label
        shutil.copytree(before,target)
        run(["git","init","-q"],target)
        run(["git","config","core.autocrlf","false"],target)
        run(["git","apply","--check",str(patch)],target)
        run(["git","apply",str(patch)],target)
        for name in paths: assert (target/name).read_bytes()==(after/name).read_bytes(),name
    make_patch()
    verify("verify1")
    report["checkpoint"].update(git_apply_check=True,byte_exact=True,changed_paths=len(paths))
    write(record,(json.dumps(report,indent=2)+"\n").encode())
    shutil.copyfile(record,after/REL/"report.json")
    make_patch()
    verify("verify2")
    for name,value in report["sha256"].items(): assert sha(ROOT/name)==value,name
    for name,value in frozen.items(): assert sha(ROOT/name)==value,name
    print(json.dumps({"checkpoint":report["checkpoint"],"hashes_verified":len(files),"patch_bytes":patch.stat().st_size}))

if __name__=="__main__": main()
