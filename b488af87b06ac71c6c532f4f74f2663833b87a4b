#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <GL/gl.h>
#include <iostream>
#include <string>
int main(){
    WNDCLASSA cls{};cls.lpfnWndProc=DefWindowProcA;cls.hInstance=GetModuleHandle(nullptr);cls.lpszClassName="OwnedColdRendererCaps";RegisterClassA(&cls);
    HWND window=CreateWindowExA(0,cls.lpszClassName,"",WS_POPUP,0,0,1,1,nullptr,nullptr,cls.hInstance,nullptr);
    HDC dc=GetDC(window);PIXELFORMATDESCRIPTOR p{};p.nSize=sizeof(p);p.nVersion=1;p.dwFlags=PFD_SUPPORT_OPENGL|PFD_DRAW_TO_WINDOW|PFD_DOUBLEBUFFER;p.iPixelType=PFD_TYPE_RGBA;p.cColorBits=24;
    if(!SetPixelFormat(dc,ChoosePixelFormat(dc,&p),&p))return 2;
    HGLRC context=wglCreateContext(dc);if(!context||!wglMakeCurrent(dc,context))return 3;
    using CreateContext=HGLRC(WINAPI*)(HDC,HGLRC,const int*);
    auto create=reinterpret_cast<CreateContext>(wglGetProcAddress("wglCreateContextAttribsARB"));
    if(create){int attributes[]={0x2091,3,0x2092,3,0x9126,1,0};auto core=create(dc,nullptr,attributes);if(core){wglMakeCurrent(dc,core);wglDeleteContext(context);context=core;}}
    using GetStringI=const GLubyte*(APIENTRY*)(GLenum,GLuint);auto get=reinterpret_cast<GetStringI>(wglGetProcAddress("glGetStringi"));
    GLint count=0;glGetIntegerv(0x821D,&count);bool arb=false,khr=false;
    for(int i=0;get&&i<count;i++){std::string name=reinterpret_cast<const char*>(get(GL_EXTENSIONS,i));arb|=name=="GL_ARB_parallel_shader_compile";khr|=name=="GL_KHR_parallel_shader_compile";}
    std::cout<<"{\"vendor\":\""<<glGetString(GL_VENDOR)<<"\",\"renderer\":\""<<glGetString(GL_RENDERER)<<"\",\"version\":\""<<glGetString(GL_VERSION)<<"\",\"ARB_parallel_shader_compile\":"<<(arb?"true":"false")<<",\"KHR_parallel_shader_compile\":"<<(khr?"true":"false")<<",\"ARB_entrypoint\":"<<(wglGetProcAddress("glMaxShaderCompilerThreadsARB")?"true":"false")<<",\"KHR_entrypoint\":"<<(wglGetProcAddress("glMaxShaderCompilerThreadsKHR")?"true":"false")<<"}\n";
    wglMakeCurrent(nullptr,nullptr);wglDeleteContext(context);ReleaseDC(window,dc);DestroyWindow(window);return 0;
}
