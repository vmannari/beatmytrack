#include "modular_bank.hpp"
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <memory>
#include <new>
static bool guard=false;
void *operator new(std::size_t n){if(guard)std::abort();if(auto p=std::malloc(n))return p;throw std::bad_alloc();}
void operator delete(void *p)noexcept{std::free(p);}void operator delete(void *p,std::size_t)noexcept{std::free(p);}
static void u32(std::ofstream &f,uint32_t x){f.write(reinterpret_cast<char*>(&x),4);}
static void u16(std::ofstream &f,uint16_t x){f.write(reinterpret_cast<char*>(&x),2);}
int main(int argc,char **argv){
 using namespace modular_music;
 // Slot contracts ensure every foreground phrase leaves the answer's space free.
 for(auto &pattern:MELODY)for(auto e:pattern){assert(e.step%16<=7 && e.tone>=0 && e.tone<3);}
 for(auto &pattern:ANSWER)for(auto e:pattern){assert(e.step%16>=9 && e.step%16<=14 && e.tone>=0 && e.tone<3);}
 if(argc==1){
  float largest=0;int peak=0;uint64_t hashes[COMBINATIONS]{};
  for(int id=0;id<COMBINATIONS;++id){
   auto synth=std::make_unique<Synth>(id,24000);synth->set_intensity(1);
   uint64_t hash=1469598103934665603ull;double square=0;
   guard=true;
   for(int i=0;i<180000;++i){float l,r;synth->render(l,r);assert(std::isfinite(l)&&std::isfinite(r));assert(std::abs(l)<.35f&&std::abs(r)<.35f);largest=std::max(largest,std::max(std::abs(l),std::abs(r)));square+=l*l;uint32_t bits;std::memcpy(&bits,&l,4);hash=(hash^bits)*1099511628211ull;}
   guard=false;
   assert(square/180000>.00001 && synth->peak_voices()<=POOL && synth->beats()==16);peak=std::max(peak,synth->peak_voices());
   for(int j=0;j<id;++j)assert(hash!=hashes[j]);hashes[id]=hash;
  }
  auto a=std::make_unique<Synth>(137),b=std::make_unique<Synth>(137);
  guard=true;for(int i=0;i<48000*8;++i){float l,r,x,y;a->render(l,r);b->render(x,y);assert(l==x && r==y);assert(a->active_stage()==0);}guard=false;
  assert(a->peak_voices()<=2);
  a->set_intensity(1);float l,r;while(a->beats()<20.01)a->render(l,r);assert(a->active_stage()==4);
  a->set_intensity(0);while(a->beats()<24.01)a->render(l,r);assert(a->active_stage()==0);
  std::printf("PASS: all 243 combinations, 4-bar cycle each at 24 kHz; finite/bounded/non-silent, allocation guard, distinct PCM; compatible tone/foreground slots; 48 kHz exact seed repeat, solo intro, bar-aligned build/reset. peak voices=%d/24, maximum sample=%.6f. No listening/device approval.\n",peak,largest);return 0;
 }
 if(argc!=3)return 1;
 int id=std::atoi(argv[2]);if(id<0 || id>=COMBINATIONS)return 2;
 constexpr int rate=48000,frames=rate*30;
 std::ofstream f(argv[1],std::ios::binary);if(!f)return 3;
 f.write("RIFF",4);u32(f,frames*4+36);f.write("WAVEfmt ",8);u32(f,16);u16(f,1);u16(f,2);u32(f,rate);u32(f,rate*4);u16(f,4);u16(f,16);f.write("data",4);u32(f,frames*4);
 auto synth=std::make_unique<Synth>(id);double square=0;float peak=0;
 for(int i=0;i<frames;++i){
  float t=float(i)/rate;
  // 4 bars solo; 4 bars chord+bass; 4 bars full; 4 bars return to solo.
  synth->set_intensity(t<7.5f?0:t<15?.5f:t<22.5f?1:0);
  float l,r;synth->render(l,r);float fade=std::min(1.f,float(frames-i)/(rate*.12f));l*=fade*3.f;r*=fade*3.f;
  assert(std::isfinite(l)&&std::abs(l)<.8f&&std::abs(r)<.8f);square+=l*l+r*r;peak=std::max(peak,std::max(std::abs(l),std::abs(r)));
  u16(f,uint16_t(int16_t(l*32767)));u16(f,uint16_t(int16_t(r*32767)));
 }
 auto s=synth->selection;std::printf("ID %d: melody=%d answer=%d chords=%d bass=%d drums=%d; RMS %.2f dBFS, peak %.2f dBFS; fixed identical mix gain.\n",id,s.melody,s.answer,s.chords,s.bass,s.drums,20*std::log10(std::sqrt(square/(frames*2))),20*std::log10(peak));return f?0:4;
}
