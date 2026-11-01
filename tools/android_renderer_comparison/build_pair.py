"""Build task-owned release APKs from prepared isolated projects; no ADB calls.

Every Godot invocation, including dev.ps1's direct version check, is launched
under the repository's crash-dialog wrapper. This may run for many minutes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / "build/android-renderer-comparison-20261031"
ENGINE = Path("C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe")
SDK = Path("C:/Users/ville/AppData/Local/Android/Sdk")
JDK = Path("C:/Users/ville/AppData/Local/Android/Java/jdk-17.0.20.1+1")
TEMPLATES = Path("C:/Users/ville/AppData/Roaming/Godot/export_templates/4.7.2.stable")
USER = TASK / "godot-user"
GRADLE = TASK / "gradle-user"
KEY = TASK / "probe-only.keystore"
WRAPPER = ROOT / "scripts/run_no_crash_dialog.py"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args: list[str], cwd: Path, env: dict[str, str], log: Path, timeout: int) -> int:
    with log.open("w", encoding="utf-8") as stream:
        child = subprocess.Popen(args, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT)
        try:
            return child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            stream.write("\nPARENT_TIMEOUT: operation exceeded deadline\n")
            subprocess.run(["taskkill.exe", "/PID", str(child.pid), "/T", "/F"],
                           stdout=stream, stderr=subprocess.STDOUT, check=False)
            child.wait(timeout=30)
            return 124


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=("compatibility", "mobile"))
    parser.add_argument("--max-seconds", type=int, default=300)
    args = parser.parse_args()
    if args.max_seconds < 60 or args.max_seconds > 600:
        parser.error("max-seconds must be 60..600")
    if not (TASK / "provenance.json").is_file():
        raise SystemExit("Run prepare.py and resolve its checks first.")
    for name in ((args.only,) if args.only else ("compatibility", "mobile")):
        folder = TASK / name
        result = subprocess.run([sys.executable, str(folder / "scripts/check_garage_previews.py")],
                                cwd=folder, capture_output=True, text=True)
        if result.returncode:
            raise SystemExit(f"{name} source preview integrity gate failed:\n{result.stderr}")
    if not ENGINE.is_file() or not (SDK / "platform-tools/adb.exe").is_file() or not (JDK / "bin/keytool.exe").is_file():
        raise SystemExit("Pinned engine or Android SDK/JDK is unavailable.")
    template_dir = USER / "Godot/export_templates/4.7.2.stable"
    template_dir.mkdir(parents=True, exist_ok=True)
    for filename in ("android_debug.apk", "android_release.apk", "version.txt"):
        shutil.copy2(TEMPLATES / filename, template_dir / filename)
    settings = USER / "Godot/editor_settings-4.7.tres"
    settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
                        f'export/android/android_sdk_path = "{SDK.as_posix()}"\n'
                        f'export/android/java_sdk_path = "{JDK.as_posix()}"\n'
                        f'export/android/debug_keystore = "{KEY.as_posix()}"\n'
                        'export/android/debug_keystore_user = "probeonly"\n'
                        'export/android/debug_keystore_pass = "android"\n', encoding="utf-8")
    if not KEY.exists():
        command = [str(JDK / "bin/keytool.exe"), "-genkeypair", "-keystore", str(KEY),
                   "-alias", "probeonly", "-storepass", "android", "-keypass", "android",
                   "-dname", "CN=Beat My Track Local Renderer Probe", "-keyalg", "RSA",
                   "-keysize", "2048", "-validity", "30"]
        subprocess.run(command, check=True, capture_output=True)
    # Offline artifacts must already be present in this private task directory.
    # Never read from or write to the owner's live Gradle cache.
    for sub in ("caches/modules-2", "wrapper/dists"):
        destination = GRADLE / sub
        if not destination.exists():
            raise SystemExit(f"Private offline Gradle dependency cache is missing: {destination}")
    env = os.environ.copy()
    scratch = TASK / "scratch"
    scratch.mkdir(exist_ok=True)
    android_preferences = TASK / "android-user"
    android_preferences.mkdir(exist_ok=True)
    env.update(APPDATA=str(USER), LOCALAPPDATA=str(USER), GRADLE_USER_HOME=str(GRADLE),
               TEMP=str(scratch), TMP=str(scratch), ANDROID_USER_HOME=str(android_preferences),
               BMT_API_URL="", GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(KEY),
               GODOT_ANDROID_KEYSTORE_RELEASE_USER="probeonly", GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="android")
    # AGP treats ANDROID_SDK_HOME as a parent of .android; setting it alongside
    # ANDROID_USER_HOME to the same text produces conflicting resolved paths.
    env.pop("ANDROID_SDK_HOME", None)
    env["GIT_CONFIG_COUNT"] = "1"
    env["GIT_CONFIG_KEY_0"] = "safe.directory"
    receipt_path = TASK / "build-receipt.json"
    outputs = json.loads(receipt_path.read_text(encoding="utf-8")) if args.only and receipt_path.is_file() else {}
    for name in ((args.only,) if args.only else ("compatibility", "mobile")):
        folder = TASK / name
        # Install the pinned template inside the private project. The manifest
        # merge rule removes INTERNET even if an included library requests it.
        android_root = folder / "game/android"
        gradle_root = android_root / "build"
        if not gradle_root.exists():
            template = folder / ".tools/admob/android_source.zip"
            if digest(template).upper() != "A15416B528EFB0A19A7D187E4D9F4E5336D0689144B111329FB4BD12C4447AD3":
                raise SystemExit("Android template source does not match pinned SHA-256")
            with zipfile.ZipFile(template) as archive:
                archive.extractall(gradle_root)
            (android_root / ".build_version").write_text("4.7.2.stable\n", encoding="utf-8")
            (gradle_root / ".gdignore").write_text("\n", encoding="utf-8")
            manifest = gradle_root / "src/main/AndroidManifest.xml"
            text = manifest.read_text(encoding="utf-8")
            if text.count("    <supports-screens") != 1:
                raise SystemExit("Unexpected pinned template manifest")
            text = text.replace("    <supports-screens", '    <uses-permission android:name="android.permission.INTERNET" tools:node="remove" />\n\n    <supports-screens', 1)
            manifest.write_text(text, encoding="utf-8", newline="\n")
        gradlew = gradle_root / "gradlew.bat"
        text = gradlew.read_text(encoding="utf-8")
        original = "org.gradle.wrapper.GradleWrapperMain %*"
        offline = "org.gradle.wrapper.GradleWrapperMain --offline %*"
        if original in text:
            text = text.replace(original, offline, 1)
            gradlew.write_text(text, encoding="utf-8", newline="\n")
        elif offline not in text:
            raise SystemExit("Could not verify task-only Gradle offline mode")
        if not (folder / ".git").is_dir():
            subprocess.run(["git", "init", "-q", str(folder)], check=True, cwd=ROOT)
        (folder / ".gitignore").write_text("build/\ngame/.godot/\ngame/android/build/\n.tools/\n", encoding="utf-8")
        env["GIT_CONFIG_VALUE_0"] = folder.as_posix()
        command = [sys.executable, str(WRAPPER), "--", "powershell.exe", "-NoProfile",
                   "-ExecutionPolicy", "Bypass", "-File", str(folder / "scripts/dev.ps1"),
                   "ExportAndroid", "-GodotPath", str(ENGINE), "-QuickValidation",
                   "-CommandTimeoutSeconds", str(max(1, args.max_seconds - 60))]
        log = TASK / f"{name}-release-build.log"
        exit_code = run(command, folder, env, log, args.max_seconds)
        apk = folder / "build/android/circuit01-debug.apk"
        outputs[name] = {"exit": exit_code, "log": str(log), "apk": str(apk) if apk.is_file() else None,
                         "sha256": digest(apk) if exit_code == 0 and apk.is_file() else None,
                         "release_mode": True, "verification": "pending"}
        receipt_path.write_text(json.dumps(outputs, indent=2), encoding="utf-8")
        if exit_code == 0 and apk.is_file():
            try:
                aapt = SDK / "build-tools/35.0.1/aapt.exe"
                permissions = subprocess.run([str(aapt), "dump", "permissions", str(apk)], capture_output=True, text=True, check=True)
                badging = subprocess.run([str(aapt), "dump", "badging", str(apk)], capture_output=True, text=True, check=True)
                (TASK / f"{name}-apk-permissions.txt").write_text(permissions.stdout, encoding="utf-8")
                (TASK / f"{name}-apk-badging.txt").write_text(badging.stdout, encoding="utf-8")
                if "android.permission.INTERNET" in permissions.stdout:
                    raise ValueError("APK still requests INTERNET")
                if "application-debuggable" in badging.stdout:
                    raise ValueError("APK unexpectedly uses a debuggable build")
                expected_package = ("org.beatmytrack.rendererprobe.gl20261031" if name == "compatibility"
                                    else "org.beatmytrack.rendererprobe.vk20261031")
                if f"package: name='{expected_package}'" not in badging.stdout:
                    raise ValueError("APK has an unexpected package identity")
                audit = subprocess.run([sys.executable, str(ROOT / "tools/android_renderer_comparison/audit_imports.py"),
                                        str(folder / "game"), "--out", str(TASK / f"{name}-import-audit.json")],
                                       capture_output=True, text=True)
                if audit.returncode:
                    raise ValueError("private import checksum audit failed: " + audit.stdout.strip())
                outputs[name]["verification"] = "package/release/no INTERNET/import checksum checks passed"
            except (OSError, subprocess.SubprocessError, ValueError) as error:
                outputs[name]["verification"] = "failed: " + str(error)
                receipt_path.write_text(json.dumps(outputs, indent=2), encoding="utf-8")
                raise SystemExit(f"{name} APK validation failed: {error}") from error
        receipt_path.write_text(json.dumps(outputs, indent=2), encoding="utf-8")
        if exit_code != 0 or not apk.is_file():
            raise SystemExit(f"{name} build failed ({exit_code}); see {log}")
    print(json.dumps(outputs, indent=2))


if __name__ == "__main__":
    main()
