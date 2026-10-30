import hashlib,json,os,struct
from pathlib import Path
LAB=Path(__file__).resolve().parent/'programs'
target_dir=LAB/'jobs-context';target_dir.mkdir(exist_ok=True)
rows=[]
for path in sorted((LAB/'jobs').glob('*.job')):
    old=path.read_bytes()
    length=struct.unpack_from('<I',old,4)[0]
    driver=old[8:8+length]+b'context_profile=1;context_flags=1\n'
    data=old[:4]+struct.pack('<I',len(driver))+driver+old[8+length:]
    key=hashlib.sha256(data).hexdigest()
    target=target_dir/(key+'.job');target.write_bytes(data)
    stat=path.stat();os.utime(target,ns=(stat.st_atime_ns,stat.st_mtime_ns))
    rows.append(dict(original=path.stem,context_key=key))
(LAB/'context-migration.json').write_text(json.dumps(dict(
    context_evidence='import-2 main GL_CONTEXT_PROFILE_MASK=1, GL_CONTEXT_FLAGS=1; exact pinned engine',
    records=rows),indent=2),encoding='utf-8')
print('Added explicit captured context identity to',len(rows),'owned diagnostic jobs')
