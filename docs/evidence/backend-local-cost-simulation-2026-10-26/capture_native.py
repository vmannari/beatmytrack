"""Capture the exact child exit code without PowerShell stderr conversion."""
import json
import subprocess
import sys
from pathlib import Path

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
result=subprocess.run([sys.executable,"-X","utf8",str(OUT/"run_native_cache.py"),"--final-trial"],
    cwd=ROOT,capture_output=True,timeout=240)
(OUT/"native-final.stdout.log").write_bytes(result.stdout)
(OUT/"native-final.stderr.log").write_bytes(result.stderr)
record={"python_returncode":result.returncode,"stdout_bytes":len(result.stdout),"stderr_bytes":len(result.stderr),
    "native_summary_present":b"Local cost native: 21 checks, 0 failures" in result.stdout,
    "all_assertions_completed":(OUT/"native-cache.json").is_file() and result.returncode==0}
(OUT/"native-exit.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
print(json.dumps(record))
raise SystemExit(result.returncode)
