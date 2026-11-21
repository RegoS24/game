"""Stable, smooth 2D atlas generation. Avoid per-key invented neural details.
The sparse original key poses are unchanged and require a rig for genuine
high-fidelity movement. Geometry interpolation is spatially regularized.
"""
from pathlib import Path
import os
import cv2
import numpy as np
from PIL import Image

ROOT=Path(__file__).parent/"assets"
COUNTS={"idle":162,"walk":90,"jump":72,"crouch":45,"prone":61}
LOOPS={"idle","walk","run"}
TILE_W,TILE_H=384,512
S=256
cv2.setNumThreads(2)

# Deterministic restoration prevents flickering fabricated texture detail.
print("RIN_STABLE_RESAMPLE_OK",flush=True)
yy,xx=np.mgrid[:S,:S].astype(np.float32)
grid=np.stack((xx,yy),axis=-1)
hy,hx=np.mgrid[:512,:512].astype(np.float32)
highgrid=np.stack((hx,hy),axis=-1)

def clean(a):
 a=a.copy()
 # Discard invisible encoder RGB. Keep the original matte and all garment details.
 a[a[:,:,3]<5]=0
 return a

def pm(a):
 a=a.astype(np.float32)/255
 a[:,:,:3]*=a[:,:,3:4]
 return a

def unpm(a):
 a=a.copy()
 a[:,:,:3]=np.divide(a[:,:,:3],a[:,:,3:4],out=np.zeros_like(a[:,:,:3]),where=a[:,:,3:4]>1e-5)
 a[a[:,:,3]<2/255]=0
 return np.clip(a*255+.5,0,255).astype(np.uint8)

def gray(a):
 # Include the silhouette so legs and hair remain tracked.
 p=pm(a)
 return np.clip((cv2.cvtColor(p[:,:,:3],cv2.COLOR_RGB2GRAY)*.72+p[:,:,3]*.28)*255,0,255).astype(np.uint8)

def flow(a,b):
 f=cv2.calcOpticalFlowFarneback(gray(a),gray(b),None,.5,5,19,5,7,1.5,0)
 # Suppress per-pixel optical-flow turbulence without freezing limb motion.
 return cv2.GaussianBlur(f,(0,0),2.4).astype(np.float32)

def restore(a):
 # Work in premultiplied RGB to keep soft alpha edges free of dark fringes.
 premul=pm(a)
 h,w=a.shape[:2]
 result=cv2.resize(premul,(w*2,h*2),interpolation=cv2.INTER_CUBIC)
 alpha=cv2.GaussianBlur(np.clip(result[:,:,3],0,1),(3,3),0.45)
 rgb=np.clip(result[:,:,:3],0,1)
 # Reduce encoder speckle before generating many in-between frames;
 # do not invent sharp details separately in each of the eight poses.
 rgb=cv2.bilateralFilter(rgb.astype(np.float32),5,0.035,2.0)
 rgb=np.minimum(rgb,alpha[:,:,None])
 return np.dstack((rgb,alpha)).astype(np.float32)

def high_flow(f):
 return cv2.resize(f,(512,512),interpolation=cv2.INTER_LINEAR)*2

def inverse(f,t):
 # Invert x->x+t*flow(x) with fixed-point refinement rather than
 # subtracting a forward displacement sampled at the wrong coordinate.
 m=highgrid-f*t
 for _ in range(2):
  sampled=cv2.remap(f,m,None,cv2.INTER_LINEAR,borderMode=cv2.BORDER_REPLICATE)
  m=highgrid-sampled*t
 return m

def tween(a,b,ab,ba,t):
 if t<1e-6:return a
 if t>1-1e-6:return b
 wa=cv2.remap(a,inverse(ab,t),None,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
 wb=cv2.remap(b,inverse(ba,1-t),None,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
 return wa*(1-t)+wb*t

for name,count in COUNTS.items():
 src=np.array(Image.open(ROOT/(name+".webp")).convert("RGBA"))
 assert src.shape[:2]==(768,2048),(name,src.shape)
 keys=[clean(src[(3*i)//8*S:((3*i)//8+1)*S,(3*i)%8*S:((3*i)%8+1)*S]) for i in range(8)]
 high=[restore(k) for k in keys]
 loop=name in LOOPS
 pairs=[(high_flow(flow(keys[i],keys[(i+1)%8])),high_flow(flow(keys[(i+1)%8],keys[i]))) for i in range(8 if loop else 7)]
 atlas=np.zeros(((count+7)//8*TILE_H,8*TILE_W,4),np.uint8)
 for i in range(count):
  phase=i*8/count if loop else i*7/(count-1)
  j=min(int(phase),len(pairs)-1)
  t=phase-j
  frame=unpm(tween(high[j],high[(j+1)%8],*pairs[j],t))[:,64:448]
  assert np.count_nonzero(frame[:,:,3]>30)>4000,(name,i)
  r,c=divmod(i,8)
  atlas[r*TILE_H:(r+1)*TILE_H,c*TILE_W:(c+1)*TILE_W]=frame
 Image.fromarray(atlas).save(ROOT/(name+"_smooth.webp"),lossless=True,method=3,exact=True)
 print("RIN_STABLE_CLIP",name,count,"frames",TILE_W,TILE_H,flush=True)
print("ATLAS_OK",sum(COUNTS.values()),flush=True)
