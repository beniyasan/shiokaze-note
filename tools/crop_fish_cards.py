"""Regenerate the six framed *legacy* fish cards from the concept sheet.

This script intentionally writes opaque 480x320 ``<stem>.png`` files. They
are compatibility fallbacks for cards that already use the old paper/frame
treatment; this workflow does not produce the preferred transparent
``<stem>_v2.png`` assets described in ``skills/fish-art-generation/SKILL.md``.
For a new card, use a transparent RGBA crop/export workflow instead of treating
this script as an ``_v2`` generator.

The output is deliberately separate from assets/fish/: the latter remains tiny
pixel art for the ledger strip, while these cards preserve the larger original
illustrations for result and legendary reveal faces.
"""
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import numpy as np
src_path=Path('generated_images/exec-e207f20a-d3b7-4ca0-b8fa-3ae717c38532.png')
if not src_path.exists():
    raise SystemExit(f'missing concept sheet: {src_path}')
src=Image.open(src_path).convert('RGB')
# Crop slightly inside each framed concept-sheet panel
panels={
'sand_goby':(28,28,490,478),
'silver_sprat':(538,28,1000,478),
'moonfin_trout':(1050,28,1510,478),
'coral_bream':(28,538,490,988),
'abyssal_angler':(538,538,1000,988),
'rainbow_kingfish':(1050,538,1510,988),
}
OUT=Path('assets/fish_cards'); OUT.mkdir(parents=True,exist_ok=True)
# Card palette sampled from paper, with a tiny noise texture for tactile print look
W,H=480,320
rng=np.random.default_rng(7)
base=np.zeros((H,W,3),dtype=np.uint8)
noise=rng.normal(0,1.6,(H,W,1))
base[:]=np.clip(np.array([245,239,220])[None,None,:]+noise,0,255)
base=Image.fromarray(base,'RGB').convert('RGBA')
def fg_mask(arr):
    # Flood-fill only the cream paper from the crop edges. Dark/saturated illustration
    # pixels (including pale fish highlights enclosed by outlines) remain foreground.
    h,w,_=arr.shape
    bg=np.median(np.concatenate([arr[:12].reshape(-1,3),arr[-12:].reshape(-1,3),arr[:,:12].reshape(-1,3),arr[:,-12:].reshape(-1,3)]),axis=0)
    # Keep paper-like pixels that are near edge-paper tone; don't rely on one RGB value
    d=np.sqrt(((arr.astype(float)-bg[None,None,:])**2).sum(2))
    sat=(arr.max(2)-arr.min(2))/np.maximum(arr.max(2),1)
    val=arr.mean(2)/255
    paper=(d<36)&(sat<0.20)&(val>0.72)
    # flood fill 8-neighbour through paper pixels
    seen=np.zeros((h,w),bool); st=[]
    for x in range(w): st.extend([(0,x),(h-1,x)])
    for y in range(h): st.extend([(y,0),(y,w-1)])
    while st:
      y,x=st.pop()
      if y<0 or y>=h or x<0 or x>=w or seen[y,x] or not paper[y,x]: continue
      seen[y,x]=1
      st += [(y-1,x),(y+1,x),(y,x-1),(y,x+1),(y-1,x-1),(y-1,x+1),(y+1,x-1),(y+1,x+1)]
    # Remove any isolated border pixels too; foreground is everything else
    return ~seen
for name,box in panels.items():
    crop=src.crop(box)
    arr=np.asarray(crop)
    mask=fg_mask(arr)
    ys,xs=np.where(mask)
    # trim tiny noise by quantile bounds and preserve context around art
    x0,x1=np.percentile(xs,[1,99]); y0,y1=np.percentile(ys,[1,99])
    x0=max(0,int(x0)-4); x1=min(crop.width,int(x1)+5); y0=max(0,int(y0)-4); y1=min(crop.height,int(y1)+5)
    # create RGBA crop with paper removed to uniform card backing; use original RGB where foreground
    sub=crop.crop((x0,y0,x1+1,y1+1)).convert('RGBA')
    submask=Image.fromarray((mask[y0:y1+1,x0:x1+1]*255).astype('uint8'),'L')
    # keep antialiased edge via a slight blur on mask
    sub.putalpha(submask.filter(ImageFilter.GaussianBlur(0.35)))
    # fit art to inner card area, preserving aspect
    inner=(22,20,W-22,H-20)
    maxw,maxh=inner[2]-inner[0],inner[3]-inner[1]
    scale=min(maxw/sub.width,maxh/sub.height)
    nw,nh=max(1,round(sub.width*scale)),max(1,round(sub.height*scale))
    sub=sub.resize((nw,nh),Image.Resampling.LANCZOS)
    x=(W-nw)//2; y=(H-nh)//2
    card=base.copy(); card.alpha_composite(sub,(x,y))
    d=ImageDraw.Draw(card)
    # simple card-friendly double frame; this replaces the source grid frame cleanly
    d.rounded_rectangle((7,7,W-8,H-8),radius=7,outline=(37,121,121,230),width=2)
    d.rounded_rectangle((13,13,W-14,H-14),radius=5,outline=(210,173,94,110),width=1)
    # corner studs
    for cx,cy in [(17,17),(W-18,17),(17,H-18),(W-18,H-18)]:
      d.rectangle((cx-2,cy-2,cx+2,cy+2),fill=(37,121,121,220))
    card.save(OUT/f'{name}.png')
    print(name, 'mask bbox', (x0,y0,x1,y1), 'sub',sub.size)
