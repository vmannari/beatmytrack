import hashlib
import json
import struct
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
directory = root / "docs/evidence/world-ranking-refined-2026-10-22"
report = directory / "report.html"
screenshot = directory / "report-desktop.png"
profile = root / "build/world-ranking-refined-chrome-2026-10-22"
command = ["C:/Program Files/Google/Chrome/Application/chrome.exe",
    "--headless=new", "--disable-gpu", "--disable-background-networking",
    "--disable-extensions", "--disable-component-update", "--no-first-run",
    "--no-default-browser-check", "--window-size=1600,1800",
    "--virtual-time-budget=8000", f"--user-data-dir={profile}",
    f"--screenshot={screenshot}", "--dump-dom", report.as_uri()]
result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=50)
(root / "build/world-ranking-report-browser.stderr.log").write_text(result.stderr, encoding="utf-8")
(root / "build/world-ranking-report-browser.dom.html").write_text(result.stdout, encoding="utf-8")
assert result.returncode == 0, result.stderr[-2000:]
assert result.stdout.count('class="main-svg"') >= 2, "Plotly figures did not render"
assert '1,000,000' in result.stdout
assert 'best 12 results over 26 weeks' in result.stdout
assert 'Selected worldwide weekly point schedule' in result.stdout
png = screenshot.read_bytes()
assert png.startswith(b"\x89PNG\r\n\x1a\n")
width, height = struct.unpack(">II", png[16:24])
evidence = {"browser": "Installed Chrome, headless, dedicated workspace profile",
    "mode": "Offline file URL; self-contained report and embedded Plotly",
    "exit_code": result.returncode, "rendered_svg_layers": result.stdout.count('class="main-svg"'),
    "screenshot_dimensions": [width, height], "checks": ["figures rendered", "million-player result",
        "best12/26 specification", "selected points chart", "PNG output"],
    "report_sha256": hashlib.sha256(report.read_bytes()).hexdigest()}
(directory / "browser-check.json").write_text(json.dumps(evidence, indent=2), encoding="utf-8")
print(json.dumps(evidence))
