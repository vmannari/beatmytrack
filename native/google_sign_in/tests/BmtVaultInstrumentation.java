package org.beatmytrack.signin;

import android.app.Instrumentation;
import android.content.Context;
import android.os.Bundle;
import java.io.File;
import java.nio.file.Files;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;

/** Runs only in a separately signed disposable package, never the game's data sandbox. */
public final class BmtVaultInstrumentation extends Instrumentation {
    private String phase;
    private int checks;
    @Override public void onCreate(Bundle args) { phase = args.getString("phase"); start(); }
    private void check(boolean value) { checks++; if (!value) throw new AssertionError("vault check " + checks); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            Context app = getTargetContext();
            File file = new File(app.getFilesDir(), "fixture.enc");
            String text = "fictional-session-fixture", context = "bmt-vault-test/origin/profile";
            KeyStore keys = KeyStore.getInstance("AndroidKeyStore"); keys.load(null);
            if ("write".equals(phase)) {
                byte[] encrypted = BmtSecureSession.seal(text, context);
                check(encrypted.length > 28);
                check(!new String(encrypted, StandardCharsets.UTF_8).contains(text));
                check(!Arrays.equals(encrypted, BmtSecureSession.seal(text, context)));
                check(text.equals(BmtSecureSession.open(encrypted, context)));
                check(BmtSecureSession.open(encrypted, context + "other").isEmpty());
                byte[] tampered = encrypted.clone(); tampered[tampered.length-1] ^= 1;
                check(BmtSecureSession.open(tampered, context).isEmpty());
                check(keys.getKey("bmt.session.v1", null).getEncoded() == null);
                check(BmtSecureSession.seal("x".repeat(32769), context).length == 0);
                Files.write(file.toPath(), encrypted);
            } else if ("read".equals(phase)) {
                byte[] encrypted = Files.readAllBytes(file.toPath());
                check(text.equals(BmtSecureSession.open(encrypted, context)));
                check(keys.getKey("bmt.session.v1", null).getEncoded() == null);
                check(BmtSecureSession.open(new byte[65537], context).isEmpty());
                keys.deleteEntry("bmt.session.v1");
                check(BmtSecureSession.open(encrypted, context).isEmpty());
                check(!keys.containsAlias("bmt.session.v1"));
            } else { throw new AssertionError("phase required"); }
            result.putString("result", "BMT_VAULT_PASS:" + phase + ":" + checks);
            finish(-1, result);
        } catch (Throwable error) {
            // Deliberately omit device IDs, credential/ciphertext contents and exception text.
            result.putString("result", "BMT_VAULT_FAIL:" + phase + ":" + checks);
            finish(0, result);
        }
    }
}
