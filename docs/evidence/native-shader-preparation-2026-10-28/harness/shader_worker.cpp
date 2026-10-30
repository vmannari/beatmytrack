#include "shader_job.hpp"
using namespace prep;
using Obj=void(APIENTRY*)(GLuint);using Query=void(APIENTRY*)(GLuint,GLenum,GLint*);
static void status(GLuint id,bool program){GLint ok=0;gl<Query>(program?"glGetProgramiv":"glGetShaderiv")(id,program?0x8B82:0x8B81,&ok);if(!ok){using Log=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,char*);char text[8192]{};gl<Log>(program?"glGetProgramInfoLog":"glGetShaderInfoLog")(id,sizeof(text),nullptr,text);throw std::runtime_error(text);}}
int main(int argc,char**argv){
 if(argc<3||argc>4)return 2;fs::path jobs=fs::absolute(argv[1]),results=fs::absolute(argv[2]);uint64_t began=us();int completed=0,reused=0;uint64_t max_compile=0,max_link=0;
 try{
  fs::create_directories(results);SetPriorityClass(GetCurrentProcess(),BELOW_NORMAL_PRIORITY_CLASS);Context context;auto identity=driver();GLint formats=0;glGetIntegerv(0x87FE,&formats);if(!formats)throw std::runtime_error("no binary formats");
  using Hint=void(APIENTRY*)(GLuint);auto hint=reinterpret_cast<Hint>(wglGetProcAddress("glMaxShaderCompilerThreadsKHR"));if(hint)hint(2);
  std::vector<fs::path> files;for(auto&entry:fs::directory_iterator(jobs))if(entry.path().extension()==".job")files.push_back(entry.path());std::sort(files.begin(),files.end());if(files.empty()||files.size()>256)throw std::runtime_error("inventory count");
  if(argc==4&&std::string(argv[3])=="--validate"){
   GLint profile=0,flags=0;glGetIntegerv(0x9126,&profile);glGetIntegerv(0x821E,&flags);std::printf("VALIDATE_CONTEXT profile=%d flags=%d\n",profile,flags);
   auto bytes=read(files[0],MAX_JOB);auto key=sha(bytes);auto job=Job::decode(bytes);GLenum format=0;auto binary=decode_binary(read(results/(key+".bin"),MAX_BINARY+4096),key,identity,format);
   using CreateShader=GLuint(APIENTRY*)(GLenum);using Source=void(APIENTRY*)(GLuint,GLsizei,const char* const*,const GLint*);using CreateProgram=GLuint(APIENTRY*)();using Attach=void(APIENTRY*)(GLuint,GLuint);using Binary=void(APIENTRY*)(GLuint,GLenum,const void*,GLsizei);
   GLuint program=gl<CreateProgram>("glCreateProgram")();std::vector<GLuint> shaders;for(auto pair:{std::pair<GLenum,std::string*>{0x8B31,&job.vertex},{0x8B30,&job.fragment}}){if(pair.second->empty())continue;auto shader=gl<CreateShader>("glCreateShader")(pair.first);const char* text=pair.second->c_str();gl<Source>("glShaderSource")(shader,1,&text,nullptr);gl<Attach>("glAttachShader")(program,shader);shaders.push_back(shader);}
   for(int attempt=0;attempt<3;attempt++){if(attempt==1)for(auto shader:shaders)gl<Attach>("glDetachShader")(program,shader);if(attempt==2)program=gl<CreateProgram>("glCreateProgram")();gl<Binary>("glProgramBinary")(program,format,binary.data(),GLsizei(binary.size()));GLint ok=0;gl<Query>("glGetProgramiv")(program,0x8B82,&ok);using Log=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,char*);char text[2048]{};gl<Log>("glGetProgramInfoLog")(program,sizeof(text),nullptr,text);std::printf("VALIDATE_BINARY attempt=%d valid=%d error=%u detail=%s\n",attempt,ok,glGetError(),text);}
   return 0;
  }
  for(auto&file:files){
   auto bytes=read(file,MAX_JOB);auto key=sha(bytes);if(file.stem()!=key)throw std::runtime_error("job checksum");auto job=Job::decode(bytes);if(job.driver!=identity)throw std::runtime_error("driver mismatch");
   if(fs::exists(results/(key+".bin"))){GLenum format=0;decode_binary(read(results/(key+".bin"),MAX_BINARY+4096),key,identity,format);completed++;reused++;continue;}
   using CreateShader=GLuint(APIENTRY*)(GLenum);using Source=void(APIENTRY*)(GLuint,GLsizei,const char* const*,const GLint*);using CreateProgram=GLuint(APIENTRY*)();using Attach=void(APIENTRY*)(GLuint,GLuint);using Parameter=void(APIENTRY*)(GLuint,GLenum,GLint);
   auto started=us();GLuint program=gl<CreateProgram>("glCreateProgram")();gl<Parameter>("glProgramParameteri")(program,0x8257,1);std::vector<GLuint> shaders;
   for(auto pair:{std::pair<GLenum,std::string*>{0x8B31,&job.vertex},{0x8B30,&job.fragment}}){if(pair.second->empty())continue;GLuint shader=gl<CreateShader>("glCreateShader")(pair.first);const char* text=pair.second->c_str();auto t=us();gl<Source>("glShaderSource")(shader,1,&text,nullptr);gl<Obj>("glCompileShader")(shader);status(shader,false);max_compile=std::max(max_compile,us()-t);gl<Attach>("glAttachShader")(program,shader);shaders.push_back(shader);}
   using BindingCall=void(APIENTRY*)(GLuint,GLuint,const char*);for(auto&binding:job.attributes)gl<BindingCall>("glBindAttribLocation")(program,binding.index,binding.name.c_str());for(auto&binding:job.outputs)gl<BindingCall>("glBindFragDataLocation")(program,binding.index,binding.name.c_str());
   if(!job.feedback.empty()){std::vector<const char*> names;for(auto&s:job.feedback)names.push_back(s.c_str());using Feedback=void(APIENTRY*)(GLuint,GLsizei,const char* const*,GLenum);gl<Feedback>("glTransformFeedbackVaryings")(program,GLsizei(names.size()),names.data(),job.feedback_mode);}
   auto t=us();gl<Obj>("glLinkProgram")(program);status(program,true);max_link=std::max(max_link,us()-t);GLint size=0;gl<Query>("glGetProgramiv")(program,0x8741,&size);if(size<=0||size>int(MAX_BINARY))throw std::runtime_error("program binary size");Bytes binary(size);GLsizei used=0;GLenum format=0;using Get=void(APIENTRY*)(GLuint,GLsizei,GLsizei*,GLenum*,void*);gl<Get>("glGetProgramBinary")(program,size,&used,&format,binary.data());binary.resize(used);atomic(results/(key+".bin"),encode_binary(key,identity,format,binary));
   gl<Obj>("glDeleteProgram")(program);for(auto id:shaders)gl<Obj>("glDeleteShader")(id);completed++;
   std::printf("{\"job\":\"%s\",\"us\":%llu,\"binary_bytes\":%zu,%s}\n",key.c_str(),us()-started,binary.size(),memory().c_str());std::fflush(stdout);
  }
  std::string report="{\"success\":true,\"programs\":"+std::to_string(completed)+",\"reused\":"+std::to_string(reused)+",\"total_us\":"+std::to_string(us()-began)+",\"max_compile_us\":"+std::to_string(max_compile)+",\"max_link_us\":"+std::to_string(max_link)+","+memory()+"}";atomic(results/"worker-result.json",Bytes(report.begin(),report.end()));return 0;
 }catch(const std::exception&e){std::fprintf(stderr,"SHADER_WORKER_FAILED %s\n",e.what());std::string report="{\"success\":false,\"programs\":"+std::to_string(completed)+"}";try{atomic(results/"worker-result.json",Bytes(report.begin(),report.end()));}catch(...){}return 1;}
}
