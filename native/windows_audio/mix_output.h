#pragma once
#include <godot_cpp/classes/audio_effect.hpp>
#include <godot_cpp/classes/audio_effect_instance.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <cstring>

// Post-effect stereo transfer. One producer (Godot's audio thread), one consumer
// (WASAPI); no allocation, decoding or mutex on the Godot mixing callback.
class BmtWindowsMixSink : public RefCounted {
 GDCLASS(BmtWindowsMixSink,RefCounted)
 static constexpr uint64_t CAPACITY=4096;
 std::array<AudioFrame,CAPACITY> ring{};
 std::atomic<uint64_t> written{0},consumed{0},submitted{0},rendered{0};
 std::atomic<uint32_t> peak_queue{0},overflows{0},idle_blocks{0},period_frames{0},queued_frames{0};
 std::atomic<uint32_t> source_rate{48000},device_rate{0},generation{0};
 std::atomic<bool> stopping{false},ready{false},enabled{true},failed{false},muted{false},device_changed{false};
 std::atomic<float> gain{1};
 std::atomic<long> error{0};
 std::thread worker;
 std::mutex init_guard;
 std::condition_variable initialized;
 bool init_done=false;
 HANDLE wake=nullptr;
 class Notification : public IMMNotificationClient {
  LONG references=1; BmtWindowsMixSink *owner;
 public:
  explicit Notification(BmtWindowsMixSink *value):owner(value) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid,void **value) override {if(iid==__uuidof(IUnknown)||iid==__uuidof(IMMNotificationClient)){*value=this;AddRef();return S_OK;}*value=nullptr;return E_NOINTERFACE;}
  ULONG STDMETHODCALLTYPE AddRef() override {return InterlockedIncrement(&references);}
  ULONG STDMETHODCALLTYPE Release() override {ULONG result=InterlockedDecrement(&references);if(!result) delete this;return result;}
  HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(EDataFlow flow,ERole role,LPCWSTR) override {if(flow==eRender&&role==eConsole){owner->ready=false;owner->device_changed=true;SetEvent(owner->wake);}return S_OK;}
  HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override {return S_OK;}
  HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override {return S_OK;}
  HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR,DWORD) override {return S_OK;}
  HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR,const PROPERTYKEY) override {return S_OK;}
 };
 template<class T> static void release(T *&value) {if(value){value->Release();value=nullptr;}}
 void run() {do {device_changed=false;run_device();} while(device_changed&&!stopping.load());}
 void run_device() {
  HRESULT com=CoInitializeEx(nullptr,COINIT_MULTITHREADED),hr=com;
  IMMDeviceEnumerator *enumerator=nullptr;IMMDevice *device=nullptr;
  IAudioClient3 *client=nullptr;IAudioRenderClient *render_client=nullptr;
  WAVEFORMATEX *format=nullptr;HANDLE task=nullptr;DWORD task_index=0;
  uint32_t period=0,size=0,normal=0,fundamental=0,maximum=0;
  Notification *notification=new Notification(this);bool registered=false;
  if(SUCCEEDED(hr)) hr=CoCreateInstance(__uuidof(MMDeviceEnumerator),nullptr,CLSCTX_INPROC_SERVER,__uuidof(IMMDeviceEnumerator),(void**)&enumerator);
  if(SUCCEEDED(hr)) registered=SUCCEEDED(enumerator->RegisterEndpointNotificationCallback(notification));
  if(SUCCEEDED(hr)) hr=enumerator->GetDefaultAudioEndpoint(eRender,eConsole,&device);
  if(SUCCEEDED(hr)) hr=device->Activate(__uuidof(IAudioClient3),CLSCTX_INPROC_SERVER,nullptr,(void**)&client);
  AudioClientProperties props{};props.cbSize=sizeof(props);props.eCategory=AudioCategory_GameEffects;props.Options=AUDCLNT_STREAMOPTIONS_RAW;
  if(SUCCEEDED(hr)) hr=client->SetClientProperties(&props);
  if(SUCCEEDED(hr)) hr=client->GetMixFormat(&format);
  if(SUCCEEDED(hr)) {
   const GUID floating={3,0,0x0010,{0x80,0,0,0xaa,0,0x38,0x9b,0x71}};
   bool valid=format->wFormatTag==WAVE_FORMAT_IEEE_FLOAT||(format->wFormatTag==WAVE_FORMAT_EXTENSIBLE&&reinterpret_cast<WAVEFORMATEXTENSIBLE*>(format)->SubFormat==floating);
   if(!valid||format->wBitsPerSample!=32||format->nChannels!=2||format->nSamplesPerSec!=source_rate.load()) hr=AUDCLNT_E_UNSUPPORTED_FORMAT;
   else device_rate=format->nSamplesPerSec;
  }
  if(SUCCEEDED(hr)) hr=client->GetSharedModeEnginePeriod(format,&normal,&fundamental,&period,&maximum);
  if(SUCCEEDED(hr)) hr=client->InitializeSharedAudioStream(0,period,format,nullptr);
  if(SUCCEEDED(hr)) hr=client->GetBufferSize(&size);
  if(SUCCEEDED(hr)) hr=client->GetService(__uuidof(IAudioRenderClient),(void**)&render_client);
  if(SUCCEEDED(hr)) hr=client->Start();
  consumed=written.load(std::memory_order_acquire);
  uint32_t current_generation=generation.load();
  {std::lock_guard<std::mutex> lock(init_guard);period_frames=period;error=hr;ready=SUCCEEDED(hr);init_done=true;}
  initialized.notify_one();
  if(SUCCEEDED(hr)) task=AvSetMmThreadCharacteristicsW(L"Pro Audio",&task_index);
  while(SUCCEEDED(hr)&&!stopping.load()&&!device_changed.load()) {
   uint32_t padding=0;hr=client->GetCurrentPadding(&padding);if(FAILED(hr)) break;
   queued_frames=padding;
   uint32_t next_generation=generation.load();
   if(current_generation!=next_generation||!enabled.load()||failed.load()) {consumed=written.load(std::memory_order_acquire);current_generation=next_generation;}
   uint64_t read=consumed.load(std::memory_order_relaxed),head=written.load(std::memory_order_acquire);
   if(enabled.load()&&!failed.load()&&head>read&&padding<period) {
    uint32_t count=uint32_t(std::min<uint64_t>(std::min(size-padding,period-padding),head-read));
    BYTE *bytes=nullptr;hr=render_client->GetBuffer(count,&bytes);if(FAILED(hr)) break;
    float *destination=reinterpret_cast<float*>(bytes);float level=muted.load()?0:gain.load();
    for(uint32_t frame=0;frame<count;frame++) {const AudioFrame &source=ring[(read+frame)%CAPACITY];destination[frame*2]=source.left*level;destination[frame*2+1]=source.right*level;}
    hr=render_client->ReleaseBuffer(count,0);
    consumed.store(read+count,std::memory_order_release);rendered.fetch_add(count);
   }
   WaitForSingleObject(wake,2);
  }
  ready=false;error=hr;
  if(client) client->Stop();if(task) AvRevertMmThreadCharacteristics(task);
  if(registered) enumerator->UnregisterEndpointNotificationCallback(notification);
  notification->Release();release(render_client);release(client);release(device);release(enumerator);
  if(format) CoTaskMemFree(format);if(SUCCEEDED(com)) CoUninitialize();
 }
protected:
 static void _bind_methods() {
  ClassDB::bind_method(D_METHOD("open","rate"),&BmtWindowsMixSink::open);
  ClassDB::bind_method(D_METHOD("make_effect"),&BmtWindowsMixSink::make_effect);
  ClassDB::bind_method(D_METHOD("set_output","gain","mute","enabled"),&BmtWindowsMixSink::set_output);
  ClassDB::bind_method(D_METHOD("close"),&BmtWindowsMixSink::close);
  ClassDB::bind_method(D_METHOD("stats"),&BmtWindowsMixSink::stats);
 }
public:
 ~BmtWindowsMixSink() {close();}
 bool open(int64_t rate) {
  close();if(rate<8000||rate>192000) return false;
  source_rate=uint32_t(rate);stopping=false;enabled=true;failed=false;init_done=false;
  written=0;consumed=0;wake=CreateEventW(nullptr,FALSE,FALSE,nullptr);if(!wake) return false;
  worker=std::thread(&BmtWindowsMixSink::run,this);
  std::unique_lock<std::mutex> lock(init_guard);initialized.wait(lock,[this]{return init_done;});return ready.load();
 }
 void set_output(double level,bool mute,bool enable) {
  gain=std::isfinite(level)?float(std::max(level,0.0)):0;muted=mute;
  if(enabled.exchange(enable)!=enable) generation.fetch_add(1);
 }
 Ref<AudioEffect> make_effect();
 void process(const AudioFrame *source,AudioFrame *destination,int32_t count) {
  if(!ready.load()||!enabled.load()||failed.load()||count<=0) {if(count>0) std::memcpy(destination,source,count*sizeof(AudioFrame));return;}
  uint64_t head=written.load(std::memory_order_relaxed),read=consumed.load(std::memory_order_acquire);
  if(uint64_t(count)>CAPACITY||head-read+count>CAPACITY) {
   failed=true;overflows++;generation++;std::memcpy(destination,source,count*sizeof(AudioFrame));return;
  }
  bool silent=true;for(int32_t frame=0;frame<count;frame++) if(source[frame].left!=0||source[frame].right!=0) {silent=false;break;}
  if(silent&&head==read&&queued_frames.load()==0) {idle_blocks++;std::memset(destination,0,count*sizeof(AudioFrame));return;}
  for(int32_t frame=0;frame<count;frame++) ring[(head+frame)%CAPACITY]=source[frame];
  written.store(head+count,std::memory_order_release);submitted.fetch_add(count);
  uint32_t queued=uint32_t(head-read+count),peak=peak_queue.load();while(queued>peak&&!peak_queue.compare_exchange_weak(peak,queued)) {}
  std::memset(destination,0,count*sizeof(AudioFrame));
 }
 void close() {ready=false;stopping=true;if(wake) SetEvent(wake);if(worker.joinable()) worker.join();if(wake){CloseHandle(wake);wake=nullptr;}}
 Dictionary stats() {
  Dictionary d;uint64_t head=written.load(),read=consumed.load();
  d["ready"]=ready.load();d["enabled"]=enabled.load();d["failed"]=failed.load();d["raw"]=true;
  d["capacity_frames"]=int64_t(CAPACITY);d["buffer_bytes"]=int64_t(sizeof(ring));d["queued_frames"]=int64_t(head>=read?head-read:0);d["peak_queued_frames"]=peak_queue.load();
  d["overflows"]=overflows.load();d["submitted_frames"]=int64_t(submitted.load());d["rendered_frames"]=int64_t(rendered.load());d["idle_blocks"]=idle_blocks.load();
  d["period_frames"]=period_frames.load();d["source_rate"]=source_rate.load();d["device_rate"]=device_rate.load();d["error"]=int64_t(error.load());return d;
 }
};

class BmtWindowsMixTapInstance : public AudioEffectInstance {
 GDCLASS(BmtWindowsMixTapInstance,AudioEffectInstance)
protected: static void _bind_methods() {}
public:
 Ref<BmtWindowsMixSink> sink;
 void _process(const void *source,AudioFrame *destination,int32_t count) override {if(sink.is_valid()) sink->process(static_cast<const AudioFrame*>(source),destination,count);else std::memcpy(destination,source,count*sizeof(AudioFrame));}
 bool _process_silence() const override {return true;}
};
class BmtWindowsMixTap : public AudioEffect {
 GDCLASS(BmtWindowsMixTap,AudioEffect)
protected: static void _bind_methods() {}
public:
 Ref<BmtWindowsMixSink> sink;
 Ref<AudioEffectInstance> _instantiate() override {Ref<BmtWindowsMixTapInstance> instance;instance.instantiate();instance->sink=sink;return instance;}
};
inline Ref<AudioEffect> BmtWindowsMixSink::make_effect() {Ref<BmtWindowsMixTap> effect;effect.instantiate();effect->sink=Ref<BmtWindowsMixSink>(this);return effect;}
