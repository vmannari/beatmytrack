from pathlib import Path
import subprocess,sys
out=Path(__file__).resolve().parent
for name in ['run_preparation.py','review_native.py']:
 subprocess.run([sys.executable,str(out/name)],check=True)
