"""Rin HD raster atlas preparation. Original eight key poses are retained.
Neural restoration is done once per key, then temporally coherent motion warps.
All pixels remain 2D. No runtime AI, skeleton or 3D character.
"""
from pathlib import Path
import os
import cv2
import numpy as np
from PIL import Image
import torch
from torch import nn
from torch.nn import functional as F

ROOT=Path(__file__).parent/"assets"
COUNTS={"idle":162,"walk":90,"jump":72,"crouch":45,"prone":61}
LOOPS={"idle","walk","run"}
TILE_W,TILE_H=384,512
S=256
cv2.setNumThreads(2)
torch.set_num_threads(2)
torch.set_num_interop_threads(1)

# Architecture of Real-ESRGAN anime video v3 (BSD-3-Clause).
# Weight source: official xinntao/Real-ESRGAN release v0.2.5.0.
class SRVGGNetCompact(nn.Module):
 def __init__(self):
  super().__init__()
  self.body=nn.ModuleList([nn.Conv2d(3,64,3,1,1),nn.PReLU(num_parameters=64)])
  for _ in range(16):
   self.body.extend([nn.Conv2d(64,64,3,1,1),nn.PReLU(num_parameters=64)])
  self.body.append(nn.Conv2d(64,48,3,1,1))
  self.upsampler=nn.PixelShuffle(4)
 def forward(self,x):
  y=x
  for layer in self.body:y=layer(y)
  return self.upsampler(y)+F.interpolate(x,scale_factor=4,mode="nearest")

model=SRVGGNetCompact().eval()
weights=torch.load(os.environ["RIN_SR_WEIGHTS"],map_location="cpu",weights_only=True)
model.load_state_dict(weights.get("params_ema",weights.get("params",weights)),strict=True)
print("RIN_NEURAL_WEIGHTS_OK",flush=True)
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
 return cv2.calcOpticalFlowFarneback(gray(a),gray(b),None,.5,5,19,5,7,1.5,0)

def restore(a):
 mask=a[:,:,3]>8
 ys,xs=np.nonzero(mask)
 assert len(xs)>1000
 x0,x1=max(0,int(xs.min())-16),min(S,int(xs.max())+17)
 y0,y1=max(0,int(ys.min())-16),min(S,int(ys.max())+17)
 crop=a[y0:y1,x0:x1]
 inside=crop[:,:,3]>24
 # Extend foreground colors into transparent pixels before enhancement.
 _,labels=cv2.distanceTransformWithLabels((~inside).astype(np.uint8),cv2.DIST_L2,5,labelType=cv2.DIST_LABEL_PIXEL)
 colors=np.zeros((int(labels.max())+1,3),np.uint8)
 colors[labels[inside]]=crop[:,:,:3][inside]
 rgb=colors[labels]
 inp=torch.from_numpy(rgb.copy()).permute(2,0,1).unsqueeze(0).float()/255
 with torch.inference_mode():
  out=model(inp).clamp(0,1)[0].permute(1,2,0).numpy()
 h,w=inside.shape
 sharpened=cv2.resize(out,(w*2,h*2),interpolation=cv2.INTER_AREA)
 # Mix with the original reconstruction to avoid invented hard ink outlines.
 base=cv2.resize(pm(crop),(w*2,h*2),interpolation=cv2.INTER_CUBIC)
 base_alpha=np.clip(base[:,:,3:4],0,1)
 base_rgb=np.divide(base[:,:,:3],base_alpha,out=sharpened.copy(),where=base_alpha>1e-3)
 rgb=np.clip(sharpened*.65+base_rgb*.35,0,1)
 alpha=np.clip(cv2.resize(crop[:,:,3].astype(np.float32)/255,(w*2,h*2),interpolation=cv2.INTER_CUBIC),0,1)
 result=np.zeros((512,512,4),np.float32)
 result[y0*2:y1*2,x0*2:x1*2]=np.dstack((rgb*alpha[:,:,None],alpha))
 return result

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
 print(name,count,"frames",TILE_W,TILE_H,flush=True)
print("ATLAS_OK",sum(COUNTS.values()),flush=True)
