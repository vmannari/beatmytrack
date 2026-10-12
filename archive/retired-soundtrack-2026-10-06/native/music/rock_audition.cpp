// Offline reference-direction audition. Original riff, no recording/sample input.
// Physical strings and a small two-times-oversampled amp/cabinet replace synth lead.
#include <algorithm>
#include <array>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <memory>
#include <vector>
namespace rock {
constexpr float TAU=6.28318530718f;
constexpr int RATE=48000, BPM=128, VOICES=24;
float random(uint32_t &seed) {seed=seed*1664525u+1013904223u;return float(seed>>8)/8388608.f-1.f;}
struct StringVoice {
 std::array<float,1024> ring{};
 int cursor=0,age=0,gate=0;float delay=1,previous=0,gain=0,pan=0,damping=.995f;
 bool active=false;
};
struct Cabinet {
 float prior_input=0,highpass=0,pre_low=0,last=0,low1=0,low2=0;
 float tick(float input) {
  highpass=input-prior_input+.988f*highpass;prior_input=input;
  pre_low+=.42f*(highpass-pre_low);
  float sum=0;
  for(int sub=0;sub<2;++sub) {
   float x=last+(pre_low-last)*(sub+1)*.5f;
   // Continuous saturator and low cabinet cutoff; no hard clipping/fizzy top.
   x*=5.0f;x=x/(1+std::abs(x));x*=2.8f;x=x/(1+std::abs(x));
   low1+=.18f*(x-low1);low2+=.18f*(low1-low2);sum+=low2;
  }
  last=pre_low;return sum*.5f;
 }
};
class Band {
 std::array<StringVoice,VOICES> voices{};
 Cabinet left_amp,right_amp;
 uint32_t seed=92173;
 int64_t samples=0,last_step=-1;
 float kick=0,kick_pitch=0,kick_phase=0,snare=0,snare_low=0,snare_body=0;
 float hat=0,hat_low=0,bass_phase=0,bass_inc=0,bass_env=0,bass_age=0;
 int peak=0;
 void string_note(int pitch,float duration,float pan,float level,float detune) {
  StringVoice *voice=nullptr;
  for(auto &v:voices) if(!v.active){voice=&v;break;}
  if(!voice) {voice=&voices[0];for(auto &v:voices)if(v.age>voice->age)voice=&v;}
  auto &v=*voice;v.active=true;v.cursor=0;v.age=0;v.previous=0;
  v.delay=RATE/(440.f*std::pow(2.f,(pitch-69+detune)/12.f))-.5f;
  assert(v.delay>2 && v.delay<1023);
  v.gate=int(duration*RATE);v.pan=pan;v.gain=level;v.damping=.997f;
  float filtered=0;
  for(auto &cell:v.ring) {filtered+=.55f*(random(seed)-filtered);cell=filtered;}
 }
 void chord(int pitch,float beats,float velocity) {
  for(int side=0;side<2;++side) {
   float pan=side?.65f:-.65f;
   string_note(pitch,beats*60/BPM,pan,velocity,side?.025f:-.025f);
   string_note(pitch+7,beats*60/BPM,pan,velocity*.72f,side?.018f:-.018f);
   string_note(pitch+12,beats*60/BPM,pan,velocity*.38f,side?.012f:-.012f);
  }
  bass_inc=440.f*std::pow(2.f,(pitch-12-69)/12.f)/RATE;bass_env=1;bass_age=0;
 }
 void sequence(int step) {
  int s=step%8,bar=(step/8)%4;
  if(s==0 || s==4 || (bar%2==1 && s==7)){kick=1;kick_pitch=1;kick_phase=0;}
  if(s==2 || s==6)snare=1;
  hat=s%2?.65f:1.f;
  // Authored E-minor/blues power-chord rhythm, not the reference's riff/melody.
  constexpr int riffs[4][8]={{40,40,-1,43,40,-1,45,43},
                            {40,-1,40,43,45,-1,43,40},
                            {48,48,-1,47,45,-1,45,43},
                            {40,-1,43,45,47,-1,43,40}};
  int pitch=riffs[bar][s];
  if(pitch>=0)chord(pitch,(s==1 || s==3)?.24f:.42f,s%2?.8f:1.f);
 }
public:
 int peak_voices()const{return peak;}
 void render(float &l,float &r) {
  int step=int(samples*BPM*2/(int64_t(RATE)*60));
  if(step!=last_step){sequence(step);last_step=step;}
  float gl=0,gr=0;int active=0;
  for(auto &v:voices) {
   if(!v.active)continue;++active;++v.age;
   float release=std::clamp(1.f-float(v.age-v.gate)/(RATE*.045f),0.f,1.f);
   if(release<=0){v.active=false;continue;}
   float read=v.cursor-v.delay;while(read<0)read+=1024;
   int index=int(read);float fraction=read-index;
   float value=v.ring[index]+fraction*(v.ring[(index+1)%1024]-v.ring[index]);
   v.ring[v.cursor]=(value+v.previous)*.5f*v.damping;v.previous=value;v.cursor=(v.cursor+1)%1024;
   float attack=std::min(1.f,v.age/(RATE*.004f));
   float output=value*v.gain*attack*release;
   gl+=output*(1-v.pan)*.5f;gr+=output*(1+v.pan)*.5f;
  }
  peak=std::max(peak,active);
  float bass=std::sin(TAU*bass_phase)+.55f*std::sin(TAU*bass_phase*2)+.20f*std::sin(TAU*bass_phase*3);
  bass_phase+=bass_inc;bass_phase-=std::floor(bass_phase);bass_age+=1.f/RATE;bass_env*=.99988f;
  bass*=std::min(1.f,bass_age*250)*std::max(0.f,1.f-(bass_age-.22f)/.05f)*bass_env*.16f;
  kick_phase+=(49+100*kick_pitch)/RATE;kick_phase-=std::floor(kick_phase);
  float drums=.40f*std::sin(TAU*kick_phase)*kick;
  kick*=.99976f;kick_pitch*=.9975f;
  float n=random(seed);snare_low+=.29f*(n-snare_low);
  snare_body+=183.f/RATE;snare_body-=std::floor(snare_body);
  drums+=(snare_low*.40f+std::sin(TAU*snare_body)*.09f)*snare;snare*=.9997f;
  hat_low+=.32f*(n-hat_low);drums+=(n-hat_low)*hat*.028f;hat*=.9982f;
  float fade=std::min(1.f,float(samples)/(RATE*.012f));
  l=fade*(left_amp.tick(gl)*.58f+bass+drums);r=fade*(right_amp.tick(gr)*.58f+bass+drums);
  l=.65f*l/(1+std::abs(l));r=.65f*r/(1+std::abs(r));++samples;
 }
};
}
static void u32(std::ofstream &out,uint32_t v){out.write(reinterpret_cast<char*>(&v),4);}
static void u16(std::ofstream &out,uint16_t v){out.write(reinterpret_cast<char*>(&v),2);}
int main(int argc,char **argv) {
 if(argc!=2){std::cerr<<"usage: rock_audition output.wav\n";return 1;}
 constexpr int frames=rock::RATE*15; // Eight bars at 128 BPM.
 auto band=std::make_unique<rock::Band>(),repeat=std::make_unique<rock::Band>();
 std::vector<float> pcm(frames*2);double square=0,peak=0;
 for(int i=0;i<frames;++i) {
  float l,r,x,y;band->render(l,r);repeat->render(x,y);
  assert(l==x && r==y && std::isfinite(l) && std::isfinite(r));
  assert(std::abs(l)<.65f && std::abs(r)<.65f);
  float fade=std::min(1.f,float(frames-1-i)/(rock::RATE*.08f));l*=fade;r*=fade;
  pcm[i*2]=l;pcm[i*2+1]=r;square+=l*l+r*r;peak=std::max(peak,double(std::max(std::abs(l),std::abs(r))));
 }
 double rms=std::sqrt(square/pcm.size());assert(rms>.001 && band->peak_voices()<=rock::VOICES);
 double gain=std::min(std::pow(10.,-18./20)/rms,std::pow(10.,-2./20)/peak);
 std::ofstream out(argv[1],std::ios::binary);if(!out)return 2;
 out.write("RIFF",4);u32(out,frames*4+36);out.write("WAVEfmt ",8);u32(out,16);u16(out,1);u16(out,2);u32(out,rock::RATE);u32(out,rock::RATE*4);u16(out,4);u16(out,16);out.write("data",4);u32(out,frames*4);
 for(float x:pcm)u16(out,uint16_t(int16_t(x*gain*32767)));
 std::cout<<"PASS: 15-second deterministic stereo render, finite/bounded output, non-silent, peak "<<band->peak_voices()<<"/24 strings. RMS "<<20*std::log10(rms*gain)<<" dBFS, peak "<<20*std::log10(peak*gain)<<" dBFS. No device/ear acceptance.\n";
}
