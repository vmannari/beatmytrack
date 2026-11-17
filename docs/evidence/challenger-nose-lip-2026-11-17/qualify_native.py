from pathlib import Path
import subprocess,sys
out=Path(__file__).resolve().parent
for name in ['validate_prototype.py','finish_native.py']:
 subprocess.run([sys.executable,str(out/name)],check=True)
