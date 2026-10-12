#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <avrt.h>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <array>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <condition_variable>
#include <mutex>
#include <thread>
#include <vector>
using namespace godot;

// Windows-only presentation adapter. Godot remains the fallback. The pinned
// engine's WASAPI stream does not request RAW, which permits slow optional APOs.
class BmtWindowsImpact : public RefCounted {
 GDCLASS(BmtWindowsImpact,RefCounted)
 struct Clip {std::vector<float> pcm; int rate=44100;};
 struct Voice {int clip=-1; double frame=0,step=1; float gain=0;};
 std::array<Clip,3> clips;
 std::array<Voice,4> voices;
 std::thread worker;
 std::mutex guard;
 std::condition_variable initialized;
 std::atomic<bool> exit{false},ready{false};
 std::atomic<bool> device_changed{false};
 std::atomic<uint32_t> submitted{0},mixed{0},period_frames{0},buffer_frames{0};
 std::atomic<long> last_error{0};
 bool init_done=false,paused=false,muted=false;
 float impact_gain=1,master_gain=1;
 uint32_t next_voice=0;
 HANDLE wake=nullptr;
 class Notification : public IMMNotificationClient {
  LONG references=1; BmtWindowsImpact *owner;
 public:
  explicit Notification(BmtWindowsImpact *value):owner(value) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid,void **value) override {if(iid==__uuidof(IUnknown) || iid==__uuidof(IMMNotificationClient)){*value=this;AddRef();return S_OK;}*value=nullptr;return E_NOINTERFACE;}
  ULONG STDMETHODCALLTYPE AddRef() override {return InterlockedIncrement(&references);}
  ULONG STDMETHODCALLTYPE Release() override {ULONG result=InterlockedDecrement(&references);if(!result) delete this;return result;}
  HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(EDataFlow flow,ERole role,LPCWSTR) override {if(flow==eRender && role==eConsole){owner->ready=false;owner->device_changed=true;SetEvent(owner->wake);}return S_OK;}
  HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override {return S_OK;}
  HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override {return S_OK;}
  HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR,DWORD) override {return S_OK;}
  HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR,const PROPERTYKEY) override {return S_OK;}
 };
 template<class T> static void release(T *&value) {if(value){value->Release();value=nullptr;}}
 void render(float *data,uint32_t frames,uint32_t channels,uint32_t rate) {
  std::lock_guard<std::mutex> lock(guard);
  constexpr float impact_ceiling=0.7943282347f,master_ceiling=0.8912509381f;
  for(uint32_t f=0;f<frames;f++) {
   float value=0;
   if(!paused) for(auto &voice:voices) if(voice.clip>=0) {
    auto &clip=clips[voice.clip]; size_t index=size_t(voice.frame);
    if(index>=clip.pcm.size()) {voice.clip=-1;continue;}
    float a=clip.pcm[index],b=index+1<clip.pcm.size()?clip.pcm[index+1]:0;
    value+=(a+(b-a)*float(voice.frame-index))*voice.gain;
    voice.frame+=voice.step*clip.rate/rate;
   }
   value=std::clamp(value,-impact_ceiling,impact_ceiling)*impact_gain;
   value=std::clamp(value,-master_ceiling,master_ceiling)*master_gain;
   if(paused || muted) value=0;
   for(uint32_t c=0;c<channels;c++) data[f*channels+c]=value;
  }
  mixed.fetch_add(frames,std::memory_order_relaxed);
 }
 void run() {do {device_changed=false;run_device();} while(device_changed && !exit.load());}
 void run_device() {
  HRESULT com=CoInitializeEx(nullptr,COINIT_MULTITHREADED),hr=com;
  IMMDeviceEnumerator *enumerator=nullptr; IMMDevice *device=nullptr;
  IAudioClient3 *client=nullptr; IAudioRenderClient *render_client=nullptr;
  WAVEFORMATEX *format=nullptr; HANDLE task=nullptr; DWORD task_index=0;
  uint32_t period=0,size=0;
  Notification *notification=new Notification(this); bool registered=false;
  if(SUCCEEDED(hr)) hr=CoCreateInstance(__uuidof(MMDeviceEnumerator),nullptr,CLSCTX_INPROC_SERVER,__uuidof(IMMDeviceEnumerator),(void**)&enumerator);
  if(SUCCEEDED(hr)) registered=SUCCEEDED(enumerator->RegisterEndpointNotificationCallback(notification));
  if(SUCCEEDED(hr)) hr=enumerator->GetDefaultAudioEndpoint(eRender,eConsole,&device);
  if(SUCCEEDED(hr)) hr=device->Activate(__uuidof(IAudioClient3),CLSCTX_INPROC_SERVER,nullptr,(void**)&client);
  AudioClientProperties props{}; props.cbSize=sizeof(props);props.eCategory=AudioCategory_GameEffects;props.Options=AUDCLNT_STREAMOPTIONS_RAW;
  if(SUCCEEDED(hr)) hr=client->SetClientProperties(&props);
  if(SUCCEEDED(hr)) hr=client->GetMixFormat(&format);
  if(SUCCEEDED(hr)) {
   const GUID float_format={3,0,0x0010,{0x80,0,0,0xaa,0,0x38,0x9b,0x71}};
   bool floating=format->wFormatTag==WAVE_FORMAT_IEEE_FLOAT ||
    (format->wFormatTag==WAVE_FORMAT_EXTENSIBLE && reinterpret_cast<WAVEFORMATEXTENSIBLE*>(format)->SubFormat==float_format);
   // Do not silently send misinterpreted samples to unsupported devices.
   if(!floating || format->wBitsPerSample!=32 || format->nChannels!=2) hr=AUDCLNT_E_UNSUPPORTED_FORMAT;
  }
  uint32_t normal=0,fundamental=0,maximum=0;
  if(SUCCEEDED(hr)) hr=client->GetSharedModeEnginePeriod(format,&normal,&fundamental,&period,&maximum);
  if(SUCCEEDED(hr)) hr=client->InitializeSharedAudioStream(0,period,format,nullptr);
  if(SUCCEEDED(hr)) hr=client->GetBufferSize(&size);
  if(SUCCEEDED(hr)) hr=client->GetService(__uuidof(IAudioRenderClient),(void**)&render_client);
  if(SUCCEEDED(hr)) {
   BYTE *data=nullptr; hr=render_client->GetBuffer(period,&data);
   if(SUCCEEDED(hr)) hr=render_client->ReleaseBuffer(period,AUDCLNT_BUFFERFLAGS_SILENT);
   if(SUCCEEDED(hr)) hr=client->Start();
  }
  {
   std::lock_guard<std::mutex> lock(guard);
   period_frames=period;buffer_frames=size;last_error=hr;
   ready=SUCCEEDED(hr);init_done=true;
  }
  initialized.notify_one();
  if(SUCCEEDED(hr)) task=AvSetMmThreadCharacteristicsW(L"Pro Audio",&task_index);
  while(SUCCEEDED(hr) && !exit.load() && !device_changed) {
   uint32_t padding=0;hr=client->GetCurrentPadding(&padding);
   if(FAILED(hr)) break;
   // Keep at most one period queued, rather than filling WASAPI's larger buffer
   // with silence that every subsequent collision would have to wait behind.
   if(padding<period) {
    uint32_t count=std::min(size-padding,period-padding); BYTE *data=nullptr;
    hr=render_client->GetBuffer(count,&data);
    if(FAILED(hr)) break;
    render(reinterpret_cast<float*>(data),count,format->nChannels,format->nSamplesPerSec);
    hr=render_client->ReleaseBuffer(count,0);
   }
   WaitForSingleObject(wake,2);
  }
  ready=false;last_error=hr;
  if(client) client->Stop();
  if(task) AvRevertMmThreadCharacteristics(task);
  if(registered) enumerator->UnregisterEndpointNotificationCallback(notification);
  notification->Release();
  release(render_client);release(client);release(device);release(enumerator);
  if(format) CoTaskMemFree(format);
  if(SUCCEEDED(com)) CoUninitialize();
 }
protected:
 static void _bind_methods() {
  ClassDB::bind_method(D_METHOD("open"),&BmtWindowsImpact::open);
  ClassDB::bind_method(D_METHOD("load_pcm","clip","data","rate"),&BmtWindowsImpact::load_pcm);
  ClassDB::bind_method(D_METHOD("play","clip","gain","pitch","slot"),&BmtWindowsImpact::play,DEFVAL(-1));
  ClassDB::bind_method(D_METHOD("stop_voice","slot"),&BmtWindowsImpact::stop_voice);
  ClassDB::bind_method(D_METHOD("set_output","impact_gain","master_gain","muted","paused"),&BmtWindowsImpact::set_output);
  ClassDB::bind_method(D_METHOD("clear"),&BmtWindowsImpact::clear);
  ClassDB::bind_method(D_METHOD("close"),&BmtWindowsImpact::close);
  ClassDB::bind_method(D_METHOD("stats"),&BmtWindowsImpact::stats);
 }
public:
 ~BmtWindowsImpact() {close();}
 bool open() {
  close();exit=false;init_done=false;wake=CreateEventW(nullptr,FALSE,FALSE,nullptr);
  if(!wake) return false;
  worker=std::thread(&BmtWindowsImpact::run,this);
  std::unique_lock<std::mutex> lock(guard);
  initialized.wait(lock,[this]{return init_done;});
  return ready.load();
 }
 bool load_pcm(int64_t index,const PackedByteArray &data,int64_t rate) {
  if(index<0 || index>=3 || data.size()<2 || data.size()%2 || rate<8000 || rate>192000) return false;
  std::lock_guard<std::mutex> lock(guard);auto &clip=clips[index];clip.pcm.resize(data.size()/2);clip.rate=int(rate);
  for(int64_t i=0;i<data.size()/2;i++) {const uint8_t *p=data.ptr()+i*2;int16_t sample=int16_t(uint16_t(p[0]) | (uint16_t(p[1])<<8));clip.pcm[i]=sample/32768.f;}
  return true;
 }
 bool play(int64_t index,double gain,double pitch,int64_t slot) {
  if(!ready || index<0 || index>=3 || !std::isfinite(gain) || !std::isfinite(pitch)) return false;
  std::lock_guard<std::mutex> lock(guard);
  if(clips[index].pcm.empty() || paused) return false;
  if(slot>=int64_t(voices.size()) || slot< -1) return false;
  Voice &voice=voices[slot<0?next_voice++%voices.size():size_t(slot)];voice.clip=int(index);voice.frame=0;voice.step=std::clamp(pitch,0.5,2.0);voice.gain=float(std::clamp(gain,0.0,1.0));
  submitted++;SetEvent(wake);return true;
 }
 void set_output(double impact,double master,bool mute,bool pause) {
  std::lock_guard<std::mutex> lock(guard);
  impact_gain=std::isfinite(impact)?float(std::clamp(impact,0.0,4.0)):0;
  master_gain=std::isfinite(master)?float(std::clamp(master,0.0,4.0)):0;
  muted=mute;paused=pause;
 }
 void clear() {std::lock_guard<std::mutex> lock(guard);for(auto &voice:voices) voice=Voice{};next_voice=0;}
 void stop_voice(int64_t slot) {if(slot<0 || slot>=int64_t(voices.size())) return;std::lock_guard<std::mutex> lock(guard);voices[slot]=Voice{};}
 void close() {exit=true;if(wake) SetEvent(wake);if(worker.joinable()) worker.join();if(wake){CloseHandle(wake);wake=nullptr;}ready=false;clear();}
 Dictionary stats() {
  std::lock_guard<std::mutex> lock(guard);Dictionary d;int active=0;for(auto &voice:voices) if(voice.clip>=0) active++;
  d["ready"]=ready.load();d["raw"]=true;d["submitted"]=submitted.load();d["mixed_frames"]=mixed.load();d["active_voices"]=active;d["voice_limit"]=4;
  d["period_frames"]=period_frames.load();d["buffer_frames"]=buffer_frames.load();d["queued_period_limit"]=1;d["error"]=int64_t(last_error.load());return d;
 }
};
static void initialize(ModuleInitializationLevel level) {if(level==MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<BmtWindowsImpact>();}
static void uninitialize(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT bmt_windows_audio_init(GDExtensionInterfaceGetProcAddress address,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
 GDExtensionBinding::InitObject init(address,library,initialization);init.register_initializer(initialize);init.register_terminator(uninitialize);init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
