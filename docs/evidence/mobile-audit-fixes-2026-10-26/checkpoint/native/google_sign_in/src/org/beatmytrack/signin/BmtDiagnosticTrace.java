package org.beatmytrack.signin;

import java.io.InputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Discard raw OS data. Emit only library-relative PCs/build IDs or own Java sites.
 * Native field numbers: AOSP debuggerd/proto/tombstone.proto (Tombstone/Thread/BacktraceFrame).
 * No generated protobuf runtime, raw abort message, registers, names, IDs or memory. */
public final class BmtDiagnosticTrace {
    private static final int MAX = 262144;
    private static final Pattern LIB = Pattern.compile("(?:^|[/!])(lib(?:godot_android|bmt_track_geometry)[A-Za-z0-9_.-]*\\.so)$");
    private static final Pattern NATIVE = Pattern.compile("#[0-9]+\\s+pc\\s+([0-9a-fA-F]{1,16})\\s+([^\\s()]+)");
    private static final Pattern JAVA = Pattern.compile("\\bat (org\\.beatmytrack\\.[A-Za-z0-9_.$]+\\([A-Za-z0-9_$]+\\.java:[0-9]{1,7}\\))");
    private BmtDiagnosticTrace() { }
    public static List<String> read(InputStream input, boolean proto) throws java.io.IOException {
        List<String> result = new ArrayList<>();
        if (input == null) return result;
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        byte[] block = new byte[4096];
        while (bytes.size() < MAX) {
            int count = input.read(block, 0, Math.min(block.length, MAX - bytes.size()));
            if (count <= 0) break;
            bytes.write(block, 0, count);
        }
        byte[] data = bytes.toByteArray();
        if (proto) {
            try { parse(new Cursor(data, 0, data.length), 0, crashedThread(data), result); }
            catch (IllegalArgumentException ignored) { /* Truncated or newer OS layout. */ }
        } else {
            // Text traces can contain secrets; only these exact frame forms survive.
            for (String line : new String(data, StandardCharsets.UTF_8).split("\n")) {
                Matcher nativeFrame = NATIVE.matcher(line);
                if (nativeFrame.find()) add(result, nativeFrame.group(2), nativeFrame.group(1).toLowerCase(), "");
                Matcher javaFrame = JAVA.matcher(line);
                if (javaFrame.find() && result.size() < 24) result.add(javaFrame.group(1));
                if (result.size() >= 24) break;
            }
        }
        return result;
    }
    private static void add(List<String> result, String file, String pc, String build) {
        Matcher library = LIB.matcher(file);
        if (result.size() < 24 && file.length() <= 1024 && library.find()) {
            String suffix = build.matches("[0-9a-f]{1,64}") ? "#" + build : "";
            result.add(library.group(1) + "@0x" + pc + suffix);
        }
    }
    // Bounded wire reader. Walk only tombstone threads -> map values -> backtraces.
    private static long crashedThread(byte[] data) {
        Cursor root = new Cursor(data,0,data.length);
        while (root.position<root.end) {
            long tag=root.number(); int field=(int)(tag>>>3), wire=(int)(tag&7);
            if (field==0) throw new IllegalArgumentException();
            if (wire==0) { long value=root.number(); if(field==6)return value; }
            else if(wire==2) root.child();
            else if(wire==1) root.skip(8);
            else if(wire==5) root.skip(4);
            else throw new IllegalArgumentException();
        }
        return 0;
    }
    private static void parse(Cursor cursor, int level, long crashed, List<String> result) {
        long pc = 0, threadId = 0; String file = "", build = ""; Cursor thread = null;
        while (cursor.position < cursor.end && result.size() < 24) {
            long tag = cursor.number(); int field = (int)(tag >>> 3), wire = (int)(tag & 7);
            if (field == 0) throw new IllegalArgumentException();
            if (wire == 0) { long number = cursor.number(); if (level == 3 && field == 1) pc = number; if(level==1 && field==1)threadId=number; }
            else if (wire == 2) {
                Cursor child = cursor.child();
                if ((level == 0 && field == 16) || (level == 2 && field == 4)) parse(child, level + 1, crashed, result);
                else if(level==1 && field==2) thread=child;
                else if (level == 3 && (field == 6 || field == 8) && child.end - child.position <= 1024) {
                    String value = new String(child.data, child.position, child.end - child.position, StandardCharsets.UTF_8);
                    if (field == 6) file = value; else build = value;
                }
            } else if (wire == 1) cursor.skip(8);
            else if (wire == 5) cursor.skip(4);
            else throw new IllegalArgumentException();
        }
        if(level==1 && thread!=null && (crashed==0 || crashed==threadId)) parse(thread,2,crashed,result);
        if (level == 3) add(result, file, Long.toUnsignedString(pc, 16), build);
    }
    private static final class Cursor {
        final byte[] data; int position; final int end;
        Cursor(byte[] data, int position, int end) { this.data=data; this.position=position; this.end=end; }
        long number() {
            long result=0;
            for (int shift=0; shift<64; shift+=7) {
                if (position>=end) throw new IllegalArgumentException();
                int next=data[position++] & 255;
                if (shift==63 && next>1) throw new IllegalArgumentException();
                result |= (long)(next & 127)<<shift;
                if ((next & 128)==0) return result;
            }
            throw new IllegalArgumentException();
        }
        void skip(int size) { if (size<0 || size>end-position) throw new IllegalArgumentException(); position+=size; }
        Cursor child() { long size=number(); if (size<0 || size>end-position) throw new IllegalArgumentException(); int start=position; skip((int)size); return new Cursor(data,start,position); }
    }
}
