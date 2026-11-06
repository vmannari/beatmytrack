// Evidence only: exact pinned, owned process; capture and count, never skip work.
#include "shader_job.hpp"
#include "gdextension_interface.h"
#include <map>
#include <set>
using namespace prep;
using Obj=void(APIENTRY*)(GLuint);using Query=void(APIENTRY*)(GLuint,GLenum,GLint*);
using Feedback=void(APIENTRY*)(GLuint,GLsizei,const char* const*,GLenum);
using BindingCall=void(APIENTRY*)(GLuint,GLuint,const char*);
using Binary=void(APIENTRY*)(GLuint,GLenum,const void*,GLsizei);
using GetBinary=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,GLenum*,void*);
using DrawElements=void(APIENTRY*)(GLenum,GLsizei,GLenum,const void*);
using DrawInstances=void(APIENTRY*)(GLenum,GLsizei,GLenum,const void*,GLsizei);
using DrawArrays=void(APIENTRY*)(GLenum,GLint,GLsizei);
using ArrayInstances=void(APIENTRY*)(GLenum,GLint,GLsizei,GLsizei);
using DrawRange=void(APIENTRY*)(GLenum,GLuint,GLuint,GLsizei,GLenum,const void*);
static Obj original_link,original_use,original_delete;
static Query original_shader_iv,original_program_iv;
static Feedback original_feedback;static BindingCall original_attribute,original_output;
static Binary original_binary;
static GetBinary original_get_binary;
static std::map<std::string,std::string> binary_sources;
static DrawElements original_elements;static DrawInstances original_instances;
static DrawArrays original_arrays;static ArrayInstances original_array_instances;static DrawRange original_range;
struct Record{GLuint id;std::string key,kind;uint64_t link_us=0,status_us=0,linked_utc=0,first_draw=0,last_draw=0,binds=0,draws=0,arrays=0,elements=0,instanced=0;int status=-1;};
static std::vector<Record> records;
static std::map<GLuint,size_t> current;
static std::map<GLuint,Job> link_state;
static std::set<std::string> keys;
static size_t active=size_t(-1);static GLuint active_id=0;
static int failures=0,captures=0,links=0,binaries=0,context_mismatches=0;
static HGLRC context;static DWORD render_thread;static bool installed=false;
static fs::path jobs_dir,report_path;static std::string identity;
struct Patch{void** slot;void* original;void* replacement;};static std::vector<Patch> patches;
static uint64_t utc(){FILETIME t;GetSystemTimePreciseAsFileTime(&t);return (((uint64_t(t.dwHighDateTime)<<32)|t.dwLowDateTime)-116444736000000000ULL)/10;}
static bool same_context(){if(wglGetCurrentContext()==context&&GetCurrentThreadId()==render_thread)return true;context_mismatches++;return false;}
static size_t record(GLuint id,const std::string& key,const char* kind){
 if(records.size()>=8192)throw std::runtime_error("record bound");
 records.push_back(Record{id,key,kind});auto index=records.size()-1;current[id]=index;
 if(active_id==id)active=index;return index;
}
static Job job_for(GLuint program){
 Job job=link_state[program];job.driver=identity;
 using Attached=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,GLuint*);using Source=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,char*);
 GLuint ids[8]{};GLsizei count=0;gl<Attached>("glGetAttachedShaders")(program,8,&count,ids);
 for(int i=0;i<count;i++){GLint size=0,type=0;original_shader_iv(ids[i],0x8B88,&size);original_shader_iv(ids[i],0x8B4F,&type);if(size<=0||size>int(MAX_JOB/2))throw std::runtime_error("stage size");std::vector<char> text(size);GLsizei used=0;gl<Source>("glGetShaderSource")(ids[i],size,&used,text.data());if(type==0x8B31)job.vertex.assign(text.data(),used);else if(type==0x8B30)job.fragment.assign(text.data(),used);else throw std::runtime_error("unexpected stage");}
 return job;
}
static void APIENTRY link(GLuint id){
 size_t index=size_t(-1);
 try{if(!same_context())throw std::runtime_error("foreign context");auto job=job_for(id);auto encoded=job.encode();auto key=sha(encoded);
 if(keys.insert(key).second){if(captures>=4096)throw std::runtime_error("job bound");atomic(jobs_dir/(key+".job"),encoded);captures++;}
 index=record(id,key,"linked");links++;
 }catch(const std::exception& e){failures++;std::fprintf(stderr,"USAGE_CAPTURE_ERROR %s\n",e.what());}
 auto t=us();original_link(id);auto cost=us()-t;
 if(index!=size_t(-1)){records[index].link_us=cost;records[index].linked_utc=utc();}
}
static void APIENTRY binary(GLuint id,GLenum format,const void* bytes,GLsizei count){
 size_t index=size_t(-1);
 try{if(count<0||count>int(MAX_BINARY))throw std::runtime_error("binary bound");Bytes data;put(data,uint32_t(format));auto b=static_cast<const unsigned char*>(bytes);data.insert(data.end(),b,b+count);index=record(id,"binary-"+sha(data),"binary");binaries++;}catch(...){failures++;}
 auto t=us();original_binary(id,format,bytes,count);auto cost=us()-t;
 if(index!=size_t(-1)){records[index].link_us=cost;records[index].linked_utc=utc();}
}
static void APIENTRY get_binary(GLuint id,GLsizei capacity,GLsizei* length,GLenum* format,void* data){
 GLsizei written=0;original_get_binary(id,capacity,&written,format,data);if(length)*length=written;
 try{auto it=current.find(id);if(it==current.end()||written<=0)return;if(written>capacity||written>int(MAX_BINARY))throw std::runtime_error("export bound");
 Bytes encoded;put(encoded,uint32_t(*format));auto b=static_cast<unsigned char*>(data);encoded.insert(encoded.end(),b,b+written);
 auto key="binary-"+sha(encoded);auto source=records[it->second].key;if(source.rfind("binary-",0)!=0&&source.rfind("preexisting-",0)!=0)binary_sources[key]=source;
 }catch(...){failures++;}
}
static void APIENTRY query(GLuint id,GLenum field,GLint* value){auto t=us();original_program_iv(id,field,value);auto cost=us()-t;auto it=current.find(id);if(it!=current.end()&&field==0x8B82){records[it->second].status=*value;records[it->second].status_us+=cost;}}
static void APIENTRY use(GLuint id){
 original_use(id);active_id=id;active=size_t(-1);if(!id)return;
 if(!same_context())return;
 auto it=current.find(id);
 try{active=it==current.end()?record(id,"preexisting-"+std::to_string(id),"preexisting"):it->second;records[active].binds++;}catch(...){failures++;}
}
static void drawn(GLsizei count,GLsizei instances,bool array,bool instanced){
 if(count<=0||instances<=0)return;
 if(active==size_t(-1)){failures++;return;}
 auto& r=records[active];r.draws++;if(array)r.arrays++;else r.elements++;if(instanced)r.instanced++;
 auto now=utc();if(!r.first_draw)r.first_draw=now;r.last_draw=now;
}
static void APIENTRY elements(GLenum m,GLsizei n,GLenum t,const void* p){drawn(n,1,false,false);original_elements(m,n,t,p);}
static void APIENTRY instances(GLenum m,GLsizei n,GLenum t,const void* p,GLsizei i){drawn(n,i,false,true);original_instances(m,n,t,p,i);}
static void APIENTRY arrays(GLenum m,GLint first,GLsizei n){drawn(n,1,true,false);original_arrays(m,first,n);}
static void APIENTRY array_instances(GLenum m,GLint first,GLsizei n,GLsizei i){drawn(n,i,true,true);original_array_instances(m,first,n,i);}
static void APIENTRY range(GLenum m,GLuint start,GLuint end,GLsizei n,GLenum t,const void* p){drawn(n,1,false,false);original_range(m,start,end,n,t,p);}
static void APIENTRY feedback(GLuint id,GLsizei count,const char* const* names,GLenum packing){auto& j=link_state[id];j.feedback_mode=packing;j.feedback.clear();for(int i=0;i<count;i++)j.feedback.emplace_back(names[i]);original_feedback(id,count,names,packing);}
static void binding(std::vector<Binding>& bindings,GLuint index,const char* name){auto it=std::find_if(bindings.begin(),bindings.end(),[&](auto& v){return v.name==name;});if(it==bindings.end())bindings.push_back({index,name});else it->index=index;}
static void APIENTRY attribute(GLuint id,GLuint index,const char* name){binding(link_state[id].attributes,index,name);original_attribute(id,index,name);}
static void APIENTRY output(GLuint id,GLuint index,const char* name){binding(link_state[id].outputs,index,name);original_output(id,index,name);}
static void APIENTRY remove(GLuint id){current.erase(id);link_state.erase(id);original_delete(id);}
static std::vector<void**> slots(void* address){
 auto base=reinterpret_cast<unsigned char*>(GetModuleHandle(nullptr));auto dos=reinterpret_cast<IMAGE_DOS_HEADER*>(base);auto nt=reinterpret_cast<IMAGE_NT_HEADERS*>(base+dos->e_lfanew);auto section=IMAGE_FIRST_SECTION(nt);std::vector<void**> found;
 for(int i=0;i<nt->FileHeader.NumberOfSections;i++){if(!(section[i].Characteristics&IMAGE_SCN_MEM_WRITE))continue;auto begin=base+section[i].VirtualAddress;auto size=section[i].Misc.VirtualSize;for(size_t at=0;at+sizeof(void*)<=size;at+=sizeof(void*)){auto slot=reinterpret_cast<void**>(begin+at);if(*slot==address)found.push_back(slot);}}return found;
}
template<class T>static void patch(const char* name,T replacement,T& original,bool required=true){original=gl<T>(name);auto found=slots(reinterpret_cast<void*>(original));if((required&&found.empty())||found.size()>8)throw std::runtime_error(std::string("GLAD slots ")+name);for(auto slot:found)patches.push_back({slot,*slot,reinterpret_cast<void*>(replacement)});std::printf("USAGE_SLOT %s count=%zu\n",name,found.size());}
template<class T>static T through_slot(T replacement){for(auto& p:patches)if(p.replacement==reinterpret_cast<void*>(replacement))return reinterpret_cast<T>(*p.slot);throw std::runtime_error("control slot missing");}
static void controls(){
 using CreateShader=GLuint(APIENTRY*)(GLenum);using CreateProgram=GLuint(APIENTRY*)();using Source=void(APIENTRY*)(GLuint,GLsizei,const char* const*,const GLint*);using Attach=void(APIENTRY*)(GLuint,GLuint);
 using Generate=void(APIENTRY*)(GLsizei,GLuint*);using DeleteArray=void(APIENTRY*)(GLsizei,const GLuint*);
 GLint old_vao=0;glGetIntegerv(0x85B5,&old_vao);GLuint old_program=active_id,vao=0;
 auto discard=glIsEnabled(0x8C89);gl<Generate>("glGenVertexArrays")(1,&vao);gl<Obj>("glBindVertexArray")(vao);glEnable(0x8C89);
 for(int used=0;used<2;used++){
  std::string vs="#version 330\n// BMT_USAGE_CONTROL_"+std::to_string(used)+"\nvoid main(){gl_Position=vec4(0,0,0,1);gl_PointSize=1.;}";
  const char* sources[]={vs.c_str(),"#version 330\nout vec4 c;void main(){c=vec4(1);}"};GLuint shaders[2];
  auto id=gl<CreateProgram>("glCreateProgram")();
  for(int s=0;s<2;s++){shaders[s]=gl<CreateShader>("glCreateShader")(s?0x8B30:0x8B31);gl<Source>("glShaderSource")(shaders[s],1,&sources[s],nullptr);gl<Obj>("glCompileShader")(shaders[s]);gl<Attach>("glAttachShader")(id,shaders[s]);}
  through_slot(link)(id);GLint ok=0;through_slot(query)(id,0x8B82,&ok);if(!ok)throw std::runtime_error("control link failed");
  through_slot(use)(id);if(used)through_slot(arrays)(GL_POINTS,0,1);
  auto& r=records[current.at(id)];if(r.binds!=1||r.draws!=uint64_t(used))throw std::runtime_error("control count failed");
  through_slot(use)(0);through_slot<Obj>(remove)(id);for(auto s:shaders)gl<Obj>("glDeleteShader")(s);
 }
 gl<Obj>("glBindVertexArray")(GLuint(old_vao));gl<DeleteArray>("glDeleteVertexArrays")(1,&vao);if(!discard)glDisable(0x8C89);through_slot(use)(old_program);
 if(glGetError()!=GL_NO_ERROR)throw std::runtime_error("control GL error");std::puts("USAGE_CONTROLS unused_bound=1 used_fast_array=1 PASS");
}
static void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 try{auto jobs=std::getenv("BMT_PREP_JOBS"),report=std::getenv("BMT_PREP_REPORT");if(!jobs||!report)throw std::runtime_error("missing owned paths");jobs_dir=jobs;report_path=report;fs::create_directories(jobs_dir);identity=driver();context=wglGetCurrentContext();render_thread=GetCurrentThreadId();original_shader_iv=gl<Query>("glGetShaderiv");
 patch("glLinkProgram",link,original_link);patch("glProgramBinary",binary,original_binary);patch("glGetProgramBinary",get_binary,original_get_binary);patch("glGetProgramiv",query,original_program_iv);patch("glUseProgram",use,original_use);patch("glDeleteProgram",remove,original_delete);
 patch("glTransformFeedbackVaryings",feedback,original_feedback);patch("glBindAttribLocation",attribute,original_attribute);patch("glBindFragDataLocation",output,original_output);
 patch("glDrawElements",elements,original_elements);patch("glDrawElementsInstanced",instances,original_instances);patch("glDrawArrays",arrays,original_arrays);patch("glDrawArraysInstanced",array_instances,original_array_instances);patch("glDrawRangeElements",range,original_range,false);
 GLint bound=0;glGetIntegerv(0x8B8D,&bound);if(bound){active_id=GLuint(bound);active=record(active_id,"preexisting-"+std::to_string(active_id),"preexisting");}
 for(auto& p:patches)*p.slot=p.replacement;installed=true;controls();std::puts("USAGE_READY");std::fflush(stdout);
 }catch(const std::exception& e){failures++;std::fprintf(stderr,"USAGE_INIT_FAILED %s\n",e.what());}
}
static void deinitialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 if(installed)for(auto& p:patches)if(*p.slot==p.replacement)*p.slot=p.original;
 std::string out="{\"installed\":"+std::string(installed?"true":"false")+",\"failures\":"+std::to_string(failures)+",\"context_mismatches\":"+std::to_string(context_mismatches)+",\"unique_sources\":"+std::to_string(captures)+",\"links\":"+std::to_string(links)+",\"binary_imports\":"+std::to_string(binaries)+",\"records\":[";
 for(size_t i=0;i<records.size();i++){auto& r=records[i];if(i)out+=",";out+="{\"id\":"+std::to_string(r.id)+",\"key\":\""+r.key+"\",\"kind\":\""+r.kind+"\",\"link_us\":"+std::to_string(r.link_us)+",\"status_us\":"+std::to_string(r.status_us)+",\"status\":"+std::to_string(r.status)+",\"linked_utc\":"+std::to_string(r.linked_utc)+",\"first_draw_utc\":"+std::to_string(r.first_draw)+",\"last_draw_utc\":"+std::to_string(r.last_draw)+",\"binds\":"+std::to_string(r.binds)+",\"draws\":"+std::to_string(r.draws)+",\"arrays\":"+std::to_string(r.arrays)+",\"elements\":"+std::to_string(r.elements)+",\"instanced\":"+std::to_string(r.instanced)+"}";}
 out+="],\"binary_sources\":{";bool first=true;for(auto& pair:binary_sources){if(!first)out+=",";first=false;out+="\""+pair.first+"\":\""+pair.second+"\"";}out+="},"+memory()+"}";try{atomic(report_path,Bytes(out.begin(),out.end()));}catch(...){std::fputs("USAGE_REPORT_FAILED\n",stderr);}std::printf("USAGE_COMPLETE sources=%d links=%d binaries=%d failures=%d contexts=%d\n",captures,links,binaries,failures,context_mismatches);std::fflush(stdout);
}
extern "C" __declspec(dllexport) GDExtensionBool program_probe_init(GDExtensionInterfaceGetProcAddress,GDExtensionClassLibraryPtr,GDExtensionInitialization* init){init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->userdata=nullptr;init->initialize=initialize;init->deinitialize=deinitialize;return 1;}
