import os
import subprocess
import sys
from pathlib import Path

root = Path.cwd()
source = root / 'backend'
environment = os.environ.copy()
environment['PYTHONPATH'] = os.pathsep.join((str(source), str(source / 'tests')))
names = ('backend_final_review attack_resistance auth google_crypto browser_auth admin admin_support commerce provider_proofs resumes '
         'communication_boundary medium_communication publication_intents challenges track_lifecycle discovery_paging '
         'robustness_fixes review_followups maintenance request_trace privacy privacy_http').split()
command = [sys.executable, '-m', 'pytest', *(str(source / 'tests' / ('test_'+name+'.py')) for name in names),
           '-q', '-x', '-k', 'not postgres and not canonical_three_rewinds_keep_original_verified_time',
           '--junitxml=.tools/backend-final-review-20261014/regression-sqlite.xml']
sys.exit(subprocess.run(command, env=environment).returncode)
