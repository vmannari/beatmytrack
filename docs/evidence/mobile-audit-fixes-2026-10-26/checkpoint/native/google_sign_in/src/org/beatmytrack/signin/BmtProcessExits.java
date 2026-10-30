package org.beatmytrack.signin;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.os.Build;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONObject;

/** Coarse consented telemetry, plus explicit local support frames; never raw traces. */
public final class BmtProcessExits {
    private BmtProcessExits() { }
    public static String read(Activity activity) {
        return read(activity, false);
    }
    public static String readSupport(Activity activity) {
        return read(activity, true);
    }
    private static String read(Activity activity, boolean support) {
        if (Build.VERSION.SDK_INT < 30 || activity == null) return "[]";
        JSONArray result = new JSONArray();
        try {
            ActivityManager manager = (ActivityManager) activity.getSystemService(Context.ACTIVITY_SERVICE);
            long floor = System.currentTimeMillis() - 7L * 86400000L;
            List<ApplicationExitInfo> exits = new ArrayList<>(manager.getHistoricalProcessExitReasons(
                    activity.getPackageName(), 0, 4));
            if (!support) Collections.reverse(exits);
            for (ApplicationExitInfo exit : exits) {
                int reason = exit.getReason();
                if (exit.getTimestamp() < floor || (reason != 4 && reason != 5 && reason != 6)) continue;
                JSONObject record = new JSONObject();
                record.put("at", exit.getTimestamp()); record.put("reason", reason);
                if (support) {
                    JSONArray frames = new JSONArray();
                    try (java.io.InputStream trace = exit.getTraceInputStream()) {
                        for (String frame : BmtDiagnosticTrace.read(trace, reason == 5)) frames.put(frame);
                    } catch (Exception ignored) { /* Missing or rotated OS trace. */ }
                    record.put("frames", frames);
                }
                result.put(record);
            }
        } catch (Exception ignored) { return "[]"; }
        return result.toString();
    }
}
