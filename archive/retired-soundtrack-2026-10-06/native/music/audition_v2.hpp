#pragma once
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>

namespace bmt {
// Offline ear-review candidate. Not included by extension.cpp or shipping builds.
constexpr int MUSIC_ENGINE_VERSION = 3;
constexpr double TAU = 6.283185307179586;
constexpr int VOICES = 32;
enum Instrument { KICK, SNARE, HAT, OPEN_HAT, PERC, BASS, PLUCK, PAD, PULSE, LEAD, ACCENT };
struct Note { uint8_t step, pitch; float length, velocity; };
// One key (D natural minor), two-bar chord holds, voice-led inner parts.
// New motif: pitches are fixed in the key, not shifted wholesale at every chord.
constexpr int ROOTS[4] = {50,46,53,48};
constexpr int CHORDS[4][4] = {{50,57,60,65},{50,57,58,65},{48,55,57,65},{48,55,62,64}};
constexpr Note HOOKS[3][6] = {
 {{2,69,.70f,.78f},{8,65,1.0f,.70f},{14,67,.45f,.57f},{18,69,.70f,.73f},{24,64,.6f,.60f},{28,62,.8f,.72f}},
 {{2,69,.70f,.78f},{8,65,1.0f,.70f},{14,67,.45f,.57f},{18,69,.70f,.73f},{24,65,.6f,.60f},{28,62,.8f,.72f}},
 {{2,69,.70f,.78f},{8,65,1.0f,.70f},{14,67,.45f,.57f},{18,72,.70f,.73f},{24,69,.6f,.60f},{28,67,.8f,.72f}}
};
constexpr uint16_t BASS_MASK[3] = {0x4545,0x4549,0x4945};
struct Controls {
 std::atomic<uint32_t> state{0x009980aa}; // packed E,T,H; coherent one-word publication
 std::atomic<uint32_t> context{0}; // final lap bit 0, finish bit 1, muted bit 2
 std::atomic<uint32_t> bpm{132}, seed{1};
 std::atomic<uint32_t> brightness{650}, metallicity{350}, decay{650}, width{450};
};
static_assert(std::atomic<uint32_t>::is_always_lock_free, "audio controls require lock-free atomics");
struct Voice {
 bool on=false; int kind=0; float phase=0, phase2=0, increment=0, env=0, decay=0, age=0, duration=0;
 float gain=0, pan=0, filter=0, noise_last=0; uint32_t noise=1;
 float alpha=.1f, filter2=0, attack=.004f, release=.06f, transient=1, transient_decay=.99f;
};
class Synth {
 std::array<float,4097> sine{};
 std::array<Voice,VOICES> voices{};
 std::array<float,16384> delay_l{}, delay_r{};
 uint32_t delay_cursor=0, random=1;
 double beat=0; int64_t last_step=-1; int bar_mode=1; bool hook_on=true, final_on=false;
 bool finish_pending=false, finish_latched=false; double finish_beat=-1;
 float energy=.6f,tension=.2f,hook=.7f, brightness=.65f,metal=.35f,decay_preset=.65f,width=.45f;
 float out_gain=0, dc_l=0,dc_r=0,last_l=0,last_r=0;
 int seed_variant=0,drum_variant=0,voicing=0; uint64_t sample_count=0; int active=0, peak=0;
 bool backing_only=false;
 float sin_lut(float phase) const {
  phase-=std::floor(phase); float p=phase*4096; int i=int(p);
  return sine[i]+(sine[i+1]-sine[i])*(p-i);
 }
 static float noise(Voice &v) { v.noise=v.noise*1664525u+1013904223u; return float(v.noise>>8)*(2.f/16777216.f)-1.f; }
 static float blep(float phase,float increment) {
  if(phase<increment) {float t=phase/increment;return t+t-t*t-1;}
  if(phase>1-increment) {float t=(phase-1)/increment;return t*t+t+t+1;}
  return 0;
 }
 static float saw(float phase,float increment) {return 2*phase-1-blep(phase,increment);}
 void note(int kind,int pitch,float velocity,float duration,float pan=0) {
  Voice *v=&voices[0];
  for(auto &candidate:voices) { if(!candidate.on) {v=&candidate;break;} if(candidate.env*candidate.gain<v->env*v->gain) v=&candidate; }
  *v=Voice{}; v->on=true;v->kind=kind;v->gain=velocity;v->duration=duration;
  v->increment=float(440*std::pow(2.,(pitch-69)/12.)/rate); v->pan=pan*width;v->env=1;
  float seconds=.20f, cutoff=2000;
  if(kind==KICK) {seconds=.075f;v->attack=.001f;}
  if(kind==SNARE) {seconds=.085f;cutoff=2600;v->attack=.002f;}
  if(kind==HAT) {seconds=.017f;cutoff=3200;v->attack=.002f;}
  if(kind==OPEN_HAT) {seconds=.085f;cutoff=3200;v->attack=.002f;}
  if(kind==BASS) {seconds=.8f;cutoff=700+brightness*700;v->release=.045f;}
  if(kind==PLUCK) {seconds=.15f+.16f*decay_preset;cutoff=900+brightness*1300;v->release=.10f;}
  if(kind==PAD) {seconds=12.f;cutoff=1400;v->attack=.08f;v->release=.18f;}
  if(kind==LEAD) {seconds=.32f;cutoff=750;v->attack=.035f;v->release=.15f;}
  if(kind==PULSE) {seconds=.10f;cutoff=1100;}
  v->decay=std::exp(-1.f/(float(rate)*std::max(.01f,seconds)));
  v->alpha=1-std::exp(-float(TAU)*cutoff/float(rate));
  v->transient_decay=std::exp(-1.f/(float(rate)*.012f));
  random=random*1664525u+1013904223u; v->noise=random;
 }
 void schedule(int64_t step) {
  int s=int(step%16),bar=int(step/16);
  if(s==0) {
   // Hysteresis plus a full bar hold. Hooks/maximum arrangement enter on phrases.
   if(energy>.72f) bar_mode=2; else if(energy<.60f) bar_mode=1;
   if(energy<.30f) bar_mode=0;
   if(bar%4==0) {if(hook>.62f) hook_on=true; if(hook<.38f) hook_on=false;}
   if(bar%8==0) final_on=final_requested;
  }
  if(finish_pending && step%4==0 && !finish_latched) {
   finish_latched=true;finish_beat=beat;note(ACCENT,74,.16f,.4f);
   for(auto &v:voices) if(v.on) v.duration=v.age;
   for(int p:{50,57,65,69}) note(PLUCK,p,.22f,.7f); return;
  }
  if(finish_latched) return;
  int root=ROOTS[(bar/2)%4];
  float beat_seconds=60.f/bpm;
  float variation=.96f+float(((step%256)*13+seed_variant*7)%9)*.005f;
  if(s%4==0 && (bar_mode>0 || s%8==0)) note(KICK,36,.44f*variation,.18f);
  if(bar_mode==2 && bar%2==1 && s==(drum_variant==1?7:14)) note(KICK,36,.20f,.13f);
  if(s==4 || s==12) note(SNARE,54,.28f*variation,.19f);
  if(s%2==0) note(HAT,90,(s%4==2?.06f:.035f)*variation,.05f,-.3f);
  if(tension>.60f && bar%2==1 && s==15) note(PERC,62,.055f,.07f,.4f);
  if(BASS_MASK[seed_variant%3] & (1u<<s)) {
   int bass_pitch=root-12+(s==14 && bar%2==1?7:0);
   note(BASS,bass_pitch,.40f*variation,.43f*beat_seconds);
  }
  if(s==0 && bar%2==0) {
   // Explicit note-off stops previous chord tails crossing the next harmony.
   for(auto &v:voices) if(v.on && v.kind==PAD) v.duration=v.age;
   for(int i=0;i<4;++i) note(PAD,CHORDS[(bar/2)%4][i],.15f,7.45f*beat_seconds,(i%2?1:-1)*.45f);
  }
  int hook_variant=bar%8==6?2:seed_variant%2;
  for(const auto &n:HOOKS[hook_variant]) if(!backing_only && n.step==step%32) {
   // Same motif, same tonal centre. Later phrases answer a third lower.
   int pitch=n.pitch;
   if(bar%8==4 && n.step==18) pitch=67;
   note(LEAD,pitch-12,n.velocity*(hook_on?.24f:.10f),n.length*beat_seconds,-.12f);
  }
  // No upper-register pluck answer or tension ostinato in this timbre review.
  if(bar%8==7 && s==15) note(SNARE,54,.075f,.08f);
 }
 bool final_requested=false;
public:
 double rate=48000; uint32_t bpm=132;
 void set_backing_only(bool value) {backing_only=value;}
 explicit Synth(double sample_rate=48000,uint32_t seed=1):rate(sample_rate) {
  for(int i=0;i<=4096;++i) sine[i]=float(std::sin(TAU*i/4096.));
  random=seed?seed:1;seed_variant=int(seed%3);drum_variant=int((seed/3)%3);voicing=int((seed/9)%2);
 }
 void controls(uint32_t state,uint32_t context,uint32_t tempo,float bright=.65f,float metallic=.35f,float decay=.65f,float stereo=.45f) {
  energy=float(state&255)/255;tension=float((state>>8)&255)/255;hook=float((state>>16)&255)/255;
  final_requested=context&1;finish_pending=context&2; muted=context&4;
  bpm=std::clamp(tempo,60u,180u);brightness=bright;metal=metallic;decay_preset=decay;width=stereo;
 }
 bool muted=false;
 void render(float &l,float &r) {
  if(muted) { l=r=0; return; } // pause freezes the authoritative sample/beat position
  int64_t step=int64_t(std::floor(beat*4+1e-9));
  if(step!=last_step) {schedule(step);last_step=step;}
  l=r=0;active=0;float send_l=0,send_r=0;
  for(auto &v:voices) {
   if(!v.on) continue; ++active;v.age+=1.f/float(rate); v.env*=v.decay;v.transient*=v.transient_decay;
   float release=std::clamp(1.f-(v.age-v.duration)/v.release,0.f,1.f);
   if(v.env<.0001f || release==0) {v.on=false;continue;}
   float x=0, env=v.env*std::min(1.f,v.age/v.attack)*release, osc=sin_lut(v.phase), n=0;
   switch(v.kind) {
    case KICK:
     v.phase+=float((51+115*v.transient*v.transient)/rate);
     x=(osc+.018f*noise(v)*v.transient)*env;break;
    case SNARE:
     n=noise(v);v.filter+=v.alpha*(n-v.filter);v.filter2+=.035f*(v.filter-v.filter2);
     x=((v.filter-v.filter2)*1.8f+.3f*osc+.15f*sin_lut(v.phase2))*env;
     v.phase+=185.f/float(rate);v.phase2+=330.f/float(rate);break;
    case HAT: case OPEN_HAT:
     n=noise(v);v.filter+=v.alpha*(n-v.filter);v.filter2+=.4f*(v.filter-v.filter2);
     x=(v.filter-v.filter2)*env;break;
    case PERC:
     x=sin_lut(v.phase+.12f*v.transient*sin_lut(v.phase2))*env;
     v.phase+=v.increment;v.phase2+=v.increment*2.414f;break;
    case BASS:
     x=.55f*osc+.66f*sin_lut(v.phase*2)+.21f*sin_lut(v.phase*3)+.10f*sin_lut(v.phase*4);
     v.filter+=v.alpha*(x-v.filter);x=v.filter*env;v.phase+=v.increment;break;
    case PAD:
     x=.45f*saw(v.phase,v.increment)+.45f*saw(v.phase2,v.increment*1.0015f);
     v.filter+=v.alpha*(x-v.filter);v.filter2+=v.alpha*(v.filter-v.filter2);
     x=v.filter2*env;v.phase+=v.increment;v.phase2+=v.increment*1.0015f;break;
    case PLUCK:
     x=.8f*sin_lut(v.phase+metal*.10f*v.transient*sin_lut(v.phase*2))+.24f*saw(v.phase,v.increment);
     v.filter+=v.alpha*(x-v.filter);x=v.filter*env;v.phase+=v.increment;break;
    case LEAD:
     // Short, softly attacked midrange chord-key tone, replacing the exposed
     // sine/harmonic upper lead. Two-pole damping; no FM or bright transient.
     x=.65f*saw(v.phase,v.increment)+.35f*saw(v.phase2,v.increment*1.001f);
     v.filter+=v.alpha*(x-v.filter);v.filter2+=v.alpha*(v.filter-v.filter2);
     x=v.filter2*env;v.phase+=v.increment;v.phase2+=v.increment*1.001f;break;
    case PULSE:
     x=(osc+.18f*sin_lut(v.phase*2))*env;v.phase+=v.increment;break;
    case ACCENT:
     x=(osc+.2f*sin_lut(v.phase*2))*env;v.phase+=v.increment;break;
   }
   v.phase-=std::floor(v.phase);v.phase2-=std::floor(v.phase2);
   x*=v.gain; float vl=x*(1-v.pan)*.5f,vr=x*(1+v.pan)*.5f;l+=vl;r+=vr;
   // Dry comparison: no repeating upper-note delay cloud.
  }
  peak=std::max(peak,active);
  uint32_t read=(delay_cursor+16384-std::min(16383u,uint32_t(rate*60/bpm*.375)))%16384;
  float dl=delay_l[read],dr=delay_r[read];
  delay_l[delay_cursor]=send_r*.18f+dr*.20f;delay_r[delay_cursor]=send_l*.18f+dl*.20f;
  delay_cursor=(delay_cursor+1)%16384; l+=dl;r+=dr;
  float gain_target=finish_latched?float(std::clamp(1.-(beat-finish_beat)/4.,0.,1.)):1.f;
  out_gain+=(gain_target-out_gain)*.001f;
  // DC blocking, conservative gain, bounded soft saturation. No master/SFX processing.
  float a=l-last_l+.995f*dc_l,b=r-last_r+.995f*dc_r;last_l=l;last_r=r;dc_l=a;dc_r=b;
  a*=2.0f;b*=2.0f;
  l=.45f*out_gain*a/(1+std::abs(a));r=.45f*out_gain*b/(1+std::abs(b));
  beat+=double(bpm)/(60.*rate);++sample_count;
 }
 double beats()const{return beat;} uint64_t samples()const{return sample_count;}
 int voice_count()const{return active;} int peak_voices()const{return peak;}
 int drum_pattern()const{return bar_mode;} int bass_pattern()const{return seed_variant;}
 int hook_pattern()const{return int(beat/4)%8==6?2:seed_variant%2;}
};
}
