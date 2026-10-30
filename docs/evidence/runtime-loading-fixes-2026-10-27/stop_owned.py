from pathlib import Path
import ctypes as c
from ctypes import wintypes as w
import json,sys

root=Path.cwd();lab=root/'build/runtime-loading-fixes-2026-10-27'
label=sys.argv[1]
record=json.loads((lab/(label+'-started.json')).read_text(encoding='utf-8'))
script=Path(record['command'][record['command'].index('--script')+1]).resolve()
assert script.parent==(lab/'checks').resolve()
assert script.name==label+'.gd'
k=c.WinDLL('kernel32',use_last_error=True);nt=c.WinDLL('ntdll')
class UnicodeString(c.Structure):
    _fields_=[('Length',w.USHORT),('MaximumLength',w.USHORT),('Buffer',c.c_void_p)]
k.OpenProcess.restype=w.HANDLE;k.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD]
k.CloseHandle.argtypes=[w.HANDLE];k.TerminateProcess.argtypes=[w.HANDLE,w.UINT]
nt.NtQueryInformationProcess.argtypes=[w.HANDLE,w.ULONG,c.c_void_p,w.ULONG,c.POINTER(w.ULONG)]
handle=k.OpenProcess(0x1001,False,record['pid']);assert handle
try:
    needed=w.ULONG();nt.NtQueryInformationProcess(handle,60,None,0,c.byref(needed))
    assert 0<needed.value<1024*1024
    data=c.create_string_buffer(needed.value)
    assert nt.NtQueryInformationProcess(handle,60,data,needed.value,c.byref(needed))==0
    text=UnicodeString.from_buffer(data)
    command=c.wstring_at(text.Buffer,text.Length//2)
    assert str(script).lower() in command.lower()
    assert 'Godot_v4.7.2-stable_win64.exe'.lower() in command.lower()
    assert k.TerminateProcess(handle,130)
    record['verified_command']=command
    record['reason']=sys.argv[2] if len(sys.argv)>2 else 'Owned failed fixture stopped'
    (lab/(label+'-stopped.json')).write_text(json.dumps(record,indent=2),encoding='utf-8')
    print('Stopped verified task-owned PID',record['pid'])
finally:k.CloseHandle(handle)
