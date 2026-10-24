"""Ranking is an optional supervised, low-priority shipping process."""
import json
import os
import signal
import subprocess
import sys

import pytest
from test_service_worker import PROBE, cleanup, wait_file

pytestmark = pytest.mark.skipif(not sys.platform.startswith("linux"), reason="Linux process priority/signals")


def test_ranking_role_priority_and_shutdown(tmp_path):
    code = """import sys
from bmt_backend.service_worker import supervise
fixture, folder = sys.argv[1:]
commands = {role:(sys.executable,fixture,'child',folder,role,'normal')
            for role in ('worker','publication','discovery','ranking')}
raise SystemExit(supervise(ranking_enabled=True,commands=commands,shutdown_seconds=2))
"""
    output = (tmp_path / "ranking-supervisor.log").open("w",encoding="utf-8")
    process = subprocess.Popen([sys.executable,"-c",code,str(PROBE),str(tmp_path)],stdout=output,stderr=output)
    try:
        ranking = wait_file(process,tmp_path,"ranking.ready")
        worker = wait_file(process,tmp_path,"worker.ready")
        assert ranking["nice"] == 19 and worker["nice"] < ranking["nice"]
        process.send_signal(signal.SIGTERM)
        assert process.wait(4) == 0
        assert json.loads((tmp_path / "ranking.signal").read_text())["signal"] == signal.SIGTERM
        with pytest.raises(ProcessLookupError): os.kill(ranking["pid"],0)
    finally:
        cleanup(process,output)
