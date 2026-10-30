#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <windows.h>
#include <cstdio>
#include <cstring>
#include <cstdint>
using namespace godot;
namespace {
using Malloc = void *(__cdecl *)(size_t);
using Realloc = void *(__cdecl *)(void *, size_t);
using Calloc = void *(__cdecl *)(size_t, size_t);
using Free = void (__cdecl *)(void *);
Malloc real_malloc=nullptr; Realloc real_realloc=nullptr; Calloc real_calloc=nullptr; Free real_free=nullptr;
struct Record { void *ptr; size_t size, previous; unsigned short count; void *frames[24]; };
constexpr size_t CAP=65536;
Record records[CAP];
SRWLOCK lock=SRWLOCK_INIT;
volatile bool enabled=false;
thread_local bool entered=false;
size_t minimum=2048, dropped=0;
uintptr_t base=0;
void *tombstone=reinterpret_cast<void *>(1);
size_t index_of(void *p) { return (reinterpret_cast<uintptr_t>(p)>>4)*11400714819323198485ull&(CAP-1); }
void forget(void *p) {
 if(!p)return;
 for(size_t n=0,i=index_of(p);n<CAP;n++,i=(i+1)&(CAP-1)) {
  if(records[i].ptr==nullptr)return;
  if(records[i].ptr==p){
   size_t hole=i,j=(i+1)&(CAP-1);
   while(records[j].ptr){
    size_t ideal=index_of(records[j].ptr);
    if(((j-ideal)&(CAP-1))>=((hole-ideal)&(CAP-1))){records[hole]=records[j];hole=j;}
    j=(j+1)&(CAP-1);
   }
   records[hole].ptr=nullptr;return;
  }
 }
}
void remember(void *p,size_t bytes,size_t previous) {
 if(!p||bytes<minimum)return;
 void *frames[24]; auto count=CaptureStackBackTrace(2,24,frames,nullptr);
 for(size_t n=0,i=index_of(p);n<CAP;n++,i=(i+1)&(CAP-1)) {
  if(records[i].ptr==nullptr||records[i].ptr==tombstone||records[i].ptr==p){
   records[i].ptr=p;records[i].size=bytes;records[i].previous=previous;records[i].count=count;
   memcpy(records[i].frames,frames,count*sizeof(void *));return;
  }
 }
 dropped++;
}
void * __cdecl traced_malloc(size_t bytes) {
 void *p=real_malloc(bytes);
 if(enabled&&!entered){entered=true;AcquireSRWLockExclusive(&lock);remember(p,bytes,0);ReleaseSRWLockExclusive(&lock);entered=false;}
 return p;
}
void * __cdecl traced_calloc(size_t count,size_t bytes) {
 void *p=real_calloc(count,bytes);
 if(enabled&&!entered){entered=true;AcquireSRWLockExclusive(&lock);remember(p,count*bytes,0);ReleaseSRWLockExclusive(&lock);entered=false;}
 return p;
}
void * __cdecl traced_realloc(void *old,size_t bytes) {
 if(!enabled||entered)return real_realloc(old,bytes);
 entered=true;AcquireSRWLockExclusive(&lock);
 size_t previous=0;
 if(old){for(size_t n=0,i=index_of(old);n<CAP;n++,i=(i+1)&(CAP-1)){
  if(records[i].ptr==nullptr)break;if(records[i].ptr==old){previous=records[i].size;break;}
 }}
 void *p=real_realloc(old,bytes);
 if(p||bytes==0){forget(old);remember(p,bytes,previous);}
 ReleaseSRWLockExclusive(&lock);entered=false;return p;
}
void __cdecl traced_free(void *p) {
 if(enabled&&!entered){entered=true;AcquireSRWLockExclusive(&lock);forget(p);ReleaseSRWLockExclusive(&lock);entered=false;}
 real_free(p);
}
struct Patch { uintptr_t *slot; uintptr_t original; } patches[8];size_t patch_count=0;
void patch(const char *name,uintptr_t *slot,uintptr_t replacement,uintptr_t *original){
 DWORD prior; if(!VirtualProtect(slot,sizeof(uintptr_t),PAGE_READWRITE,&prior))return;
 *original=*slot;patches[patch_count++]={slot,*slot};*slot=replacement;VirtualProtect(slot,sizeof(uintptr_t),prior,&prior);
}
}
class BmtHeapProbe : public RefCounted {
 GDCLASS(BmtHeapProbe,RefCounted)
protected:
 static void _bind_methods(){ClassDB::bind_method(D_METHOD("start","minimum_bytes"),&BmtHeapProbe::start);ClassDB::bind_method(D_METHOD("dump","path","tag"),&BmtHeapProbe::dump);ClassDB::bind_method(D_METHOD("queue_info","tree"),&BmtHeapProbe::queue_info);ClassDB::bind_method(D_METHOD("dictionary_assignment","count","move"),&BmtHeapProbe::dictionary_assignment);}
public:
 void dictionary_assignment(int count,bool move){for(int i=0;i<count;i++){Dictionary destination,source;if(move)destination=std::move(source);else destination=source;}}
 Dictionary queue_info(Object *tree){
  Dictionary result;
  // Read-only inspection for the exact ed1daf0bf Windows x86_64 official binary.
  auto module=reinterpret_cast<unsigned char *>(GetModuleHandleW(nullptr));
  const unsigned char signature[]={0x48,0x83,0xec,0x48,0x48,0x85,0xd2};
  if(memcmp(module+0x2485180,signature,sizeof(signature))!=0){result["unsupported_binary"]=true;return result;}
  struct Set { uint64_t *keys;uint32_t *hash_to_key,*key_to_hash,*hashes;uint32_t capacity_index,size; };
  auto set=reinterpret_cast<const Set *>(reinterpret_cast<unsigned char *>(tree->_owner)+0x760);
  result["size"]=set->size;result["capacity_index"]=set->capacity_index;
  if(set->size>2000000 || (set->size&&!set->keys)){result["invalid_layout"]=true;return result;}
  uint32_t alive=0;for(uint32_t i=0;i<set->size;i++)if(internal::gdextension_interface_object_get_instance_from_id(set->keys[i]))alive++;
  result["alive"]=alive;result["dead"]=set->size-alive;
  size_t bytes=0;for(auto ptr:{reinterpret_cast<void *>(set->keys),reinterpret_cast<void *>(set->hash_to_key),reinterpret_cast<void *>(set->key_to_hash),reinterpret_cast<void *>(set->hashes)})if(ptr)bytes+=reinterpret_cast<size_t *>(ptr)[-2]+16;
  result["bytes"]=int64_t(bytes);return result;
 }
 int start(int threshold){
  if(patch_count)return int(patch_count);
  minimum=threshold;base=reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
  auto dos=reinterpret_cast<IMAGE_DOS_HEADER *>(base);auto nt=reinterpret_cast<IMAGE_NT_HEADERS *>(base+dos->e_lfanew);
  auto desc=reinterpret_cast<IMAGE_IMPORT_DESCRIPTOR *>(base+nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);
  for(;desc->Name;desc++){
   auto names=reinterpret_cast<IMAGE_THUNK_DATA *>(base+desc->OriginalFirstThunk);auto slots=reinterpret_cast<IMAGE_THUNK_DATA *>(base+desc->FirstThunk);
   for(;names->u1.AddressOfData;names++,slots++){
    if(IMAGE_SNAP_BY_ORDINAL(names->u1.Ordinal))continue;
    const char *name=reinterpret_cast<IMAGE_IMPORT_BY_NAME *>(base+names->u1.AddressOfData)->Name;
    auto slot=reinterpret_cast<uintptr_t *>(&slots->u1.Function);
    if(!strcmp(name,"malloc"))patch(name,slot,reinterpret_cast<uintptr_t>(traced_malloc),reinterpret_cast<uintptr_t *>(&real_malloc));
    if(!strcmp(name,"calloc"))patch(name,slot,reinterpret_cast<uintptr_t>(traced_calloc),reinterpret_cast<uintptr_t *>(&real_calloc));
    if(!strcmp(name,"realloc"))patch(name,slot,reinterpret_cast<uintptr_t>(traced_realloc),reinterpret_cast<uintptr_t *>(&real_realloc));
    if(!strcmp(name,"free"))patch(name,slot,reinterpret_cast<uintptr_t>(traced_free),reinterpret_cast<uintptr_t *>(&real_free));
   }
  }
  enabled=true;return int(patch_count);
 }
 void dump(String path,String tag){
  auto filename=path.utf8();auto label=tag.utf8();
  entered=true;AcquireSRWLockExclusive(&lock);
  FILE *file=fopen(filename.get_data(),"w");
  if(file){
   fprintf(file,"# %s base=%llx dropped=%llu threshold=%llu\n",label.get_data(),(unsigned long long)base,(unsigned long long)dropped,(unsigned long long)minimum);
   for(auto &r:records){if(!r.ptr||r.ptr==tombstone)continue;
    fprintf(file,"%llx\t%llu\t%llu\t",(unsigned long long)r.ptr,(unsigned long long)r.size,(unsigned long long)r.previous);
    for(unsigned j=0;j<r.count;j++)fprintf(file,"%llx,",(unsigned long long)(reinterpret_cast<uintptr_t>(r.frames[j])-base));
    fprintf(file,"\t");for(size_t j=0;j<96&&j<r.size;j++)fprintf(file,"%02x",static_cast<unsigned char *>(r.ptr)[j]);fprintf(file,"\n");
   }
   fclose(file);
  }
  ReleaseSRWLockExclusive(&lock);entered=false;
 }
};
void initialize(ModuleInitializationLevel level){if(level==MODULE_INITIALIZATION_LEVEL_SCENE)ClassDB::register_class<BmtHeapProbe>();}
void terminate(ModuleInitializationLevel level){if(level!=MODULE_INITIALIZATION_LEVEL_SCENE)return;enabled=false;for(size_t i=0;i<patch_count;i++){DWORD prior;VirtualProtect(patches[i].slot,sizeof(uintptr_t),PAGE_READWRITE,&prior);*patches[i].slot=patches[i].original;VirtualProtect(patches[i].slot,sizeof(uintptr_t),prior,&prior);}}
extern "C" GDExtensionBool GDE_EXPORT bmt_heap_probe_init(GDExtensionInterfaceGetProcAddress proc,GDExtensionClassLibraryPtr lib,GDExtensionInitialization *init){GDExtensionBinding::InitObject object(proc,lib,init);object.register_initializer(initialize);object.register_terminator(terminate);object.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return object.init();}
