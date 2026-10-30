"""Run final native review and integration checks sequentially (shared build metadata)."""
from pathlib import Path
import hashlib
import json
import subprocess
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
BASE="res://../docs/evidence/electric-rear-redesign-2026-10-28/"
JOBS=[
 ("arrays","audit_electric_rear_redesign",None,[]),
 ("native","review_electric_rear_redesign","gl_compatibility",["--evidence-root="+BASE+"native"]),
 ("mobile","review_electric_rear_redesign","mobile",["--evidence-root="+BASE+"desktop-mobile"]),
 ("before-mobile","review_electric_rear_redesign","mobile",["--before","--evidence-root="+BASE+"before-desktop-mobile"]),
 ("construction","test_electric_rebuild",None,["--evidence-root="+BASE+"construction"]),
 ("model-native","test_electric_model","gl_compatibility",["--evidence-root="+BASE+"model-native"]),
 ("model-mobile","test_electric_model","mobile",["--evidence-root="+BASE+"model-mobile"]),
 ("rear-app-native","test_electric_rear_app","gl_compatibility",["--evidence-root="+BASE+"app-native"]),
 ("rear-app-mobile","test_electric_rear_app","mobile",["--evidence-root="+BASE+"app-mobile"]),
 ("racing","test_racing_car_models",None,["--vehicle=electric"]),
 ("hood","test_electric_convex_hood",None,["--evidence-root="+BASE+"hood"]),
 ("retained-flow","test_electric_rear_flow",None,["--evidence-root="+BASE+"retained-flow"]),
 ("parser","test_script_parse",None,[]),
]
def main():
 receipt=HERE/"qa-commands.json"
 history=json.loads(receipt.read_text(encoding="utf-8")) if receipt.exists() else []
 completed={r["job"] for r in history if r["exit_code"]==0}
 for label,script,renderer,arguments in JOBS:
  if label in completed:continue
  command="& './scripts/dev.ps1' -Action TestScript -ScriptPath 'res://tests/"+script+".gd'"
  if renderer:command+=" -Graphical -RenderingMethod "+renderer
  if arguments:command+=" -TestArgument @("+",".join("'"+a+"'" for a in arguments)+")"
  command+=" -CommandTimeoutSeconds 300"
  argv=["powershell","-NoProfile","-ExecutionPolicy","Bypass","-Command",command]
  result=subprocess.run(argv,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  output=result.stdout.decode("utf-8",errors="replace")
  record={"job":label,"argv":argv,"exit_code":result.returncode,"output":output,"coachwork_sha256":hashlib.sha256((ROOT/"game/vehicle/electric_coachwork.gd").read_bytes()).hexdigest()}
  history.append(record);receipt.write_text(json.dumps(history,indent=2)+"\n",encoding="utf-8")
  print(label+": exit "+str(result.returncode),flush=True)
  if result.returncode:
   print(output[-5000:],flush=True);raise SystemExit(result.returncode)
if __name__=="__main__":main()
