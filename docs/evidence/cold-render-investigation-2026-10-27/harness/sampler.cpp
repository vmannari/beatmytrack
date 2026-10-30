#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>
#include <dbghelp.h>
#include <algorithm>
#include <iostream>
#include <map>
#include <string>
#include <vector>

static unsigned long long ticks(const FILETIME &v) { return (static_cast<unsigned long long>(v.dwHighDateTime)<<32)|v.dwLowDateTime; }
static unsigned long long now_us() { FILETIME t; GetSystemTimePreciseAsFileTime(&t); return (ticks(t)-116444736000000000ULL)/10; }
struct Thread { DWORD id; unsigned long long cpu, created; };
static std::vector<Thread> threads(DWORD pid) {
    std::vector<Thread> out; HANDLE snapshot=CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD,0);
    if(snapshot==INVALID_HANDLE_VALUE)return out;
    THREADENTRY32 row{}; row.dwSize=sizeof(row);
    if(Thread32First(snapshot,&row))do {
        if(row.th32OwnerProcessID!=pid)continue;
        HANDLE t=OpenThread(THREAD_QUERY_INFORMATION,FALSE,row.th32ThreadID); if(!t)continue;
        if(GetProcessIdOfThread(t)==pid){FILETIME c,e,k,u;if(GetThreadTimes(t,&c,&e,&k,&u))out.push_back({row.th32ThreadID,ticks(k)+ticks(u),ticks(c)});}
        CloseHandle(t);
    }while(Thread32Next(snapshot,&row));
    CloseHandle(snapshot); return out;
}
int main(int argc,char**argv) {
    if(argc!=4)return 2;
    DWORD pid=std::stoul(argv[1]), parent=std::stoul(argv[2]); int seconds=std::stoi(argv[3]);
    bool owned=false; HANDLE processes=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);
    PROCESSENTRY32 row{};row.dwSize=sizeof(row);
    if(Process32First(processes,&row))do{if(row.th32ProcessID==pid)owned=row.th32ParentProcessID==parent && std::string(row.szExeFile)=="Godot_v4.7.2-stable_win64.exe";}while(Process32Next(processes,&row));
    CloseHandle(processes);
    if(!owned){std::cout<<"{\"error\":\"not owned Godot child\"}\n";return 3;}
    HANDLE process=OpenProcess(PROCESS_QUERY_INFORMATION|PROCESS_VM_READ,FALSE,pid);
    if(!process){std::cout<<"{\"error\":\"OpenProcess\",\"code\":"<<GetLastError()<<"}\n";return 4;}
    SetEnvironmentVariableA("_NT_SYMBOL_PATH","");SetEnvironmentVariableA("_NT_ALT_SYMBOL_PATH","");
    SymSetOptions(SYMOPT_UNDNAME|SYMOPT_DEFERRED_LOADS|SYMOPT_FAIL_CRITICAL_ERRORS|SYMOPT_NO_PROMPTS);
    bool symbols=SymInitialize(process,"",TRUE);
    std::cout<<"{\"kind\":\"begin\",\"pid\":"<<pid<<",\"utc_us\":"<<now_us()<<",\"symbols\":"<<(symbols?"true":"false")<<"}\n"<<std::flush;
    auto start=GetTickCount64(); std::map<DWORD,unsigned long long> previous;
    while(GetTickCount64()-start<static_cast<unsigned long long>(seconds)*1000){
        DWORD exit=0;if(!GetExitCodeProcess(process,&exit)||exit!=STILL_ACTIVE)break;
        auto found=threads(pid);DWORD main=0;unsigned long long earliest=~0ULL;
        for(auto&t:found)if(t.created<earliest){earliest=t.created;main=t.id;}
        struct Candidate{DWORD id;unsigned long long delta;};std::vector<Candidate> ranked;
        for(auto&t:found){auto old=previous.find(t.id);auto delta=old==previous.end()?0:t.cpu-old->second;previous[t.id]=t.cpu;if(delta>0||t.id==main)ranked.push_back({t.id,delta});}
        std::sort(ranked.begin(),ranked.end(),[](auto a,auto b){return a.delta>b.delta;});if(ranked.size()>6)ranked.resize(6);
        for(auto t:ranked){
            HANDLE thread=OpenThread(THREAD_GET_CONTEXT|THREAD_SUSPEND_RESUME|THREAD_QUERY_INFORMATION,FALSE,t.id);
            if(!thread)continue;if(GetProcessIdOfThread(thread)!=pid){CloseHandle(thread);continue;}
            CONTEXT context{};context.ContextFlags=CONTEXT_FULL;
            std::vector<DWORD64> addresses; auto began=now_us();DWORD suspended=SuspendThread(thread);DWORD error=0;
            if(suspended!=static_cast<DWORD>(-1)){
                if(GetThreadContext(thread,&context)){
                    STACKFRAME64 frame{};frame.AddrPC.Offset=context.Rip;frame.AddrPC.Mode=AddrModeFlat;
                    frame.AddrFrame.Offset=context.Rbp;frame.AddrFrame.Mode=AddrModeFlat;frame.AddrStack.Offset=context.Rsp;frame.AddrStack.Mode=AddrModeFlat;
                    addresses.push_back(context.Rip);
                    for(int i=0;i<23&&symbols;i++){if(!StackWalk64(IMAGE_FILE_MACHINE_AMD64,process,thread,&frame,&context,nullptr,SymFunctionTableAccess64,SymGetModuleBase64,nullptr)||!frame.AddrPC.Offset)break;addresses.push_back(frame.AddrPC.Offset);}
                }else error=GetLastError();
                ResumeThread(thread);
            }else error=GetLastError();
            auto paused=now_us()-began;CloseHandle(thread);
            std::cout<<"{\"kind\":\"sample\",\"utc_us\":"<<began<<",\"thread\":"<<t.id<<",\"main\":"<<(t.id==main?"true":"false")<<",\"cpu_delta_us\":"<<t.delta/10<<",\"pause_us\":"<<paused<<",\"error\":"<<error<<",\"frames\":[";
            bool first=true;
            for(auto address:addresses){
                if(!first)std::cout<<",";first=false;IMAGEHLP_MODULE64 module{};module.SizeOfStruct=sizeof(module);bool known=symbols&&SymGetModuleInfo64(process,address,&module);
                char buffer[sizeof(SYMBOL_INFO)+1024]{};auto*symbol=reinterpret_cast<SYMBOL_INFO*>(buffer);symbol->SizeOfStruct=sizeof(SYMBOL_INFO);symbol->MaxNameLen=1023;DWORD64 displacement=0;
                bool named=symbols&&SymFromAddr(process,address,&displacement,symbol);std::string name=named?symbol->Name:"";
                for(auto &c:name)if(c=='"'||c=='\\'||static_cast<unsigned char>(c)<32)c='_';
                std::cout<<"{\"module\":\""<<(known?module.ModuleName:"unknown")<<"\",\"offset\":"<<(known?address-module.BaseOfImage:address)<<",\"symbol\":\""<<name<<"\",\"displacement\":"<<displacement<<"}";
            }
            std::cout<<"]}\n";
        }
        std::cout<<std::flush;Sleep(100);
    }
    if(symbols)SymCleanup(process);CloseHandle(process);return 0;
}
