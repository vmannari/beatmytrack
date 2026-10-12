"""Exercise the actual CLI, report contract and failing performance gates."""
import json
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

from bmt_backend.loadtest import database_url


def test_lab_rejects_remote_database_and_ignores_live_configuration(monkeypatch):
    args=SimpleNamespace(database_env=None)
    monkeypatch.setenv("BMT_DATABASE_URL","postgresql+psycopg://live@remote.invalid/live")
    monkeypatch.delenv("BMT_LOAD_DATABASE_URL",raising=False)
    assert database_url(args)==""
    monkeypatch.setenv("BMT_LOAD_DATABASE_URL","postgresql+psycopg://fixture@remote.invalid/fixture")
    with pytest.raises(ValueError,match="disposable"):database_url(args)


@pytest.mark.parametrize("budget,exit_code",[(5000,0),(.001,1)])
def test_real_http_lab_emits_metrics_and_enforces_latency_budget(tmp_path,budget,exit_code):
    output=tmp_path/"load.json"
    result=subprocess.run([sys.executable,"-m","bmt_backend.loadtest","--players","50","--tracks","5",
        "--actors","6","--clients","2","--duration","2","--scenario","reads","--workers","0",
        "--max-requests","20","--p95-budget-ms",str(budget),"--output",str(output)],
        cwd=Path(__file__).resolve().parents[2],capture_output=True,text=True,timeout=45,check=False)
    assert result.returncode==exit_code,result.stdout+result.stderr
    report=json.loads(output.read_text())
    assert report["fixture"]["synthetic_seed"] and report["requests"]>=12
    assert report["response_body_wire_bytes"]>0 and report["api_processes"][0]["rss_peak_bytes"]>0
    assert report["api_processes"][0]["statements"]["SELECT"]>20
    assert report["connection_budget"]["total_max"]==9
    assert all(item["status"]==200 for item in report["post_load_recovery"])
    assert bool(report["budget_violations"])==(exit_code==1)
