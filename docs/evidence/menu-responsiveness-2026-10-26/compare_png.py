from pathlib import Path
import struct,zlib,json,sys

def read(p):
 b=p.read_bytes();i=8;data=b""
 while i<len(b):
  n=struct.unpack(">I",b[i:i+4])[0];k=b[i+4:i+8];x=b[i+8:i+8+n];i+=12+n
  if k==b"IHDR":w,h,d,c,_,_,inter=struct.unpack(">IIBBBBB",x)
  if k==b"IDAT":data+=x
 assert d==8 and c in (2,6) and inter==0
 bpp=3 if c==2 else 4;raw=zlib.decompress(data);rows=[];prev=bytearray(w*bpp);at=0
 for y in range(h):
  f=raw[at];at+=1;row=bytearray(raw[at:at+w*bpp]);at+=w*bpp
  for j in range(len(row)):
   a=row[j-bpp] if j>=bpp else 0;b=prev[j];c=prev[j-bpp] if j>=bpp else 0
   if f==1:t=a
   elif f==2:t=b
   elif f==3:t=(a+b)//2
   elif f==4:
    v=a+b-c;pa=abs(v-a);pb=abs(v-b);pc=abs(v-c);t=a if pa<=pb and pa<=pc else b if pb<=pc else c
   else:t=0
   row[j]=(row[j]+t)&255
  rows.append(row);prev=row
 return w,h,bpp,b"".join(rows)
p=Path(sys.argv[1]); results=[]
for aa,bb in [("synchronous-2.png","cooperative.png"),("synchronous-2.png","synchronous-4.png")]:
 if not (p/aa).exists() or not (p/bb).exists():continue
 w,h,bpp,a=read(p/aa);_,_,_,b=read(p/bb)
 diffs=[abs(x-y) for x,y in zip(a,b)];changed=sum(x!=0 for x in diffs)
 results.append({"before":aa,"after":bb,"width":w,"height":h,"different_components":changed,"max_component_difference":max(diffs),"mean_component_difference":sum(diffs)/len(diffs)})
(p/"pixel-comparison.json").write_text(json.dumps(results,indent=2));print(json.dumps(results))
