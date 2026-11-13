import collections
import hashlib
import re
import struct
import zipfile

path = 'docs/evidence/native-shader-preparation-2026-10-28/captured-program-jobs.zip'
z = zipfile.ZipFile(path)
programs = []
for name in z.namelist():
    b = z.read(name)
    assert struct.unpack_from('<I', b, 0)[0] == 0x314A5342
    assert hashlib.sha256(b).hexdigest() + '.job' == name
    pos = 4
    fields = []
    for _ in range(3):
        n = struct.unpack_from('<I', b, pos)[0]
        pos += 4
        fields.append(b[pos:pos+n].decode('utf-8'))
        pos += n
    programs.append(fields)
assert len(programs) == 192
print('program count', len(programs))
for index, name in [(1, 'vertex'), (2, 'fragment')]:
    counts = collections.Counter(x[index] for x in programs)
    print(name, 'unique', len(counts), 'largest occurrence counts', sorted(counts.values(), reverse=True)[:20])
    prefix = collections.Counter(x[index].split('#define samplerExternalOES')[0] for x in programs)
    print(name, 'unique prefixes', len(prefix), 'top counts', sorted(prefix.values(), reverse=True)[:20])
    body = collections.Counter(x[index].split('#define samplerExternalOES', 1)[-1] for x in programs)
    print(name, 'unique bodies', len(body), 'top counts', sorted(body.values(), reverse=True)[:25])
    flags = collections.Counter()
    for p in programs:
        for line in p[index].split('#define samplerExternalOES')[0].splitlines():
            if line.startswith('#define '): flags[line] += 1
    print('flags', flags.most_common())

def canonical_preamble(source):
    before, sep, body = source.partition('#define samplerExternalOES')
    if not sep:
        return source
    definitions = sorted(re.sub(r'\s+', ' ', line.strip()) for line in before.splitlines() if line.lstrip().startswith('#define '))
    return '\n'.join(definitions) + '\n' + sep + body

canonical = collections.Counter((canonical_preamble(p[1]), canonical_preamble(p[2])) for p in programs)
print('unique canonical-preamble program pairs', len(canonical), 'duplicate multiplicities', sorted([n for n in canonical.values() if n > 1], reverse=True))
