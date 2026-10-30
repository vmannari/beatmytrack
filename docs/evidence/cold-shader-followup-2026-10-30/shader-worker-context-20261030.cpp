#include "shader_job.hpp"
int main() {
 try {
  std::printf("{\"phase\":\"startup\",%s}\n", prep::memory().c_str());
  prep::Context context;
  std::printf("{\"phase\":\"context\",%s}\n", prep::memory().c_str());
  auto identity = prep::driver();
  GLint formats = 0; glGetIntegerv(0x87FE, &formats);
  using Hint=void(APIENTRY*)(GLuint);
  auto hint=reinterpret_cast<Hint>(wglGetProcAddress("glMaxShaderCompilerThreadsKHR"));
  if(hint) hint(2);
  std::printf("{\"phase\":\"worker_ready\",\"binary_formats\":%d,%s}\n", formats, prep::memory().c_str());
  return 0;
 } catch(const std::exception &e) { std::fprintf(stderr,"CONTEXT_FAILED %s\n",e.what()); return 1; }
}
