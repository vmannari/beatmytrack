"""Run the actual Java link/share adapter against minimal host platform doubles.

This verifies parsing, pending-intent consumption and share payloads; it is not
an Android device, native activity dispatch or verified-domain association test.
"""
from pathlib import Path
import argparse
import os
import subprocess
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/track-link-bridge-test"
JAVA = Path(r"C:/Program Files/Android/Android Studio/jbr/bin")
STUBS = {
    "android/net/Uri.java": '''package android.net; public class Uri {
 private java.net.URI value; public static Uri parse(String text) { Uri u=new Uri(); u.value=java.net.URI.create(text); return u; }
 public String getScheme(){return value.getScheme();} public String getHost(){return value.getHost();}
 public String getPath(){return value.getPath();} public String toString(){return value.toString();}}''',
    "android/content/Intent.java": '''package android.content; import android.net.Uri; public class Intent {
 public static final String ACTION_VIEW="view",ACTION_SEND="send",EXTRA_TEXT="text"; public static String chooser;
 private String action; private Uri data; public String text,type; public Intent(String a){action=a;}
 public String getAction(){return action;} public Uri getData(){return data;} public Intent setData(Uri u){data=u;return this;}
 public void setType(String v){type=v;} public void putExtra(String k,String v){text=v;}
 public static Intent createChooser(Intent value,String title){chooser=title;return value;}}''',
    "android/app/Activity.java": '''package android.app; import android.content.Intent; public class Activity {
 public Intent intent,started; public Intent getIntent(){return intent;} public void runOnUiThread(Runnable r){r.run();}
 public boolean isFinishing(){return false;} public void startActivity(Intent value){started=value;}}''',
    "androidx/annotation/NonNull.java": "package androidx.annotation; public @interface NonNull {}",
    "org/godotengine/godot/Godot.java": '''package org.godotengine.godot; public class Godot {
 public android.app.Activity activity; public Godot(android.app.Activity a){activity=a;}}''',
    "org/godotengine/godot/plugin/GodotPlugin.java": '''package org.godotengine.godot.plugin; public class GodotPlugin {
 private org.godotengine.godot.Godot godot; public GodotPlugin(org.godotengine.godot.Godot g){godot=g;}
 public String getPluginName(){return "";} public android.app.Activity getActivity(){return godot.activity;}}''',
    "org/godotengine/godot/plugin/UsedByGodot.java": "package org.godotengine.godot.plugin; public @interface UsedByGodot {}",
    "TrackLinksTest.java": '''import org.beatmytrack.challenges.BmtChallenges;
import android.app.Activity; import android.content.Intent; import android.net.Uri;
public class TrackLinksTest {
 static int checks=0; static void check(boolean value){checks++; if(!value)throw new AssertionError("check "+checks);}
 public static void main(String[] args){ Activity a=new Activity(); BmtChallenges p=new BmtChallenges(new org.godotengine.godot.Godot(a));
 String id="11111111-2222-4333-8444-555555555555";
 String[] valid={"beatmytrack://track/"+id,"https://fixture.invalid/t/"+id,"https://fixture.invalid/v1/track-versions/"+id,
 "beatmytrack://challenge/AB12CD34EF56AB78","https://fixture.invalid/c/AB12CD34EF56AB78"};
 for(String url:valid){a.intent=new Intent(Intent.ACTION_VIEW).setData(Uri.parse(url));check(p.takePendingLink().equals(url));check(p.takePendingLink().isEmpty());}
 String[] invalid={"beatmytrack://track/bad","beatmytrack://wrong/"+id,"https://fixture.invalid/t/"+id+"/document","https://fixture.invalid/t/no-id","http://fixture.invalid/t/"+id};
 for(String url:invalid){a.intent=new Intent(Intent.ACTION_VIEW).setData(Uri.parse(url));check(p.takePendingLink().isEmpty());}
 a.intent=new Intent(Intent.ACTION_SEND).setData(Uri.parse(valid[0]));check(p.takePendingLink().isEmpty());
 p.shareTrack("Mountain Run\\n"+valid[1]);check(a.started.text.endsWith(valid[1]));check(a.started.type.equals("text/plain"));check(Intent.chooser.equals("Share track"));
 p.shareChallenge("Existing challenge");check(a.started.text.equals("Existing challenge"));check(Intent.chooser.equals("Share challenge"));
 Intent before=a.started;p.shareTrack("x".repeat(4097));check(a.started==before);
 System.out.println("JAVA_TRACK_LINKS: "+checks+" checks, 0 failures");}}
''',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--android-compile", action="store_true")
    args = parser.parse_args()
    javac = str(JAVA / "javac.exe") if (JAVA / "javac.exe").is_file() else shutil.which("javac")
    java = str(JAVA / "java.exe") if (JAVA / "java.exe").is_file() else shutil.which("java")
    assert javac and java, "Java compiler/runtime are required"
    sources = []
    for name, source in STUBS.items():
        path = WORK / "src" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")
        sources.append(str(path))
    classes = WORK / "classes"
    classes.mkdir(parents=True, exist_ok=True)
    actual = ROOT / "native/challenges/src/org/beatmytrack/challenges/BmtChallenges.java"
    subprocess.run([javac, "-d", str(classes), *sources, str(actual)], check=True)
    result = subprocess.run([java, "-cp", str(classes), "TrackLinksTest"], check=True,
                            text=True, capture_output=True)
    print(result.stdout, end="")
    if args.android_compile:
        sdk = Path(os.environ.get("ANDROID_HOME", str(Path.home() / "AppData/Local/Android/Sdk")))
        native = WORK / "android-compile"
        native.mkdir(exist_ok=True)
        # Work only with copied jars: Windows sandbox metadata lookups on the
        # external SDK path can fail during javac's zip-filesystem teardown.
        shutil.copy2(sdk / "platforms/android-36/android.jar", native / "android.jar")
        with zipfile.ZipFile(ROOT / "game/android/build/libs/debug/godot-lib.template_debug.aar") as archive:
            (native / "godot-classes.jar").write_bytes(archive.read("classes.jar"))
        classpath = str(native / "android.jar") + os.pathsep + str(native / "godot-classes.jar")
        result = subprocess.run([javac, "--release", "17", "-classpath", classpath, "-d", str(native / "classes-final"),
            str(WORK / "src/androidx/annotation/NonNull.java"), str(actual)], text=True, capture_output=True)
        assert result.returncode == 0 and "exception" not in result.stderr.lower(), result.stderr
        assert (native / "classes-final/org/beatmytrack/challenges/BmtChallenges.class").is_file()
        javap = str(JAVA / "javap.exe") if (JAVA / "javap.exe").is_file() else shutil.which("javap")
        bytecode = subprocess.check_output([javap, "-classpath", str(native / "godot-classes.jar"), "-c",
            "org.godotengine.godot.GodotActivity"], text=True)
        warm = bytecode.split("protected void onNewIntent(android.content.Intent);", 1)[1][:2200]
        assert "setIntent:" in warm
        (native / "warm-intent.txt").write_text(warm, encoding="utf-8")
        print("ANDROID_TRACK_LINKS_COMPILE: Android 36 + pinned Godot AAR, release 17; warm intent updates verified; no APK export")


if __name__ == "__main__":
    main()
