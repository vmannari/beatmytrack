// Evidence-only interceptor in an SHA256-pinned, owned Godot test process.
// It is not an engine API and must never be loaded by the production project.
#include "shader_job.hpp"
#include "gdextension_interface.h"
#include <map>
#include <set>
using namespace prep;
using Obj=void(APIENTRY*)(GLuint);using Query=void(APIENTRY*)(GLuint,GLenum,GLint*);
using Feedback=void(APIENTRY*)(GLuint,GLsizei,const char* const*,GLenum);
using BindingCall=void(APIENTRY*)(GLuint,GLuint,const char*);
static Obj original_compile,original_link,original_delete_shader,original_delete_program;
static Query original_shader_iv;static Feedback original_feedback;static BindingCall original_attribute,original_output;
static Query original_program_iv;static Obj original_use;
using Location=GLint(APIENTRY*)(GLuint,const char*);static Location original_location;
using BufferData=void(APIENTRY*)(GLenum,intptr_t,const void*,GLenum);static BufferData original_buffer;
using TexImage=void(APIENTRY*)(GLenum,GLint,GLint,GLsizei,GLsizei,GLint,GLenum,GLenum,const void*);static TexImage original_image;
using DrawElements=void(APIENTRY*)(GLenum,GLsizei,GLenum,const void*);static DrawElements original_draw;
using DrawInstances=void(APIENTRY*)(GLenum,GLsizei,GLenum,const void*,GLsizei);static DrawInstances original_instances;
static std::map<GLuint,Job> link_state;static std::set<GLuint> skipped;
static fs::path jobs_dir,binaries_dir,report_path;static std::string identity,mode;
static int captures=0,imports=0,misses=0,failures=0,skipped_compiles=0;
static uint64_t max_import=0,max_link=0;static bool installed=false;
static std::set<std::string> seen;
static std::map<GLuint,std::string> program_keys;
static GLuint active_program=0;
struct Patch{void** slot;void* original;void* replacement;};static std::vector<Patch> patches;

static Job job_for(GLuint program){
 Job job=link_state[program];job.driver=identity;
 using Attached=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,GLuint*);using Source=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,char*);
 GLuint ids[8]{};GLsizei count=0;gl<Attached>("glGetAttachedShaders")(program,8,&count,ids);
 for(int i=0;i<count;i++){GLint size=0,type=0;original_shader_iv(ids[i],0x8B88,&size);original_shader_iv(ids[i],0x8B4F,&type);if(size<=0||size>int(MAX_JOB/2))throw std::runtime_error("stage size");std::vector<char> text(size);GLsizei used=0;gl<Source>("glGetShaderSource")(ids[i],size,&used,text.data());if(type==0x8B31)job.vertex.assign(text.data(),used);else if(type==0x8B30)job.fragment.assign(text.data(),used);else throw std::runtime_error("unexpected shader stage");}
 return job;
}
static void slow(const char* api,uint64_t began,GLuint program=0){auto duration=us()-began;if(duration<2000)return;FILETIME time;GetSystemTimePreciseAsFileTime(&time);auto utc=(((uint64_t(time.dwHighDateTime)<<32)|time.dwLowDateTime)-116444736000000000ULL)/10;auto found=program_keys.find(program);std::printf("NATIVE_CALL api=%s us=%llu utc_end_us=%llu program=%u key=%s\n",api,duration,utc,program,found==program_keys.end()?"-":found->second.c_str());std::fflush(stdout);}
static void APIENTRY compile(GLuint shader){if(mode=="import"){skipped.insert(shader);skipped_compiles++;}else{auto t=us();original_compile(shader);slow("glCompileShader",t);}}
static void APIENTRY shader_iv(GLuint shader,GLenum field,GLint* value){if(mode=="import"&&field==0x8B81&&skipped.count(shader))*value=GL_TRUE;else{auto t=us();original_shader_iv(shader,field,value);slow("glGetShaderiv",t);}}
static void APIENTRY program_iv(GLuint program,GLenum field,GLint* value){auto t=us();original_program_iv(program,field,value);slow("glGetProgramiv",t);}
static void APIENTRY use(GLuint program){active_program=program;auto t=us();original_use(program);slow("glUseProgram",t,program);}
static GLint APIENTRY location(GLuint program,const char* name){auto t=us();auto value=original_location(program,name);slow("glGetUniformLocation",t);return value;}
static void APIENTRY buffer(GLenum target,intptr_t size,const void* data,GLenum usage){auto t=us();original_buffer(target,size,data,usage);slow("glBufferData",t);}
static void APIENTRY image(GLenum target,GLint level,GLint format,GLsizei width,GLsizei height,GLint border,GLenum input_format,GLenum type,const void* data){auto t=us();original_image(target,level,format,width,height,border,input_format,type,data);slow("glTexImage2D",t);}
static void APIENTRY draw(GLenum mode,GLsizei count,GLenum type,const void* indices){auto t=us();original_draw(mode,count,type,indices);slow("glDrawElements",t,active_program);}
static void APIENTRY instances(GLenum mode,GLsizei count,GLenum type,const void* indices,GLsizei instances){auto t=us();original_instances(mode,count,type,indices,instances);slow("glDrawElementsInstanced",t,active_program);}
static void APIENTRY feedback(GLuint program,GLsizei count,const char* const* names,GLenum packing){auto& job=link_state[program];job.feedback_mode=packing;job.feedback.clear();for(int i=0;i<count;i++)job.feedback.emplace_back(names[i]);original_feedback(program,count,names,packing);}
static void binding(std::vector<Binding>& bindings,GLuint index,const char* name){auto found=std::find_if(bindings.begin(),bindings.end(),[&](auto& v){return v.name==name;});if(found==bindings.end())bindings.push_back({index,name});else found->index=index;}
static void APIENTRY attribute(GLuint program,GLuint index,const char* name){binding(link_state[program].attributes,index,name);original_attribute(program,index,name);}
static void APIENTRY output(GLuint program,GLuint index,const char* name){binding(link_state[program].outputs,index,name);original_output(program,index,name);}
static void APIENTRY delete_shader(GLuint shader){skipped.erase(shader);original_delete_shader(shader);}
static void APIENTRY delete_program(GLuint program){link_state.erase(program);program_keys.erase(program);original_delete_program(program);}
static void APIENTRY link(GLuint program){
 auto began=us();
 if(mode=="trace"){original_link(program);slow("glLinkProgram",began);return;}
 try{
  auto job=job_for(program);auto encoded=job.encode();auto key=sha(encoded);program_keys[program]=key;
  if(mode=="capture"){
   if(seen.insert(key).second){if(captures>=512)throw std::runtime_error("inventory bound");if(!fs::exists(jobs_dir/(key+".job")))atomic(jobs_dir/(key+".job"),encoded);captures++;}
   std::printf("NATIVE_PROGRAM program=%u key=%s vertex_bytes=%zu fragment_bytes=%zu\n",program,key.c_str(),job.vertex.size(),job.fragment.size());std::fflush(stdout);
  }else{
   auto bytes=read(binaries_dir/(key+".bin"),MAX_BINARY+4096);GLenum format=0;auto binary=decode_binary(bytes,key,identity,format);
   using Binary=void(APIENTRY*)(GLuint,GLenum,const void*,GLsizei);auto t=us();gl<Binary>("glProgramBinary")(program,format,binary.data(),GLsizei(binary.size()));GLint ok=0;gl<Query>("glGetProgramiv")(program,0x8B82,&ok);max_import=std::max(max_import,us()-t);if(!ok){if(misses<3){using Log=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,char*);char info[2048]{};gl<Log>("glGetProgramInfoLog")(program,sizeof(info),nullptr,info);std::fprintf(stderr,"PROGRAM_BINARY_REJECT format=%u error=%u detail=%s\n",format,glGetError(),info);}throw std::runtime_error("binary rejected");}imports++;
   std::printf("PROGRAM_IMPORT key=%s bytes=%zu native_us=%llu all_us=%llu\n",key.c_str(),binary.size(),us()-t,us()-began);std::fflush(stdout);return;
  }
 }catch(const std::exception& error){failures++;if(mode=="import")misses++;std::fprintf(stderr,"PROGRAM_PROBE_FALLBACK %s\n",error.what());}
 // A miss is a failed prototype gate, never a different material. Finish the
 // original shader path so its final pixels can still be inspected.
 if(mode=="import"){
  using Attached=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,GLuint*);GLuint ids[8]{};GLsizei count=0;gl<Attached>("glGetAttachedShaders")(program,8,&count,ids);for(int i=0;i<count;i++)if(skipped.erase(ids[i]))original_compile(ids[i]);
 }
 auto native_began=us();original_link(program);slow("glLinkProgram",native_began,program);max_link=std::max(max_link,us()-began);
}
static std::vector<void**> slots(void* address){
 auto base=reinterpret_cast<unsigned char*>(GetModuleHandle(nullptr));auto dos=reinterpret_cast<IMAGE_DOS_HEADER*>(base);auto nt=reinterpret_cast<IMAGE_NT_HEADERS*>(base+dos->e_lfanew);auto section=IMAGE_FIRST_SECTION(nt);std::vector<void**> found;
 for(int i=0;i<nt->FileHeader.NumberOfSections;i++){if(!(section[i].Characteristics&IMAGE_SCN_MEM_WRITE))continue;auto begin=base+section[i].VirtualAddress;auto size=section[i].Misc.VirtualSize;
  for(size_t at=0;at+sizeof(void*)<=size;at+=sizeof(void*)){auto slot=reinterpret_cast<void**>(begin+at);if(*slot==address)found.push_back(slot);}}
 return found;
}
template<class T>static void prepare_patch(const char* name,T replacement,T& original,bool required=true){
 original=gl<T>(name);auto found=slots(reinterpret_cast<void*>(original));if(found.empty()&&!required){std::printf("PROGRAM_PROBE_SLOT %s unavailable\n",name);return;}if(found.empty()||found.size()>8)throw std::runtime_error(std::string("unexpected GLAD slots ")+name);
 for(auto slot:found)patches.push_back({slot,*slot,reinterpret_cast<void*>(replacement)});
 std::printf("PROGRAM_PROBE_SLOT %s count=%zu\n",name,found.size());
}
static void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 try{
  auto mode_env=std::getenv("BMT_PREP_MODE"),jobs_env=std::getenv("BMT_PREP_JOBS"),binary_env=std::getenv("BMT_PREP_BINARIES"),report_env=std::getenv("BMT_PREP_REPORT");
  if(!mode_env||!jobs_env||!binary_env||!report_env)throw std::runtime_error("missing diagnostic configuration");mode=mode_env;if(mode!="capture"&&mode!="import"&&mode!="trace")throw std::runtime_error("diagnostic mode");jobs_dir=jobs_env;binaries_dir=binary_env;report_path=report_env;fs::create_directories(jobs_dir);identity=driver();
  GLint profile=0,flags=0;glGetIntegerv(0x9126,&profile);glGetIntegerv(0x821E,&flags);std::printf("PROGRAM_PROBE_CONTEXT profile=%d flags=%d\n",profile,flags);
  prepare_patch("glCompileShader",compile,original_compile);prepare_patch("glGetShaderiv",shader_iv,original_shader_iv);prepare_patch("glLinkProgram",link,original_link);prepare_patch("glTransformFeedbackVaryings",feedback,original_feedback);prepare_patch("glBindAttribLocation",attribute,original_attribute);prepare_patch("glBindFragDataLocation",output,original_output);prepare_patch("glDeleteShader",delete_shader,original_delete_shader);prepare_patch("glDeleteProgram",delete_program,original_delete_program);
  prepare_patch("glGetProgramiv",program_iv,original_program_iv);prepare_patch("glUseProgram",use,original_use);prepare_patch("glGetUniformLocation",location,original_location);prepare_patch("glBufferData",buffer,original_buffer);prepare_patch("glTexImage2D",image,original_image,false);prepare_patch("glDrawElements",draw,original_draw,false);prepare_patch("glDrawElementsInstanced",instances,original_instances);
  for(auto& patch:patches)*patch.slot=patch.replacement;installed=true;std::printf("PROGRAM_PROBE_READY mode=%s\n",mode.c_str());std::fflush(stdout);
 }catch(const std::exception& e){failures++;std::fprintf(stderr,"PROGRAM_PROBE_INIT_FAILED %s\n",e.what());}
}
static void deinitialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 if(installed)for(auto& patch:patches)if(*patch.slot==patch.replacement)*patch.slot=patch.original;
 std::string report="{\"installed\":"+std::string(installed?"true":"false")+",\"captures\":"+std::to_string(captures)+",\"imports\":"+std::to_string(imports)+",\"misses\":"+std::to_string(misses)+",\"failures\":"+std::to_string(failures)+",\"skipped_compiles\":"+std::to_string(skipped_compiles)+",\"max_import_us\":"+std::to_string(max_import)+",\"max_original_link_us\":"+std::to_string(max_link)+","+memory()+"}";
 try{if(!report_path.empty())atomic(report_path,Bytes(report.begin(),report.end()));}catch(...){}std::printf("PROGRAM_PROBE_RESULT %s\n",report.c_str());std::fflush(stdout);
}
extern "C" __declspec(dllexport) GDExtensionBool program_probe_init(GDExtensionInterfaceGetProcAddress,GDExtensionClassLibraryPtr,GDExtensionInitialization* init){init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->userdata=nullptr;init->initialize=initialize;init->deinitialize=deinitialize;return 1;}
