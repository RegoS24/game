"""Create denser atlases from the eight original keyed poses.
Bidirectional optical flow and premultiplied RGBA prevent dark interpolation halos.
All output is raster 2D. Original atlases are left unchanged."""
from pathlib import Path
import cv2
import numpy as np
from PIL import Image
root=Path(__file__).parent/"assets"
counts={"idle":32,"walk":40,"run":40,"jump":36,"crouch":32,"prone":36}
yy,xx=np.mgrid[:256,:256].astype(np.float32)
grid=np.stack((xx,yy),axis=-1)
def pm(a):
 a=a.astype(np.float32)/255
 a[:,:,:3]*=a[:,:,3:4]
 return a
def gray(a):
 return cv2.cvtColor((pm(a)[:,:,:3]*255).astype(np.uint8),cv2.COLOR_RGB2GRAY)
def flow(a,b):
 return cv2.calcOpticalFlowFarneback(gray(a),gray(b),None,.5,4,21,4,7,1.5,0)
def tween(a,b,ab,ba,t):
 if t<1e-6:return a
 if t>1-1e-6:return b
 wa=cv2.remap(pm(a),grid-ab*t,None,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
 wb=cv2.remap(pm(b),grid-ba*(1-t),None,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
 v=wa*(1-t)+wb*t
 v[:,:,:3]=np.divide(v[:,:,:3],v[:,:,3:4],out=np.zeros_like(v[:,:,:3]),where=v[:,:,3:4]>1e-5)
 return np.clip(v*255+.5,0,255).astype(np.uint8)
for name,count in counts.items():
 src=np.array(Image.open(root/(name+".webp")).convert("RGBA"))
 keys=[src[(3*i)//8*256:((3*i)//8+1)*256,(3*i)%8*256:((3*i)%8+1)*256].copy() for i in range(8)]
 loop=name in ("idle","walk","run")
 pairs=[(flow(keys[i],keys[(i+1)%8]),flow(keys[(i+1)%8],keys[i])) for i in range(8 if loop else 7)]
 atlas=np.zeros(((count+7)//8*256,2048,4),np.uint8)
 for i in range(count):
  phase=i*8/count if loop else i*7/(count-1)
  j=min(int(phase),len(pairs)-1)
  t=phase-j
  im=tween(keys[j],keys[(j+1)%8],*pairs[j],t)
  assert np.count_nonzero(im[:,:,3]>30)>1000, (name,i)
  r,c=divmod(i,8);atlas[r*256:(r+1)*256,c*256:(c+1)*256]=im
 Image.fromarray(atlas).save(root/(name+"_smooth.webp"),lossless=True,method=4)
 print(name,count,"frames",flush=True)
print("ATLAS_OK",sum(counts.values()))
