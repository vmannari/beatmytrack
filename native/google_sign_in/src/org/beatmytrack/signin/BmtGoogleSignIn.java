package org.beatmytrack.signin;

import android.app.Activity;
import android.os.CancellationSignal;
import androidx.annotation.NonNull;
import androidx.credentials.*;
import androidx.credentials.exceptions.*;
import com.google.android.libraries.identity.googleid.*;
import java.util.concurrent.atomic.AtomicReference;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/** Tokens stay in memory and are consumed once; never logged or persisted here. */
public final class BmtGoogleSignIn extends GodotPlugin {
    private final AtomicReference<String> result = new AtomicReference<>("");
    private CancellationSignal cancellation;
    public BmtGoogleSignIn(Godot godot) { super(godot); }
    @NonNull @Override public String getPluginName() { return "BmtGoogleSignIn"; }

    /** OS evidence only; no stack traces, PIDs, package/device IDs or credentials. */
    @UsedByGodot public String getProcessExits() {
        return BmtProcessExits.read(getActivity());
    }

    @UsedByGodot public void startSignIn(String clientId, String nonce) {
        Activity activity = getActivity();
        if (activity == null) { result.set("error:unavailable"); return; }
        activity.runOnUiThread(() -> {
            cancelCurrent();
            result.set("");
            CancellationSignal requestCancellation = new CancellationSignal();
            cancellation = requestCancellation;
            try {
                GetSignInWithGoogleOption option = new GetSignInWithGoogleOption.Builder(clientId)
                        .setNonce(nonce).build();
                GetCredentialRequest request = new GetCredentialRequest.Builder()
                        .addCredentialOption(option).build();
                CredentialManager.create(activity).getCredentialAsync(activity, request,
                        requestCancellation, activity::runOnUiThread,
                        new CredentialManagerCallback<GetCredentialResponse, GetCredentialException>() {
                    @Override public void onResult(GetCredentialResponse response) {
                        if (cancellation != requestCancellation) return;
                        cancellation = null;
                        try {
                            Credential credential = response.getCredential();
                            if (!(credential instanceof CustomCredential)
                                    || !GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL.equals(credential.getType())) {
                                result.set("error:invalid"); return;
                            }
                            result.set("token:" + GoogleIdTokenCredential.createFrom(credential.getData()).getIdToken());
                        } catch (Exception ignored) { result.set("error:invalid"); }
                    }
                    @Override public void onError(@NonNull GetCredentialException error) {
                        if (cancellation != requestCancellation) return;
                        cancellation = null;
                        result.set(error instanceof GetCredentialCancellationException
                                ? "error:cancelled" : "error:unavailable");
                    }
                });
            } catch (Exception ignored) {
                cancellation = null;
                result.set("error:unavailable");
            }
        });
    }
    private void cancelCurrent() {
        CancellationSignal old = cancellation;
        cancellation = null;
        if (old != null) old.cancel();
        result.set("");
    }
    @UsedByGodot public String takeResult() { return result.getAndSet(""); }
    @UsedByGodot public void cancelSignIn() {
        Activity activity = getActivity();
        if (activity != null) activity.runOnUiThread(this::cancelCurrent);
    }
    @UsedByGodot public void clearSignIn() {
        Activity activity = getActivity();
        if (activity == null) return;
        activity.runOnUiThread(() -> {
            cancelCurrent();
            CredentialManager.create(activity).clearCredentialStateAsync(new ClearCredentialStateRequest(),
                    null, activity::runOnUiThread,
                    new CredentialManagerCallback<Void, ClearCredentialException>() {
                @Override public void onResult(Void unused) { }
                @Override public void onError(@NonNull ClearCredentialException ignored) { }
            });
        });
    }
}
