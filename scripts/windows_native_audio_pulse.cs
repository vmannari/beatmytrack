// Diagnostic renderer used only to calibrate the process-loopback clock.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

[ComImport,Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDeviceEnumerator {
 [PreserveSig] int EnumAudioEndpoints(int flow,uint mask,out IntPtr devices);
 [PreserveSig] int GetDefaultAudioEndpoint(int flow,int role,out IMMDevice device);
}
[ComImport,Guid("D666063F-1587-4E43-81F1-B948E807363F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDevice {
 [PreserveSig] int Activate(ref Guid iid,uint context,IntPtr parameters,[MarshalAs(UnmanagedType.IUnknown)] out object audio);
}
[ComImport,Guid("F294ACFC-3146-4483-A7BF-ADDCA7C260E2"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioRenderClient {
 [PreserveSig] int GetBuffer(uint frames,out IntPtr data);
 [PreserveSig] int ReleaseBuffer(uint frames,uint flags);
}
[ComImport,Guid("CD63314F-3FBA-4a1b-812C-EF96358728E7"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioClock {
 [PreserveSig] int GetFrequency(out ulong frequency);
 [PreserveSig] int GetPosition(out ulong position,out ulong qpc);
 [PreserveSig] int GetCharacteristics(out uint flags);
}
public class NativePulse : IDisposable {
 [StructLayout(LayoutKind.Sequential)] struct ClientProperties { public uint size; public int offload,category; public uint options; }
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int SetProperties(IntPtr self,ref ClientProperties properties);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetPeriod(IntPtr self,IntPtr format,out uint normal,out uint fundamental,out uint minimum,out uint maximum);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int InitializeShared(IntPtr self,uint flags,uint period,IntPtr format,IntPtr session);
 IAudioClient client; IAudioRenderClient render; IAudioClock audioClock; ulong frequency,written; uint size; int trial=0; string folder;
 List<ulong> targets=new List<ulong>(); List<double> requests=new List<double>(); List<string> clockRows=new List<string>();
 List<string> rows=new List<string>();
 bool floating=false;
 static void Check(int value,string action) { if(value<0) throw new Exception(action+": HRESULT 0x"+value.ToString("X8")); }
 static double UnixUs() { return (DateTime.UtcNow.Ticks-621355968000000000L)/10.0; }
 public NativePulse(string output,bool raw,bool fast) {
  folder=output;
  IMMDeviceEnumerator enumerator=(IMMDeviceEnumerator)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")));
  IMMDevice device; Check(enumerator.GetDefaultAudioEndpoint(0,0,out device),"Default render device");
  Guid iid=new Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2"); object audio;
  Check(device.Activate(ref iid,23,IntPtr.Zero,out audio),"Activate native render"); client=(IAudioClient)audio;
  IntPtr unknown=Marshal.GetIUnknownForObject(audio),client2=IntPtr.Zero;
  Guid client2Iid=new Guid("726778CD-F60A-4EDA-82DE-E47610CD78AA");
  try {
   Check(Marshal.QueryInterface(unknown,ref client2Iid,out client2),"Native client2");
   IntPtr table=Marshal.ReadIntPtr(client2),address=Marshal.ReadIntPtr(table,16*IntPtr.Size);
   SetProperties set=(SetProperties)Marshal.GetDelegateForFunctionPointer(address,typeof(SetProperties));
   ClientProperties properties=new ClientProperties {size=16,offload=0,category=6,options=raw?1u:0u};
   Check(set(client2,ref properties),"Native game/raw properties");
  } finally { if(client2!=IntPtr.Zero) Marshal.Release(client2); Marshal.Release(unknown); }
  WaveFormat format=new WaveFormat {tag=1,channels=2,rate=48000,bytes=192000,align=4,bits=16,extra=0};
  uint selected=0;
  if(fast) {
   Guid client3Iid=new Guid("7ED4EE07-8E67-4CD4-8C1A-2B7A5987AD42"); IntPtr client3=IntPtr.Zero,mix=IntPtr.Zero;
   unknown=Marshal.GetIUnknownForObject(audio);
   try {
    Check(Marshal.QueryInterface(unknown,ref client3Iid,out client3),"Native client3");
    Check(client.GetMixFormat(out mix),"Native mix format");
    WaveFormat w=(WaveFormat)Marshal.PtrToStructure(mix,typeof(WaveFormat));
    if(w.rate!=48000 || w.channels!=2 || w.bits!=32) throw new Exception("Fast diagnostic expects 48k stereo float");
    floating=true;
    IntPtr table=Marshal.ReadIntPtr(client3);
    GetPeriod get=(GetPeriod)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(table,18*IntPtr.Size),typeof(GetPeriod));
    uint normal,fundamental,minimum,maximum; Check(get(client3,mix,out normal,out fundamental,out minimum,out maximum),"Native periods");
    selected=minimum;
    InitializeShared init=(InitializeShared)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(table,20*IntPtr.Size),typeof(InitializeShared));
    Check(init(client3,0,selected,mix,IntPtr.Zero),"Native fast initialize");
   } finally { if(mix!=IntPtr.Zero) Marshal.FreeCoTaskMem(mix); if(client3!=IntPtr.Zero) Marshal.Release(client3); Marshal.Release(unknown); }
  } else Check(client.Initialize(0,0x80000000,100000,0,ref format,IntPtr.Zero),"Initialize native render");
  Check(client.GetBufferSize(out size),"Render buffer size"); long latency; Check(client.GetStreamLatency(out latency),"Render latency");
  Guid renderIid=new Guid("F294ACFC-3146-4483-A7BF-ADDCA7C260E2"); object service;
  Check(client.GetService(ref renderIid,out service),"Render service"); render=(IAudioRenderClient)service;
  Guid clockIid=new Guid("CD63314F-3FBA-4a1b-812C-EF96358728E7"); object clockService;
  Check(client.GetService(ref clockIid,out clockService),"Audio clock service"); audioClock=(IAudioClock)clockService;
  Check(audioClock.GetFrequency(out frequency),"Audio clock frequency"); written=size;
  IntPtr data; Check(render.GetBuffer(size,out data),"Initial render buffer"); Check(render.ReleaseBuffer(size,2),"Initial silence");
  Check(client.Start(),"Start native render");
  File.WriteAllText(Path.Combine(folder,"native-meta.txt"),"buffer_frames="+size+"\nreported_latency_ms="+(latency/10000.0)+"\nraw="+raw+"\nperiod_frames="+selected+"\n");
  Marshal.ReleaseComObject(device); Marshal.ReleaseComObject(enumerator);
 }
 public void Fill(double seconds) {
  ulong position,qpc; Check(audioClock.GetPosition(out position,out qpc),"Render clock position");
  if(clockRows.Count<targets.Count && position>=targets[clockRows.Count]) {
   int index=clockRows.Count;
   double clockUtc=UnixUs()+((double)qpc-Stopwatch.GetTimestamp()*10000000.0/Stopwatch.Frequency)/10.0;
   double outputUtc=clockUtc-(position-targets[index])*1000000.0/frequency;
   clockRows.Add(index+","+requests[index].ToString("F3",System.Globalization.CultureInfo.InvariantCulture)+","+outputUtc.ToString("F3",System.Globalization.CultureInfo.InvariantCulture)+","+((outputUtc-requests[index])/1000.0).ToString("F3",System.Globalization.CultureInfo.InvariantCulture));
  }
  uint padding; Check(client.GetCurrentPadding(out padding),"Render padding"); uint available=size-padding;
  if(available==0) return;
  bool fire=trial<6 && seconds>=1.0+trial*1.4;
  double eventUs=UnixUs(); IntPtr data; Check(render.GetBuffer(available,out data),"Render buffer");
  if(fire) {
   targets.Add(written*frequency/48000); requests.Add(eventUs);
   short[] samples=new short[available*2];
   for(int i=0;i<available;i++) { short value=(short)(18000*Math.Exp(-i/120.0)*Math.Cos(i*.18)); samples[i*2]=samples[i*2+1]=value; }
   if(floating) { float[] values=new float[samples.Length]; for(int i=0;i<values.Length;i++) values[i]=samples[i]/32768.0f; Marshal.Copy(values,0,data,values.Length); }
   else Marshal.Copy(samples,0,data,samples.Length);
   rows.Add("{\"trial\":"+trial+",\"unix_us\":"+eventUs.ToString("F0",System.Globalization.CultureInfo.InvariantCulture)+",\"reported_latency_ms\":0,\"next_mix_ms\":"+(padding/48.0).ToString("F3",System.Globalization.CultureInfo.InvariantCulture)+"}");
   trial++;
  }
  Check(render.ReleaseBuffer(available,fire?0u:2u),"Release render buffer");
  written+=available;
 }
 public void Dispose() {
  client.Stop(); File.WriteAllText(Path.Combine(folder,"events.json"),"["+String.Join(",",rows.ToArray())+"]\n");
  File.WriteAllText(Path.Combine(folder,"render-clock.csv"),"trial,request_us,output_us,latency_ms\n"+String.Join("\n",clockRows.ToArray())+"\n");
  Marshal.ReleaseComObject(audioClock); Marshal.ReleaseComObject(render); Marshal.ReleaseComObject(client);
 }
}
