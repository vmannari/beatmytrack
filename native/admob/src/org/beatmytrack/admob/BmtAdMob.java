package org.beatmytrack.admob;

import android.app.Activity;
import android.content.pm.ApplicationInfo;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.annotation.NonNull;
import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

/** Original development-only bridge; only Google's demo units are used. */
public final class BmtAdMob extends GodotPlugin {
    private static final String TAG = "BMTAdMobTest";
    private static final String DEMO_UNIT = "ca-app-pub-3940256099942544/5224354917";
    private static final String INTERSTITIAL_DEMO_UNIT = "ca-app-pub-3940256099942544/1033173712";
    private final Handler main = new Handler(Looper.getMainLooper());
    private String request;
    private boolean initialized;
    private boolean showing;
    private boolean earned;
    private boolean abandoned;
    private boolean interstitialRequest;
    private boolean interstitialShown;
    private InterstitialAd interstitial;
    private long interstitialLoadedAt;
    private boolean interstitialLoading;
    private int interstitialGeneration;

    public BmtAdMob(Godot godot) { super(godot); }

    @NonNull @Override public String getPluginName() { return "BmtAdMob"; }

    @NonNull @Override public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(
            new SignalInfo("rewarded_result", String.class, Boolean.class, String.class),
            new SignalInfo("rewarded_presented", String.class),
            new SignalInfo("interstitial_result", String.class, Boolean.class, String.class)));
    }

    @UsedByGodot public void showRewarded(String id) {
        main.post(() -> {
            Activity activity = getActivity();
            if (activity == null || activity.isFinishing()
                    || (activity.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
                emitSignal("rewarded_result", id, false, "Test ads require an Android development build.");
                return;
            }
            if (request != null) {
                emitSignal("rewarded_result", id, false, "An ad is already open.");
                return;
            }
            request = id;
            interstitialRequest = false;
            showing = false;
            earned = false;
            abandoned = false;
            Log.i(TAG, "Loading rewarded demo ad");
            main.postDelayed(() -> {
                if (id.equals(request) && !showing)
                    finish(id, false, "Test ad loading timed out. Please retry.");
            }, 45000);
            if (initialized) load(id);
            else MobileAds.initialize(activity, status -> main.post(() -> {
                initialized = true;
                if (id.equals(request)) load(id);
            }));
        });
    }

    private void load(String id) {
        Activity activity = getActivity();
        if (activity == null || activity.isFinishing()) {
            finish(id, false, "The game is closing.");
            return;
        }
        RewardedAd.load(activity, DEMO_UNIT, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
            @Override public void onAdFailedToLoad(@NonNull LoadAdError error) {
                Log.w(TAG, "Rewarded demo load failed: " + error.toString());
                finish(id, false, "Test ad unavailable (code " + error.getCode() + "). Please retry.");
            }
            @Override public void onAdLoaded(@NonNull RewardedAd ad) {
                if (!id.equals(request)) return;
                Activity owner = getActivity();
                if (owner == null || owner.isFinishing() || abandoned) {
                    finish(id, false, "Test ad cancelled.");
                    return;
                }
                ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                    @Override public void onAdShowedFullScreenContent() {
                        Log.i(TAG, "Rewarded demo ad shown");
                        if (id.equals(request)) emitSignal("rewarded_presented", id);
                    }
                    @Override public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                        Log.w(TAG, "Rewarded demo show failed: " + error.toString());
                        finish(id, false, "Test ad could not open (code " + error.getCode() + ").");
                    }
                    @Override public void onAdDismissedFullScreenContent() {
                        Log.i(TAG, earned ? "Rewarded demo ad completed and dismissed" : "Rewarded demo ad dismissed without reward");
                        finish(id, earned && !abandoned, earned ? "" : "Ad closed before completion. No resume used.");
                    }
                });
                showing = true;
                ad.show(owner, reward -> {
                    if (id.equals(request) && !abandoned) {
                        earned = true;
                        Log.i(TAG, "Rewarded demo completion callback");
                    }
                });
            }
        });
    }

    private void finish(String id, boolean completed, String message) {
        if (!id.equals(request)) return;
        request = null;
        showing = false;
        emitSignal("rewarded_result", id, completed, message);
    }

    private boolean developmentActivity(Activity activity) {
        return activity != null && !activity.isFinishing() && !activity.isDestroyed()
            && (activity.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
    }

    private boolean interstitialReady() {
        // Google's loaded ads expire after an hour. Keep one for at most 55 min.
        return interstitial != null && android.os.SystemClock.elapsedRealtime() - interstitialLoadedAt < 55 * 60 * 1000L;
    }

    @UsedByGodot public void prepareInterstitial() {
        main.post(() -> {
            Activity activity = getActivity();
            if (!developmentActivity(activity) || request != null || interstitialLoading || interstitialReady()) return;
            interstitial = null;
            interstitialLoading = true;
            int generation = ++interstitialGeneration;
            main.postDelayed(() -> {
                if (generation == interstitialGeneration && interstitialLoading) {
                    interstitialLoading = false;
                    ++interstitialGeneration;
                }
            }, 45000);
            Runnable load = () -> {
                Activity owner = getActivity();
                if (generation != interstitialGeneration) return;
                if (!developmentActivity(owner)) {
                    interstitialLoading = false;
                    return;
                }
                InterstitialAd.load(owner, INTERSTITIAL_DEMO_UNIT, new AdRequest.Builder().build(), new InterstitialAdLoadCallback() {
                    @Override public void onAdLoaded(@NonNull InterstitialAd ad) {
                        if (generation != interstitialGeneration) return;
                        interstitialLoading = false;
                        interstitial = ad;
                        interstitialLoadedAt = android.os.SystemClock.elapsedRealtime();
                        Log.i(TAG, "Interstitial demo ready");
                    }
                    @Override public void onAdFailedToLoad(@NonNull LoadAdError error) {
                        if (generation != interstitialGeneration) return;
                        interstitialLoading = false;
                        Log.w(TAG, "Interstitial demo load failed: " + error.getCode());
                    }
                });
            };
            if (initialized) load.run();
            else MobileAds.initialize(activity, status -> main.post(() -> {
                initialized = true;
                load.run();
            }));
        });
    }

    @UsedByGodot public void discardInterstitial() {
        main.post(() -> {
            ++interstitialGeneration;
            interstitialLoading = false;
            interstitial = null;
        });
    }

    @UsedByGodot public void tryShowInterstitial(String id) {
        main.post(() -> {
            Activity activity = getActivity();
            if (!developmentActivity(activity) || !activity.hasWindowFocus() || request != null || !interstitialReady()) {
                emitSignal("interstitial_result", id, false, "Ad unavailable.");
                return;
            }
            InterstitialAd ad = interstitial;
            interstitial = null;
            request = id;
            interstitialRequest = true;
            interstitialShown = false;
            showing = true;
            abandoned = false;
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override public void onAdShowedFullScreenContent() {
                    if (id.equals(request)) interstitialShown = true;
                }
                @Override public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                    finishInterstitial(id, "Ad could not open.");
                }
                @Override public void onAdDismissedFullScreenContent() {
                    finishInterstitial(id, "");
                }
            });
            try {
                ad.show(activity);
            } catch (RuntimeException error) {
                finishInterstitial(id, "Ad could not open.");
            }
        });
    }

    private void finishInterstitial(String id, String message) {
        if (!id.equals(request) || !interstitialRequest) return;
        request = null;
        showing = false;
        interstitialRequest = false;
        emitSignal("interstitial_result", id, interstitialShown, message);
    }

    @UsedByGodot public void cancelRequest(String id) {
        main.post(() -> {
            if (!id.equals(request)) return;
            abandoned = true;
            if (!showing) {
                if (interstitialRequest) finishInterstitial(id, "Test ad cancelled.");
                else finish(id, false, "Test ad cancelled.");
            }
        });
    }
}
