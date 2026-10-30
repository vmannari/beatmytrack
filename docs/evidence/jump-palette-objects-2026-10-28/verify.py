"""Run the pinned engine offline, redirecting all account/save paths locally."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
ENGINE=r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"
environment=os.environ.copy()
environment["BMT_API_URL"]=""
environment["APPDATA"]=str(ROOT/"tmp/jump-palette-appdata")
Path(environment["APPDATA"]).mkdir(parents=True,exist_ok=True)
sources=[path.relative_to(OUT/"before") for path in (OUT/"before").rglob("*") if path.is_file()]
protected=["game/editor/jump_profiles.gd","game/vehicle/track_hazards.gd","game/vehicle/vehicle_simulation.gd","game/editor/track_compiler.gd","game/track/jump_visual.gd","game/track/jump_earth.gdshader","docs/schemas/creator-track-v5.schema.json","backend/deploy/stage_verifier.py"]
protected += [str(path.relative_to(ROOT)).replace("\\","/") for path in (ROOT/"game/resources/cars").glob("*.tres")]
def hashes(paths): return {str(path).replace("\\","/"):hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in paths}
if not (OUT/"protected-source-hashes.json").exists(): (OUT/"protected-source-hashes.json").write_text(json.dumps(hashes(protected),indent=2),encoding="utf-8")
mode=sys.argv[1] if len(sys.argv)>1 else "focused"
cases={
 "focused":[("focused-headless","test_editor_jump_styles.gd","headless")],
 "native":[("focused-compatibility","test_editor_jump_styles.gd","gl_compatibility"),("focused-mobile","test_editor_jump_styles.gd","mobile")],
 "retained":[("object-browser","test_object_browser.gd","headless"),("app","test_app.gd","headless"),("worker","test_jump_profiles_worker.gd","headless"),("parser","test_script_parse.gd","headless")],
 "control":[("control-object-browser","test_object_browser.gd","headless"),("control-app","test_app.gd","headless")],
 "parse":[("parse-app","../core/app.gd","headless"),("parse-catalog","../editor/creator_catalog.gd","headless"),("parse-browser","../editor/object_browser.gd","headless"),("parse-thumbnail","../editor/object_thumbnail.gd","headless"),("parse-focused","test_editor_jump_styles.gd","headless"),("parse-browser-test","test_object_browser.gd","headless")],
}[mode]
results=[]
for name,script,renderer in cases:
    project=ROOT/"tmp/jump-palette-control/game" if mode=="control" else ROOT/"game"
    command=[ENGINE,"--path",str(project),"--log-file",str(OUT/(name+"-engine.log"))]
    command += ["--headless"] if renderer=="headless" else ["--rendering-method",renderer,"--rendering-driver","opengl3" if renderer=="gl_compatibility" else "vulkan"]
    if mode=="parse": command += ["--check-only"]
    command += ["--script","res://tests/"+script]
    print("RUN",name,flush=True)
    before=hashes(sources)
    try:
        process=subprocess.run(command,cwd=ROOT,env=environment,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
        output=process.stdout.decode("utf-8","replace")
        (OUT/(name+".log")).write_text(output,encoding="utf-8")
        item={"name":name,"command":command,"exit":process.returncode,"script_error":"SCRIPT ERROR" in output,
              "summary":[line for line in output.splitlines() if any(token in line for token in ("TESTS:","SCRIPT_PARSE:","EDITOR_JUMP_STYLES:","JUMP_WORKER:","FAIL:"))]}
    except subprocess.TimeoutExpired as error:
        (OUT/(name+".log")).write_bytes(error.stdout or b"")
        item={"name":name,"command":command,"timeout":True}
    item["source_hashes_before"]=before; item["source_hashes_after"]=hashes(sources)
    results.append(item)
    (OUT/("commands-"+mode+".json")).write_text(json.dumps(results,indent=2),encoding="utf-8")
    print(json.dumps({key:value for key,value in item.items() if not key.startswith("source_hashes")}),flush=True)
sys.exit(1 if any(item.get("exit",1)!=0 or item.get("script_error",False) for item in results) else 0)
