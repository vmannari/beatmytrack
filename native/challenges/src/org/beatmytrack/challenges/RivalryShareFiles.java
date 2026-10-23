package org.beatmytrack.challenges;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.Comparator;
import java.util.UUID;

/** Only generated PNG receipts live here; no player saves or public storage. */
final class RivalryShareFiles {
    static final int MAX_BYTES = 4 * 1024 * 1024;
    private static final int MAX_FILES = 6;
    private static final long MAX_AGE = 24L * 60 * 60 * 1000;
    private static final byte[] PNG = {(byte)137,80,78,71,13,10,26,10};

    static boolean validPng(byte[] png) {
        if (png == null || png.length < 33 || png.length > MAX_BYTES) return false;
        for (int i = 0; i < PNG.length; i++) if (png[i] != PNG[i]) return false;
        if (png[8] != 0 || png[9] != 0 || png[10] != 0 || png[11] != 13
                || png[12] != 'I' || png[13] != 'H' || png[14] != 'D' || png[15] != 'R') return false;
        int width = integer(png,16), height = integer(png,20);
        return width > 0 && height > 0 && width <= 2048 && height <= 2048;
    }

    private static int integer(byte[] value, int index) {
        return (value[index] & 255) << 24 | (value[index+1] & 255) << 16
                | (value[index+2] & 255) << 8 | value[index+3] & 255;
    }

    static synchronized File save(File cache, byte[] png) throws IOException {
        if (!validPng(png)) throw new IOException("Invalid result image");
        File directory = new File(cache,"rivalry-shares");
        if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("Share cache unavailable");
        String name = "rivalry-" + UUID.randomUUID().toString().replace("-","") + ".png";
        File staging = new File(directory,name+".tmp"), result = new File(directory,name);
        try {
            try (FileOutputStream stream = new FileOutputStream(staging)) { stream.write(png); }
            if (!staging.renameTo(result)) throw new IOException("Result image could not be saved");
        } finally { if (staging.exists()) staging.delete(); }
        File[] files = directory.listFiles(file -> file.getName().matches("rivalry-[a-f0-9]{32}\\.png(\\.tmp)?"));
        if (files != null) {
            Arrays.sort(files,Comparator.comparingLong(File::lastModified).reversed());
            long oldest = System.currentTimeMillis()-MAX_AGE;
            int kept = 1;
            for (File file : files) {
                if (file.equals(result)) continue;
                if (file.getName().endsWith(".tmp") || file.lastModified() < oldest || kept >= MAX_FILES) file.delete();
                else kept++;
            }
        }
        return result;
    }

    static File resolve(File cache, String name) throws IOException {
        if (name == null || !name.matches("rivalry-[a-f0-9]{32}\\.png")) throw new IOException("Unknown result image");
        File directory = new File(cache,"rivalry-shares").getCanonicalFile();
        File image = new File(directory,name).getCanonicalFile();
        if (!directory.equals(image.getParentFile()) || !image.isFile() || image.length() > MAX_BYTES)
            throw new IOException("Unknown result image");
        return image;
    }
}
