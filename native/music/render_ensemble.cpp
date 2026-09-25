// Offline review of the production core: solo, build, full ensemble, recovery.
#include "synth.hpp"
#include <fstream>
#include <memory>
#include <cassert>
static void u32(std::ofstream &f,uint32_t x){f.write(reinterpret_cast<char*>(&x),4);}
static void u16(std::ofstream &f,uint16_t x){f.write(reinterpret_cast<char*>(&x),2);}
int main(int argc,char **argv){
 if(argc!=2)return 1;
 constexpr int rate=48000,frames=48*rate;
 std::ofstream f(argv[1],std::ios::binary);if(!f)return 2;
 f.write("RIFF",4);u32(f,frames*4+36);f.write("WAVEfmt ",8);u32(f,16);u16(f,1);u16(f,2);u32(f,rate);u32(f,rate*4);u16(f,4);u16(f,16);f.write("data",4);u32(f,frames*4);
 auto synth=std::make_unique<bmt::Synth>(rate,1987);
 for(int i=0;i<frames;++i){
  float seconds=float(i)/rate,build=std::clamp((seconds-8)/24.f,0.f,1.f);
  if(seconds>=40)build=0;
  float energy=.12f+.88f*build,hook=.1f+.9f*build;
  if(i%512==0)synth->controls(uint32_t(energy*255)|(20u<<8)|(uint32_t(hook*255)<<16),seconds>=40?8:0,128);
  float l,r;synth->render(l,r);float fade=std::min(1.f,float(frames-i)/(rate*.5f));
  assert(std::isfinite(l)&&std::isfinite(r)&&std::abs(l)<.45f&&std::abs(r)<.45f);
  u16(f,uint16_t(int16_t(l*fade*32767)));u16(f,uint16_t(int16_t(r*fade*32767)));
 }
 return f?0:3;
}
