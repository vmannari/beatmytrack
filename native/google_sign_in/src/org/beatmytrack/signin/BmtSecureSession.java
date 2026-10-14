package org.beatmytrack.signin;

import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** An app-owned non-exportable key; encrypted bytes alone are persisted by Godot. */
final class BmtSecureSession {
    private static final String ALIAS = "bmt.session.v1";
    private static SecretKey key(boolean create) throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        SecretKey key = (SecretKey) store.getKey(ALIAS, null);
        if (key == null && create) {
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256).setRandomizedEncryptionRequired(true).build());
            key = generator.generateKey();
        }
        return key;
    }
    static synchronized byte[] seal(String value, String context) {
        byte[] plain = value.getBytes(StandardCharsets.UTF_8);
        try {
            if (plain.length == 0 || plain.length > 32768 || context.isEmpty() || context.length() > 4096) return new byte[0];
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key(true));
            cipher.updateAAD(context.getBytes(StandardCharsets.UTF_8));
            byte[] encrypted = cipher.doFinal(plain), iv = cipher.getIV();
            if (iv.length != 12) return new byte[0];
            byte[] result = Arrays.copyOf(iv, iv.length + encrypted.length);
            System.arraycopy(encrypted, 0, result, iv.length, encrypted.length);
            return result;
        } catch (Exception ignored) { return new byte[0]; }
        finally { Arrays.fill(plain, (byte) 0); }
    }
    static synchronized String open(byte[] value, String context) {
        byte[] plain = null;
        try {
            if (value.length < 28 || value.length > 65536 || context.isEmpty() || context.length() > 4096) return "";
            SecretKey key = key(false);
            if (key == null) return "";
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, value, 0, 12));
            cipher.updateAAD(context.getBytes(StandardCharsets.UTF_8));
            plain = cipher.doFinal(value, 12, value.length - 12);
            return plain.length <= 32768 ? new String(plain, StandardCharsets.UTF_8) : "";
        } catch (Exception ignored) { return ""; }
        finally { if (plain != null) Arrays.fill(plain, (byte) 0); }
    }
}
