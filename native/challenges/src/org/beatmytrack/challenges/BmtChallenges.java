package org.beatmytrack.challenges;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import androidx.annotation.NonNull;
import java.util.concurrent.atomic.AtomicReference;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/** Original Android platform bridge, using only the existing Godot/Android APIs. */
public final class BmtChallenges extends GodotPlugin {
    private final AtomicReference<String> pending = new AtomicReference<>("");
    // Activity intents are observed on Android's UI thread only.
    private Intent consumedIntent;

    public BmtChallenges(Godot godot) { super(godot); }

    @NonNull @Override public String getPluginName() { return "BmtChallenges"; }

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
        return custom || web ? uri.toString() : "";
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
        Activity activity = getActivity();
        if (activity == null || text == null || text.length() > 4096) return;
        activity.runOnUiThread(() -> {
            if (activity.isFinishing()) return;
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("text/plain");
            send.putExtra(Intent.EXTRA_TEXT, text);
            activity.startActivity(Intent.createChooser(send, "Share challenge"));
        });
    }
}
