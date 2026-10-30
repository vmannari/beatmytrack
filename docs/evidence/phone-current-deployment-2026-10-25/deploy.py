from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import time
import urllib.request

root = Path(__file__).resolve().parents[2]
work = Path(__file__).resolve().parent
evidence = root / "docs/evidence/phone-current-deployment-2026-10-25"
adb = Path(os.environ["LOCALAPPDATA"]) / "Android/Sdk/platform-tools/adb.exe"
serial = "PRQKU4U4PREQNRWG"
package = "org.circuit01.handlinglab"
verified = json.loads((work / "verified-build.json").read_text(encoding="utf-8-sig"))
apk = Path(verified["apk_path"])
assert hashlib.sha256(apk.read_bytes()).hexdigest() == verified["apk_sha256"]


def run(*args, timeout=60):
    result = subprocess.run([str(adb), "-s", serial, *args], capture_output=True, timeout=timeout)
    if result.returncode:
        (work / "last-adb-error.log").write_bytes(result.stdout + result.stderr)
        raise RuntimeError(f"ADB failed: {args[:3]}; inspect private last-adb-error.log")
    return result.stdout


assert run("get-state").decode().strip() == "device", "USB debugging must be authorized"
assert run("shell", "getprop", "ro.product.model").decode().strip() == "DN2103"
before = run("shell", "dumpsys", "package", package).decode("utf-8", errors="replace")
(evidence / "package-before.txt").write_text(before, encoding="utf-8")
first = re.search(r"firstInstallTime=([^\r\n]+)", before)
assert first, "Expected existing installation; investigate before proceeding"
print("Verified current APK; updating DN2103 with install -r", flush=True)
installed = run("install", "-r", str(apk), timeout=300).decode("utf-8", errors="replace")
(evidence / "install.log").write_text(installed, encoding="utf-8")
assert "Success" in installed

after = run("shell", "dumpsys", "package", package).decode("utf-8", errors="replace")
(evidence / "package-after.txt").write_text(after, encoding="utf-8")
assert re.search(r"versionName=(\S+)", after).group(1) == verified["build_id"]
assert first.group(1) == re.search(r"firstInstallTime=([^\r\n]+)", after).group(1)
remote = run("shell", "pm", "path", package).decode().strip().removeprefix("package:")
assert re.fullmatch(r"/data/app/[A-Za-z0-9_./+=~\-]+\.apk", remote)
installed_hash = run("shell", "sha256sum", remote).decode().split()[0]
assert installed_hash == verified["apk_sha256"]
(evidence / "installed-apk-sha256.txt").write_text(installed_hash + "\n", encoding="utf-8")

# Re-establish the existing development USB route if the existing API is ready.
ready = None
route_restored = False
try:
    with urllib.request.urlopen("http://127.0.0.1:18181/ready", timeout=5) as reply:
        ready = reply.status
except Exception as error:
    (work / "pc-readiness-error.txt").write_text(type(error).__name__, encoding="utf-8")
if ready == 200:
    run("reverse", "tcp:18181", "tcp:18181")
    route_restored = True
(evidence / "usb-route.txt").write_bytes(run("reverse", "--list"))

print("Installation verified; launching the game", flush=True)
launch = run("shell", "am", "start", "-W", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", "-p", package)
(evidence / "launch.log").write_bytes(launch)
pid = run("shell", "pidof", package).decode().strip().split()[0]
assert pid.isdecimal()
logs = ""
for attempt in range(40):
    logs = run("logcat", "-d", "--pid=" + pid, "-v", "brief").decode("utf-8", errors="replace")
    if "APP_READY" in logs:
        break
    time.sleep(1)
(work / "device-startup-private.log").write_text(logs, encoding="utf-8")
errors = [line for line in logs.splitlines() if re.search(r"SCRIPT ERROR:|(^|\s)ERROR:|FATAL EXCEPTION|Unable to load GDExtension", line)]
summary = {
    "serial": serial,
    "model": "DN2103",
    "android": run("shell", "getprop", "ro.build.version.release").decode().strip(),
    "build": verified,
    "previous_version": re.search(r"versionName=(\S+)", before).group(1),
    "installed_version_matches": True,
    "installed_apk_sha256_matches": True,
    "first_install_time_unchanged": True,
    "app_ready": "APP_READY" in logs,
    "process_id": pid,
    "matched_startup_errors": len(errors),
    "driving_input": False,
    "provider_interaction": False,
    "uninstall": False,
    "clear_data": False,
    "track_sync": False,
    "backend_deployment": False,
    "pc_readiness_http": ready,
    "usb_route_restored": route_restored,
}
(evidence / "device-verification.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
time.sleep(2)
(evidence / "phone-launch.png").write_bytes(run("exec-out", "screencap", "-p"))
assert summary["app_ready"], "No APP_READY; inspect private log and screenshot"
assert not errors, "Startup errors; inspect private log"
print(json.dumps({"installed": True, "app_ready": True, "startup_errors": 0, "data_preserved_by_install_r": True, "build_id": verified["build_id"]}), flush=True)
