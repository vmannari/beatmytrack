"""Retry one isolated release export after independently validated import.

Never launches ADB or touches the production project. Refuses to proceed when
the source snapshot, previous quick validation, offline manifest or imports fail.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import uuid

import build_pair as b
import prepare as p


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", required=True, choices=("compatibility", "mobile"))
    parser.add_argument("--max-seconds", type=int, default=480)
    args = parser.parse_args()
    if not 60 <= args.max_seconds <= 600:
        parser.error("max-seconds must be 60..600")
    task, variant = p.TASK, p.TASK / args.only
    previous_log = task / f"{args.only}-release-build.log"
    prior = previous_log.read_text(encoding="utf-8", errors="replace")
    if "PASS: focused deployment checks (import, startup, driving, catalog, menus)" not in prior:
        raise SystemExit("Prior isolated full import and quick validation are not proven")
    saved = json.loads((task / "snapshot-sha256.json").read_text(encoding="utf-8"))
    current = p.inventory(variant)
    changed = [path for path in saved if saved[path] != current.get(path)]
    expected = ["game/core/build_identity.gd", "game/export_presets.cfg", "game/project.godot"]
    if changed != expected or set(current) - set(saved) != {".gitignore"} or set(saved) - set(current):
        raise SystemExit(f"Source snapshot check failed: changed={changed}, extra={sorted(set(current)-set(saved))[:20]}")
    audit_path = task / f"{args.only}-direct-pre-import-audit.json"
    audit_cmd = [sys.executable, str(p.ROOT / "tools/android_renderer_comparison/audit_imports.py"),
                 str(variant / "game"), "--out", str(audit_path)]
    subprocess.run(audit_cmd, check=True)
    gradle_root = variant / "game/android/build"
    gradlew = (gradle_root / "gradlew.bat").read_text(encoding="utf-8")
    manifest = (gradle_root / "src/main/AndroidManifest.xml").read_text(encoding="utf-8")
    if "org.gradle.wrapper.GradleWrapperMain --offline %*" not in gradlew or \
       'android.permission.INTERNET" tools:node="remove"' not in manifest:
        raise SystemExit("Private offline Gradle/manifest gates are absent")
    if not b.KEY.is_file():
        raise SystemExit("Task-only release key is absent")
    output_dir = variant / "build/android"
    output_dir.mkdir(parents=True, exist_ok=True)
    apk = output_dir / f"probe-direct-{uuid.uuid4().hex}.apk"
    environment = os.environ.copy()
    environment.update(APPDATA=str(b.USER), LOCALAPPDATA=str(b.USER), GRADLE_USER_HOME=str(b.GRADLE),
                       TEMP=str(task / "scratch"), TMP=str(task / "scratch"),
                       ANDROID_USER_HOME=str(task / "android-user"), BMT_API_URL="",
                       GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(b.KEY),
                       GODOT_ANDROID_KEYSTORE_RELEASE_USER="probeonly",
                       GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="android")
    environment.pop("ANDROID_SDK_HOME", None)
    environment["JAVA_TOOL_OPTIONS"] = "-Djavax.net.ssl.trustStoreType=Windows-ROOT -Djavax.net.ssl.trustStore=NONE"
    log = task / f"{args.only}-direct-export.log"
    command = [sys.executable, str(b.WRAPPER), "--", str(b.ENGINE), "--headless", "--path", str(variant / "game"),
               "--export-release", "Android Debug", str(apk)]
    code = b.run(command, variant, environment, log, args.max_seconds)
    result = {"exit": code, "log": str(log), "fresh_output": str(apk), "validation": "pending",
              "source_changes": changed, "pre_import_audit": str(audit_path), "offline_gradle": True}
    receipt = task / f"{args.only}-direct-export-receipt.json"
    def save(): receipt.write_text(json.dumps(result, indent=2), encoding="utf-8")
    save()
    try:
        output = log.read_text(encoding="utf-8", errors="replace")
        if code != 0 or not apk.is_file() or re.search(r"(?im)(^|\s)(ERROR:|SCRIPT ERROR:|Parse Error:)", output):
            raise ValueError("export failed, emitted an engine error, or did not produce its fresh APK")
        aapt = b.SDK / "build-tools/35.0.1/aapt.exe"
        permissions = subprocess.run([str(aapt), "dump", "permissions", str(apk)], capture_output=True, text=True, check=True).stdout
        badging = subprocess.run([str(aapt), "dump", "badging", str(apk)], capture_output=True, text=True, check=True).stdout
        (task / f"{args.only}-direct-permissions.txt").write_text(permissions, encoding="utf-8")
        (task / f"{args.only}-direct-badging.txt").write_text(badging, encoding="utf-8")
        expected_package = p.VARIANTS[args.only][1]
        if "android.permission.INTERNET" in permissions or "application-debuggable" in badging or \
           f"package: name='{expected_package}'" not in badging:
            raise ValueError("APK failed package ID, release, or no-INTERNET validation")
        subprocess.run(audit_cmd, check=True)
        result.update(validation="package/release/no INTERNET and pre/post import checksum checks passed",
                      sha256=b.digest(apk))
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        result["validation"] = "failed: " + str(error)
        save()
        raise SystemExit(result["validation"]) from error
    save()
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
