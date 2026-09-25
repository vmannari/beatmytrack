#pragma once
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>

namespace bmt {
constexpr int MUSIC_ENGINE_VERSION = 1;
constexpr double TAU = 6.283185307179586;
constexpr int VOICES = 32;
enum Instrument { KICK, SNARE, HAT, OPEN_HAT, PERC, BASS, PLUCK, PAD, PULSE, LEAD, ACCENT };
struct Note { uint8_t step, degree; float length, velocity; };
// A minor / Dorian-compatible DNA. Harmony Am9, Fmaj7, Cmaj9, G6, two bars each.
constexpr int SCALE[7] = {0,2,3,5,7,9,10};
constexpr int ROOTS[4] = {45,41,48,43};
constexpr Note HOOKS[3][8] = {
 {{0,0,.22f,.8f},{3,4,.18f,.62f},{6,6,.3f,.72f},{10,4,.2f,.66f},{16,2,.35f,.85f},{20,1,.2f,.64f},{23,4,.3f,.73f},{28,0,.6f,.82f}},
 {{0,0,.3f,.8f},{4,2,.2f,.6f},{7,4,.3f,.72f},{12,1,.2f,.7f},{16,6,.35f,.8f},{19,4,.3f,.67f},{24,2,.3f,.7f},{28,0,.6f,.8f}},
 {{0,4,.3f,.8f},{3,2,.25f,.65f},{8,0,.3f,.7f},{11,1,.2f,.6f},{16,2,.3f,.8f},{22,4,.3f,.68f},{26,1,.2f,.63f},{28,0,.6f,.8f}}
};
constexpr uint16_t BASS_MASK[3] = {0x1149,0x4921,0x1125};
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
 float sin_lut(float phase) const {
  phase-=std::floor(phase); float p=phase*4096; int i=int(p);
  return sine[i]+(sine[i+1]-sine[i])*(p-i);
 }
 static float noise(Voice &v) { v.noise=v.noise*1664525u+1013904223u; return float(v.noise>>8)*(2.f/16777216.f)-1.f; }
 void note(int kind,int pitch,float velocity,float duration,float pan=0) {
  Voice *v=&voices[0];
  for(auto &candidate:voices) { if(!candidate.on) {v=&candidate;break;} if(candidate.env*candidate.gain<v->env*v->gain) v=&candidate; }
  *v=Voice{}; v->on=true;v->kind=kind;v->gain=velocity;v->duration=duration;
  v->increment=float(440*std::pow(2.,(pitch-69)/12.)/rate); v->pan=pan*width;v->env=1;
  float seconds=duration;
  if(kind==KICK) seconds=.17f; if(kind==SNARE) seconds=.085f;
  if(kind==HAT) seconds=.023f; if(kind==OPEN_HAT) seconds=.12f;
  if(kind==PLUCK || kind==LEAD) seconds*=.65f+decay_preset;
  v->decay=std::exp(-1.f/(float(rate)*std::max(.01f,seconds)));
  random=random*1664525u+1013904223u; v->noise=random;
 }
 void schedule(int64_t step) {
  int s=int(step%16),bar=int(step/16), phrase=bar/8;
  if(s==0) {
   // Hysteresis plus a full bar hold. Hooks/maximum arrangement enter on phrases.
   if(energy>.72f) bar_mode=2; else if(energy<.60f) bar_mode=1;
   if(energy<.30f) bar_mode=0;
   if(bar%4==0) {if(hook>.62f) hook_on=true; if(hook<.38f) hook_on=false;}
   if(bar%8==0) final_on=final_requested;
  }
  if(finish_pending && step%4==0 && !finish_latched) {
   finish_latched=true;finish_beat=beat;note(ACCENT,81,.22f,.4f);
   for(int p:{57,60,64,71}) note(PLUCK,p,.22f,.7f); return;
  }
  if(finish_latched) return;
  int root=ROOTS[(bar/2)%4];
  float variation=.94f+float((step*13+seed_variant*7)%11)*.006f;
  if(s%4==0 && (bar_mode>0 || s%8==0)) note(KICK,36,.53f*variation,.2f);
  if(bar_mode==2 && s==(drum_variant==1?7:drum_variant==2?10:14)) note(KICK,36,.28f,.13f);
  if(s==4 || s==12) note(SNARE,50,.24f*variation,.15f);
  if(s%2==0 || (bar_mode==2 && s%4==3)) note(HAT,90,(s%4==2?.11f:.065f)*variation,.04f,-.4f);
  if(bar_mode==2 && s==14) note(OPEN_HAT,87,.075f,.14f,.4f);
  if(tension>.55f && (s==3 || s==10 || s==15)) note(PERC,74,.085f,.08f,.65f);
  if(BASS_MASK[seed_variant%3] & (1u<<s)) note(BASS,root-12,.27f,.16f);
  if(s==0 && bar%2==0) {
   int third=((bar/2)%4==0)?3:4;
   note(PAD,root+12+voicing*12,.085f,1.6f,-.7f);note(PAD,root+12+third,.07f,1.6f,.7f);note(PAD,root+19,.065f,1.6f);
  }
  int hook_variant=(seed_variant+phrase%2)%3;
  for(const auto &n:HOOKS[hook_variant]) if(n.step==step%32) {
   // Hook uses chord tones and shared pentatonic extensions, never geometry-generated notes.
   constexpr int degrees[7]={0,2,3,7,9,10,12};
   int interval=degrees[n.degree]; if(interval==3 && (bar/2)%4!=0) interval=4;
   note(PLUCK,root+24+interval,n.velocity*(hook_on?.18f:.08f),n.length,(n.step%3-1)*.6f);
   if(hook_on && (final_on || bar%16>=8) && n.step%4==0) note(LEAD,root+24+interval,.07f,n.length*.8f,-.3f);
  }
  if(tension>.38f && s%(tension>.72f?2:4)==0) note(PULSE,root+12,.08f*tension,.08f,.25f);
  if(bar%8==7 && s>=14) note(PERC,69+s,.075f,.055f,-.5f);
 }
 bool final_requested=false;
public:
 double rate=48000; uint32_t bpm=132;
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
  l=r=0;active=0;
  for(auto &v:voices) {
   if(!v.on) continue; ++active;v.age+=1.f/float(rate); v.env*=v.decay;
   if(v.env<.0001f || v.age>v.duration*8+1) {v.on=false;continue;}
   float x=0, env=v.env, osc=sin_lut(v.phase), n=0;
   switch(v.kind) {
    case KICK: v.phase+=float((46+110*env*env*env)/rate);x=osc*env+.07f*noise(v)*env*env*env*env;break;
    case SNARE: n=noise(v);v.filter+=.22f*(n-v.filter);x=(n-v.filter)*.75f+osc*.25f;x*=env;v.phase+=v.increment;break;
    case HAT: case OPEN_HAT: n=noise(v);x=(n-v.noise_last)*.35f*env;v.noise_last=n;break;
    case PERC: x=sin_lut(v.phase+.4f*env*sin_lut(v.phase*2.73f))*env;v.phase+=v.increment;break;
    case BASS: x=(osc+.22f*sin_lut(v.phase*2)+.08f*sin_lut(v.phase*3))*env;v.phase+=v.increment;break;
    case PAD: x=(osc+sin_lut(v.phase2))*.5f*std::min(1.f,v.age*3)*env;v.phase+=v.increment;v.phase2+=v.increment*1.002f;break;
    case PLUCK: case LEAD:
     x=sin_lut(v.phase+metal*.42f*env*env*sin_lut(v.phase*3));
     x+=brightness*.16f*sin_lut(v.phase*2)*env;
     x*=env*std::min(1.f,v.age*700);v.phase+=v.increment*(1+.002f*env*env);break;
    case PULSE: x=(osc+brightness*.25f*sin_lut(v.phase*3))*env;v.phase+=v.increment;break;
    case ACCENT: x=(osc+.3f*sin_lut(v.phase*1.5f))*env;v.phase+=v.increment;break;
   }
   v.phase-=std::floor(v.phase);v.phase2-=std::floor(v.phase2);
   x*=v.gain; l+=x*(1-v.pan)*.5f;r+=x*(1+v.pan)*.5f;
  }
  peak=std::max(peak,active);
  uint32_t read=(delay_cursor+16384-uint32_t(rate*.09375))%16384;
  float dl=delay_l[read],dr=delay_r[read];
  delay_l[delay_cursor]=r*.13f+dr*.22f;delay_r[delay_cursor]=l*.13f+dl*.22f;
  delay_cursor=(delay_cursor+1)%16384; l+=dl;r+=dr;
  float gain_target=finish_latched?float(std::clamp(1.-(beat-finish_beat)/4.,0.,1.)):1.f;
  out_gain+=(gain_target-out_gain)*.001f;
  // DC blocking, conservative gain, bounded soft saturation. No master/SFX processing.
  float a=l-last_l+.995f*dc_l,b=r-last_r+.995f*dc_r;last_l=l;last_r=r;dc_l=a;dc_r=b;
  l=.45f*out_gain*a/(1+std::abs(a));r=.45f*out_gain*b/(1+std::abs(b));
  beat+=double(bpm)/(60.*rate);++sample_count;
 }
 double beats()const{return beat;} uint64_t samples()const{return sample_count;}
 int voice_count()const{return active;} int peak_voices()const{return peak;}
 int drum_pattern()const{return bar_mode;} int bass_pattern()const{return seed_variant;}
 int hook_pattern()const{return (seed_variant+int(beat/32)%2)%3;}
};
}
