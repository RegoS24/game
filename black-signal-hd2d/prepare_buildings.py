"""Create deterministic detailed 4-view facades for six BLACK SIGNAL building archetypes.

These are original procedural game textures based on approved visual directions,
NOT 3D mesh/PBR maps and NOT direct copies of user generated reference sheets.
Tile: 256x384; atlas: 4 columns (front,left,back,right), 6 rows.
"""
from pathlib import Path
import random, math
from PIL import Image, ImageDraw, ImageFilter

TW, TH = 256, 384
OUT = Path(__file__).parent / "assets" / "buildings"
OUT.mkdir(parents=True, exist_ok=True)
STYLES = ["residential", "factory", "market", "corporate", "slum", "clinic"]
BASE = [(37,39,58),(48,54,64),(39,37,53),(37,53,69),(57,47,51),(48,62,79)]
ACCENT = [(245,61,171),(248,176,74),(242,74,181),(66,207,255),(255,93,115),(59,220,239)]
atlas = Image.new("RGBA",(TW*4,TH*6),(0,0,0,0))

def shade(rgb,n,alpha=255):
 return tuple(max(0,min(255,int(c+n))) for c in rgb)+(alpha,)
def rgba(rgb,a=255): return tuple(rgb)+(a,)
def frame(style,view):
 rng=random.Random(9217+style*113+view*7)
 im=Image.new("RGBA",(TW,TH))
 d=ImageDraw.Draw(im,"RGBA")
 w=[205,224,224,191,225,214][style]
 if view in (1,3):w=int(w*.76)
 left=(TW-w)//2
 top=[45,109,108,37,99,99][style]
 if view==2:top+=5
 bottom=TH-10
 accent=ACCENT[style]
 base=BASE[style]
 # Clean anti-aliased gradient panels, substantial trim, and inset sides.
 for y in range(top,bottom):
  t=(y-top)/max(1,bottom-top)
  darkness=int(-18*t+6*math.sin(t*4.0))
  d.line((left,y,left+w,y),fill=shade(base,darkness))
 d.rectangle((left,top,left+w,bottom),outline=shade(base,36),width=3)
 d.rectangle((left+8,top+8,left+w-8,bottom-13),outline=shade(base,-27),width=2)
 d.rectangle((left,top,left+15,bottom),fill=shade(base,-28))
 d.rectangle((left+w-14,top,left+w,bottom),fill=shade(base,-35))
 # Structural floor bands.
 floors= [7,3,4,9,5,4][style]
 usable=bottom-top-25
 unit=usable/floors
 for k in range(1,floors):
  y=int(top+k*unit)
  d.rectangle((left+11,y-4,left+w-11,y+4),fill=shade(base,-18))
  d.line((left+11,y-4,left+w-11,y-4),fill=shade(base,30),width=2)
 # Window / vent texture; different geometry per architectural type and view.
 cols=[4,4,4,5,5,4][style] if view in (0,2) else 2
 spacing=(w-35)/cols
 for fl in range(floors):
  for col in range(cols):
   if style==1 and fl==floors-1:continue
   x0=int(left+19+col*spacing);x1=int(x0+spacing*.66)
   y0=int(top+8+fl*unit);y1=int(y0+unit*.55)
   if y1>=bottom-14:continue
   d.rectangle((x0-3,y0-3,x1+3,y1+4),fill=shade(base,-32),outline=shade(base,28),width=2)
   lit=rng.random() < (.71 if style in (0,2,3,5) else .48)
   glass=(115,204,220) if style in (3,5) else (236,161,102)
   pane=shade(glass,-70 if not lit else rng.randint(-17,8))
   d.rectangle((x0,y0,x1,y1),fill=pane)
   d.line((x0+(x1-x0)//2,y0,x0+(x1-x0)//2,y1),fill=shade(base,-30),width=2)
   d.line((x0,y0+(y1-y0)//2,x1,y0+(y1-y0)//2),fill=shade(base,-18),width=1)
   if lit:
    d.line((x0+3,y0+3,x1-2,y0+3),fill=rgba((255,219,156),175),width=2)
   else:d.line((x0+2,y1-2,x1-2,y1-2),fill=rgba((89,106,122),125),width=2)
 # Facade wear and seam rivets are stable, no temporal noise or shimmer.
 for k in range(70):
  x=rng.randrange(left+10,left+w-10);y=rng.randrange(top+8,bottom-10)
  d.line((x,y,x+rng.randrange(1,5),y+rng.randrange(1,7)),
         fill=shade(base,rng.choice([-22,-14,9,15]),rng.randrange(55,125)),width=1)
 for k in range(7):
  x=left+int((k+.4)/7*w)
  d.line((x,top+5,x,bottom-12),fill=shade(base,-15,95),width=1)
 # Roof trim, aerials, ventilation and dish/tanks.
 d.rectangle((left-5,top-5,left+w+5,top+3),fill=shade(base,23))
 for j in range(3):
  x=left+20+j*(w-40)//2
  d.line((x,top-10,x,top-rng.randint(21,36)),fill=(95,113,125,255),width=2)
  d.ellipse((x-3,top-38,x+3,top-32),fill=rgba(accent))
 if style==1:
  for cx in (left+26,left+w-57):
   d.rectangle((cx,top-34,cx+24,top+7),fill=(74,83,91,255),outline=(191,146,94,255),width=2)
   for z in range(3): d.line((cx+3,top-30+z*8,cx+21,top-30+z*8),fill=(108,123,133,190))
  for j in range(4):
   x=left+24+j*int(w*.19)
   d.line((x,top+25,x,bottom-20),fill=(127,88,61,220),width=3)
   d.line((x+4,top+25,x+4,bottom-20),fill=(50,43,40,220),width=2)
  y=bottom-76
  d.rectangle((left+w//4,y,left+3*w//4,bottom-13),fill=(24,25,30,255),outline=(193,149,65,255),width=4)
  for k in range(11):
   yy=y+k*5;d.line((left+w//4+3,yy,left+3*w//4-3,yy),fill=(67,70,77,255))
  for k in range(10):
   x=left+w//4+k*(w//2)//10
   d.polygon([(x,bottom-15),(x+8,bottom-15),(x+16,bottom-8),(x+8,bottom-8)],fill=(217,151,53,245))
 elif style==2:
  # Pink street canopy and arched marketplace sign.
  d.polygon([(left-8,top+17),(left+w//2,top-25),(left+w+8,top+17),
             (left+w-9,top+38),(left+8,top+38)],fill=(181,36,110,240))
  for j in range(6):
   x=left+10+j*(w-20)//6
   d.line((x,top+40,x,top+65),fill=(235,154,83,190),width=2)
  for j in range(3):
   x=left+17+j*(w-35)//3
   d.rectangle((x,bottom-72,x+int(w*.23),bottom-15),
               fill=(25,28,40,255),outline=(247,107,176,255),width=2)
   d.polygon([(x-6,bottom-74),(x+int(w*.23)+7,bottom-74),
              (x+int(w*.23),bottom-60),(x,bottom-60)],fill=(176,38,119,255))
 elif style==3:
  d.rectangle((left+w//3,top+19,left+2*w//3,bottom-85),
             fill=(16,57,85,250),outline=(101,219,250,220),width=4)
  for i in range(11):
   y=top+24+i*max(1,(bottom-top-110)//11)
   d.line((left+w//3+3,y,left+2*w//3-3,y),fill=(85,170,220,100),width=1)
  cx=left+w//2;cy=top+int((bottom-top)*.35)
  d.ellipse((cx-25,cy-25,cx+25,cy+25),outline=rgba(accent),width=3)
  d.arc((cx-32,cy-8,cx+32,cy+8),10,170,fill=(102,240,255,255),width=3)
  d.rectangle((left+w//4,bottom-82,left+3*w//4,bottom-13),fill=(14,25,39,255),outline=(175,203,216,255),width=4)
 elif style==4:
  for i in range(5):
   x=left+12+i*(w-20)//5
   y=top+25+(i%3)*40
   d.rectangle((x,y,x+35,y+32),fill=(64,77,87,210),outline=(131,90,84,190),width=2)
   d.line((x,y+12,x+35,y+12),fill=(169,87,104,140),width=3)
  d.polygon([(left+12,top+26),(left+w*.8,top+13),(left+w-12,top+55),
             (left+40,top+65)],fill=(65,106,136,240))
  for k in range(4):
   y=bottom-40+k*4
   d.line((left+11,y,left+w-11,y+2),fill=(121,62,68,180),width=2)
 elif style==5:
  d.rectangle((left+14,top+20,left+w-14,top+119),fill=(22,63,86,245),outline=(91,194,225,255),width=3)
  for j in range(5):
   y=top+35+j*14;d.line((left+22,y,left+w-23,y),fill=(118,200,229,150))
  for k in range(2):
   x=left+20+k*(w-69)
   d.ellipse((x,top+140,x+36,top+176),outline=(155,174,191,255),width=4)
   for z in range(4):
    d.line((x+18,top+142,x+18,top+173),fill=(101,129,146,255))
  # Medical cross, consistently placed on two visible facades.
  if view in (0,3):
   cx=left+w//2;cy=top+52
   d.rectangle((cx-5,cy-20,cx+5,cy+20),fill=rgba(accent))
   d.rectangle((cx-20,cy-5,cx+20,cy+5),fill=rgba(accent))
 # Balcony railings, side pipes, rooftop signage.
 if style==0:
  for floor in range(1,6):
   y=int(top+floor*unit)-6
   d.rectangle((left+3,y,left+w-3,y+5),fill=(60,72,90,255))
   for x in range(left+8,left+w-6,11):
    d.line((x,y-12,x,y),fill=(145,162,171,190),width=1)
  d.rectangle((left+w//3,top+58,left+2*w//3,top+148),
              fill=(29,23,68,220),outline=rgba(accent),width=4)
  d.ellipse((left+w//2-21,top+80,left+w//2+21,top+125),outline=(130,96,252,255),width=3)
  d.arc((left+w//2-14,top+90,left+w//2+16,top+136),75,270,fill=(255,98,187,255),width=4)
 # Vertical glowing strips in all districts, with variations by viewing direction.
 glow=Image.new("RGBA",(TW,TH),(0,0,0,0))
 g=ImageDraw.Draw(glow,"RGBA")
 if style in (0,2,3,5):
  x=left+w-7 if view in (0,1) else left+8
  g.line((x,top+15,x,bottom-24),fill=rgba(accent,175),width=11)
  d.line((x,top+15,x,bottom-24),fill=rgba(accent,225),width=3)
 if style in (1,4):
  for j in range(4):
   x=left+12+j*(w-24)//4
   g.ellipse((x,top+10,x+9,top+20),fill=(249,171,104,150))
   d.ellipse((x+2,top+12,x+7,top+17),fill=(252,202,147,255))
 # Surface reflections and ambient bloom are pre-baked and stable frame to frame.
 bloom=glow.filter(ImageFilter.GaussianBlur(9.0))
 result=Image.alpha_composite(bloom,im)
 result=Image.alpha_composite(result,glow)
 return result

for s in range(6):
 for v in range(4):
  atlas.alpha_composite(frame(s,v),(v*TW,s*TH))
target=OUT/"facades.webp"
atlas.save(target,format="WEBP",quality=78,method=6,exact=True)
with Image.open(target) as check:
 assert check.size==(1024,2304),check.size
 assert check.mode=="RGBA"
 assert check.getpixel((10,10))[3]==0
print("BLACK_SIGNAL_BUILDINGS_READY",len(STYLES),4,target.stat().st_size,flush=True)
