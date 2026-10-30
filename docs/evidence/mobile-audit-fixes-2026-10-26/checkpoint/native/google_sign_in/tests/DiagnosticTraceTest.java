package org.beatmytrack.signin;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class DiagnosticTraceTest {
    static void check(boolean value) { if (!value) throw new AssertionError(); }
    static byte[] number(long n) { ByteArrayOutputStream b=new ByteArrayOutputStream(); do { int v=(int)(n&127); n>>>=7; b.write(v|(n==0?0:128)); } while(n!=0); return b.toByteArray(); }
    static byte[] concat(byte[]... chunks) throws Exception { ByteArrayOutputStream b=new ByteArrayOutputStream(); for(byte[] c:chunks)b.write(c); return b.toByteArray(); }
    static byte[] field(int n, byte[] data) throws Exception { return concat(number((n<<3)|2),number(data.length),data); }
    static byte[] text(int n,String text) throws Exception { return field(n,text.getBytes(StandardCharsets.UTF_8)); }
    public static void main(String[] args) throws Exception {
        String secret="token=secret /private/player/track";
        String source=secret+"\n #00 pc 00001abc /data/app/private/lib/arm64/libgodot_android.so (secret)\n at org.beatmytrack.signin.BmtGoogleSignIn.start(BmtGoogleSignIn.java:42)\n at com.vendor.Secret.read(Secret.java:9)\n";
        List<String> text=BmtDiagnosticTrace.read(new ByteArrayInputStream(source.getBytes(StandardCharsets.UTF_8)),false);
        check(text.equals(Arrays.asList("libgodot_android.so@0x00001abc","org.beatmytrack.signin.BmtGoogleSignIn.start(BmtGoogleSignIn.java:42)")));
        byte[] frame=concat(number(8),number(0x1abc),text(6,"/data/app/private/libbmt_track_geometry.android.arm64.so"),text(8,"a5b6"),text(4,secret));
        byte[] proto=concat(text(14,secret),field(16,field(2,field(4,frame))));
        List<String> nativeFrames=BmtDiagnosticTrace.read(new ByteArrayInputStream(proto),true);
        check(nativeFrames.equals(Arrays.asList("libbmt_track_geometry.android.arm64.so@0x1abc#a5b6")));
        byte[] thread=field(4,frame);
        byte[] selected=concat(number(48),number(42),field(16,concat(number(8),number(43),field(2,thread))),field(16,concat(number(8),number(42),field(2,thread))));
        check(BmtDiagnosticTrace.read(new ByteArrayInputStream(selected),true).size()==1);
        check(BmtDiagnosticTrace.read(null,true).isEmpty());
        check(BmtDiagnosticTrace.read(new ByteArrayInputStream(new byte[]{(byte)255}),true).isEmpty());
        StringBuilder many=new StringBuilder(); for(int i=0;i<100;i++)many.append(source);
        check(BmtDiagnosticTrace.read(new ByteArrayInputStream(many.toString().getBytes(StandardCharsets.UTF_8)),false).size()==24);
        check(!text.toString().contains(secret) && !nativeFrames.toString().contains(secret));
        System.out.println("DIAGNOSTIC_TRACE: text/native protobuf, bounds, malformed input and redaction pass");
    }
}
