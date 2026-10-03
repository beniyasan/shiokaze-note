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
# Hero 32x48, 4 facings x 4 walk frames.  The player is authored at the
# reference's intended cell size rather than being a lightly-upscaled 16x24
# icon.  The world still uses 16px tiles, so this sprite is two tiles tall and
# its feet stay on the existing player anchor.  Each frame is nearest-neighbor
# pixel art with a dark keyed outline, an identifiable brimmed cap, fishing rod,
# layered vest and a side tackle bag.
a,p=canvas(128,192)
COL={
 'shadow':'#526750', 'outline':'#2a2030', 'deep':'#3a2639', 'ink':'#241b2a',
 'boot':'#293b49', 'boot_hi':'#526975', 'pants':'#465761',
 'skin':'#e5b77f', 'skin_hi':'#f2cf96', 'skin_shadow':'#a96155',
 'hair':'#6b3f45', 'hair_hi':'#a8604e', 'shirt':'#d7bf8b',
 'shirt_shadow':'#a88463', 'vest':'#347477', 'vest_hi':'#79aa96',
 'vest_shadow':'#24535f', 'vest_edge':'#1d3d50', 'cap':'#405f72',
 'cap_hi':'#7fa194', 'cap_shadow':'#263e58', 'cap_band':'#d0ac63',
 'bag':'#815640', 'bag_hi':'#bd8853', 'rod':'#514047',
 'rod_hi':'#d5ae68', 'metal':'#d8d5ad'
}

def _px(draw, ox, oy, box, color):
    x0,y0,x1,y1=box; draw.rectangle((ox+x0,oy+y0,ox+x1,oy+y1),fill=color)

def _poly(draw, ox, oy, points, color):
    draw.polygon([(ox+x,oy+y) for x,y in points],fill=color)

def _line(draw, ox, oy, points, color, width=1):
    draw.line([(ox+x,oy+y) for x,y in points],fill=color,width=width)

def _front(draw, ox, oy, stride):
    # Rod is held outside the shoulder, with a warm highlight like the sample.
    _line(draw,ox,oy,[(24,30),(28,17),(31,3)],COL['rod'],2)
    _line(draw,ox,oy,[(25,28),(29,16),(31,6)],COL['rod_hi'],1)
    # Crown, under-brim shadow, and a broad cap brim.
    _px(draw,ox,oy,(10,2,22,9),COL['ink']); _px(draw,ox,oy,(12,1,20,3),COL['cap_shadow'])
    _poly(draw,ox,oy,[(11,4),(14,1),(21,2),(24,7),(22,11),(9,11)],COL['cap'])
    _px(draw,ox,oy,(13,3,19,5),COL['cap_hi']); _px(draw,ox,oy,(9,9,23,11),COL['cap_shadow'])
    _px(draw,ox,oy,(6,10,26,13),COL['ink']); _px(draw,ox,oy,(7,10,25,11),COL['cap_band'])
    _px(draw,ox,oy,(9,11,23,12),COL['cap_hi'])
    # Face, hair, ears and neck; the two-pixel eye line survives the map scale.
    _px(draw,ox,oy,(9,14,23,24),COL['ink']); _px(draw,ox,oy,(11,14,21,23),COL['skin'])
    _px(draw,ox,oy,(9,15,11,22),COL['hair']); _px(draw,ox,oy,(21,15,23,22),COL['hair'])
    _px(draw,ox,oy,(10,15,11,17),COL['hair_hi']); _px(draw,ox,oy,(21,15,22,17),COL['skin_hi'])
    _px(draw,ox,oy,(12,14,20,15),COL['skin_shadow']); _px(draw,ox,oy,(13,18,14,19),COL['ink']); _px(draw,ox,oy,(19,18,20,19),COL['ink'])
    _px(draw,ox,oy,(15,21,18,22),COL['skin_shadow']); _px(draw,ox,oy,(14,23,19,26),COL['skin'])
    # Shoulders, shirt sleeves, and the vest's offset panels and pockets.
    _px(draw,ox,oy,(6,25,10,35),COL['ink']); _px(draw,ox,oy,(22,25,26,35),COL['ink'])
    _px(draw,ox,oy,(7,25,10,33),COL['shirt']); _px(draw,ox,oy,(23,25,25,33),COL['shirt'])
    _px(draw,ox,oy,(9,24,23,36),COL['vest_edge']); _px(draw,ox,oy,(11,25,21,35),COL['vest'])
    _px(draw,ox,oy,(12,26,14,34),COL['vest_hi']); _px(draw,ox,oy,(19,26,21,35),COL['vest_shadow'])
    _px(draw,ox,oy,(14,25,18,27),COL['shirt']); _px(draw,ox,oy,(14,29,14,30),COL['cap_band']); _px(draw,ox,oy,(19,29,19,30),COL['cap_band'])
    _px(draw,ox,oy,(15,30,16,33),COL['metal']); _px(draw,ox,oy,(18,31,19,33),COL['metal'])
    # Buckled tackle bag and hands give the silhouette an asymmetrical authored cue.
    _px(draw,ox,oy,(23,28,29,37),COL['ink']); _px(draw,ox,oy,(24,29,28,36),COL['bag']); _px(draw,ox,oy,(25,29,28,31),COL['bag_hi']); _px(draw,ox,oy,(26,32,27,32),COL['metal'])
    _px(draw,ox,oy,(5,30,8,34),COL['skin']); _px(draw,ox,oy,(24,31,26,35),COL['skin_hi'])
    # Separated trouser legs and thick boots. stride is -1, 0, or +1.
    _px(draw,ox,oy,(9,35,15,42),COL['pants']); _px(draw,ox,oy,(18,35,24,42),COL['pants'])
    _px(draw,ox,oy,(9,41+stride,15,45+stride),COL['boot']); _px(draw,ox,oy,(18,41-stride,24,45-stride),COL['boot'])
    _px(draw,ox,oy,(10,42+stride,14,42+stride),COL['boot_hi']); _px(draw,ox,oy,(19,42-stride,23,42-stride),COL['boot_hi'])

def _back(draw, ox, oy, stride):
    _line(draw,ox,oy,[(8,31),(5,17),(1,3)],COL['rod'],2); _line(draw,ox,oy,[(7,29),(4,16),(1,6)],COL['rod_hi'],1)
    _px(draw,ox,oy,(10,2,22,9),COL['ink']); _poly(draw,ox,oy,[(11,4),(14,1),(21,2),(24,7),(22,11),(9,11)],COL['cap'])
    _px(draw,ox,oy,(13,3,19,5),COL['cap_hi']); _px(draw,ox,oy,(9,9,23,11),COL['cap_shadow']); _px(draw,ox,oy,(6,10,26,13),COL['ink']); _px(draw,ox,oy,(7,10,25,11),COL['cap_band']); _px(draw,ox,oy,(9,11,23,12),COL['cap_hi'])
    # Hair and neck are shaded darker than the front so the back read is clear.
    _px(draw,ox,oy,(9,14,23,24),COL['ink']); _px(draw,ox,oy,(11,14,21,23),COL['hair']); _px(draw,ox,oy,(13,14,19,16),COL['hair_hi']); _px(draw,ox,oy,(14,23,19,26),COL['skin'])
    _px(draw,ox,oy,(6,25,10,35),COL['ink']); _px(draw,ox,oy,(22,25,26,35),COL['ink']); _px(draw,ox,oy,(7,25,10,33),COL['shirt']); _px(draw,ox,oy,(23,25,25,33),COL['shirt'])
    _px(draw,ox,oy,(9,24,23,36),COL['vest_edge']); _px(draw,ox,oy,(11,25,21,35),COL['vest']); _px(draw,ox,oy,(12,26,14,34),COL['vest_hi']); _px(draw,ox,oy,(19,26,21,35),COL['vest_shadow'])
    # Cross-body strap and pack separate the rear silhouette from the front.
    _line(draw,ox,oy,[(11,25),(21,36)],COL['bag_hi'],2); _px(draw,ox,oy,(22,28,29,38),COL['ink']); _px(draw,ox,oy,(23,29,28,37),COL['bag']); _px(draw,ox,oy,(24,29,28,31),COL['bag_hi']); _px(draw,ox,oy,(25,33,26,33),COL['metal'])
    _px(draw,ox,oy,(5,30,8,34),COL['skin']); _px(draw,ox,oy,(24,31,26,35),COL['skin'])
    _px(draw,ox,oy,(9,35,15,42),COL['pants']); _px(draw,ox,oy,(18,35,24,42),COL['pants']); _px(draw,ox,oy,(9,41+stride,15,45+stride),COL['boot']); _px(draw,ox,oy,(18,41-stride,24,45-stride),COL['boot']); _px(draw,ox,oy,(10,42+stride,14,42+stride),COL['boot_hi']); _px(draw,ox,oy,(19,42-stride,23,42-stride),COL['boot_hi'])

def _side(draw, ox, oy, stride, right=False):
    # Draw a right-facing profile, then mirror it for the left facing row.
    def X(x): return x if right else 31-x
    def box(b):
        x0,y0,x1,y1=b; return (min(X(x0),X(x1)),y0,max(X(x0),X(x1)),y1)
    def px(b,c): _px(draw,ox,oy,box(b),c)
    def poly(points,c): _poly(draw,ox,oy,[(X(x),y) for x,y in points],c)
    def ln(points,c,w=1): _line(draw,ox,oy,[(X(x),y) for x,y in points],c,w)
    ln([(23,31),(28,17),(31,3)],COL['rod'],2); ln([(24,29),(29,16),(31,6)],COL['rod_hi'],1)
    px((11,2,22,9),COL['ink']); poly([(12,4),(15,1),(21,2),(24,7),(22,11),(10,11)],COL['cap']); px((14,3,20,5),COL['cap_hi']); px((10,9,23,11),COL['cap_shadow']); px((6,10,27,13),COL['ink']); px((7,10,26,11),COL['cap_band']); px((10,11,23,12),COL['cap_hi'])
    # Nose, one eye and a swept lock make travel direction unambiguous.
    px((10,14,23,24),COL['ink']); px((12,14,21,23),COL['skin']); px((10,15,13,22),COL['hair']); px((12,15,14,17),COL['hair_hi']); px((21,17,24,20),COL['skin_hi']); px((18,18,19,19),COL['ink']); px((15,22,20,26),COL['skin'])
    px((7,25,12,35),COL['ink']); px((22,25,26,35),COL['ink']); px((8,25,12,33),COL['shirt']); px((23,25,25,33),COL['shirt_shadow']); px((10,24,23,36),COL['vest_edge']); px((12,25,21,35),COL['vest']); px((13,26,15,34),COL['vest_hi']); px((19,26,21,35),COL['vest_shadow']); px((15,28,15,30),COL['cap_band']); px((17,30,18,33),COL['metal'])
    # Bag sits behind the shoulder on the side profile.
    px((4,28,10,38),COL['ink']); px((5,29,9,37),COL['bag']); px((6,29,9,31),COL['bag_hi']); px((7,33,8,33),COL['metal']); px((23,31,26,35),COL['skin'])
    px((10,35,16,42),COL['pants']); px((18,35,24,42),COL['pants']); px((10,41+stride,16,45+stride),COL['boot']); px((18,41-stride,24,45-stride),COL['boot']); px((11,42+stride,15,42+stride),COL['boot_hi']); px((19,42-stride,23,42-stride),COL['boot_hi'])

for face in range(4):
    for frame in range(4):
        x,y=frame*32,face*48
        bob=1 if frame in [1,3] else 0
        stride=1 if frame==1 else (-1 if frame==3 else 0)
        # A soft two-pixel ground shadow stays anchored while the body bobs.
        p.ellipse((x+5,y+44,x+26,y+47),fill=COL['shadow'])
        ox,oy=x,y+bob
        if face == 0: _front(p,ox,oy,stride)
        elif face == 1: _back(p,ox,oy,stride)
        else: _side(p,ox,oy,stride,right=face==3)
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
