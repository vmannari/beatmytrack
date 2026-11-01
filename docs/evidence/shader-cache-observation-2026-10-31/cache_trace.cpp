// Diagnostic-only GL dispatch observer for an owned, SHA256-pinned Godot process.
// This does not replace shader programs or suppress cache writes. Never load in
// the owner's editor or game. Results describe CPU call spans, not GPU time.
#include "../native-shader-preparation-2026-10-28/shader_job.hpp"
#include "gdextension_interface.h"
#include <atomic>

using namespace prep;
using Query=void(APIENTRY*)(GLuint,GLenum,GLint*);
using Extract=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,GLenum*,void*);
using Import=void(APIENTRY*)(GLuint,GLenum,const void*,GLsizei);
using Delete=void(APIENTRY*)(GLuint);
static Query original_query=nullptr;
static Extract original_extract=nullptr;
static Import original_import=nullptr;
static Delete original_delete=nullptr;
struct Patch {void** slot;void* original;void* replacement;};
static std::vector<Patch> patches;
static bool installed=false;
static fs::path report_path;

// Bounded fixed allocation; only slow-path shader/cache operations are logged.
// Allocation and file output do not happen inside these hooked operations.
struct Event {uint64_t began_us;uint64_t elapsed_us;uint32_t kind;uint32_t tid;uint32_t program;int32_t bytes;};
static constexpr uint32_t MAX_EVENTS=32768;
static Event events[MAX_EVENTS]{};
static std::atomic<uint32_t> event_count{0};
static uint64_t utc_base_us=0,qpc_base_us=0;
static void record(uint32_t kind,GLuint program,int32_t bytes,uint64_t start){
 uint64_t end=us();uint32_t slot=event_count.fetch_add(1,std::memory_order_relaxed);
 if(slot>=MAX_EVENTS)return;
 events[slot]={utc_base_us+(start-qpc_base_us),end-start,kind,GetCurrentThreadId(),program,bytes};
}
static void APIENTRY query(GLuint program,GLenum field,GLint* value){
 if(field!=0x8741){original_query(program,field,value);return;} // GL_PROGRAM_BINARY_LENGTH
 auto start=us();original_query(program,field,value);record(1,program,value?*value:-1,start);
}
static void APIENTRY extract(GLuint program,GLsizei size,GLsizei* written,GLenum* format,void* binary){
 auto start=us();original_extract(program,size,written,format,binary);record(2,program,written?*written:size,start);
}
static void APIENTRY import_binary(GLuint program,GLenum format,const void* binary,GLsizei size){
 auto start=us();original_import(program,format,binary,size);record(3,program,size,start);
}
static void APIENTRY delete_program(GLuint program){auto start=us();original_delete(program);record(4,program,0,start);}
static std::vector<void**> slots(void* address){
 auto base=reinterpret_cast<unsigned char*>(GetModuleHandle(nullptr));
 auto dos=reinterpret_cast<IMAGE_DOS_HEADER*>(base);auto nt=reinterpret_cast<IMAGE_NT_HEADERS*>(base+dos->e_lfanew);
 auto section=IMAGE_FIRST_SECTION(nt);std::vector<void**> found;
 for(int i=0;i<nt->FileHeader.NumberOfSections;i++){
  if(!(section[i].Characteristics&IMAGE_SCN_MEM_WRITE))continue;
  auto begin=base+section[i].VirtualAddress;auto size=section[i].Misc.VirtualSize;
  for(size_t at=0;at+sizeof(void*)<=size;at+=sizeof(void*)){
   auto slot=reinterpret_cast<void**>(begin+at);if(*slot==address)found.push_back(slot);
  }
 }
 return found;
}
template<class T>static void prepare_patch(const char* name,T replacement,T& original){
 original=gl<T>(name);auto found=slots(reinterpret_cast<void*>(original));
 if(found.empty()||found.size()>8)throw std::runtime_error(std::string("unexpected GL dispatch slots: ")+name);
 for(auto slot:found)patches.push_back({slot,*slot,reinterpret_cast<void*>(replacement)});
}
static void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 try{
  auto path=std::getenv("BMT_CACHE_TRACE_REPORT");if(!path)throw std::runtime_error("missing private report path");report_path=path;
  FILETIME now;GetSystemTimePreciseAsFileTime(&now);
  utc_base_us=(((uint64_t(now.dwHighDateTime)<<32)|now.dwLowDateTime)-116444736000000000ULL)/10;
  qpc_base_us=us();
  prepare_patch("glGetProgramiv",query,original_query);prepare_patch("glGetProgramBinary",extract,original_extract);
  prepare_patch("glProgramBinary",import_binary,original_import);prepare_patch("glDeleteProgram",delete_program,original_delete);
  for(auto& patch:patches)*patch.slot=patch.replacement;
  installed=true;std::printf("CACHE_TRACE_READY slots=%zu max_events=%u\n",patches.size(),MAX_EVENTS);std::fflush(stdout);
 }catch(const std::exception& e){std::fprintf(stderr,"CACHE_TRACE_INIT_FAILED %s\n",e.what());std::fflush(stderr);}
}
static void deinitialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 if(installed)for(auto& patch:patches)if(*patch.slot==patch.replacement)*patch.slot=patch.original;
 uint32_t count=event_count.load(std::memory_order_relaxed),used=std::min(count,MAX_EVENTS);
 std::string result="{\"schema\":1,\"installed\":"+std::string(installed?"true":"false")+",\"pid\":"+std::to_string(GetCurrentProcessId())+",\"events_total\":"+std::to_string(count)+",\"events_dropped\":"+std::to_string(count-used)+",\"events\":[";
 for(uint32_t i=0;i<used;i++){
  auto& e=events[i];if(i)result+=",";
  result+="["+std::to_string(e.kind)+","+std::to_string(e.tid)+","+std::to_string(e.program)+","+std::to_string(e.bytes)+","+std::to_string(e.began_us)+","+std::to_string(e.elapsed_us)+"]";
 }
 result+="]}";
 try{if(!report_path.empty())atomic(report_path,Bytes(result.begin(),result.end()));}
 catch(const std::exception& e){std::fprintf(stderr,"CACHE_TRACE_WRITE_FAILED %s\n",e.what());}
 std::printf("CACHE_TRACE_RESULT installed=%d events=%u dropped=%u\n",installed,count,count-used);std::fflush(stdout);
}
extern "C" __declspec(dllexport) GDExtensionBool cache_trace_init(GDExtensionInterfaceGetProcAddress,GDExtensionClassLibraryPtr,GDExtensionInitialization* init){
 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->userdata=nullptr;init->initialize=initialize;init->deinitialize=deinitialize;return 1;
}
