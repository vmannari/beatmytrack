#pragma once
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>
#include <psapi.h>
#include <GL/gl.h>
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace prep {
namespace fs=std::filesystem;
using Bytes=std::vector<unsigned char>;
constexpr size_t MAX_JOB=4*1024*1024,MAX_BINARY=8*1024*1024;
inline uint64_t us(){LARGE_INTEGER value,frequency;QueryPerformanceCounter(&value);QueryPerformanceFrequency(&frequency);return uint64_t(value.QuadPart)*1000000/uint64_t(frequency.QuadPart);}
inline std::string sha(const Bytes& data){
 BCRYPT_ALG_HANDLE algorithm=nullptr;BCRYPT_HASH_HANDLE hash=nullptr;
 if(BCryptOpenAlgorithmProvider(&algorithm,BCRYPT_SHA256_ALGORITHM,nullptr,0)<0)throw std::runtime_error("SHA256 provider");
 unsigned char digest[32]{};
 bool ok=BCryptCreateHash(algorithm,&hash,nullptr,0,nullptr,0,0)>=0&&BCryptHashData(hash,const_cast<PUCHAR>(data.data()),ULONG(data.size()),0)>=0&&BCryptFinishHash(hash,digest,32,0)>=0;
 if(hash)BCryptDestroyHash(hash);BCryptCloseAlgorithmProvider(algorithm,0);if(!ok)throw std::runtime_error("SHA256 hash");
 std::string text;for(auto byte:digest){char pair[3];std::snprintf(pair,3,"%02x",byte);text+=pair;}return text;
}
inline Bytes read(const fs::path& path,size_t max){
 auto size=fs::file_size(path);if(size>max)throw std::runtime_error("file exceeds bound");
 Bytes bytes(size);std::ifstream file(path,std::ios::binary);if(size&&!file.read(reinterpret_cast<char*>(bytes.data()),size))throw std::runtime_error("file read");return bytes;
}
inline void atomic(const fs::path& path,const Bytes& bytes){
 auto temp=path;temp+=".tmp";std::ofstream file(temp,std::ios::binary|std::ios::trunc);file.write(reinterpret_cast<const char*>(bytes.data()),bytes.size());file.close();if(!file)throw std::runtime_error("file write");
 if(!MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH))throw std::runtime_error("atomic publish");
}
inline void put(Bytes& b,uint32_t n){for(int i=0;i<4;i++)b.push_back((n>>(i*8))&255);}
inline void put(Bytes& b,const std::string& s){put(b,uint32_t(s.size()));b.insert(b.end(),s.begin(),s.end());}
struct Reader {
 const Bytes& b;size_t at=0;
 uint32_t number(){if(at+4>b.size())throw std::runtime_error("truncated header");uint32_t n=0;for(int i=0;i<4;i++)n|=uint32_t(b[at++])<<(i*8);return n;}
 std::string string(){auto n=number();if(n>MAX_JOB||n>b.size()-at)throw std::runtime_error("truncated string");std::string s(reinterpret_cast<const char*>(b.data()+at),n);at+=n;return s;}
};
struct Binding {GLuint index;std::string name;};
struct Job {
 std::string driver,vertex,fragment;GLenum feedback_mode=0x8C8C;
 std::vector<std::string> feedback;std::vector<Binding> attributes,outputs;
 Bytes encode()const{
  Bytes b;put(b,0x314A5342);put(b,driver);put(b,vertex);put(b,fragment);put(b,feedback_mode);put(b,uint32_t(feedback.size()));for(auto&s:feedback)put(b,s);
  for(auto* list:{&attributes,&outputs}){put(b,uint32_t(list->size()));for(auto&v:*list){put(b,v.index);put(b,v.name);}}
  if(b.size()>MAX_JOB)throw std::runtime_error("source job exceeds bound");return b;
 }
 static Job decode(const Bytes& b){
  Reader r{b};if(r.number()!=0x314A5342)throw std::runtime_error("job magic");Job job;job.driver=r.string();job.vertex=r.string();job.fragment=r.string();job.feedback_mode=r.number();
  auto count=r.number();if(count>64)throw std::runtime_error("feedback count");while(count--)job.feedback.push_back(r.string());
  for(auto* list:{&job.attributes,&job.outputs}){count=r.number();if(count>64)throw std::runtime_error("binding count");while(count--){auto index=r.number();list->push_back({index,r.string()});}}
  if(r.at!=b.size()||job.vertex.empty())throw std::runtime_error("job body");return job;
 }
};
inline Bytes encode_binary(const std::string& key,const std::string& driver,GLenum format,const Bytes& binary){
 Bytes b;put(b,0x31425342);put(b,key);put(b,driver);put(b,format);put(b,sha(binary));put(b,uint32_t(binary.size()));b.insert(b.end(),binary.begin(),binary.end());return b;
}
inline Bytes decode_binary(const Bytes& b,const std::string& key,const std::string& driver,GLenum& format){
 Reader r{b};if(r.number()!=0x31425342||r.string()!=key||r.string()!=driver)throw std::runtime_error("binary identity");format=r.number();auto expected=r.string();auto n=r.number();
 if(n>MAX_BINARY||n!=b.size()-r.at)throw std::runtime_error("binary length");Bytes data(b.begin()+r.at,b.end());if(sha(data)!=expected)throw std::runtime_error("binary checksum");return data;
}
inline std::string driver(){std::string s;for(auto name:{GL_VENDOR,GL_RENDERER,GL_VERSION,0x8B8C}){auto value=glGetString(name);if(!value)throw std::runtime_error("GL identity");s+=reinterpret_cast<const char*>(value);s+='\n';}GLint profile=0,flags=0;glGetIntegerv(0x9126,&profile);glGetIntegerv(0x821E,&flags);s+="context_profile="+std::to_string(profile)+";context_flags="+std::to_string(flags)+"\n";return s;}
template<class T>T gl(const char* name){auto address=wglGetProcAddress(name);if(!address||reinterpret_cast<uintptr_t>(address)<=3||reinterpret_cast<intptr_t>(address)==-1)address=GetProcAddress(GetModuleHandleW(L"opengl32.dll"),name);if(!address)throw std::runtime_error(name);return reinterpret_cast<T>(address);}
struct Context {
 HWND window=nullptr;HDC dc=nullptr;HGLRC context=nullptr;
 Context(){
  WNDCLASSW cls{};cls.lpfnWndProc=DefWindowProcW;cls.hInstance=GetModuleHandle(nullptr);cls.lpszClassName=L"OwnedShaderPreparationWorker";RegisterClassW(&cls);
  window=CreateWindowExW(0,cls.lpszClassName,L"",WS_POPUP,0,0,16,16,nullptr,nullptr,cls.hInstance,nullptr);dc=GetDC(window);PIXELFORMATDESCRIPTOR p{};p.nSize=sizeof(p);p.nVersion=1;p.dwFlags=PFD_DRAW_TO_WINDOW|PFD_SUPPORT_OPENGL|PFD_DOUBLEBUFFER;p.iPixelType=PFD_TYPE_RGBA;p.cColorBits=24;
  if(!SetPixelFormat(dc,ChoosePixelFormat(dc,&p),&p))throw std::runtime_error("pixel format");context=wglCreateContext(dc);if(!context||!wglMakeCurrent(dc,context))throw std::runtime_error("legacy context");
  // Match this pinned Godot's core, forward-compatible context. This is part
  // of the program-binary identity, not implied by the GL version string.
  using Create=HGLRC(WINAPI*)(HDC,HGLRC,const int*);int attributes[]={0x2091,3,0x2092,3,0x9126,1,0x2094,2,0};auto core=gl<Create>("wglCreateContextAttribsARB")(dc,nullptr,attributes);if(!core)throw std::runtime_error("core context");wglMakeCurrent(dc,core);wglDeleteContext(context);context=core;
 }
 ~Context(){wglMakeCurrent(nullptr,nullptr);if(context)wglDeleteContext(context);if(dc)ReleaseDC(window,dc);if(window)DestroyWindow(window);}
};
inline std::string memory(){PROCESS_MEMORY_COUNTERS_EX m{};m.cb=sizeof(m);if(!GetProcessMemoryInfo(GetCurrentProcess(),reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&m),sizeof(m)))throw std::runtime_error("process memory");
 return "\"private_bytes\":"+std::to_string(m.PrivateUsage)+",\"peak_commit_bytes\":"+std::to_string(m.PeakPagefileUsage)+",\"working_set_bytes\":"+std::to_string(m.WorkingSetSize)+",\"peak_working_set_bytes\":"+std::to_string(m.PeakWorkingSetSize);
}
}
