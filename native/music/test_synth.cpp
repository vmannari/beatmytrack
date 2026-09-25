#ifdef BMT_REFERENCE_AUDITION
#include "audition_v2.hpp"
#else
#include "synth.hpp"
#endif
#include <cassert>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <new>
static bool guard=false;
void *operator new(std::size_t n) {if(guard) std::abort();if(void *p=std::malloc(n))return p;throw std::bad_alloc();}
void operator delete(void *p) noexcept {std::free(p);}
void operator delete(void *p,std::size_t) noexcept {std::free(p);}
void u32(std::ofstream &out,uint32_t v){out.write(reinterpret_cast<char*>(&v),4);}
void u16(std::ofstream &out,uint16_t v){out.write(reinterpret_cast<char*>(&v),2);}
int main(int argc,char **argv) {
 const int rate=48000, frames=rate*60;
 auto a=new bmt::Synth(rate,1987), b=new bmt::Synth(rate,1987), other=new bmt::Synth(rate,1988);
 std::ofstream wav;if(argc>1){wav.open(argv[1],std::ios::binary);wav.write("RIFF",4);u32(wav,frames*4+36);wav.write("WAVEfmt ",8);u32(wav,16);u16(wav,1);u16(wav,2);u32(wav,rate);u32(wav,rate*4);u16(wav,4);u16(wav,16);wav.write("data",4);u32(wav,frames*4);}
 double square=0,max_sample=0;int differences=0;auto start=std::chrono::steady_clock::now();
 for(int i=0;i<frames;++i){
  uint32_t control=i<rate*20?0xff20d9:i<rate*40?0x20e099:0xff30ff;
  a->controls(control,0,132);b->controls(control,0,132);other->controls(control,0,132);
  float l,r,x,y,z,w;guard=true;a->render(l,r);b->render(x,y);other->render(z,w);guard=false;
  assert(l==x && r==y);assert(std::isfinite(l)&&std::isfinite(r));assert(std::abs(l)<.45f&&std::abs(r)<.45f);
  if(l!=z) ++differences;square+=l*l;max_sample=std::max(max_sample,double(std::abs(l)));
  if(wav){u16(wav,uint16_t(int16_t(l*32767)));u16(wav,uint16_t(int16_t(r*32767)));}
 }
 assert(differences>rate);assert(a->peak_voices()<=32);assert(std::abs(a->beats()-132)<1e-6);assert(square/frames>.00001);
 double beat=a->beats();a->controls(0,4,132);float l,r;a->render(l,r);assert(a->beats()==beat && l==0 && r==0);
 a->controls(0xff20ff,2,132);for(int i=0;i<rate*4;++i)a->render(l,r);assert(std::abs(l)<.0001&&std::abs(r)<.0001);
 auto hysteresis=new bmt::Synth(rate,1);
 hysteresis->controls(0xff20ff,0,132);hysteresis->render(l,r);assert(hysteresis->drum_pattern()==2);
 hysteresis->controls(0xff20a6,0,132); // E=.65: hold full across bar, no threshold chatter.
 while(hysteresis->beats()<4.01) hysteresis->render(l,r);
 assert(hysteresis->drum_pattern()==2);
 hysteresis->controls(0xff2090,0,132); // E=.56: drop only at the next bar.
 hysteresis->render(l,r);assert(hysteresis->drum_pattern()==2);
 while(hysteresis->beats()<8.01) hysteresis->render(l,r);
 assert(hysteresis->drum_pattern()==1);delete hysteresis;
 for(int hz:{44100,96000,192000}) {
  auto probe=new bmt::Synth(hz,1987);probe->controls(0xff20ff,0,128);
  guard=true;
  for(int i=0;i<hz*3;++i) {probe->render(l,r);assert(std::isfinite(l)&&std::isfinite(r)&&std::abs(l)<.45f&&std::abs(r)<.45f);}
  guard=false;
  assert(std::abs(probe->beats()-6.4)<1e-9);
  probe->controls(0xff20ff,0,135);
  for(int i=0;i<hz;++i)probe->render(l,r);
  assert(std::abs(probe->beats()-8.65)<1e-9);delete probe;
 }
 // Drift check across block sizes is implicit: render has no block-dependent timing.
 auto ms=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-start).count();
 std::printf("PASS: 60s exact seeded PCM, variant difference, allocation guard, bounds, clock, pause, finish, bar scheduling, hysteresis, 44.1/96/192 kHz and tempo change. peak=%d rms=%.6f max=%.6f; three renders + WAV %lld ms\n",a->peak_voices(),std::sqrt(square/frames),max_sample,(long long)ms);
 delete a;delete b;delete other;
}
