"""Original/fixed tiny-body attack against an owned disposable Uvicorn process."""
import http.client
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
ORIGINAL='--original' in sys.argv
LABEL='original' if ORIGINAL else 'fixed'
WORK=ROOT/'build/security-fixes-20261024'/('slow-body-'+LABEL)

def application():
    if os.environ.get('BMT_PROBE_ORIGINAL')=='1':
        import bmt_backend.middleware as module
        source=OUT/'before/backend/bmt_backend/middleware.py'
        exec(compile(source.read_text(),str(source),'exec'),module.__dict__)
    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.migrate import upgrade
    app=create_app(Settings(database_url='sqlite://',object_dir=str(WORK/'objects'),
        google_client_ids=('fixture.apps.googleusercontent.com',)))
    upgrade(app.state.engine)
    return app

def main():
    WORK.mkdir(parents=True,exist_ok=True)
    with socket.socket() as listener:
        listener.bind(('127.0.0.1',0));port=listener.getsockname()[1]
    env={k:v for k,v in os.environ.items() if not k.startswith('BMT_')}
    env['PYTHONPATH']=str(OUT)+os.pathsep+str(ROOT/'backend')
    env['BMT_PROBE_ORIGINAL']='1' if ORIGINAL else '0'
    command=[sys.executable,'-m','uvicorn','slow_body_probe:application','--factory','--host','127.0.0.1',
        '--port',str(port),'--limit-concurrency','24','--no-proxy-headers','--no-access-log','--timeout-keep-alive','5']
    def request(path,method='GET',body=None):
        c=http.client.HTTPConnection('127.0.0.1',port,timeout=3)
        try:
            c.request(method,path,body,{'Connection':'close','Content-Type':'application/json'})
            r=c.getresponse();r.read()
            return r.status
        finally:c.close()
    held=[];started=time.monotonic()
    with (OUT/('slow-body-'+LABEL+'-server.log')).open('wb') as log:
        process=subprocess.Popen(command,env=env,cwd=ROOT,stdout=log,stderr=log)
        try:
            for _ in range(150):
                try:
                    if request('/healthz')==200:break
                except (OSError,http.client.HTTPException):pass
                if process.poll() is not None:raise RuntimeError('Disposable server exited')
                time.sleep(.1)
            else:raise RuntimeError('Disposable server did not start')
            for _ in range(23):
                c=socket.create_connection(('127.0.0.1',port),timeout=3)
                c.sendall(b'POST /v1/auth/google/challenge HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{')
                held.append(c);time.sleep(.04)
            time.sleep(.4)
            during=[request('/healthz') for _ in range(3)]
            ordinary=request('/v1/auth/google/challenge','POST','{}')
            replies=[]
            if not ORIGINAL:
                time.sleep(2)
                for c in held:
                    raw=c.recv(4096)
                    replies.append(int(raw.split(b' ')[1]))
                    assert b'connection: close' in raw.lower()
                    assert c.recv(4096)==b''
            for c in held:c.close()
            held.clear();time.sleep(.3)
            after=request('/healthz')
            result={'variant':LABEL,'unfinished_bodies':23,'health_while_held':during,
                'ordinary_auth_status':ordinary,'server_closed_replies':replies,'health_after':after,
                'elapsed_seconds':round(time.monotonic()-started,3),'scope':'disposable loopback SQLite/Uvicorn, shipping cap24'}
            (OUT/('slow-body-'+LABEL+'.json')).write_text(json.dumps(result,indent=2)+'\n')
            print(json.dumps(result))
            assert after==200
            assert during==([503]*3 if ORIGINAL else [200]*3)
            assert ordinary==(503 if ORIGINAL else 201)
            if not ORIGINAL:assert sorted(replies)==[408]*2+[503]*21
        finally:
            for c in held:c.close()
            process.terminate()
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
if __name__=='__main__':main()
