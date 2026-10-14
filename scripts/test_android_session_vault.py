"""Build/run the actual Keystore adapter in a disposable phone package; no game install."""
import argparse
import json
import os
import secrets
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    args = parser.parse_args()
    sdk = Path(os.environ.get("ANDROID_HOME", str(Path.home() / "AppData/Local/Android/Sdk")))
    java = Path(os.environ.get("JAVA_HOME", "C:/Program Files/Android/Android Studio/jbr")) / "bin"
    tools = sdk / "build-tools/36.1.0"
    android = sdk / "platforms/android-36/android.jar"
    identifier = secrets.token_hex(6)
    package = "org.beatmytrack.vaulttest.t" + identifier
    work = ROOT / "build/communication-m1-m6-2026-10-13" / ("android-vault-" + identifier)
    work.mkdir(parents=True)
    classes, dex = work / "classes", work / "dex"
    classes.mkdir(); dex.mkdir()
    env = dict(os.environ)
    env["JAVA_HOME"] = str(java.parent)
    env["BMT_VAULT_FIXTURE_PASS"] = secrets.token_urlsafe(24)

    def run(argv, timeout=60):
        completed = subprocess.run([str(v) for v in argv], capture_output=True, text=True, env=env, timeout=timeout, check=False)
        if completed.returncode:
            raise RuntimeError("Vault fixture command failed: " + completed.stderr[-2000:])
        return completed.stdout

    adb = [sdk / "platform-tools/adb.exe", "-s", args.serial]
    assert not run([*adb, "shell", "pm", "list", "packages", package]).strip(), "Disposable package already exists"
    manifest = work / "AndroidManifest.xml"
    manifest.write_text(f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{package}">
<uses-sdk android:minSdkVersion="26" android:targetSdkVersion="36"/>
<application android:label="BMT vault regression" android:debuggable="true" android:allowBackup="false"/>
<instrumentation android:name="org.beatmytrack.signin.BmtVaultInstrumentation" android:targetPackage="{package}"/>
</manifest>''')
    run([java / "javac.exe", "-source", "17", "-target", "17", "-classpath", android, "-d", classes,
         ROOT / "native/google_sign_in/src/org/beatmytrack/signin/BmtSecureSession.java",
         ROOT / "native/google_sign_in/tests/BmtVaultInstrumentation.java"])
    run([tools / "d8.bat", "--min-api", "26", "--lib", android, "--output", dex, *classes.rglob("*.class")])
    unsigned, aligned, signed = work / "unsigned.apk", work / "aligned.apk", work / "fixture.apk"
    run([tools / "aapt2.exe", "link", "-I", android, "--manifest", manifest, "-o", unsigned])
    with zipfile.ZipFile(unsigned, "a") as archive:
        archive.write(dex / "classes.dex", "classes.dex")
    run([tools / "zipalign.exe", "-f", "4", unsigned, aligned])
    keystore = work / "fixture.p12"
    run([java / "keytool.exe", "-genkeypair", "-keystore", keystore, "-alias", "fixture", "-keyalg", "RSA",
         "-keysize", "2048", "-validity", "1", "-dname", "CN=Disposable BMT regression",
         "-storepass:env", "BMT_VAULT_FIXTURE_PASS", "-keypass:env", "BMT_VAULT_FIXTURE_PASS"])
    run([tools / "apksigner.bat", "sign", "--ks", keystore, "--ks-pass", "env:BMT_VAULT_FIXTURE_PASS",
         "--out", signed, aligned])
    installed = False
    results = {}
    try:
        run([*adb, "install", "-t", signed])
        installed = True
        for phase, count in [("write", 8), ("read", 5)]:
            run([*adb, "shell", "am", "force-stop", package])
            output = run([*adb, "shell", "am", "instrument", "-w", "-e", "phase", phase,
                          package + "/org.beatmytrack.signin.BmtVaultInstrumentation"])
            (work / (phase + ".log")).write_text(output, encoding="utf-8")
            assert "BMT_VAULT_PASS:" + phase + ":" + str(count) in output, "Phone Keystore regression failed"
            results[phase] = count
    finally:
        if installed:
            assert "Success" in run([*adb, "uninstall", package]), "Disposable fixture cleanup failed"
        # Only this generated throwaway signing key; no release material is used.
        keystore.unlink(missing_ok=True)
    receipt = {"package": package, "checks": results, "total": sum(results.values()),
               "process_restart": True, "uninstalled": installed, "game_install_or_data_changes": False}
    (work / "result.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
