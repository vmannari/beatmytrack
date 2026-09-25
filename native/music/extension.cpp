#include "synth.hpp"
#include <chrono>
#include <memory>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
using namespace godot;
class BMTPlayback : public AudioStreamPlayback {
 GDCLASS(BMTPlayback,AudioStreamPlayback)
 std::unique_ptr<bmt::Synth> synth;
 std::shared_ptr<bmt::Controls> controls;
 std::atomic<uint32_t> running{0}, beat_milli{0}, voices{0}, peak{0}, cpu_us{0}, max_us{0}, budget_misses{0}, buffer_frames{0}, patterns{0};
protected:
 static void _bind_methods() { ClassDB::bind_method(D_METHOD("telemetry"),&BMTPlayback::telemetry); }
public:
 void initialize(std::shared_ptr<bmt::Controls> c) {controls=c;synth=std::make_unique<bmt::Synth>(AudioServer::get_singleton()->get_mix_rate(),c->seed.load());}
 void _start(double) override {running.store(1);}
 void _stop() override {running.store(0);}
 bool _is_playing() const override {return running.load()!=0;}
 double _get_playback_position() const override {return beat_milli.load()/1000.*60./controls->bpm.load();}
 int32_t _mix(AudioFrame *buffer,float,int32_t frames) override {
  auto start=std::chrono::steady_clock::now();
  synth->controls(controls->state.load(),controls->context.load(),controls->bpm.load(),controls->brightness.load()/1000.f,controls->metallicity.load()/1000.f,controls->decay.load()/1000.f,controls->width.load()/1000.f);
  for(int i=0;i<frames;++i) {float l=0,r=0;if(running.load(std::memory_order_relaxed)) synth->render(l,r);buffer[i].left=l;buffer[i].right=r;}
  beat_milli.store(uint32_t(synth->beats()*1000)); voices.store(synth->voice_count());peak.store(synth->peak_voices());
  patterns.store(synth->drum_pattern() | synth->bass_pattern()<<8 | synth->hook_pattern()<<16);
  uint32_t us=uint32_t(std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-start).count());
  cpu_us.store(us);max_us.store(std::max(us,max_us.load()));buffer_frames.store(frames);
  if(us>1000000.*frames/synth->rate) budget_misses.fetch_add(1);
  return frames;
 }
 Dictionary telemetry() const {
  Dictionary d;d["engine_version"]=bmt::MUSIC_ENGINE_VERSION;d["beat_position"]=beat_milli.load()/1000.;d["active_voices"]=voices.load();d["peak_voices"]=peak.load();
  d["mix_us"]=cpu_us.load();d["max_mix_us"]=max_us.load();d["render_budget_overruns"]=budget_misses.load();d["buffer_frames"]=buffer_frames.load();d["sample_rate"]=synth->rate;
  d["drum_pattern"]=patterns.load()&255;d["bass_pattern"]=(patterns.load()>>8)&255;d["hook_pattern"]=(patterns.load()>>16)&255;return d;
 }
};
class BMTMusicStream : public AudioStream {
 GDCLASS(BMTMusicStream,AudioStream)
 std::shared_ptr<bmt::Controls> controls=std::make_shared<bmt::Controls>();
protected:
 static void _bind_methods() {
  ClassDB::bind_method(D_METHOD("configure","seed","bpm"),&BMTMusicStream::configure);
  ClassDB::bind_method(D_METHOD("set_state","energy","tension","hook","context"),&BMTMusicStream::set_state);
  ClassDB::bind_method(D_METHOD("set_preset","brightness","metallicity","decay","width"),&BMTMusicStream::set_preset);
 }
public:
 void configure(int64_t seed,int bpm) {controls->seed.store(uint32_t(seed));controls->bpm.store(std::clamp(bpm,60,180));}
 void set_state(double e,double t,double h,int context) {controls->state.store(uint32_t(std::clamp(e,0.,1.)*255)|(uint32_t(std::clamp(t,0.,1.)*255)<<8)|(uint32_t(std::clamp(h,0.,1.)*255)<<16));controls->context.store(context);}
 void set_preset(double b,double m,double d,double w) {controls->brightness.store(uint32_t(std::clamp(b,0.,1.)*1000));controls->metallicity.store(uint32_t(std::clamp(m,0.,1.)*1000));controls->decay.store(uint32_t(std::clamp(d,0.,1.)*1000));controls->width.store(uint32_t(std::clamp(w,0.,1.)*1000));}
 Ref<AudioStreamPlayback> _instantiate_playback() const override {
  Ref<BMTPlayback> p;p.instantiate();p->initialize(controls);
  // Resolve Godot's lazy extension virtual dispatch on the creating thread,
  // before the first callback (including short-lived headless race scenes).
  // This does not advance time or create a note: running is still false.
  p->start(0.0);p->stop();p->mix_audio(1.0f,1);p->is_playing();p->get_playback_position();
  return p;
 }
 String _get_stream_name() const override {return "Beat My Track / Grass";}
 double _get_length() const override {return 0;}
 bool _is_monophonic() const override {return false;}
};
void initialize_music(ModuleInitializationLevel level) {if(level==MODULE_INITIALIZATION_LEVEL_SCENE){ClassDB::register_class<BMTPlayback>();ClassDB::register_class<BMTMusicStream>();}}
void uninitialize_music(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT bmt_music_init(GDExtensionInterfaceGetProcAddress address,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
 GDExtensionBinding::InitObject init(address,library,initialization);init.register_initializer(initialize_music);init.register_terminator(uninitialize_music);init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
