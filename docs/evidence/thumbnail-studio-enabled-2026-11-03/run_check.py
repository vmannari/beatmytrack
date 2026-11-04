"""Bounded private native thumbnail experiment; no owner data/network/index."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

p = argparse.ArgumentParser()
p.add_argument("label")
p.add_argument("--renderer",default="gl_compatibility",choices=["gl_compatibility","mobile"])
p.add_argument("--script",default="res://tests/test_thumbnail_studio.gd")
p.add_argument("--import-assets",action="store_true")
args, extra = p.parse_known_args()
evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
output = evidence/args.label
output.mkdir(exist_ok=True)
profile = root/"build/thumbnail-studio-enabled-20261103"/(args.label+"-"+str(time.time_ns()))
profile.mkdir(parents=True)
env = os.environ.copy()
env.update(APPDATA=str(profile),BMT_API_URL="",BMT_THUMBNAIL_OUTPUT=str(output),BMT_GARAGE_DEFERRED_EVIDENCE=str(output))
command = [sys.executable,str(root/"scripts/run_no_crash_dialog.py"),"--",
           "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe","--path",str(root/"game"),
           "--audio-driver","Dummy","--rendering-method",args.renderer,"--script",args.script,"--","--output="+str(output),*extra]
if args.import_assets:
    command = command[:command.index("--script")]+["--headless","--editor","--import","--quit"]
paths = ["game/ui/garage_preview_cache.gd","game/ui/garage_preview_renderer.gd","game/ui/garage_thumbnail_studio.gd",
         "game/ui/garage_thumbnail_shadow.gdshader","game/ui/garage_preloaded_studio.gd","game/ui/garage_page.gd","scripts/bake_garage_previews.gd","game/ui/car_showroom.gd","game/ui/garage_environment.gd",
         "game/ui/garage_reflections.gd","game/core/build_identity.gd",args.script.replace("res://","game/")]
paths += [str(path.relative_to(root)).replace("\\","/") for path in (root/"game/vehicle").glob("*.gd")]
def hashes():
    return {path:hashlib.sha256((root/path).read_bytes()).hexdigest() for path in paths}
receipt = dict(command=command,profile=str(profile),before=hashes())
started = time.monotonic()
with (evidence/(args.label+".log")).open("w",encoding="utf-8") as log:
    process = subprocess.Popen(command,env=env,cwd=root,stdout=log,stderr=subprocess.STDOUT)
    (evidence/(args.label+"-running.json")).write_text(json.dumps(dict(pid=process.pid,**receipt),indent=2))
    try: receipt["exit_code"] = process.wait(timeout=420)
    except subprocess.TimeoutExpired:
        receipt["exit_code"] = 124
        subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],capture_output=True,check=False)
        try: process.wait(timeout=20)
        except subprocess.TimeoutExpired: receipt["cleanup_failed"] = True
receipt.update(elapsed_seconds=time.monotonic()-started,after=hashes())
receipt["changed_sources"] = [path for path in paths if receipt["before"][path] != receipt["after"][path]]
(evidence/(args.label+"-receipt.json")).write_text(json.dumps(receipt,indent=2)+"\n")
print(json.dumps({key:receipt[key] for key in ("exit_code","elapsed_seconds","changed_sources")}))
sys.exit(receipt["exit_code"])
