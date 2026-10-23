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
 public String getScheme(){return value.getScheme();} public String getHost(){return value.getHost();} public String getAuthority(){return value.getAuthority();}
 public String getPath(){return value.getPath();} public String getLastPathSegment(){return getPath().substring(getPath().lastIndexOf('/')+1);}
 public java.util.List<String> getPathSegments(){return java.util.Arrays.asList(getPath().substring(1).split("/"));}
 public String toString(){return value.toString();}
 public static class Builder {String scheme,authority,path;public Builder scheme(String s){scheme=s;return this;}public Builder authority(String a){authority=a;return this;}
 public Builder appendPath(String p){path=p;return this;}public Uri build(){return Uri.parse(scheme+"://"+authority+"/"+path);}}}''',
    "android/content/Intent.java": '''package android.content; import android.net.Uri; public class Intent {
 public static final String ACTION_VIEW="view",ACTION_SEND="send",EXTRA_TEXT="text",EXTRA_STREAM="stream",EXTRA_TITLE="title"; public static String chooser;
 public static final int FLAG_GRANT_READ_URI_PERMISSION=1;public int flags; public Uri stream; public ClipData clip;
 private String action; private Uri data; public String text,type,title; public Intent(String a){action=a;}
 public String getAction(){return action;} public Uri getData(){return data;} public Intent setData(Uri u){data=u;return this;}
 public void setType(String v){type=v;} public void putExtra(String k,String v){if(EXTRA_TEXT.equals(k))text=v;else title=v;}
 public void putExtra(String k,Uri v){stream=v;}public void setClipData(ClipData c){clip=c;} public ClipData getClipData(){return clip;}
 public Intent addFlags(int value){flags|=value;return this;}
 public static Intent createChooser(Intent value,String title){chooser=title;return value;}}''',
    "android/content/ClipData.java": '''package android.content; public class ClipData {public android.net.Uri uri;public static ClipData newRawUri(String label,android.net.Uri uri){ClipData c=new ClipData();c.uri=uri;return c;}}''',
    "android/content/Context.java": '''package android.content; public class Context {public java.io.File cache=new java.io.File(System.getProperty("bmt.test.cache")); public java.io.File getCacheDir(){cache.mkdirs();return cache;}public String getPackageName(){return "fixture.bmt";}}''',
    "android/app/Activity.java": '''package android.app; import android.content.Intent; public class Activity extends android.content.Context {
 public Intent intent,started;public boolean finishing,failStart,defer;public Runnable waiting; public Intent getIntent(){return intent;}
 public void runOnUiThread(Runnable r){if(defer)waiting=r;else r.run();}
 public boolean isFinishing(){return finishing;} public void startActivity(Intent value){if(failStart)throw new IllegalStateException("fixture failure");started=value;}}''',
    "android/content/ContentValues.java": "package android.content; public class ContentValues {}",
    "android/content/ContentProvider.java": '''package android.content; import android.net.Uri; public abstract class ContentProvider {
 public Context context;public Context getContext(){return context;}public abstract boolean onCreate();
 public abstract android.os.ParcelFileDescriptor openFile(Uri u,String m)throws java.io.FileNotFoundException; public abstract String getType(Uri u);
 public abstract android.database.Cursor query(Uri u,String[] p,String s,String[] a,String o);public abstract Uri insert(Uri u,ContentValues v);
 public abstract int update(Uri u,ContentValues v,String s,String[] a);public abstract int delete(Uri u,String s,String[] a);}''',
    "android/database/Cursor.java": "package android.database; public interface Cursor {}",
    "android/database/MatrixCursor.java": '''package android.database; public class MatrixCursor implements Cursor {public String[] columns;public Object[] row;public MatrixCursor(String[] c,int n){columns=c;}public void addRow(Object[] r){row=r;}}''',
    "android/provider/OpenableColumns.java": "package android.provider; public interface OpenableColumns {String DISPLAY_NAME=\"_display_name\",SIZE=\"_size\";}",
    "android/os/ParcelFileDescriptor.java": '''package android.os; public class ParcelFileDescriptor {public static final int MODE_READ_ONLY=1;public java.io.File file; public static ParcelFileDescriptor open(java.io.File f,int mode){ParcelFileDescriptor p=new ParcelFileDescriptor();p.file=f;return p;}}''',
    "androidx/annotation/NonNull.java": "package androidx.annotation; public @interface NonNull {}",
    "org/godotengine/godot/Godot.java": '''package org.godotengine.godot; public class Godot {
 public android.app.Activity activity; public Godot(android.app.Activity a){activity=a;}}''',
    "org/godotengine/godot/plugin/GodotPlugin.java": '''package org.godotengine.godot.plugin; public class GodotPlugin {
 private org.godotengine.godot.Godot godot; public GodotPlugin(org.godotengine.godot.Godot g){godot=g;}
 public String getPluginName(){return "";} public android.app.Activity getActivity(){return godot.activity;}
 public java.util.Set<SignalInfo> getPluginSignals(){return java.util.Collections.emptySet();}public String lastSignal;public Object[] lastValues;
 public void emitSignal(String name,Object... values){lastSignal=name;lastValues=values;}}''',
    "org/godotengine/godot/plugin/SignalInfo.java": "package org.godotengine.godot.plugin; public class SignalInfo {public SignalInfo(String name,Class<?>... types){}}",
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
    "org/beatmytrack/challenges/RivalrySharingTest.java": '''package org.beatmytrack.challenges;
import android.app.Activity;import android.content.Intent;import android.net.Uri;import android.database.MatrixCursor;
import java.io.*;import java.nio.file.Files;import java.util.Arrays;import javax.imageio.ImageIO;import java.awt.image.BufferedImage;
public class RivalrySharingTest {
 static int checks;static void check(boolean value){checks++;if(!value)throw new AssertionError("share check "+checks);}
 static void refuses(Runnable action){boolean denied=false;try{action.run();}catch(RuntimeException e){denied=true;}check(denied);}
 public static void main(String[] args)throws Exception {
  Activity activity=new Activity();BmtChallenges bridge=new BmtChallenges(new org.godotengine.godot.Godot(activity));
  ByteArrayOutputStream bytes=new ByteArrayOutputStream();ImageIO.write(new BufferedImage(2,2,BufferedImage.TYPE_INT_ARGB),"png",bytes);byte[] png=bytes.toByteArray();
  String text="Beat my track - Weekly Rivalry - Week 42\\n#1 / 20 | 150 points | 5/5 track victories";
  check(bridge.shareResults("request-1",png,text));Intent send=activity.started;
  check("image/png".equals(send.type));check(text.equals(send.text));check("Share Rivalry results".equals(Intent.chooser));
  check(send.stream!=null&&"content".equals(send.stream.getScheme()));check(send.stream.getAuthority().equals("fixture.bmt.rivalry-share"));
  check(send.clip.uri.equals(send.stream));check(send.flags==Intent.FLAG_GRANT_READ_URI_PERMISSION);
  RivalryShareProvider provider=new RivalryShareProvider();provider.context=activity;check(provider.onCreate());
  check(provider.getType(send.stream).equals("image/png"));check(Arrays.equals(Files.readAllBytes(provider.openFile(send.stream,"r").file.toPath()),png));
  MatrixCursor cursor=(MatrixCursor)provider.query(send.stream,null,null,null,null);check(cursor.row[0].equals("Beat my track - Weekly Rivalry.png"));check(((Long)cursor.row[1])==png.length);
  boolean denied=false;try{provider.openFile(send.stream,"rw");}catch(FileNotFoundException e){denied=true;}check(denied);
  for(String uri:new String[]{"content://fixture.bmt.rivalry-share/../records.json","content://wrong/"+send.stream.getLastPathSegment(),"content://fixture.bmt.rivalry-share/records.json"}) {
   denied=false;try{provider.openFile(Uri.parse(uri),"r");}catch(FileNotFoundException e){denied=true;}check(denied);
  }
  refuses(()->provider.insert(send.stream,null));refuses(()->provider.delete(send.stream,null,null));refuses(()->provider.update(send.stream,null,null,null));
  check(!bridge.shareResults("bad",new byte[40],text));check(!bridge.shareResults("bad",new byte[RivalryShareFiles.MAX_BYTES+1],text));
  check(!bridge.shareResults("bad",png,"x".repeat(4097)));check(!bridge.shareResults("bad",png,""));
  byte[] oversized=png.clone();oversized[16]=0x7f;check(!bridge.shareResults("bad",oversized,text));
  activity.finishing=true;check(!bridge.shareResults("closed",png,text));activity.finishing=false;
  activity.failStart=true;check(bridge.shareResults("failed",png,text));check(bridge.lastSignal.equals("results_share_failed")&&bridge.lastValues[0].equals("failed"));activity.failStart=false;
  activity.defer=true;check(bridge.shareResults("closing",png,text));activity.finishing=true;activity.waiting.run();check(bridge.lastValues[0].equals("closing"));activity.finishing=false;activity.defer=false;
  File directory=new File(activity.getCacheDir(),"rivalry-shares");File untouched=new File(directory,"unrelated.txt");Files.write(untouched.toPath(),new byte[]{1,2,3});
  for(int i=0;i<12;i++)RivalryShareFiles.save(activity.getCacheDir(),png);
  check(directory.listFiles(f->f.getName().endsWith(".png")).length<=6);check(untouched.isFile());check(directory.listFiles(f->f.getName().endsWith(".tmp")).length==0);
  check(new BmtChallenges(new org.godotengine.godot.Godot(null)).shareResults("absent",png,text)==false);
  System.out.println("JAVA_RIVALRY_SHARING: "+checks+" checks, 0 failures");
 }
}''',
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
    actual = sorted((ROOT / "native/challenges/src").rglob("*.java"))
    subprocess.run([javac, "-d", str(classes), *sources, *map(str,actual)], check=True)
    result = subprocess.run([java, "-Dbmt.test.cache="+str(WORK / "cache"), "-cp", str(classes), "TrackLinksTest"], check=True,
                            text=True, capture_output=True)
    print(result.stdout, end="")
    subprocess.run([java, "-Dbmt.test.cache="+str(WORK / "rivalry-cache"), "-cp", str(classes), "org.beatmytrack.challenges.RivalrySharingTest"], check=True)
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
            str(WORK / "src/androidx/annotation/NonNull.java"), *map(str,actual)], text=True, capture_output=True)
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
