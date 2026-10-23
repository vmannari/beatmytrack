package org.beatmytrack.challenges;

import android.app.Activity;
import android.content.Intent;
import android.content.ClipData;
import android.net.Uri;
import androidx.annotation.NonNull;
import java.util.concurrent.atomic.AtomicReference;
import java.io.File;
import java.io.IOException;
import java.util.Collections;
import java.util.Set;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.godotengine.godot.plugin.SignalInfo;

/** Original Android platform bridge, using only the existing Godot/Android APIs. */
public final class BmtChallenges extends GodotPlugin {
    private final AtomicReference<String> pending = new AtomicReference<>("");
    // Activity intents are observed on Android's UI thread only.
    private Intent consumedIntent;

    public BmtChallenges(Godot godot) { super(godot); }

    @NonNull @Override public String getPluginName() { return "BmtChallenges"; }

    @NonNull @Override public Set<SignalInfo> getPluginSignals() {
        return Collections.singleton(new SignalInfo("results_share_failed",String.class,String.class));
    }

    private static String invitation(Intent intent) {
        if (intent == null || !Intent.ACTION_VIEW.equals(intent.getAction())) return "";
        Uri uri = intent.getData();
        if (uri == null) return "";
        String scheme = uri.getScheme();
        String path = uri.getPath();
        if (path == null) return "";
        boolean custom = "beatmytrack".equals(scheme) && "challenge".equals(uri.getHost())
                && path.matches("/[a-fA-F0-9]{16}/?");
        boolean web = "https".equals(scheme) && path.matches("/c/[a-fA-F0-9]{16}/?");
        String version = "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}";
        boolean track = "beatmytrack".equals(scheme) && "track".equals(uri.getHost())
                && path.matches("/" + version + "/?");
        boolean webTrack = "https".equals(scheme) && path.matches("/(t/|v1/track-versions/)" + version + "/?");
        return custom || web || track || webTrack ? uri.toString() : "";
    }

    private void readIntent(Activity activity) {
        Intent intent = activity.getIntent();
        if (intent == consumedIntent) return;
        consumedIntent = intent;
        String value = invitation(intent);
        if (!value.isEmpty()) pending.set(value);
    }

    @UsedByGodot public String takePendingLink() {
        Activity activity = getActivity();
        if (activity != null) activity.runOnUiThread(() -> readIntent(activity));
        return pending.getAndSet("");
    }

    @UsedByGodot public void shareChallenge(String text) {
        shareText(text, "Share challenge");
    }

    @UsedByGodot public void shareTrack(String text) {
        shareText(text, "Share track");
    }

    @UsedByGodot public boolean shareResults(String requestId, byte[] png, String text) {
        Activity activity = getActivity();
        if (activity == null || activity.isFinishing() || requestId == null || requestId.length() > 64
                || text == null || text.isEmpty() || text.length() > 4096 || !RivalryShareFiles.validPng(png)) return false;
        final File image;
        try { image = RivalryShareFiles.save(activity.getCacheDir(),png); }
        catch (IOException error) { return false; }
        Uri uri = new Uri.Builder().scheme("content").authority(activity.getPackageName()+".rivalry-share")
                .appendPath(image.getName()).build();
        activity.runOnUiThread(() -> {
            try {
                if (activity.isFinishing()) throw new IllegalStateException("Activity closed");
                Intent send = new Intent(Intent.ACTION_SEND);
                send.setType("image/png");
                send.putExtra(Intent.EXTRA_STREAM,uri);
                send.putExtra(Intent.EXTRA_TEXT,text);
                send.putExtra(Intent.EXTRA_TITLE,"Weekly Rivalry results");
                send.setClipData(ClipData.newRawUri("Weekly Rivalry results",uri));
                send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                Intent chooser = Intent.createChooser(send,"Share Rivalry results");
                chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                chooser.setClipData(send.getClipData());
                activity.startActivity(chooser);
            } catch (RuntimeException error) {
                image.delete();
                emitSignal("results_share_failed",requestId,"Couldn't open sharing. Try again.");
            }
        });
        return true;
    }

    private void shareText(String text, String title) {
        Activity activity = getActivity();
        if (activity == null || text == null || text.length() > 4096) return;
        activity.runOnUiThread(() -> {
            if (activity.isFinishing()) return;
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("text/plain");
            send.putExtra(Intent.EXTRA_TEXT, text);
            activity.startActivity(Intent.createChooser(send, title));
        });
    }
}
