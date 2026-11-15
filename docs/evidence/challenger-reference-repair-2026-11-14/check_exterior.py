"""Independent surveys of decoded native triangles at the owner's six regions."""
from pathlib import Path
import json,sys,math
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
path=Path(sys.argv[1]);label=sys.argv[2] if len(sys.argv)>2 else 'final'
data=json.loads(path.read_text());checks=[];metrics={}
def check(ok,name):checks.append({'pass':bool(ok),'name':name})
class Mesh:
 def __init__(self,m):
  self.p=np.array(m['points']);self.n=np.array(m['normals']);self.f=np.array(m['indices']).reshape(-1,3);self.t=self.p[self.f];self.projections={}
 def ray(self,axis,a,b,last=True):
  axes=[i for i in range(3) if i!=axis];key=axis
  if key not in self.projections:
   t=self.t[:,:,axes];v=t[:,1]-t[:,0];w=t[:,2]-t[:,0];d=v[:,0]*w[:,1]-v[:,1]*w[:,0]
   self.projections[key]=(t[:,0],v,w,d,abs(d)>1e-12)
  o,v,w,d,valid=self.projections[key];q=np.array([a,b])-o
  u=np.divide(q[:,0]*w[:,1]-q[:,1]*w[:,0],d,out=np.zeros(len(d)),where=valid)
  r=np.divide(v[:,0]*q[:,1]-v[:,1]*q[:,0],d,out=np.zeros(len(d)),where=valid)
  good=valid&(u>=-1e-6)&(r>=-1e-6)&(u+r<=1.000001)
  values=self.t[:,0,axis]+u*(self.t[:,1,axis]-self.t[:,0,axis])+r*(self.t[:,2,axis]-self.t[:,0,axis])
  return float((np.max if last else np.min)(values[good])) if good.any() else float('nan')
for tier in ['simple','full']:
 body=Mesh(data[tier]['body_paint']);hood=Mesh(data[tier]['hood_paint']);dark=Mesh(data[tier]['body_dark']);m={}
 # True circular grille corners: both sides of a 2 mm radial strip are tested.
 for sign in [-1,1]:
  for theta in np.linspace(.08,math.pi/2-.08,15):
   for delta in [-.006,.002]:
    x=sign*(.750+(.052+delta)*math.cos(theta));y=.761+(.052+delta)*math.sin(theta)
    z=body.ray(2,x,y,last=False)
    check((not math.isfinite(z) or z> -2.10) if delta<0 else math.isfinite(z) and z< -2.10,tier+f' circular upper grille corner {sign}/{theta:.3f}/{delta}')
 # The nose's plan corner is a 100 mm circle, continuous with a straight return.
 errors=[]
 for x in np.linspace(.748,.834,25):
  z=body.ray(2,x,.570,last=False);expected=-2.145-math.sqrt(.100**2-(x-.740)**2)
  errors.append(abs(z-expected) if math.isfinite(z) else 1)
  check(math.isfinite(z) and abs(z-expected)<.001,tier+' circular nose plan section')
 m['nose_plan_max_error_mm']=1000*max(errors)
 for y in [.55,.60,.68,.75,.80]:
  for z in np.linspace(-2.142,-2.098,12):
   x=body.ray(0,y,z)
   check(math.isfinite(x) and abs(x-.840)<.001,tier+' closed nose/wing side return')
 # No open triangular corner between the bonnet and its leading return.
 for sign in [-1,1]:
  for x in [.750,.765,.780]:
   for z in [-2.090,-2.080,-2.060,-2.040]:
    candidates=[body.ray(1,sign*x,z),hood.ray(1,sign*x,z)]
    check(any(math.isfinite(h) and h>.82 for h in candidates),tier+' bonnet/nose corner is closed')
 joint=[]
 for y in np.linspace(.300,.830,41):
  a=body.ray(0,y,-2.0954);b=body.ray(0,y,-2.0946)
  joint.append(abs(a-b) if math.isfinite(a) and math.isfinite(b) else 1)
 m['nose_join_max_step_mm']=1000*max(joint)
 check(max(joint)<.001,tier+' nose/flank boundary has no step greater than 1 mm')
 centres=body.t.mean(1)
 ghost=(abs(body.t[:,:,2]+2.095)<.00003).all(1)&(centres[:,1]>.300)&(centres[:,1]<.800)&(np.max(abs(body.t[:,:,0]),axis=1)>.841)
 check(not ghost.any(),tier+' no obsolete cross-section protrudes through the front flank')
 # A clear downward roll at the leading tip, including a steep final tangent.
 heights=[]
 for z in [-2.170,-2.235,-2.245,-2.248]:
  y=body.ray(1,0,z);hy=hood.ray(1,0,z)
  heights.append(max(v for v in [y,hy] if math.isfinite(v)))
 drop=heights[0]-heights[-1];slope=(heights[-2]-heights[-1])/.003
 m['leading_drop_mm']=drop*1000;m['last_tip_slope']=slope
 check(drop>.025,tier+' leading lip turns down at least 25 mm in the last 78 mm')
 check(slope>.70,tier+' leading lip finishes with a steep downward tangent')
 # Cowl outer-skin sections must remain supported, with no local pinches.
 jitter=[]
 for y in [.900,.915,.930]:
  zs=np.linspace(-.88,-.69,39);xs=np.array([body.ray(0,y,z) for z in zs])
  check(np.isfinite(xs).all(),tier+' cowl has no missing exterior samples')
  second=abs(np.diff(xs,2));jitter.append(float(np.nanmax(second)))
  check(np.isfinite(xs).all() and np.max(second)<.0015,tier+' cowl has no local triangular dent')
 m['cowl_second_difference_mm']=1000*max(jitter)
 tangent_errors=[]
 for indices,tri in zip(body.f,body.t):
  p=tri.mean(0)
  if not (.900<p[1]<.930 and -.870<p[2]<-.700 and p[0]>.800):continue
  if abs(body.ray(0,p[1],p[2])-p[0])>.001:continue
  e=.001
  dy=(body.ray(0,p[1]+e,p[2])-body.ray(0,p[1]-e,p[2]))/(2*e)
  dz=(body.ray(0,p[1],p[2]+e)-body.ray(0,p[1],p[2]-e))/(2*e)
  expected=np.array([1,-dy,-dz]);expected/=np.linalg.norm(expected)
  normal=body.n[indices].mean(0);normal/=np.linalg.norm(normal)
  tangent_errors.append(math.degrees(math.acos(np.clip(normal@expected,-1,1))))
 m['cowl_max_normal_error_degrees']=max(tangent_errors,default=180)
 check(bool(tangent_errors) and max(tangent_errors)<12,tier+' cowl shading agrees with its physical tangent')
 # Crisp side character edge: normals change over a narrow physical band.
 angles=[]
 for z in [-1.60,-1.20,-.85]:
  def slope_at(y):return (body.ray(0,y+.001,z)-body.ray(0,y-.001,z))/.002
  candidates=[]
  for h in np.linspace(.790,1.010,111):
   lower=slope_at(h-.008);upper=slope_at(h+.008)
   if -.4<lower<.4 and upper<-.5:
    candidates.append(abs(math.degrees(math.atan(lower)-math.atan(upper))))
  angle=max(candidates,default=0);angles.append(angle)
  check(math.isfinite(angle) and angle>25,tier+' narrow front wing shoulder bend')
 m['front_shoulder_angles_degrees']=angles
 for x in [.770,.790,.810,.825]:
  for y in [.950,.955,.960,.965]:
   z=body.ray(2,x,y)
   check(math.isfinite(z) and z>1.95,tier+' rear upper corner has a closed paint skin')
 rear_joint=[]
 for y in np.linspace(.300,.970,61):
  a=body.ray(0,y,1.9496);b=body.ray(0,y,1.9504)
  rear_joint.append(abs(a-b) if math.isfinite(a) and math.isfinite(b) else 1)
 m['rear_join_max_step_mm']=1000*max(rear_joint)
 check(max(rear_joint)<.001,tier+' rear/side boundary has no step greater than 1 mm')
 # The retained upper-deck crack under the spoiler must have a paint skin.
 for sign in [-1,1]:
  for x,z in [(.760,1.680),(.770,1.800),(.780,1.940),(.800,2.050)]:
   h=body.ray(1,sign*x,z)
   check(math.isfinite(h) and h>.980,tier+' upper rear deck is closed above the quarter')
 # Actual native applique triangles must sit ahead of the paint at their centres.
 hidden=[]
 for tri in dark.t:
  p=tri.mean(0)
  if p[0]<.70 or p[0]>.82 or p[1]<.88 or p[1]>.945 or p[2]<1.99:continue
  z=body.ray(2,p[0],p[1])
  if math.isfinite(z):hidden.append(max(0,z-p[2]))
 m['rear_applique_max_occlusion_mm']=1000*max(hidden,default=0)
 check(bool(hidden) and max(hidden)<.0005,tier+' rear applique is not pierced by the quarter paint')
 metrics[tier]=m
receipt={'checks':len(checks),'failures':sum(not c['pass'] for c in checks),'metrics':metrics,'failed':[c['name'] for c in checks if not c['pass']]}
(OUT/('exterior-'+label+'.json')).write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt))
sys.exit(bool(receipt['failures']))
