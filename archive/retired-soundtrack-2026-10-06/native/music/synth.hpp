#pragma once
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
namespace bmt {
constexpr float TAU=6.28318530718f;
constexpr int MUSIC_ENGINE_VERSION=6, VOICES=18;
struct Controls {
 std::atomic<uint32_t> state{0x00ff20d9},context{0},bpm{128},seed{1};
 std::atomic<uint32_t> brightness{650},metallicity{350},decay{650},width{450};
};
static_assert(std::atomic<uint32_t>::is_always_lock_free, "lock-free audio controls required");
float random(uint32_t &seed) {seed=seed*1664525u+1013904223u;return float(seed>>8)/8388608.f-1.f;}
struct StringVoice {
 std::array<float,4096> ring{};
 int cursor=0,age=0,gate=0;float delay=1,previous=0,gain=0,pan=0,damping=.995f;
 bool active=false;
};
struct Cabinet {
 float prior_input=0,highpass=0,pre_low=0,last=0,low1=0,low2=0;
 float hp=.988f,pre=.42f,cut=.18f,drive=5.f;
 float tick(float input) {
  highpass=input-prior_input+hp*highpass;prior_input=input;
  pre_low+=pre*(highpass-pre_low);
  float sum=0;
  for(int sub=0;sub<2;++sub) {
   float x=last+(pre_low-last)*(sub+1)*.5f;
   // Continuous saturator and low cabinet cutoff; no hard clipping/fizzy top.
   x*=drive;x=x/(1+std::abs(x));x*=2.8f;x=x/(1+std::abs(x));
   low1+=cut*(x-low1);low2+=cut*(low1-low2);sum+=low2;
  }
  last=pre_low;return sum*.5f;
 }
};
struct SoftVoice {
 float phase=0,increment=0,age=0,gate=0,gain=0,pan=0; bool active=false;
};
class Synth {
 std::array<SoftVoice,10> soft_voices{};
 std::array<float,4097> sine{};
 int layers=1;
 float soft_slew=0,ensemble=0;
 float wave(float phase)const {
  phase-=std::floor(phase);float p=phase*4096;int i=int(p);
  return sine[i]+(sine[i+1]-sine[i])*(p-i);
 }
 void soft_note(int pitch,float beats,float level,float pan) {
  SoftVoice *v=&soft_voices[0];
  for(auto &candidate:soft_voices){if(!candidate.active){v=&candidate;break;}if(candidate.age>v->age)v=&candidate;}
  *v=SoftVoice{};v->active=true;v->increment=float(440*std::pow(2.,(pitch-69)/12.)/rate);
  v->gate=beats*60/bpm;v->gain=level;v->pan=pan;
 }
 void bass_note(int pitch) {
  bass_inc=440.f*std::pow(2.f,(pitch-12-69)/12.f)/rate;bass_env=1;bass_age=0;
 }
 std::array<StringVoice,VOICES> voices{};
 Cabinet left_amp,right_amp;
 uint32_t seed=92173;
 uint64_t sample_count=0,beat_units=0;
 int64_t last_step=-1;
 int ring_size=1024,mode=1,variant=0,active_count=0;
 float energy=.85f,tension=.12f,hook=1,gate_scale=1,width=.65f;
 float kd, kp, sd, hd, bd, sl, hl, excitation;
 bool melancholy=false,recovery_requested=false;
 float expression=.12f,expression_slew=.0001f;
 bool muted=false,final_requested=false,final_on=false,finish_pending=false,finished=false,hook_on=true;
 double finish_beat=0;
 float kick=0,kick_pitch=0,kick_phase=0,snare=0,snare_low=0,snare_body=0;
 float hat=0,hat_low=0,bass_phase=0,bass_inc=0,bass_env=0,bass_age=0;
 int peak=0;
 void string_note(int pitch,float duration,float pan,float level,float detune) {
  StringVoice *voice=nullptr;
  for(auto &v:voices) if(!v.active){voice=&v;break;}
  if(!voice) {voice=&voices[0];for(auto &v:voices)if(v.age>voice->age)voice=&v;}
  auto &v=*voice;v.active=true;v.cursor=0;v.age=0;v.previous=0;
  v.delay=rate/(440.f*std::pow(2.f,(pitch-69+detune)/12.f))-.5f;
  v.delay=std::clamp(v.delay,2.f,float(ring_size-1));
  v.gate=int(duration*rate);v.pan=pan;v.gain=level;v.damping=.997f;
  float filtered=0;
  for(int i=0;i<ring_size;++i) {filtered+=excitation*(random(seed)-filtered);v.ring[i]=filtered;}
 }
 void chord(int pitch,float beats,float velocity) {
  for(int side=0;side<2;++side) {
   float pan=side?width:-width;
   string_note(pitch,beats*60/bpm,pan,velocity,side?.025f:-.025f);
   string_note(pitch+7,beats*60/bpm,pan,velocity*.72f,side?.018f:-.018f);
   string_note(pitch+12,beats*60/bpm,pan,velocity*(hook_on?.38f:.18f),side?.012f:-.012f);
  }
  bass_note(pitch);
 }
 void sequence(int step) {
  int s=step%8,absolute_bar=step/8,bar=absolute_bar%4;
  if(s==0) {
   melancholy=recovery_requested;
   if(!melancholy && energy>.72f) mode=2; else if(energy<.60f) mode=1;
   if(energy<.30f || melancholy) mode=0;
   // Add distinct roles, rather than starting with the whole band turned down.
   layers=1;
   if(!melancholy) {
    if(energy>.28f)layers|=2; // sustained inner harmony
    if(energy>.44f)layers|=4; // low foundation
    if(energy>.60f)layers|=8; // rhythm arrives late
    if(energy>.74f)layers|=16; // accepted rhythm-guitar riff
    if(energy>.86f)layers|=32; // restrained answering voice
   }
   if(absolute_bar%4==0 || melancholy) {if(hook>.62f)hook_on=true;else if(hook<.38f)hook_on=false;}
   if(absolute_bar%8==0)final_on=final_requested;
  }
  if(finish_pending && step%2==0 && !finished) {
   finished=true;finish_beat=beats();chord(40,1.5f,1);kick=1;kick_pitch=1;kick_phase=0;return;
  }
  if(finished)return;
  constexpr int melody[4]={52,55,59,57};
  constexpr int recovery[4]={52,50,48,50};
  if(s==0) {
   soft_note(melancholy?recovery[bar]:melody[bar],3.65f,.17f,0);
   if(layers&2) {
    // Em, Em7, Cmaj7, Am7: close, low voicings under the motif.
    constexpr int harmony[4][3]={{47,55,59},{50,55,59},{48,52,55},{45,52,55}};
    for(int i=0;i<3;++i)soft_note(harmony[bar][i],3.15f,.050f,(i-1)*.5f);
   }
  }
  if((layers&32) && s==4)soft_note(bar==2?55:52,1.6f,.065f,-.35f);
  if((layers&4) && !(layers&16) && (s==0 || s==4))bass_note(bar==2?48:bar==3?45:40);
  if(layers&8) {
   if(s==0 || (s==4 && mode>0) || (mode==2 && bar%2==1 && s==7)) {kick=1;kick_pitch=1;kick_phase=0;}
   if(s==2 || s==6)snare=mode==2?.8f:.45f;
   if(s%2==0 || mode==2)hat=s%2?.35f:.55f;
  }
  // Authored E-minor/blues power-chord rhythm, not the reference's riff/melody.
  constexpr int riffs[4][8]={{40,40,-1,43,40,-1,45,43},
                            {40,-1,40,43,45,-1,43,40},
                            {48,48,-1,47,45,-1,45,43},
                            {40,-1,43,45,47,-1,43,40}};
  int pitch=riffs[bar][s];
  // Track fingerprints select a small authored pickup, never runtime-random notes.
  if(variant==1 && bar==3 && s==6)pitch=45;
  if(variant==2 && bar==1 && s==7)pitch=43;
  if(!(layers&16))return;
  if(pitch>=0)chord(pitch,((s==1 || s==3)?.24f:.42f)*gate_scale*(1-.15f*tension),s%2?.8f:1.f);
 }
public:
 double rate=48000; uint32_t bpm=128;
 explicit Synth(double sample_rate=48000,uint32_t track_seed=1):rate(std::clamp(sample_rate,8000.,192000.)) {
  for(int i=0;i<=4096;++i)sine[i]=std::sin(TAU*i/4096.f);
  soft_slew=1.f/float(rate);
  expression_slew=float(1-std::exp(-1./(rate*.25)));
  seed=track_seed?track_seed:1;variant=int(track_seed%3);
  ring_size=rate<=80000?1024:rate<=160000?2048:4096;
  auto decay=[&](float c){return float(std::pow(c,48000./rate));};
  kd=decay(.99976f);kp=decay(.9975f);sd=decay(.9997f);hd=decay(.9982f);bd=decay(.99988f);
  sl=1-decay(.71f);hl=1-decay(.68f);excitation=1-decay(.45f);
  for(auto *amp:{&left_amp,&right_amp}) {amp->hp=decay(.988f);amp->pre=1-decay(.58f);amp->cut=1-decay(.82f);}
 }
 void controls(uint32_t state,uint32_t context,uint32_t tempo,float bright=.65f,float drive=.35f,float decay=.65f,float stereo=.45f) {
  energy=float(state&255)/255;tension=float((state>>8)&255)/255;hook=float((state>>16)&255)/255;
  muted=context&4;recovery_requested=context&8;final_requested=context&1;finish_pending=context&2;bpm=std::clamp(tempo,60u,180u);
  gate_scale=.675f+.5f*std::clamp(decay,0.f,1.f);width=std::clamp(.2f+stereo,0.f,1.f);
  for(auto *amp:{&left_amp,&right_amp}) {amp->drive=3.6f+4*std::clamp(drive,0.f,1.f);amp->cut=float(1-std::pow(1-(.128f+.08f*std::clamp(bright,0.f,1.f)),48000./rate));}
 }
 double beats()const{return double(beat_units)/(rate*60.);}
 uint64_t samples()const{return sample_count;}
 int layer_mask()const{return layers;}
 int voice_count()const{return active_count;}
 int drum_pattern()const{return mode;}
 int bass_pattern()const{return variant;}
 int hook_pattern()const{return mode==0?(melancholy?5:4):(hook_on?variant:3);}
 int peak_voices()const{return peak;}
 void render(float &l,float &r) {
  if(muted){l=r=0;return;}
  int step=int(beat_units*2/(uint64_t(rate)*60));
  if(step!=last_step){sequence(step);last_step=step;}
  expression+=(energy-expression)*expression_slew;
  float gl=0,gr=0;int active=0;
  for(auto &v:voices) {
   if(!v.active)continue;++active;++v.age;
   float release=std::clamp(1.f-float(v.age-v.gate)/float(rate*.045f),0.f,1.f);
   if(release<=0){v.active=false;continue;}
   float read=v.cursor-v.delay;if(read<0)read+=ring_size;
   int index=int(read);float fraction=read-index;
   float value=v.ring[index]+fraction*(v.ring[(index+1)%ring_size]-v.ring[index]);
   v.ring[v.cursor]=(value+v.previous)*.5f*v.damping;v.previous=value;v.cursor=(v.cursor+1)%ring_size;
   float attack=std::min(1.f,v.age/float(rate*.004f));
   float output=value*v.gain*attack*release;
   gl+=output*(1-v.pan)*.5f;gr+=output*(1+v.pan)*.5f;
  }
  float warm_l=0,warm_r=0;
  for(auto &v:soft_voices) {
   if(!v.active)continue;
   v.age+=soft_slew;
   float release=std::clamp(1.f-(v.age-v.gate)/.65f,0.f,1.f);
   if(release<=0){v.active=false;continue;}
   ++active;
   float attack=std::clamp(v.age/.32f,0.f,1.f);attack=attack*attack*(3-2*attack);
   release=release*release*(3-2*release);
   float tone=(wave(v.phase)+.18f*wave(v.phase*2)+.06f*wave(v.phase*3))*v.gain*attack*release;
   v.phase+=v.increment;v.phase-=std::floor(v.phase);
   warm_l+=tone*(1-v.pan)*.5f;warm_r+=tone*(1+v.pan)*.5f;
  }
  active_count=active+(bass_env>.0001f)+(kick>.0001f)+(snare>.0001f)+(hat>.0001f);peak=std::max(peak,active_count);
  float bass=std::sin(TAU*bass_phase)+.55f*std::sin(TAU*bass_phase*2)+.20f*std::sin(TAU*bass_phase*3);
  bass_phase+=bass_inc;bass_phase-=std::floor(bass_phase);bass_age+=1.f/rate;bass_env*=bd;
  bass*=std::min(1.f,bass_age*250)*std::max(0.f,1.f-(bass_age-.22f)/.05f)*bass_env*.16f;
  kick_phase+=(49+100*kick_pitch)/rate;kick_phase-=std::floor(kick_phase);
  float drums=.40f*std::sin(TAU*kick_phase)*kick;
  kick*=kd;kick_pitch*=kp;
  float n=random(seed);snare_low+=sl*(n-snare_low);
  snare_body+=183.f/rate;snare_body-=std::floor(snare_body);
  drums+=(snare_low*.40f+std::sin(TAU*snare_body)*.09f)*snare;snare*=sd;
  hat_low+=hl*(n-hat_low);drums+=(n-hat_low)*hat*.028f;hat*=hd;
  float fade=std::min(1.f,float(sample_count)/float(rate*.012f));
  if(kick<1e-12f)kick=0;if(snare<1e-12f)snare=0;if(hat<1e-12f)hat=0;if(bass_env<1e-12f)bass_env=0;
  if(finished)fade*=float(std::clamp(1.-(beats()-finish_beat)/3.,0.,1.));
  l=fade*(warm_l+left_amp.tick(gl*(.2f+.8f*expression))*.58f+bass*(.45f+.55f*expression)+drums*(.5f+.5f*expression));r=fade*(warm_r+right_amp.tick(gr*(.2f+.8f*expression))*.58f+bass*(.45f+.55f*expression)+drums*(.5f+.5f*expression));
  l=.45f*l/(1+std::abs(l));r=.45f*r/(1+std::abs(r));++sample_count;beat_units+=bpm;
 }
};
}
