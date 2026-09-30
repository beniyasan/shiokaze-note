"""Generate original, grid-aligned pixel art. No third-party art assets."""
from PIL import Image, ImageDraw
from pathlib import Path
import random
ROOT=Path(__file__).resolve().parents[1]/'assets'; ROOT.mkdir(exist_ok=True)
r=random.Random(90210)
W,H=1024,640
im=Image.new('RGBA',(W,H),'#427e77'); d=ImageDraw.Draw(im)
def shore(x): return 464 + (0 if x<240 else 16 if x<416 else 0 if x<608 else -16 if x<752 else -32)
def land(x,y): return 24<=x<832 and 24<=y<shore(x)
for y in range(H):
 for x in range(W):
  s=shore(x)
  if land(x,y): c='#78945b' if y<s-48 else '#d9bd80' if y<s-8 else '#bda875'
  elif x<832 and s<=y<s+10: c='#77b6a4'
  elif x<850 and y<shore(x)+36 and y>24: c='#549b99'
  else: c='#367e8b'
  im.putpixel((x,y),tuple(bytes.fromhex(c[1:]))+(255,))
# textured grass blades, sand speckles, sparse water glints
for _ in range(13500):
 x,y=r.randrange(W),r.randrange(H); s=shore(x)
 if land(x,y) and y<s-48:
  c=r.choice(['#809e62','#6f8c54','#87a263']); d.line((x,y,x+1,y),fill=c)
  if r.random()<.12: d.point((x+1,y-1),fill=c)
 elif land(x,y): d.point((x,y),fill=r.choice(['#c8ac74','#e7ce95']))
 elif r.random()<.09: d.line((x,y,x+r.randrange(2,7),y),fill='#498e98')
# cobbled paths
for box in [(352,185,384,439),(190,345,552,367),(486,340,512,469),(245,316,273,359),(410,314,438,357)]:
 d.rectangle(box,fill='#bcae87')
 for y in range(box[1]+2,box[3],7):
  for x in range(box[0]+2+(y%2)*3,box[2],9):
   d.line((x,y,x+5,y),fill='#cfbf97'); d.point((x+6,y+2),fill='#9b9777')
# flower garden beds
for bx,by in [(214,322),(302,321),(410,370),(450,370)]:
 d.rectangle((bx,by,bx+17,by+8),fill='#667c4c')
 for q in range(7):
  x,y=bx+r.randrange(16),by+r.randrange(7)
  d.line((x,y,x,y+2),fill='#425f42'); d.point((x,y-1),fill=r.choice(['#edc478','#e9a583','#dfdbae']))
# pier 32px wide, extending from sand into sea
for y in range(448,547,5):
 d.rectangle((486,y,518,y+3),fill='#987b53'); d.line((488,y,516,y),fill='#b19668'); d.point((492,y+2),fill='#614e3c'); d.point((513,y+2),fill='#614e3c')
for x in (483,519):
 for y in (448,472,496,520,544):
  d.rectangle((x,y,x+3,y+5),fill='#4d5144'); d.rectangle((x,y-2,x+3,y),fill='#b59b71')
# stone well plaza
for y in range(380,417,8):
 for x in range(333,399,10):
  d.rectangle((x+(y%3),y,x+7+(y%3),y+5),fill=r.choice(['#a5a995','#969e89','#b2b39a']))
im.save(ROOT/'terrain.png')

def canvas(w,h):
 a=Image.new('RGBA',(w,h)); return a,ImageDraw.Draw(a)
# cottage, tavern, fishing shop. Rich small eaves/roof tiles/windows.
for name,w,h,roof in [('cottage',64,65,'#a55f4e'),('inn',80,80,'#697e85'),('shop',64,64,'#a57c4c')]:
 a,p=canvas(w,h)
 p.ellipse((3,h-10,w-1,h-1),fill='#52674c')
 p.rectangle((7,29,w-8,h-7),fill='#756249'); p.rectangle((10,30,w-11,h-10),fill='#d4bf90')
 for yy in range(37,h-10,8): p.line((11,yy,w-12,yy),fill='#b9a77e')
 for xx in [10,w-13,w//2-2]: p.rectangle((xx,30,xx+2,h-9),fill='#876f4d')
 p.polygon([(2,30),(12,5),(w-14,5),(w-2,30)],fill='#493f3b')
 p.polygon([(4,27),(14,7),(w-16,7),(w-5,27)],fill=roof)
 for yy in range(10,28,5):
  left=14-(yy-7)//2; right=w-16+(yy-7)//2
  p.line((left,yy,right,yy),fill='#c18b68' if name!='inn' else '#92a7a0')
  for xx in range(left+3+(yy%2)*3,right,8): p.line((xx,yy-3,xx-1,yy-1),fill='#79554a' if name!='inn' else '#4e6670')
 p.rectangle((14,1,21,14),fill='#776859'); p.rectangle((13,0,22,3),fill='#b3a58a')
 p.rectangle((3,28,w-4,31),fill='#4c4940'); p.line((5,28,w-6,28),fill='#dbb786')
 for xx in [15,w-25]:
  p.rectangle((xx,37,xx+10,48),fill='#655b44'); p.rectangle((xx+1,38,xx+9,46),fill='#587c79')
  p.line((xx+2,39,xx+4,39),fill='#bed3b1'); p.line((xx+5,38,xx+5,47),fill='#d7c493'); p.line((xx,48,xx+11,48),fill='#ead6a4')
 p.rectangle((w//2-5,h-26,w//2+5,h-7),fill='#655540'); p.rectangle((w//2-3,h-24,w//2+3,h-9),fill='#8e7850'); p.point((w//2+2,h-16),fill='#efd598')
 p.rectangle((w//2-7,h-8,w//2+7,h-5),fill='#bcb392')
 if name=='shop':
  p.rectangle((8,49,27,52),fill='#577a71'); p.line((10,50,24,50),fill='#a3c2a1')
 a.save(ROOT/(name+'.png'))
# irregular evergreen tree, 32x45 px
for variant in range(3):
 a,p=canvas(36,48)
 p.ellipse((4,38,32,47),fill='#516a49'); p.rectangle((16,27,20,43),fill='#68563f'); p.line((17,28,17,41),fill='#a08657')
 for cx,cy,rad in [(17,13,12),(11,22,10),(24,22,10),(17,28,12),(17,7,7)]:
  p.polygon([(cx,cy-rad),(cx+rad-2,cy-4),(cx+rad,cy+5),(cx+6,cy+rad-1),(cx-7,cy+rad),(cx-rad,cy+4),(cx-rad+1,cy-4)],fill=['#365e49','#38664c','#416d4e'][variant])
  p.line((cx-7,cy-2,cx-4,cy-5,cx+3,cy-5),fill='#65905a',width=2)
  p.line((cx+2,cy+5,cx+7,cy+3),fill='#294e42',width=2)
 a.save(ROOT/f'tree{variant}.png')
# Hero 16x24, 4 facings x 4 walk frames.
a,p=canvas(64,96)
for face in range(4):
 for frame in range(4):
  x,y=frame*16,face*24; bob=1 if frame in [1,3] else 0; yy=y+bob
  p.ellipse((x+3,y+20,x+13,y+23),fill='#526750')
  stride=1 if frame==1 else -1 if frame==3 else 0
  p.rectangle((x+4,yy+17,x+6,yy+20+stride),fill='#344454'); p.rectangle((x+9,yy+17,x+11,yy+20-stride),fill='#344454')
  p.rectangle((x+3,yy+21+stride,x+6,yy+21+stride),fill='#303b42'); p.rectangle((x+9,yy+21-stride,x+12,yy+21-stride),fill='#303b42')
  p.rectangle((x+4,yy+10,x+11,yy+17),fill='#e5c68a'); p.rectangle((x+5,yy+12,x+10,yy+17),fill='#5a8392')
  p.rectangle((x+3,yy+12,x+4,yy+16),fill='#e6b480'); p.rectangle((x+11,yy+12,x+12,yy+16),fill='#e6b480')
  p.rectangle((x+5,yy+5,x+10,yy+10),fill='#edc394'); p.rectangle((x+4,yy+3,x+11,yy+6),fill='#79553f')
  p.rectangle((x+4,yy+2,x+11,yy+4),fill='#d8b879'); p.rectangle((x+2,yy+5,x+13,yy+6),fill='#f0d499'); p.line((x+4,yy+4,x+11,yy+4),fill='#607d83')
  if face==0:
   p.point((x+6,yy+8),fill='#374648'); p.point((x+10,yy+8),fill='#374648'); p.point((x+8,yy+10),fill='#bc8760')
  elif face==1: p.rectangle((x+5,yy+7,x+10,yy+10),fill='#79553f'); p.rectangle((x+6,yy+12,x+10,yy+16),fill='#ab8659')
  else: p.point((x+(5 if face==2 else 10),yy+8),fill='#374648')
a.save(ROOT/'hero.png')
# small props
for name in ['barrel','sign','rock','well','reeds']:
 a,p=canvas(24,28)
 if name=='barrel':
  p.ellipse((5,20,21,26),fill='#536849'); p.rectangle((6,10,18,23),fill='#93764e'); p.ellipse((6,7,18,12),fill='#b89c69')
  for xx in [8,12,16]: p.line((xx,12,xx,21),fill='#6d5b43')
  for yy in [13,20]: p.line((6,yy,18,yy),fill='#515a52')
 elif name=='sign':
  p.rectangle((11,10,13,26),fill='#766447'); p.rectangle((3,6,22,16),fill='#715c42'); p.rectangle((4,7,21,14),fill='#c7aa71'); p.line((8,10,18,10),fill='#665d47'); p.line((15,8,18,10,15,12),fill='#665d47')
 elif name=='rock':
  p.polygon([(3,23),(2,16),(8,10),(17,9),(23,17),(21,24)],fill='#717f79'); p.polygon([(4,16),(9,11),(16,11),(19,15),(11,18)],fill='#a3aaa0'); p.line((5,21,15,23,21,20),fill='#566862')
 elif name=='well':
  p.ellipse((1,16,23,27),fill='#596b55'); p.rectangle((3,12,21,22),fill='#8e9a8e'); p.ellipse((3,8,21,17),fill='#bac1a4'); p.ellipse((6,10,18,14),fill='#3c6269'); p.line((4,19,20,19),fill='#697b72'); p.line((11,17,11,22),fill='#697b72')
  p.rectangle((3,2,5,16),fill='#856c4b'); p.rectangle((19,2,21,16),fill='#856c4b'); p.line((3,2,21,2),fill='#b39867',width=2)
 else:
  for xx,hh in [(4,12),(9,19),(14,15),(19,22)]:
   p.line((12,27,xx,hh),fill='#6e8654'); p.line((xx,hh,xx,hh-4),fill='#a89258',width=2)
 a.save(ROOT/(name+'.png'))
print('Original pixel assets generated')
