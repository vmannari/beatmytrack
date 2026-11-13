#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <GL/gl.h>
#include <atomic>
#include <chrono>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>
#include <vector>
using Clock=std::chrono::steady_clock;
static long long micros(Clock::time_point t){return std::chrono::duration_cast<std::chrono::microseconds>(Clock::now()-t).count();}
template<class T> T entry(const char* name){auto p=reinterpret_cast<T>(wglGetProcAddress(name));if(!p){std::cerr<<"Missing "<<name<<"\n";std::exit(4);}return p;}
using CreateContext=HGLRC(WINAPI*)(HDC,HGLRC,const int*);
using CreateShader=GLuint(APIENTRY*)(GLenum);
using Source=void(APIENTRY*)(GLuint,GLsizei,const char* const*,const GLint*);
using ObjectCall=void(APIENTRY*)(GLuint);
using Query=void(APIENTRY*)(GLuint,GLenum,GLint*);
using CreateProgram=GLuint(APIENTRY*)();
using Attach=void(APIENTRY*)(GLuint,GLuint);
using Log=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,char*);
using Hint=void(APIENTRY*)(GLuint);
static CreateShader create_shader;static Source source;static ObjectCall compile_shader,link_program;
static Query shader_iv,program_iv;static CreateProgram create_program;static Attach attach;static Log shader_log,program_log;
struct Row{std::string name;long long us;};
static std::vector<Row> rows;
template<class F> void timed(const char* name,F fn){auto t=Clock::now();fn();rows.push_back({name,micros(t)});}
static std::string read(const char* path){std::ifstream f(path,std::ios::binary);std::stringstream s;s<<f.rdbuf();return s.str();}
static bool status(GLuint obj,bool program){GLint ok=0;(program?program_iv:shader_iv)(obj,program?0x8B82:0x8B81,&ok);if(!ok){char log[4096]{};(program?program_log:shader_log)(obj,sizeof(log),nullptr,log);std::cerr<<log<<"\n";}return ok!=0;}
struct Result{GLuint program=0;bool ok=false;int polls=0;long long poll_max_us=0;};
static Result build(const std::string& vertex,const std::string& fragment,bool deferred){
 Result r;GLuint shaders[2]={create_shader(0x8B31),create_shader(0x8B30)};const char* texts[]={vertex.c_str(),fragment.c_str()};
 for(int i=0;i<2;i++){source(shaders[i],1,&texts[i],nullptr);timed(i?"fragment_compile":"vertex_compile",[&]{compile_shader(shaders[i]);});if(!deferred){bool ok=false;timed(i?"fragment_status":"vertex_status",[&]{ok=status(shaders[i],false);});if(!ok)return r;}}
 r.program=create_program();attach(r.program,shaders[0]);attach(r.program,shaders[1]);timed("link",[&]{link_program(r.program);});
 if(deferred){auto deadline=Clock::now()+std::chrono::seconds(60);GLint done=0;while(!done&&Clock::now()<deadline){auto t=Clock::now();program_iv(r.program,0x91B1,&done);r.poll_max_us=std::max(r.poll_max_us,micros(t));r.polls++;if(!done)std::this_thread::sleep_for(std::chrono::milliseconds(16));}if(!done)return r;}
 timed("link_status",[&]{r.ok=status(r.program,true);});if(deferred){timed("vertex_status",[&]{r.ok=status(shaders[0],false)&&r.ok;});timed("fragment_status",[&]{r.ok=status(shaders[1],false)&&r.ok;});}timed("flush",[]{glFlush();});return r;
}
int main(int argc,char** argv){
 if(argc!=4)return 2;std::string mode=argv[1],vertex=read(argv[2]),fragment=read(argv[3]);if(vertex.empty()||fragment.empty())return 3;
 WNDCLASSA cls{};cls.lpfnWndProc=DefWindowProcA;cls.hInstance=GetModuleHandle(nullptr);cls.lpszClassName="OwnedShaderOrderBench";RegisterClassA(&cls);
 HWND window=CreateWindowExA(0,cls.lpszClassName,"",WS_POPUP,0,0,16,16,nullptr,nullptr,cls.hInstance,nullptr);HDC dc=GetDC(window);PIXELFORMATDESCRIPTOR p{};p.nSize=sizeof(p);p.nVersion=1;p.dwFlags=PFD_SUPPORT_OPENGL|PFD_DRAW_TO_WINDOW|PFD_DOUBLEBUFFER;p.iPixelType=PFD_TYPE_RGBA;p.cColorBits=24;
 if(!SetPixelFormat(dc,ChoosePixelFormat(dc,&p),&p))return 4;HGLRC context=wglCreateContext(dc);if(!context||!wglMakeCurrent(dc,context))return 5;
 auto create=entry<CreateContext>("wglCreateContextAttribsARB");int attributes[]={0x2091,3,0x2092,3,0x9126,1,0};auto core=create(dc,nullptr,attributes);if(!core)return 6;wglMakeCurrent(dc,core);wglDeleteContext(context);context=core;
 create_shader=entry<CreateShader>("glCreateShader");source=entry<Source>("glShaderSource");compile_shader=entry<ObjectCall>("glCompileShader");shader_iv=entry<Query>("glGetShaderiv");create_program=entry<CreateProgram>("glCreateProgram");attach=entry<Attach>("glAttachShader");link_program=entry<ObjectCall>("glLinkProgram");program_iv=entry<Query>("glGetProgramiv");shader_log=entry<Log>("glGetShaderInfoLog");program_log=entry<Log>("glGetProgramInfoLog");
 auto hint=entry<Hint>("glMaxShaderCompilerThreadsKHR");GLint initial_hint=0;glGetIntegerv(0x91B0,&initial_hint);hint(2);
 glClear(GL_COLOR_BUFFER_BIT);SwapBuffers(dc);glFinish();
 auto began=Clock::now();Result result;int heartbeats=0;long long heartbeat_max_us=0,heartbeat_interval_max_us=0;bool shared_status=false;
 if(mode=="shared"){
  HWND worker_window=CreateWindowExA(0,cls.lpszClassName,"",WS_POPUP,0,0,16,16,nullptr,nullptr,cls.hInstance,nullptr);HDC worker_dc=GetDC(worker_window);if(!SetPixelFormat(worker_dc,GetPixelFormat(dc),&p))return 7;
  HGLRC worker_context=create(worker_dc,context,attributes);if(!worker_context)return 7;std::atomic<bool> done{false};
  std::thread worker([&]{if(!wglMakeCurrent(worker_dc,worker_context))std::exit(8);hint(2);result=build(vertex,fragment,false);wglMakeCurrent(nullptr,nullptr);done.store(true,std::memory_order_release);});
  auto previous=Clock::now();while(!done.load(std::memory_order_acquire)){auto t=Clock::now();heartbeat_interval_max_us=std::max(heartbeat_interval_max_us,std::chrono::duration_cast<std::chrono::microseconds>(t-previous).count());previous=t;glClearColor(0,0.1f,0.2f,1);glClear(GL_COLOR_BUFFER_BIT);SwapBuffers(dc);heartbeat_max_us=std::max(heartbeat_max_us,micros(t));heartbeats++;std::this_thread::sleep_for(std::chrono::milliseconds(16));}
  worker.join();shared_status=status(result.program,true);wglDeleteContext(worker_context);ReleaseDC(worker_window,worker_dc);DestroyWindow(worker_window);
 }else result=build(vertex,fragment,mode=="deferred");
 auto total=micros(began);std::cout<<"{\"mode\":\""<<mode<<"\",\"initial_threads_hint\":"<<static_cast<unsigned int>(initial_hint)<<",\"threads_hint\":2,\"success\":"<<(result.ok?"true":"false")<<",\"shared_program_valid\":"<<(shared_status?"true":"false")<<",\"total_us\":"<<total<<",\"polls\":"<<result.polls<<",\"poll_max_us\":"<<result.poll_max_us<<",\"main_heartbeats\":"<<heartbeats<<",\"main_gl_max_us\":"<<heartbeat_max_us<<",\"main_interval_max_us\":"<<heartbeat_interval_max_us<<",\"operations\":[";
 for(size_t i=0;i<rows.size();i++)std::cout<<(i?",":"")<<"{\"name\":\""<<rows[i].name<<"\",\"us\":"<<rows[i].us<<"}";std::cout<<"]}\n";
 wglMakeCurrent(nullptr,nullptr);wglDeleteContext(context);ReleaseDC(window,dc);DestroyWindow(window);return result.ok?0:9;
}
