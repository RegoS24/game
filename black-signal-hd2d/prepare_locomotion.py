"""Process the new illustrated 3-row locomotion sheet. Preserve alpha and ground anchor."""
from pathlib import Path
from PIL import Image
import cv2
import numpy as np
import sys
from PIL import ImageDraw

ROOT=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).parent/'assets'
W,H=384,512
cv2.setNumThreads(2)
rows=[('run',0,326,328,72),('crouch_walk',326,590,230,104),('crawl',590,768,150,136)]
sheet=np.array(Image.open(ROOT/'rin_locomotion_source.webp').convert('RGB'))
assert sheet.shape==(768,2048,3),sheet.shape
Y,X=np.mgrid[:H,:W].astype(np.float32); GRID=np.stack((X,Y),-1)

def segment(rgb):
 rgb=rgb.astype(np.float32)
 excess=rgb[:,:,1]-np.maximum(rgb[:,:,0],rgb[:,:,2])
 alpha=np.clip((100-excess)/65,0,1)
 # Reject saturated green backdrop, but preserve turquoise garment details.
 alpha[(rgb[:,:,1]>rgb[:,:,0]*1.75)&(rgb[:,:,1]>rgb[:,:,2]*1.65)&(excess>65)]=0
 alpha[alpha<.035]=0
 rgb[:,:,1]=np.minimum(rgb[:,:,1],np.maximum(rgb[:,:,0],rgb[:,:,2])+18)
 mask=(alpha>.5).astype(np.uint8)
 n,l,stats,_=cv2.connectedComponentsWithStats(mask,8)
 best=1+np.argmax(stats[1:,cv2.CC_STAT_AREA]);keep=(l==best).astype(np.uint8)
 keep=cv2.dilate(keep,np.ones((5,5),np.uint8))
 alpha*=keep
 a=np.dstack((rgb/255*alpha[:,:,None],alpha))
 ys,xs=np.nonzero(alpha>.3)
 return a[ys.min():ys.max()+1,xs.min():xs.max()+1],int(ys.max()),int(xs.min())

def normalise(crops,target,name):
 scale=target/np.median([im.shape[0] for im,_,_ in crops]); out=[]
 for i,(im,bottom,left) in enumerate(crops):
  if name=='run':im=im[:,::-1].copy() # retain the turquoise stole on Rin's left shoulder
  w,h=round(im.shape[1]*scale),round(im.shape[0]*scale)
  if w>W-12:
   # Never crop a hand or shoe; use the same reduction for every row via scale above where possible.
   raise ValueError((name,i,w))
  q=cv2.resize(im,(w,h),interpolation=cv2.INTER_CUBIC).clip(0,1)
  tile=np.zeros((H,W,4),np.float32)
  # Preserve a small aerial phase in the run cycle.
  lift=[0,4,10,4,0,4,10,4][i] if name=='run' else 0
  y=448-h-lift;x=(W-w)//2
  tile[y:y+h,x:x+w]=q
  out.append(tile)
 return out

def reflected(a,axis):
 # Reflect around anatomical hip axis (not the bounds of hair or weapon).
 m=np.stack((2*axis-X,Y),-1).astype(np.float32)
 return cv2.remap(a,m,None,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)

def lower_swap(a,axis,cut,fade):
 other=reflected(a,axis)
 # Constrain the swap to pelvis and legs. Keep the original arms, gloves,
 # and asymmetric turquoise fur, including the hanging end in lower stances.
 width=55 if cut>=323 else 48
 expand=np.clip((Y-(cut+42))/35,0,1)*36
 spatial=np.clip((width+expand-np.abs(X-axis))/7,0,1)
 t=np.clip((Y-cut)/fade,0,1)*spatial
 t=t*t*(3-2*t)
 def accessory(v):
  r,g,b=v[:,:,0],v[:,:,1],v[:,:,2]
  return ((g>r*1.40)&(b>r*1.28)&(g-r>.055)) | ((b>g*1.35)&(r>g*1.08)&(b-g>.07))
 # Never copy saturated turquoise/purple material across the body axis.
 t[accessory(a)&(Y<405)]=0
 bad=accessory(other)&(Y<405)
 other[bad]=0
 return a*(1-t[:,:,None])+other*t[:,:,None]

def planted(a,axis,cut,fade):
 # Build a two-foot passing pose from the left support leg. Both feet are
 # distinct, at a common baseline, with no duplicated semitransparent limbs.
 other=reflected(a,axis)
 pair=np.where((X<=axis)[:,:,None],a,other)
 t=np.clip((Y-cut)/fade,0,1)[:,:,None]; t=t*t*(3-2*t)
 return a*(1-t)+pair*t

def shoe_delta(a,axis,shoe_y):
 # Identify the two opaque white sneakers and compare their vertical centroids.
 r=rgba(a); rgb=r[:,:,:3].astype(np.int16)
 mask=(r[:,:,3]>180)&(rgb.min(2)>118)&((rgb.max(2)-rgb.min(2))<65)&(Y>shoe_y)
 n,l,st,c=cv2.connectedComponentsWithStats(mask.astype(np.uint8))
 shoes=[(int(st[i,4]),float(c[i,0]),float(c[i,1])) for i in range(1,n) if st[i,4]>220]
 left=[x for x in shoes if x[1]<axis];right=[x for x in shoes if x[1]>axis]
 if not left or not right:raise AssertionError(('missing sneaker',axis,shoes))
 return max(left)[2]-max(right)[2]

def gray(a):return np.uint8(np.clip((cv2.cvtColor(a[:,:,:3],cv2.COLOR_RGB2GRAY)*.7+a[:,:,3]*.3)*255,0,255))
def flow(a,b):
 # Track motion at half resolution, scale field back to full resolution.
 u=cv2.resize(gray(a),(W//2,H//2));v=cv2.resize(gray(b),(W//2,H//2))
 f=cv2.calcOpticalFlowFarneback(u,v,None,.5,4,17,5,7,1.5,0)
 return cv2.resize(f,(W,H))*2

def remap(a,f,t):
 m=GRID-f*t
 for _ in range(2):m=GRID-cv2.remap(f,m,None,cv2.INTER_LINEAR,borderMode=cv2.BORDER_REPLICATE)*t
 return cv2.remap(a,m,None,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
def interp(a,b,f,g,t):
 if t<1e-6:return a
 return remap(a,f,t)*(1-t)+remap(b,g,1-t)*t

def rgba(a):
 alpha=a[:,:,3:4];rgb=np.divide(a[:,:,:3],alpha,out=np.zeros_like(a[:,:,:3]),where=alpha>1e-4)
 return np.uint8(np.clip(np.dstack((rgb,alpha))*255+.5,0,255))

for name,top,bottom,target,count in rows:
 crops=[segment(sheet[top:bottom,i*256:(i+1)*256]) for i in range(8)]
 poses=normalise(crops,target,name)
 # Measure hip axis and use the same anatomical side for the first half-step.
 # Equal-foot passing pose at phase 0 and 0.5; clear opposite leg lift at 0.25 and 0.75.
 if name=='run':
  axis,cut,fade,shoe_y=192,248,22,315
  neutral=planted(poses[0],axis,cut,fade)
  mid,peak=poses[0],poses[2]
  minimum=32
 elif name=='crouch_walk':
  axis,cut,fade,shoe_y=178,323,20,375
  neutral=poses[0]
  mid,peak=poses[3],poses[2]
  minimum=14
 else:
  axis,cut,fade,shoe_y=182,369,13,387
  neutral=poses[0]
  mid,peak=poses[1],poses[2]
  minimum=9
 opposite=lower_swap(peak,axis,cut,fade)
 opposite_mid=lower_swap(mid,axis,cut,fade)
 # Both complete half-steps pass through the same planted pose, which avoids
 # an optical-flow correspondence jumping directly between crossed feet.
 keys=[neutral,mid,peak,mid,neutral,opposite_mid,opposite,opposite_mid]
 d1=shoe_delta(keys[2],axis,shoe_y);d2=shoe_delta(keys[6],axis,shoe_y)
 assert d1*d2<0 and min(abs(d1),abs(d2))>=minimum,(name,d1,d2)
 pairs=[(flow(keys[i],keys[(i+1)%8]),flow(keys[(i+1)%8],keys[i])) for i in range(8)]
 atlas=Image.new('RGBA',(W*8,H*((count+7)//8)))
 for i in range(count):
  phase=i*8/count;j=int(phase);t=phase-j
  frame=rgba(interp(keys[j],keys[(j+1)%8],*pairs[j],t))
  assert (frame[:,:,3]>75).sum()>3000,(name,i)
  atlas.paste(Image.fromarray(frame),(i%8*W,i//8*H))
 # Validate exported atlas pixels, not just the pose metadata.
 def export_pose(i):
  x,y=i%8*W,i//8*H
  v=np.asarray(atlas.crop((x,y,x+W,y+H))).astype(np.float32)/255
  v[:,:,:3]*=v[:,:,3:4]
  return v
 qa=shoe_delta(export_pose(count//4),axis,shoe_y)
 qb=shoe_delta(export_pose(3*count//4),axis,shoe_y)
 assert qa*qb<0 and min(abs(qa),abs(qb))>=minimum,(name,qa,qb)
 atlas.save(ROOT/(name+'_smooth.webp'),lossless=True,method=3,exact=True)
 print('RIN_ALTERNATION_OK',name,count,round(qa,1),round(qb,1),flush=True)