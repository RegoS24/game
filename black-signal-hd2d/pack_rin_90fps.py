"""Trim transparent borders without changing scale, and split atlases <=4096px."""
from pathlib import Path
from PIL import Image
import json
import math

root=Path(__file__).parent
assets=root/"assets"
out=assets/"rin90"
out.mkdir(exist_ok=True)
W,H=384,512
LIMIT=4096
COUNTS={"idle":162,"walk":90,"run":72,"jump":72,"crouch":45,"prone":61,"crouch_walk":104,"crawl":136}
layouts={}
sheets={}
total_pixels=0
for name,count in COUNTS.items():
 src=assets/(name+"_smooth.webp")
 im=Image.open(src).convert("RGBA")
 assert im.size==(8*W,math.ceil(count/8)*H),(name,im.size)
 def frame(i):
  x,y=i%8*W,i//8*H
  return im.crop((x,y,x+W,y+H))
 boxes=[frame(i).getchannel("A").getbbox() for i in range(count)]
 assert all(boxes),(name,"empty frame")
 left=max(0,min(b[0] for b in boxes)-2)
 top=max(0,min(b[1] for b in boxes)-2)
 right=min(W,max(b[2] for b in boxes)+2)
 bottom=min(H,max(b[3] for b in boxes)+2)
 tile_w=right-left
 tile_h=bottom-top
 cols=min(count,LIMIT//tile_w)
 cap=cols*(LIMIT//tile_h)
 layouts[name]=[left,top,tile_w,tile_h,cols,cap]
 sheets[name]=[]
 for page,start in enumerate(range(0,count,cap)):
  size=min(cap,count-start)
  used_cols=min(cols,size)
  rows=math.ceil(size/cols)
  atlas=Image.new("RGBA",(used_cols*tile_w,rows*tile_h))
  assert max(atlas.size)<=LIMIT
  for j in range(size):
   tile=frame(start+j).crop((left,top,right,bottom))
   atlas.paste(tile,(j%cols*tile_w,j//cols*tile_h))
  target=out/f"{name}_{page}.webp"
  atlas.save(target,lossless=True,method=3,exact=True)
  # Ensure the packer preserved RGBA data and page dimensions.
  with Image.open(target) as verify:
   assert verify.size==atlas.size
  total_pixels+=atlas.width*atlas.height
  sheets[name].append("res://assets/rin90/"+target.name)
  print("RIN90_PAGE",name,page,size,atlas.size,flush=True)
 im.close()
 src.unlink() # do not include or import the oversized temporary full atlas
lines=["extends RefCounted","# Generated at build time, do not edit.","const LAYOUT = "+json.dumps(layouts,separators=(",",":")),"const SHEETS = {"]
for name,paths in sheets.items():
 lines.append(" "+json.dumps(name)+":["+",".join("preload("+json.dumps(p)+")" for p in paths)+"],")
lines.append("}")
(root/"scripts/rin_frames_generated.gd").write_text("\n".join(lines)+"\n")
assert sum(COUNTS.values())==742
print("RIN90_READY",sum(COUNTS.values()),"RGBA_MiB",round(total_pixels*4/1024**2,1),flush=True)
