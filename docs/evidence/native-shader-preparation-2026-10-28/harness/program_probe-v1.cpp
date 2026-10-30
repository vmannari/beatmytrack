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
static std::map<GLuint,Job> link_state;static std::set<GLuint> skipped;
static fs::path jobs_dir,binaries_dir,report_path;static std::string identity,mode;
static int captures=0,imports=0,misses=0,failures=0,skipped_compiles=0;
static uint64_t max_import=0,max_link=0;static bool installed=false;
struct Patch{void** slot;void* original;void* replacement;};static std::vector<Patch> patches;

static Job job_for(GLuint program){
 Job job=link_state[program];job.driver=identity;
 using Attached=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,GLuint*);using Source=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,char*);
 GLuint ids[8]{};GLsizei count=0;gl<Attached>("glGetAttachedShaders")(program,8,&count,ids);
 for(int i=0;i<count;i++){GLint size=0,type=0;original_shader_iv(ids[i],0x8B88,&size);original_shader_iv(ids[i],0x8B4F,&type);if(size<=0||size>int(MAX_JOB/2))throw std::runtime_error("stage size");std::vector<char> text(size);GLsizei used=0;gl<Source>("glGetShaderSource")(ids[i],size,&used,text.data());if(type==0x8B31)job.vertex.assign(text.data(),used);else if(type==0x8B30)job.fragment.assign(text.data(),used);else throw std::runtime_error("unexpected shader stage");}
 return job;
}
static void APIENTRY compile(GLuint shader){if(mode=="import"){skipped.insert(shader);skipped_compiles++;}else original_compile(shader);}
static void APIENTRY shader_iv(GLuint shader,GLenum field,GLint* value){if(mode=="import"&&field==0x8B81&&skipped.count(shader))*value=GL_TRUE;else original_shader_iv(shader,field,value);}
static void APIENTRY feedback(GLuint program,GLsizei count,const char* const* names,GLenum packing){auto& job=link_state[program];job.feedback_mode=packing;job.feedback.clear();for(int i=0;i<count;i++)job.feedback.emplace_back(names[i]);original_feedback(program,count,names,packing);}
static void binding(std::vector<Binding>& bindings,GLuint index,const char* name){auto found=std::find_if(bindings.begin(),bindings.end(),[&](auto& v){return v.name==name;});if(found==bindings.end())bindings.push_back({index,name});else found->index=index;}
static void APIENTRY attribute(GLuint program,GLuint index,const char* name){binding(link_state[program].attributes,index,name);original_attribute(program,index,name);}
static void APIENTRY output(GLuint program,GLuint index,const char* name){binding(link_state[program].outputs,index,name);original_output(program,index,name);}
static void APIENTRY delete_shader(GLuint shader){skipped.erase(shader);original_delete_shader(shader);}
static void APIENTRY delete_program(GLuint program){link_state.erase(program);original_delete_program(program);}
static void APIENTRY link(GLuint program){
 auto began=us();
 try{
  auto job=job_for(program);auto encoded=job.encode();auto key=sha(encoded);
  if(mode=="capture"){
   if(!fs::exists(jobs_dir/(key+".job"))){if(captures>=256)throw std::runtime_error("inventory bound");atomic(jobs_dir/(key+".job"),encoded);captures++;}
  }else{
   auto bytes=read(binaries_dir/(key+".bin"),MAX_BINARY+4096);GLenum format=0;auto binary=decode_binary(bytes,key,identity,format);
   using Binary=void(APIENTRY*)(GLuint,GLenum,const void*,GLsizei);auto t=us();gl<Binary>("glProgramBinary")(program,format,binary.data(),GLsizei(binary.size()));GLint ok=0;gl<Query>("glGetProgramiv")(program,0x8B82,&ok);max_import=std::max(max_import,us()-t);if(!ok)throw std::runtime_error("binary rejected");imports++;
   std::printf("PROGRAM_IMPORT key=%s bytes=%zu native_us=%llu all_us=%llu\n",key.c_str(),binary.size(),us()-t,us()-began);std::fflush(stdout);return;
  }
 }catch(const std::exception& error){failures++;if(mode=="import")misses++;std::fprintf(stderr,"PROGRAM_PROBE_FALLBACK %s\n",error.what());}
 // A miss is a failed prototype gate, never a different material. Finish the
 // original shader path so its final pixels can still be inspected.
 if(mode=="import"){
  using Attached=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,GLuint*);GLuint ids[8]{};GLsizei count=0;gl<Attached>("glGetAttachedShaders")(program,8,&count,ids);for(int i=0;i<count;i++)if(skipped.erase(ids[i]))original_compile(ids[i]);
 }
 original_link(program);max_link=std::max(max_link,us()-began);
}
static std::vector<void**> slots(void* address){
 auto base=reinterpret_cast<unsigned char*>(GetModuleHandle(nullptr));auto dos=reinterpret_cast<IMAGE_DOS_HEADER*>(base);auto nt=reinterpret_cast<IMAGE_NT_HEADERS*>(base+dos->e_lfanew);auto section=IMAGE_FIRST_SECTION(nt);std::vector<void**> found;
 for(int i=0;i<nt->FileHeader.NumberOfSections;i++){if(!(section[i].Characteristics&IMAGE_SCN_MEM_WRITE))continue;auto begin=base+section[i].VirtualAddress;auto size=section[i].Misc.VirtualSize;
  for(size_t at=0;at+sizeof(void*)<=size;at+=sizeof(void*)){auto slot=reinterpret_cast<void**>(begin+at);if(*slot==address)found.push_back(slot);}}
 return found;
}
template<class T>static void prepare_patch(const char* name,T replacement,T& original){
 original=gl<T>(name);auto found=slots(reinterpret_cast<void*>(original));if(found.empty()||found.size()>8)throw std::runtime_error(std::string("unexpected GLAD slots ")+name);
 for(auto slot:found)patches.push_back({slot,*slot,reinterpret_cast<void*>(replacement)});
 std::printf("PROGRAM_PROBE_SLOT %s count=%zu\n",name,found.size());
}
static void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 try{
  auto mode_env=std::getenv("BMT_PREP_MODE"),jobs_env=std::getenv("BMT_PREP_JOBS"),binary_env=std::getenv("BMT_PREP_BINARIES"),report_env=std::getenv("BMT_PREP_REPORT");
  if(!mode_env||!jobs_env||!binary_env||!report_env)throw std::runtime_error("missing diagnostic configuration");mode=mode_env;if(mode!="capture"&&mode!="import")throw std::runtime_error("diagnostic mode");jobs_dir=jobs_env;binaries_dir=binary_env;report_path=report_env;fs::create_directories(jobs_dir);identity=driver();
  prepare_patch("glCompileShader",compile,original_compile);prepare_patch("glGetShaderiv",shader_iv,original_shader_iv);prepare_patch("glLinkProgram",link,original_link);prepare_patch("glTransformFeedbackVaryings",feedback,original_feedback);prepare_patch("glBindAttribLocation",attribute,original_attribute);prepare_patch("glBindFragDataLocation",output,original_output);prepare_patch("glDeleteShader",delete_shader,original_delete_shader);prepare_patch("glDeleteProgram",delete_program,original_delete_program);
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
