#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
namespace modular_music {
constexpr int BANK_VERSION=1, BPM=128, POOL=24, COMBINATIONS=243;
constexpr float TAU=6.283185307179586f;
// All scheduled parts share D / Bm / G / A triads; fourth tones are reserved.
// No independently chosen harmony.
constexpr int ROOT[4]={50,47,43,45};
constexpr int TONES[4][4]={{0,4,7,9},{0,3,7,10},{0,4,7,11},{0,4,7,14}};
struct Event {int step,tone;float velocity;};
constexpr Event MELODY[3][8]={
 {{0,0,.85f},{2,1,.65f},{4,2,.72f},{6,1,.6f},{16,2,.78f},{18,1,.62f},{21,0,.72f},{23,1,.55f}},
 {{0,2,.78f},{3,1,.62f},{5,0,.75f},{7,1,.55f},{16,0,.85f},{18,1,.64f},{20,2,.7f},{22,0,.6f}},
 {{0,1,.7f},{2,0,.82f},{5,2,.62f},{7,1,.58f},{16,1,.75f},{19,2,.65f},{21,1,.6f},{23,0,.8f}}
};
constexpr Event ANSWER[3][4]={
 {{10,2,.55f},{13,1,.5f},{26,1,.5f},{29,0,.6f}},
 {{9,0,.55f},{12,1,.5f},{25,2,.5f},{28,1,.55f}},
 {{11,1,.5f},{14,0,.6f},{27,0,.5f},{30,2,.5f}}
};
constexpr uint16_t BASS_MASK[3]={0x0101,0x0141,0x0409};
constexpr uint16_t CHORD_MASK[3]={0x0101,0x0201,0x0401};
struct Selection {
 int melody,answer,chords,bass,drums;
 explicit Selection(uint32_t race_seed) {
  // A stored selection ID is sufficient to reproduce any of the 243 arrangements.
  uint32_t id=race_seed%COMBINATIONS;
  melody=id%3;id/=3;answer=id%3;id/=3;chords=id%3;id/=3;bass=id%3;id/=3;drums=id%3;
 }
};
enum Part {KEY,ANSWER_KEY,CHORD,BASS,KICK,SNARE,HAT};
struct Voice {bool on=false;Part part=KEY;float phase=0,inc=0,env=1,decay=1,gain=0,pan=0,low=0;int age=0,gate=0;};
class Synth {
 std::array<Voice,POOL> voices{};
 std::array<float,4097> sine{};
 uint32_t noise_state;
 uint64_t frame=0;
 int64_t last_step=-1;
 float intensity=0;int stage=0,peak=0,active=0;
 float hz(int pitch)const{return 440.f*std::pow(2.f,(pitch-69)/12.f);}
 float wave(float phase)const {phase-=std::floor(phase);float p=phase*4096;int i=int(p);return sine[i]+(sine[i+1]-sine[i])*(p-i);}
 float noise(){noise_state=noise_state*1664525u+1013904223u;return float(noise_state>>8)/8388608.f-1;}
 void note(Part part,int pitch,float gain,float beats,float pan=0) {
  Voice *v=&voices[0];for(auto &q:voices){if(!q.on){v=&q;break;}if(q.age>v->age)v=&q;}
  *v=Voice{};v->on=true;v->part=part;v->inc=hz(pitch)/rate;v->gain=gain;v->pan=pan;v->gate=int(beats*60/BPM*rate);
  float tau=part==CHORD?.9f:part==BASS?.22f:part==HAT?.025f:part==SNARE?.055f:part==KICK?.11f:.20f;
  v->decay=std::exp(-1.f/(tau*rate));
 }
 void sequence(int64_t step) {
  int s=int(step%16),bar=int(step/16)%4,t=int(step%32);
  if(s==0)stage=intensity>.85f?4:intensity>.60f?3:intensity>.35f?2:intensity>.12f?1:0;
  for(const auto &e:MELODY[selection.melody])if(e.step==t)
   note(KEY,ROOT[bar]+12+TONES[bar][e.tone],.12f*e.velocity,.34f,-.12f);
  if(stage>=1 && (CHORD_MASK[selection.chords]&(1u<<s))) {
   for(int i=0;i<3;++i)note(CHORD,ROOT[bar]+TONES[bar][i],.028f,1.3f,(i-1)*.38f);
  }
  if(stage>=2 && (BASS_MASK[selection.bass]&(1u<<s)))
   note(BASS,ROOT[bar]-12,.12f,.55f);
  if(stage>=3) {
   if(s==0 || s==8 || (stage==4 && selection.drums==2 && s==11))note(KICK,36,.16f,.3f);
   if(s==4 || s==12)note(SNARE,50,.045f,.2f);
   int divisor=selection.drums==1?4:2;
   if(s%divisor==0)note(HAT,80,s%4?.012f:.016f,.08f,.15f);
  }
  if(stage>=4)for(const auto &e:ANSWER[selection.answer])if(e.step==t)
   note(ANSWER_KEY,ROOT[bar]+12+TONES[bar][e.tone],.095f*e.velocity,.32f,.2f);
 }
public:
 int rate;const Selection selection;
 explicit Synth(uint32_t race_seed,int sample_rate=48000):noise_state(race_seed?race_seed:1),rate(sample_rate),selection(race_seed){
  for(int i=0;i<=4096;++i)sine[i]=std::sin(TAU*i/4096.f);
 }
 void set_intensity(float value){intensity=std::clamp(value,0.f,1.f);}
 int active_stage()const{return stage;}int peak_voices()const{return peak;}
 double beats()const{return double(frame)*BPM/(rate*60.);}
 void render(float &l,float &r){
  int64_t step=int64_t(frame*BPM*4/(uint64_t(rate)*60));
  if(step!=last_step){sequence(step);last_step=step;}
  l=r=0;active=0;
  for(auto &v:voices){
   if(!v.on)continue;
   ++v.age;v.env*=v.decay;
   float seconds=float(v.age)/rate;
   float release_time=v.part==CHORD?.16f:.055f;
   float release=std::clamp(1.f-float(v.age-v.gate)/(rate*release_time),0.f,1.f);
   if(release<=0 || v.env<.00001f){v.on=false;continue;}
   ++active;
   float attack=std::min(1.f,seconds/(v.part==CHORD?.045f:v.part==BASS?.014f:.008f));
   attack=attack*attack*(3-2*attack);release=release*release*(3-2*release);
   float x=wave(v.phase);
   if(v.part==KEY)x+=.16f*wave(v.phase*2)+.035f*wave(v.phase*3);
   if(v.part==ANSWER_KEY)x+=.08f*wave(v.phase*2);
   if(v.part==CHORD)x+=.08f*wave(v.phase*2);
   if(v.part==BASS)x+=.15f*wave(v.phase*2);
   if(v.part==KICK)v.inc=(48+65*v.env*v.env*v.env)/rate;
   if(v.part==SNARE || v.part==HAT){float n=noise();v.low+=.20f*(n-v.low);x=v.part==SNARE?v.low+.15f*x:(n-v.low)*.35f;}
   v.phase+=v.inc;v.phase-=std::floor(v.phase);
   x*=v.env*v.gain*attack*release;
   l+=x*(1-v.pan)*.5f;r+=x*(1+v.pan)*.5f;
  }
  peak=std::max(peak,active);
  // Fixed conservative mix, with no section-by-section loudness normalization.
  l=.8f*l/(1+std::abs(l));r=.8f*r/(1+std::abs(r));++frame;
 }
};
}
