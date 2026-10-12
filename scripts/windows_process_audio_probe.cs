// Diagnostic-only WASAPI process-loopback. No microphone/system-wide capture.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

[ComImport, Guid("72A22D78-CDE4-431D-B8CC-843A71199B6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IActivateOperation { [PreserveSig] int GetActivateResult(out int result, [MarshalAs(UnmanagedType.IUnknown)] out object audio); }
[Guid("41D949AB-9862-444A-80F6-C261334DA5EB"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IActivateCompletion { [PreserveSig] int ActivateCompleted(IActivateOperation operation); }
[Guid("94EA2B94-E9CC-49E0-C0FF-EE64CA8F5B90"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAgileObject { }
[StructLayout(LayoutKind.Sequential, Pack=2)]
public struct WaveFormat { public ushort tag, channels; public uint rate, bytes; public ushort align,bits,extra; }
[ComImport, Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioClient {
 [PreserveSig] int Initialize(int mode,uint flags,long duration,long period,ref WaveFormat format,IntPtr session);
 [PreserveSig] int GetBufferSize(out uint frames);
 [PreserveSig] int GetStreamLatency(out long latency);
 [PreserveSig] int GetCurrentPadding(out uint frames);
 [PreserveSig] int IsFormatSupported(int mode,IntPtr format,out IntPtr closest);
 [PreserveSig] int GetMixFormat(out IntPtr format);
 [PreserveSig] int GetDevicePeriod(out long normal,out long minimum);
 [PreserveSig] int Start();
 [PreserveSig] int Stop();
 [PreserveSig] int Reset();
 [PreserveSig] int SetEventHandle(IntPtr handle);
 [PreserveSig] int GetService(ref Guid iid,[MarshalAs(UnmanagedType.IUnknown)] out object service);
}
[ComImport, Guid("C8ADBD64-E71E-48A0-A4DE-185C395CD317"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioCaptureClient {
 [PreserveSig] int GetBuffer(out IntPtr data,out uint frames,out uint flags,out ulong devicePosition,out ulong qpcPosition);
 [PreserveSig] int ReleaseBuffer(uint frames);
 [PreserveSig] int GetNextPacketSize(out uint frames);
}
[ComVisible(true),ClassInterface(ClassInterfaceType.None)]
public class Activation : IActivateCompletion,IAgileObject {
 public ManualResetEvent Done=new ManualResetEvent(false);
 public IAudioClient Client;
 public int Error;
 public int ActivateCompleted(IActivateOperation op) {
  object audio; int result; Error=op.GetActivateResult(out result,out audio);
  if(Error>=0) Error=result;
  if(Error>=0) Client=(IAudioClient)audio;
  Done.Set(); return 0;
 }
}
class Probe {
 [DllImport("Mmdevapi.dll",ExactSpelling=true,CharSet=CharSet.Unicode)]
 static extern int ActivateAudioInterfaceAsync(string path,ref Guid iid,IntPtr parameters,IActivateCompletion completion,out IActivateOperation operation);
 static void Check(int value,string action) { if(value<0) throw new Exception(action+": HRESULT 0x"+value.ToString("X8")); }
 static double UnixUs() { return (DateTime.UtcNow.Ticks-621355968000000000L)/10.0; }
 [MTAThread] static int Main(string[] args) {
  if(args.Length!=3) { Console.WriteLine("usage: process-audio-probe PID output-folder seconds"); return 2; }
  bool self=args[0].StartsWith("self");
  int pid=self?Process.GetCurrentProcess().Id:int.Parse(args[0]); string folder=Path.GetFullPath(args[1]); double seconds=double.Parse(args[2]);
  Directory.CreateDirectory(folder);
  // This ABI is intentionally x64 only; never silently switch to device-wide loopback.
  if(IntPtr.Size!=8) throw new Exception("Requires x64 process loopback");
  IntPtr activation=Marshal.AllocHGlobal(12),variant=Marshal.AllocHGlobal(24);
  for(int i=0;i<24;i++) Marshal.WriteByte(variant,i,0);
  Marshal.WriteInt32(activation,0,1); // PROCESS_LOOPBACK
  Marshal.WriteInt32(activation,4,pid);
  Marshal.WriteInt32(activation,8,0); // Include only this process tree
  Marshal.WriteInt16(variant,0,65); // VT_BLOB
  Marshal.WriteInt32(variant,8,12);
  Marshal.WriteIntPtr(variant,16,activation);
  Activation callback=new Activation(); IActivateOperation operation;
  Guid clientIid=new Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2");
  IAudioClient client=null;
  try {
   Check(ActivateAudioInterfaceAsync("VAD\\Process_Loopback",ref clientIid,variant,callback,out operation),"Activate process loopback");
   if(!callback.Done.WaitOne(10000)) throw new Exception("Process-loopback activation timeout");
   Check(callback.Error,"Activate result"); client=callback.Client;
   WaveFormat format=new WaveFormat {tag=1,channels=2,rate=48000,bytes=192000,align=4,bits=16,extra=0};
   Check(client.Initialize(0,0x00020000|0x80000000,0,0,ref format,IntPtr.Zero),"Initialize process loopback");
   Guid captureIid=new Guid("C8ADBD64-E71E-48A0-A4DE-185C395CD317"); object captureObject;
   Check(client.GetService(ref captureIid,out captureObject),"Get capture service");
   IAudioCaptureClient capture=(IAudioCaptureClient)captureObject;
   long q0=Stopwatch.GetTimestamp(); double utcBase=UnixUs(); long q1=Stopwatch.GetTimestamp();
   double qpcBase=(q0/2.0+q1/2.0)*10000000.0/Stopwatch.Frequency;
   Check(client.Start(),"Start process capture");
   File.WriteAllText(Path.Combine(folder,"armed"),pid.ToString());
   Stopwatch clock=Stopwatch.StartNew();
   NativePulse pulse=self?new NativePulse(folder,args[0].Contains("raw"),args[0].Contains("fast")):null;
   using(BinaryWriter pcm=new BinaryWriter(File.Open(Path.Combine(folder,"loopback.pcm"),FileMode.Create)))
   using(StreamWriter packets=new StreamWriter(Path.Combine(folder,"packets.csv"))) {
    packets.WriteLine("frame_offset,frames,flags,qpc_100ns,utc_us,arrival_us"); long offset=0;
    while(clock.Elapsed.TotalSeconds<seconds) {
     if(pulse!=null) pulse.Fill(clock.Elapsed.TotalSeconds);
     uint frames; Check(capture.GetNextPacketSize(out frames),"Next packet");
     while(frames>0) {
      IntPtr data; uint count,flags; ulong position,qpc;
      Check(capture.GetBuffer(out data,out count,out flags,out position,out qpc),"Get packet");
      double arrival=UnixUs();
      byte[] block=new byte[count*4];
      if((flags&2)==0) Marshal.Copy(data,block,0,block.Length);
      pcm.Write(block);
      double utc=utcBase+((double)qpc-qpcBase)/10.0;
      packets.WriteLine(offset+","+count+","+flags+","+qpc+","+utc.ToString("F3",System.Globalization.CultureInfo.InvariantCulture)+","+arrival.ToString("F3",System.Globalization.CultureInfo.InvariantCulture));
      offset+=count; Check(capture.ReleaseBuffer(count),"Release packet");
      Check(capture.GetNextPacketSize(out frames),"Next packet");
     }
     Thread.Sleep(2);
    }
   }
   if(pulse!=null) pulse.Dispose();
   Check(client.Stop(),"Stop process capture");
   File.WriteAllText(Path.Combine(folder,"capture-meta.txt"),"process="+pid+"\nrate=48000\nchannels=2\nclock_calibration_us="+((q1-q0)*1000000.0/Stopwatch.Frequency).ToString("F3")+"\n");
   Console.WriteLine("PROCESS_LOOPBACK_CAPTURED process="+pid+" seconds="+seconds); return 0;
  } catch(Exception ex) { Console.WriteLine(ex.Message); return 1; }
  finally { if(client!=null) {client.Stop();Marshal.ReleaseComObject(client);} Marshal.FreeHGlobal(activation);Marshal.FreeHGlobal(variant); }
 }
}
