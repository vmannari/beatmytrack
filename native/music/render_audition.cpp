#include "audition_v2.hpp"
#include <fstream>
#include <iostream>
#include <memory>
#include <vector>
// Offline only. Normalization and WAV I/O never enter the real-time module.
static void u32(std::ofstream &out,uint32_t v){out.write(reinterpret_cast<char*>(&v),4);}
static void u16(std::ofstream &out,uint16_t v){out.write(reinterpret_cast<char*>(&v),2);}
int main(int argc,char **argv) {
 if(argc!=3 && argc!=4){std::cerr<<"usage: render_audition output.wav bpm [backing|warm]\n";return 1;}
 const int rate=48000, bpm=std::atoi(argv[2]);
 if(bpm<100 || bpm>140) return 2;
 // Sixteen bars: introduction, full motif, technical passage, then release.
 const bool comparison=argc==4;
 const int frames=int(rate*(comparison?16.:64.)*60/bpm);
 auto synth=std::make_unique<bmt::Synth>(rate,1987);
 if(comparison) {
  if(std::string(argv[3])!="backing" && std::string(argv[3])!="warm") return 4;
  synth->set_backing_only(std::string(argv[3])=="backing");
 }
 std::vector<float> pcm(frames*2);
 double square=0,peak=0;
 for(int i=0;i<frames;++i) {
  double beat=i*double(bpm)/(rate*60.);
  uint32_t state=comparison?0xe530dc:beat<8?0x6020aa:beat<32?0xe530dc:beat<48?0x7096b5:0xff25ef;
  synth->controls(state,0,bpm,.50f,.18f,.42f,.34f);
  synth->render(pcm[i*2],pcm[i*2+1]);
  float fade=std::min(1.f,float(frames-1-i)/(rate*.06f));
  pcm[i*2]*=fade;pcm[i*2+1]*=fade;
  square+=pcm[i*2]*pcm[i*2]+pcm[i*2+1]*pcm[i*2+1];
  peak=std::max(peak,double(std::max(std::abs(pcm[i*2]),std::abs(pcm[i*2+1]))));
 }
 double rms=std::sqrt(square/pcm.size());
 // Identical comparison gain: removing a part must not turn up the backing.
 double gain=comparison?1.8:std::min(std::pow(10.,-18./20)/rms,std::pow(10.,-1.5/20)/peak);
 if(peak*gain>=1.0) {std::cerr<<"Preview gain would clip\n";return 5;}
 std::ofstream out(argv[1],std::ios::binary);if(!out) return 3;
 out.write("RIFF",4);u32(out,frames*4+36);out.write("WAVEfmt ",8);u32(out,16);u16(out,1);u16(out,2);u32(out,rate);u32(out,rate*4);u16(out,4);u16(out,16);out.write("data",4);u32(out,frames*4);
 for(float x:pcm)u16(out,uint16_t(int16_t(std::clamp(x*gain,-1.,1.)*32767)));
 std::cout<<(comparison?4:16)<<" bars, BPM "<<bpm<<", "<<double(frames)/rate<<" s; peak voices "<<synth->peak_voices()<<"; offline gain "<<gain<<"; RMS "<<20*std::log10(rms*gain)<<" dBFS; peak "<<20*std::log10(peak*gain)<<" dBFS\n";
}
