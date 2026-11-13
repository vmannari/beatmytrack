from pathlib import Path
import urllib.request, xml.etree.ElementTree as ET, json
out=Path('docs/evidence/loading-half-2026-11-06/engine');out.mkdir(parents=True,exist_ok=True)
url='https://dl.google.com/android/repository/repository2-3.xml'
with urllib.request.urlopen(url,timeout=25) as response: data=response.read(16*1024*1024)
root=ET.fromstring(data)
for item in root:
 if item.tag.endswith('remotePackage') and item.attrib.get('path')=='ndk;29.0.14206865':
  for archive in item.findall('.//archive'):
   if archive.findtext('host-os')!='windows':continue
   node=archive.find('complete'); receipt={'manifest_url':url,'revision':'29.0.14206865','archive_url':'https://dl.google.com/android/repository/'+node.findtext('url'),'bytes':int(node.findtext('size')),'checksum':node.findtext('checksum'),'checksum_type':node.find('checksum').attrib.get('type','sha1')}
   (out/'ndk-source.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt));break
  else:raise RuntimeError('No pinned Windows archive in official manifest')
  break
else:raise RuntimeError('Pinned NDK missing from manifest')
