#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <GL/gl.h>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <string>
#include <vector>
#include "gdextension_interface.h"
using Link=void(APIENTRY*)(GLuint);
static Link original_link=nullptr;
static Link* link_storage=nullptr;
static bool captured=false;
static unsigned long long clock_us(){LARGE_INTEGER a,b;QueryPerformanceCounter(&a);QueryPerformanceFrequency(&b);return static_cast<unsigned long long>(a.QuadPart*1000000/b.QuadPart);}
static void APIENTRY trace_link(GLuint program){
 auto start=clock_us();original_link(program);auto duration=clock_us()-start;
 if(duration>50000){std::printf("GL_LINK_CALL program=%u us=%llu\n",program,duration);std::fflush(stdout);}
 if(captured||duration<200000)return;
 using Attached=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,GLuint*);
 using ShaderIV=void(APIENTRY*)(GLuint,GLenum,GLint*);
 using Source=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,char*);
 auto attached=reinterpret_cast<Attached>(wglGetProcAddress("glGetAttachedShaders"));auto shader_iv=reinterpret_cast<ShaderIV>(wglGetProcAddress("glGetShaderiv"));auto source=reinterpret_cast<Source>(wglGetProcAddress("glGetShaderSource"));
 if(!attached||!shader_iv||!source)return;
 GLuint shaders[4]{};GLsizei count=0;attached(program,4,&count,shaders);std::string vertex,fragment;
 for(int i=0;i<count;i++){GLint length=0,type=0;shader_iv(shaders[i],0x8B88,&length);shader_iv(shaders[i],0x8B4F,&type);if(length<=0||length>2097152)continue;std::vector<char> text(length);GLsizei used=0;source(shaders[i],length,&used,text.data());if(type==0x8B31)vertex.assign(text.data(),used);else if(type==0x8B30)fragment.assign(text.data(),used);}
 auto directory=std::getenv("BMT_DIAG_SHADER_DIR");
 if(!directory||vertex.empty()||fragment.find("roughness")==std::string::npos)return;
 std::ofstream(std::string(directory)+"/captured.vert",std::ios::binary).write(vertex.data(),vertex.size());
 std::ofstream(std::string(directory)+"/captured.frag",std::ios::binary).write(fragment.data(),fragment.size());
 captured=true;std::printf("GL_SOURCE_CAPTURE program=%u link_us=%llu vertex_bytes=%zu fragment_bytes=%zu\n",program,duration,vertex.size(),fragment.size());std::fflush(stdout);
}
static bool readable(const void* p){MEMORY_BASIC_INFORMATION m{};return p&&VirtualQuery(p,&m,sizeof(m))&&m.State==MEM_COMMIT&&!(m.Protect&(PAGE_NOACCESS|PAGE_GUARD));}
static void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 if(!wglGetCurrentContext()){std::puts("GL_NATIVE_PROBE no current GL context");return;}
 using Hint=void(APIENTRY*)(GLuint);
 auto hint=reinterpret_cast<Hint>(wglGetProcAddress("glMaxShaderCompilerThreadsKHR"));
 if(!hint)hint=reinterpret_cast<Hint>(wglGetProcAddress("glMaxShaderCompilerThreadsARB"));
 GLint before=0,after=0;glGetIntegerv(0x91B0,&before);
 auto mode=std::getenv("BMT_DIAG_NATIVE_MODE");bool trace=mode&&std::string(mode)=="trace_link";
 if(hint&&!trace)hint(2);
 glGetIntegerv(0x91B0,&after);
 // Read-only mapping for the exact SHA256-pinned test executable. The sampled
 // return address's preceding indirect call goes through this GLAD slot.
 auto base=reinterpret_cast<std::uintptr_t>(GetModuleHandle(nullptr));
 auto slot=reinterpret_cast<void***>(base+0x7e23a20);
 void* actual=nullptr;
 if(readable(slot)&&readable(*slot))actual=**slot;
 auto named=reinterpret_cast<void*>(wglGetProcAddress("glLinkProgram"));
 std::printf("GL_NATIVE_PROBE threads_before=%u threads_after=%u hint=%s link_slot_matches=%s\n",static_cast<unsigned int>(before),static_cast<unsigned int>(after),hint?"yes":"no",actual&&actual==named?"yes":"no");
 std::fflush(stdout);
 if(trace&&actual==named&&readable(*slot)){link_storage=reinterpret_cast<Link*>(*slot);original_link=*link_storage;*link_storage=trace_link;}
}
static void deinitialize(void*,GDExtensionInitializationLevel level){if(level==GDEXTENSION_INITIALIZATION_SCENE&&link_storage&&*link_storage==trace_link)*link_storage=original_link;}
extern "C" __declspec(dllexport) GDExtensionBool parallel_probe_init(GDExtensionInterfaceGetProcAddress,GDExtensionClassLibraryPtr,GDExtensionInitialization* init){
 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->userdata=nullptr;init->initialize=initialize;init->deinitialize=deinitialize;return 1;
}
