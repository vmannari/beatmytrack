import subprocess,os,sys,time,json
from pathlib import Path
root=next(p for p in Path(__file__).resolve().parents if (p/"godot-version.txt").exists())
label=sys.argv[1]; script=sys.argv[2]; mode=sys.argv[3] if len(sys.argv)>3 else "gl_compatibility"
out=root/"docs/evidence/garage-cold-opening-2026-10-26"/label
out.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env["APPDATA"]=str(root/"build/garage-cold-opening-user"/os.environ.get("BMT_CACHE_PROFILE",label));env["BMT_API_URL"]=""
Path(env["APPDATA"]).mkdir(parents=True,exist_ok=True)
cmd=[r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe","--path",str(root/"game"),"--audio-driver","Dummy","--position","10000,10000","--script","res://tests/"+script]
if os.environ.get("BMT_REVIEW_VERBOSE"): cmd.insert(1,"--verbose")
cmd += ["--headless"] if mode=="headless" else ["--rendering-method",mode]
cmd += ["--","--output="+str(out)] + sys.argv[4:]
start=time.monotonic()
with (out/"run.log").open("w") as log:
 try:
  r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240);code=r.returncode
 except subprocess.TimeoutExpired: code=124
text=(out/"run.log").read_text()
errors=[line for line in text.splitlines() if any(marker in line for marker in ["SCRIPT ERROR:","FAIL:","Parse Error:","ERROR:"]) and "Failed to read the root certificate store" not in line]
if errors and code==0: code=1
record={"error_lines":errors,"certificate_store_environment_error":"Failed to read the root certificate store" in text,"command":cmd,"exit_code":code,"seconds":time.monotonic()-start,"environment":{"APPDATA":env["APPDATA"],"BMT_API_URL":""}}
(out/"command.json").write_text(json.dumps(record,indent=2))
print(json.dumps(record));print(text[-7000:]);sys.exit(code)
