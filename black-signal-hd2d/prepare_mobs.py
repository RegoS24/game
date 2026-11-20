"""Pack front art and existing side/rear motion into one bounded mobile atlas per unit."""
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).parent/"assets/mobs"
W,H=192,224
def cell(im,i):
 x,y=i%6*W,i//6*H
 return im.crop((x,y,x+W,y+H))
def bounds(im):
 a=im.getchannel("A").point(lambda x:255 if x>85 else 0)
 return a.getbbox()
def normalizer(keys,drone):
 hs=[b[3]-b[1] for im in keys if (b:=bounds(im))]
 scale=(74 if drone else 184)/max(1,float(np.median(hs)))
 def norm(im):
  b=bounds(im)
  tile=Image.new("RGBA",(W,H))
  if not b:return tile
  l,t,r,d=b
  crop=im.crop((max(0,l-2),max(0,t-2),min(W,r+2),min(H,d+2)))
  w,h=crop.size;s=min(scale,(W-4)/w,(209-2)/h)
  w,h=max(1,round(w*s)),max(1,round(h*s))
  crop=crop.resize((w,h),Image.Resampling.LANCZOS)
  tile.paste(crop,((W-w)//2,209-h))
  return tile
 return norm
for n in ("raider","guard","brute","hacker","hound","drone"):
 front=Image.open(root/(n+"_front.webp")).convert("RGBA")
 side=Image.open(root/(n+".webp")).convert("RGBA")
 rear=Image.open(root/(n+"_direction.webp")).convert("RGBA")
 assert front.size==(1152,2688) and side.size==(1152,3360) and rear.size==(1152,2688)
 out=Image.new("RGBA",(1536,3584))
 def put(i,im):out.paste(im,(i%8*W,i//8*H))
 for i in range(72):put(i,cell(front,i))
 normalize=normalizer([cell(side,i) for i in range(0,18,3)],n=="drone")
 for state in range(5):
  for i in range(6):put(72+state*6+i,normalize(cell(side,state*18+i*3 if state<3 else state*18+round(i*17/5))))
 normalize=normalizer([cell(rear,i) for i in range(48,60)],n=="drone")
 for i in range(24):put(102+i,normalize(cell(rear,48+i)))
 out.save(root/(n+"_combat.webp"),quality=93,alpha_quality=100,method=4,exact=True)
 print("MOB_ATLAS_OK",n,126,flush=True)
