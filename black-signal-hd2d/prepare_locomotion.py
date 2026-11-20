"""Process the new illustrated 3-row locomotion sheet. Preserve alpha and ground anchor."""
from pathlib import Path
from PIL import Image
import cv2
import numpy as np
import sys

ROOT=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).parent/'assets'
W,H=384,512
cv2.setNumThreads(2)
rows=[('run',0,326,328,48),('crouch_walk',326,590,230,40),('crawl',590,768,150,40)]
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

def mirror_limbs(a,cut,fade):
 # Reverse lower-body contact phases without mirroring asymmetric shoulder fur.
 t=np.clip((Y-cut)/fade,0,1)[:,:,None]; t=t*t*(3-2*t)
 return a*(1-t)+a[:,::-1]*t

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
 keys=normalise(crops,target,name)
 if name=='run':
  # Four illustrated contact/flight poses and their opposite leg phases.
  first=[keys[i] for i in (0,1,2,3)]
  keys=first+[mirror_limbs(k,273,40) for k in first]
 elif name=='crouch_walk':
  first=[keys[i] for i in (0,1,2,3)]
  keys=first+[mirror_limbs(k,333,30) for k in first]
 else:
  first=[keys[i] for i in (0,1,2,3)]
  keys=first+[mirror_limbs(k,376,22) for k in first]
 pairs=[(flow(keys[i],keys[(i+1)%8]),flow(keys[(i+1)%8],keys[i])) for i in range(8)]
 atlas=Image.new('RGBA',(W*8,H*((count+7)//8)))
 for i in range(count):
  phase=i*8/count;j=int(phase);t=phase-j
  frame=rgba(interp(keys[j],keys[(j+1)%8],*pairs[j],t))
  assert (frame[:,:,3]>75).sum()>3000,(name,i)
  atlas.paste(Image.fromarray(frame),(i%8*W,i//8*H))
 atlas.save(ROOT/(name+'_smooth.webp'),lossless=True,method=3,exact=True)
 print('RIN_LOCOMOTION_OK',name,count,flush=True)