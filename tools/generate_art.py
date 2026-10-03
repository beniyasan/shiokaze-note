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
# Hero 16x24, 4 facings x 4 walk frames.  This is intentionally drawn at the
# native pixel size: the broad cap brim, diagonal rod and little tackle bag
# are the silhouette cues that should still read when the player is tiny on the
# map.  Keep every shape grid-aligned so the game's nearest-neighbour filter
# preserves the hand-pixeled edges.
a,p=canvas(64,96)
COL={
 'shadow':'#526750', 'outline':'#29313f', 'ink':'#382b3b', 'boot':'#2d3b46',
 'boot_hi':'#40545a', 'pants':'#3d555b', 'skin':'#e5b77f',
 'skin_hi':'#f0cb91', 'skin_shadow':'#b9795b', 'hair':'#75483f', 'hair_hi':'#a7624c', 'shirt':'#d8c08b',
 'vest':'#3d7172', 'vest_hi':'#6e9a8d', 'vest_shadow':'#31565d',
 'vest_edge':'#244b58', 'cap':'#587a78', 'cap_hi':'#88a694', 'cap_shadow':'#34555f', 'cap_band':'#d0ad67',
 'bag':'#8c6348', 'bag_hi':'#bb8a58', 'rod':'#60493c',
 'rod_hi':'#d0aa6a', 'metal':'#d7d5ad'
}

def _px(draw, ox, oy, box, color):
    """Draw a rectangle in frame-local coordinates."""
    x0,y0,x1,y1=box; draw.rectangle((ox+x0,oy+y0,ox+x1,oy+y1),fill=color)

def _line(draw, ox, oy, points, color, width=1):
    draw.line([(ox+x,oy+y) for x,y in points],fill=color,width=width)

def _front(draw, ox, oy, frame):
    # Rod sits outside the shoulder so it reads as a fishing tool, not a sword.
    _line(draw,ox,oy,[(12,16),(14,9),(15,3)],COL['rod'],1)
    _line(draw,ox,oy,[(13,15),(15,8)],COL['rod_hi'],1)
    # Cap + brim. The little light band is visible against every background.
    # Deep under-pixels give the hat a shaped crown instead of a flat bar.
    _px(draw,ox,oy,(4,1,11,4),COL['ink']); _px(draw,ox,oy,(5,0,10,1),COL['ink'])
    _px(draw,ox,oy,(4,2,11,3),COL['cap']); _px(draw,ox,oy,(5,1,10,2),COL['cap_hi'])
    _px(draw,ox,oy,(4,3,11,4),COL['cap_shadow']); _px(draw,ox,oy,(3,4,13,5),COL['ink'])
    _px(draw,ox,oy,(3,4,13,4),COL['cap_band']); _px(draw,ox,oy,(4,4,11,4),COL['cap_hi'])
    # Face, ears, neck and a tiny shadow under the brim.
    _px(draw,ox,oy,(4,6,11,11),COL['ink']); _px(draw,ox,oy,(5,6,10,11),COL['skin'])
    _px(draw,ox,oy,(4,7,5,10),COL['hair']); _px(draw,ox,oy,(10,7,11,10),COL['hair'])
    _px(draw,ox,oy,(4,7,4,8),COL['hair_hi']); _px(draw,ox,oy,(10,7,10,8),COL['skin_hi'])
    _px(draw,ox,oy,(5,6,10,6),COL['skin_shadow'])
    _px(draw,ox,oy,(6,8,6,8),COL['ink']); _px(draw,ox,oy,(9,8,9,8),COL['ink'])
    _px(draw,ox,oy,(7,10,8,10),COL['skin_shadow']); _px(draw,ox,oy,(7,11,9,12),COL['skin'])
    # Shirt sleeves frame the high-contrast teal fishing vest.
    _px(draw,ox,oy,(3,12,5,17),COL['ink']); _px(draw,ox,oy,(10,12,12,17),COL['ink'])
    _px(draw,ox,oy,(3,12,4,16),COL['shirt']); _px(draw,ox,oy,(11,12,12,16),COL['shirt'])
    _px(draw,ox,oy,(4,12,11,18),COL['vest_edge']); _px(draw,ox,oy,(5,12,10,17),COL['vest'])
    _px(draw,ox,oy,(6,13,6,16),COL['vest_hi']); _px(draw,ox,oy,(9,13,10,16),COL['vest_shadow'])
    _px(draw,ox,oy,(7,12,8,12),COL['shirt'])
    # Buckles and compact tackle pouch break up the body into readable gear.
    _px(draw,ox,oy,(6,13,6,13),COL['cap_band']); _px(draw,ox,oy,(9,13,9,13),COL['cap_band'])
    _px(draw,ox,oy,(7,14,7,16),COL['metal']); _px(draw,ox,oy,(8,15,8,15),COL['metal'])
    _px(draw,ox,oy,(10,14,13,18),COL['ink']); _px(draw,ox,oy,(10,15,12,17),COL['bag']); _px(draw,ox,oy,(11,15,12,15),COL['bag_hi'])
    _px(draw,ox,oy,(2,15,3,17),COL['skin']); _px(draw,ox,oy,(12,15,13,16),COL['skin'])
    # Trouser gap and sturdy boots.
    _px(draw,ox,oy,(4,17,6,20),COL['pants']); _px(draw,ox,oy,(9,17,11,20),COL['pants'])
    _px(draw,ox,oy,(3,20,6,22),COL['boot']); _px(draw,ox,oy,(9,20,12,22),COL['boot'])
    _px(draw,ox,oy,(3,21,5,21),COL['boot_hi']); _px(draw,ox,oy,(10,21,12,21),COL['boot_hi'])

def _back(draw, ox, oy, frame):
    # Rod angles away from the pack on the left side when viewed from behind.
    _line(draw,ox,oy,[(3,16),(2,9),(1,3)],COL['rod'],1)
    _line(draw,ox,oy,[(3,15),(1,8)],COL['rod_hi'],1)
    _px(draw,ox,oy,(4,1,11,4),COL['ink']); _px(draw,ox,oy,(5,0,10,1),COL['ink'])
    _px(draw,ox,oy,(4,2,11,3),COL['cap']); _px(draw,ox,oy,(5,1,10,2),COL['cap_hi'])
    _px(draw,ox,oy,(4,3,11,4),COL['cap_shadow']); _px(draw,ox,oy,(3,4,13,5),COL['ink'])
    _px(draw,ox,oy,(3,4,13,4),COL['cap_band']); _px(draw,ox,oy,(4,4,11,4),COL['cap_hi'])
    # Back of head and neck peek beneath the cap.
    _px(draw,ox,oy,(4,6,11,11),COL['ink']); _px(draw,ox,oy,(5,6,10,11),COL['hair'])
    _px(draw,ox,oy,(6,6,9,10),COL['outline']); _px(draw,ox,oy,(6,6,8,6),COL['hair_hi'])
    _px(draw,ox,oy,(7,10,9,12),COL['skin'])
    _px(draw,ox,oy,(3,12,5,17),COL['ink']); _px(draw,ox,oy,(10,12,12,17),COL['ink'])
    _px(draw,ox,oy,(3,12,4,16),COL['shirt']); _px(draw,ox,oy,(11,12,12,16),COL['shirt'])
    _px(draw,ox,oy,(4,12,11,18),COL['vest_edge']); _px(draw,ox,oy,(5,12,10,17),COL['vest'])
    _px(draw,ox,oy,(6,13,6,16),COL['vest_hi']); _px(draw,ox,oy,(9,13,10,16),COL['vest_shadow'])
    # A clearly visible shoulder bag/strap gives the rear view its fisherman cue.
    _line(draw,ox,oy,[(5,12),(9,17)],COL['bag_hi'],1)
    _px(draw,ox,oy,(10,14,13,19),COL['ink']); _px(draw,ox,oy,(10,15,13,18),COL['bag']); _px(draw,ox,oy,(11,15,13,15),COL['bag_hi'])
    _px(draw,ox,oy,(11,16,11,16),COL['metal'])
    _px(draw,ox,oy,(2,15,3,17),COL['skin']); _px(draw,ox,oy,(12,15,13,17),COL['skin'])
    _px(draw,ox,oy,(4,17,6,20),COL['pants']); _px(draw,ox,oy,(9,17,11,20),COL['pants'])
    _px(draw,ox,oy,(3,20,6,22),COL['boot']); _px(draw,ox,oy,(9,20,12,22),COL['boot'])
    _px(draw,ox,oy,(3,21,5,21),COL['boot_hi']); _px(draw,ox,oy,(10,21,12,21),COL['boot_hi'])

def _side(draw, ox, oy, frame, right=False):
    # Mirror the side-facing silhouette. Rod and nose point in travel direction.
    s=1 if right else -1
    def X(x): return x if right else 15-x
    def box(b):
        x0,y0,x1,y1=b; return (min(X(x0),X(x1)),y0,max(X(x0),X(x1)),y1)
    def px(b,c): _px(draw,ox,oy,box(b),c)
    def ln(points,c,w=1): _line(draw,ox,oy,[(X(x),y) for x,y in points],c,w)
    ln([(11,16),(13,9),(15,3)],COL['rod'],1)
    ln([(12,15),(14,8)],COL['rod_hi'],1)
    px((5,1,10,4),COL['ink']); px((6,0,9,1),COL['ink'])
    px((5,2,10,3),COL['cap']); px((6,1,9,2),COL['cap_hi']); px((5,3,10,4),COL['cap_shadow'])
    px((3,4,12,5),COL['ink']); px((3,4,12,4),COL['cap_band']); px((4,4,11,4),COL['cap_hi'])
    # Side profile: nose and one eye make facing unambiguous.
    px((5,6,11,11),COL['ink']); px((6,6,10,11),COL['skin']); px((5,7,6,10),COL['hair'])
    px((10,8,11,9),COL['skin_hi']); px((8,8,8,8),COL['ink'])
    px((6,6,9,6),COL['hair_hi']); px((7,10,9,12),COL['skin'])
    px((3,12,6,17),COL['ink']); px((10,12,12,17),COL['ink'])
    px((4,12,6,16),COL['shirt']); px((10,12,11,16),COL['shirt'])
    px((5,12,11,18),COL['vest_edge']); px((6,12,10,17),COL['vest']); px((7,13,7,16),COL['vest_hi']); px((9,13,10,16),COL['vest_shadow'])
    px((7,13,7,13),COL['cap_band']); px((9,14,12,18),COL['ink']); px((9,15,11,17),COL['bag']); px((10,15,11,15),COL['bag_hi'])
    px((10,16,10,16),COL['metal'])
    px((3,15,4,17),COL['skin']); px((11,15,12,16),COL['skin'])
    px((5,17,7,20),COL['pants']); px((9,17,11,20),COL['pants'])
    px((4,20,7,22),COL['boot']); px((9,20,12,22),COL['boot'])
    px((4,21,6,21),COL['boot_hi']); px((10,21,12,21),COL['boot_hi'])

for face in range(4):
    for frame in range(4):
        x,y=frame*16,face*24
        bob=1 if frame in [1,3] else 0
        oy=y+bob
        # Ground shadow makes the sprite sit in the world and matches props.
        p.ellipse((x+2,y+22,x+13,y+23),fill=COL['shadow'])
        if face == 0: _front(p,x,oy,frame)
        elif face == 1: _back(p,x,oy,frame)
        else: _side(p,x,oy,frame,right=face==3)
        # Alternate boots for a readable four-frame walk without changing the silhouette.
        if frame in [1,3]:
            # cover the old feet with a one-pixel stride offset; all other gear stays still
            stride = 1 if frame == 1 else -1
            p.rectangle((x+3,oy+20,x+6,oy+22),fill=COL['shadow'])
            p.rectangle((x+9,oy+20,x+12,oy+22),fill=COL['shadow'])
            if face in (0,1):
                p.rectangle((x+3,oy+20+stride,x+6,oy+22+stride),fill=COL['boot'])
                p.rectangle((x+9,oy+20-stride,x+12,oy+22-stride),fill=COL['boot'])
            else:
                p.rectangle((x+4,oy+20+stride,x+7,oy+22+stride),fill=COL['boot'])
                p.rectangle((x+9,oy+20-stride,x+12,oy+22-stride),fill=COL['boot'])
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
