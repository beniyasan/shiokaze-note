"""Manually reconstructed 96x128 native atlas guided by the generated master.

The source master is a visual guide only. Every pixel cluster below is authored
at the game-native 96x128 grid; no master pixels are sampled or copied into the
runtime atlas. Runtime assets remain untouched.
"""
from pathlib import Path
import os
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]; ART=ROOT/'artifacts'; ART.mkdir(exist_ok=True)
MASTER=Path(os.environ.get('STYLE_MASTER_PATH', '/workspace/scratch/292fc4632731/generated_images/exec-381b8c8c-1fb5-4a2a-8fe5-fca352009cca.png'))
BASE=ROOT/'assets/hero.png'
P={'ink':'#1a2033','ink2':'#2a3047','hair':'#202a45','hair_hi':'#354465','hair_l':'#52658a','skin':'#e7a06c','skin_hi':'#ffc88b','skin_l':'#ffe0aa','skin_sh':'#a65b50','skin_deep':'#743b46','cap':'#29465a','cap_hi':'#4d717b','cap_l':'#77999a','cap_band':'#c7a66d','cap_band_hi':'#f0d09a','jacket':'#2d6674','jacket_hi':'#61969a','jacket_l':'#8db0a4','jacket_sh':'#1f4f63','cream':'#e5d0a7','cream_hi':'#f7e7c4','cream_sh':'#a98d70','pants':'#9f4938','pants_hi':'#d26745','pants_l':'#ee8650','pants_sh':'#6f3540','boot':'#4c3741','boot_hi':'#8d5644','boot_l':'#bc7048','bag':'#5d5643','bag_hi':'#927a55','bag_l':'#c7a36a','rod':'#4d3547','rod_hi':'#d8ae69','metal':'#d9c89b','reel':'#596579'}
def R(d,b,c): d.rectangle(b,fill=P[c])
def L(d,pts,c,w=1): d.line(pts,fill=P[c],width=w)
def Q(d,pts,c): d.polygon(pts,fill=P[c])
def X(d,x,y,c): d.point((x,y),fill=P[c])
def shadow(d,bob): R(d,(24,122+bob,69,124+bob),'ink2');R(d,(33,125+bob,60,126+bob),'jacket_sh')
def feet(d,stride=0):
 lx,rx=30+stride,53-stride
 R(d,(lx,86,lx+13,115),'pants_sh');R(d,(lx+2,86,lx+12,113),'pants');R(d,(rx,86,rx+13,115),'pants_sh');R(d,(rx,86,rx+11,113),'pants')
 L(d,[(lx+3,97),(lx+11,96)],'pants_hi',2);L(d,[(rx+1,103),(rx+10,103)],'pants_hi',2);X(d,lx+8,107,'pants_l');X(d,rx+4,99,'pants_l')
 Q(d,[(lx-2,111),(lx+11,111),(lx+16,118),(lx+15,122),(lx-4,121)],'boot');Q(d,[(rx-3,111),(rx+10,111),(rx+17,118),(rx+13,122),(rx-4,120)],'boot')
 R(d,(lx,116,lx+12,118),'boot_hi');R(d,(rx,116,rx+12,118),'boot_l');L(d,[(lx-2,122),(lx+14,122)],'ink',2);L(d,[(rx-3,122),(rx+15,122)],'ink',2)
def cap_hair(d,side=1,back=False):
 Q(d,[(28,21),(34,10),(46,4),(58,7),(65,15),(64,26),(28,27)],'hair');Q(d,[(35,15),(40,8),(50,6),(59,10),(62,17),(59,22),(33,23)],'cap');R(d,(43,8,54,12),'cap_hi');R(d,(47,7,58,9),'cap_l');L(d,[(36,18),(61,18)],'cap_hi',2)
 if side>0: Q(d,[(27,22),(66,22),(72,26),(31,28)],'cap_band');L(d,[(31,22),(65,22)],'cap_band_hi',2)
 else: Q(d,[(24,22),(64,22),(69,26),(28,28)],'cap_band');L(d,[(28,22),(62,22)],'cap_band_hi',2)
 if back: Q(d,[(28,26),(40,25),(42,45),(35,53),(26,46)],'hair');R(d,(31,29,38,42),'hair_hi');L(d,[(28,39),(35,32)],'hair_l',1)
 else: Q(d,[(29,26),(39,26),(38,43),(31,51),(25,46)],'hair');R(d,(28,30,34,41),'hair_hi');L(d,[(31,28),(28,38),(26,43)],'hair_l',1)
def rod_pack(d,side=1,bob=0,back=False):
 if side>0:
  L(d,[(59,108+bob),(68,80+bob),(78,54+bob),(90,20+bob)],'rod',3);L(d,[(61,106+bob),(70,79+bob),(80,53+bob),(93,18+bob)],'rod_hi',2);L(d,[(83,44+bob),(92,20+bob)],'metal',1);R(d,(58,76+bob,67,90+bob),'metal');R(d,(60,78+bob,68,88+bob),'reel');R(d,(61,79+bob,66,84+bob),'metal');X(d,65,84+bob,'ink')
 else:
  L(d,[(32,108+bob),(23,79+bob),(14,53+bob),(3,19+bob)],'rod',3);L(d,[(30,106+bob),(21,79+bob),(12,52+bob),(1,17+bob)],'rod_hi',2);R(d,(28,76+bob,37,90+bob),'metal');R(d,(27,78+bob,35,88+bob),'reel');X(d,30,83+bob,'ink')
 # asymmetrical master-inspired tackle pack sits behind the rod hand.
 if back:
  Q(d,[(17,67),(36,64),(45,73),(42,99),(21,101),(14,87)],'bag');R(d,(20,70,35,80),'bag_hi');R(d,(23,84,37,91),'bag_l');R(d,(27,71,30,95),'bag');X(d,33,77,'metal')
 else:
  Q(d,[(16,68),(35,65),(44,73),(41,98),(21,102),(14,87)],'bag');R(d,(19,70,34,80),'bag_hi');R(d,(22,83,37,91),'bag_l');R(d,(25,72,29,95),'bag');L(d,[(18,77),(37,76)],'metal',1);X(d,33,86,'metal');X(d,24,89,'bag_l')
def face_front(d):
 Q(d,[(36,28),(57,28),(63,34),(62,48),(56,57),(45,58),(36,51),(33,40)],'skin');R(d,(39,29,54,33),'skin_hi');R(d,(34,35,39,47),'skin_sh');R(d,(55,34,61,42),'skin_l');L(d,[(39,37),(45,36),(48,37)],'ink',1);L(d,[(51,37),(57,37)],'ink',1);R(d,(42,38,45,41),'metal');R(d,(52,38,55,41),'metal');X(d,44,39,'ink');X(d,53,39,'ink');X(d,44,38,'skin_l');X(d,53,38,'skin_l');L(d,[(43,49),(49,51),(55,49)],'skin_sh',1);X(d,58,47,'skin_deep')
def face_side(d,right=True):
 if right:
  Q(d,[(39,27),(55,27),(60,32),(61,37),(68,39),(72,42),(68,45),(61,45),(61,52),(56,57),(47,58),(39,53),(36,45),(37,34)],'skin');R(d,(41,28,54,32),'skin_hi');R(d,(36,34,41,46),'skin_sh');Q(d,[(53,32),(60,34),(65,38),(70,40),(65,42),(55,41)],'skin_l');L(d,[(51,33),(57,32),(60,34)],'ink',1);R(d,(53,35,59,38),'metal');R(d,(56,35,58,38),'hair_hi');X(d,57,35,'ink');X(d,56,35,'skin_l');L(d,[(50,47),(55,49),(60,47)],'skin_sh',1);X(d,64,44,'skin_deep')
 else:
  Q(d,[(57,27),(41,27),(36,32),(35,37),(28,39),(24,42),(29,45),(36,45),(35,52),(40,57),(49,58),(57,53),(60,45),(59,34)],'skin');R(d,(42,28,55,32),'skin_hi');R(d,(56,34,61,46),'skin_sh');Q(d,[(43,32),(37,34),(32,38),(26,40),(31,42),(41,41)],'skin_l');L(d,[(45,33),(39,32),(36,34)],'ink',1);R(d,(37,35,43,38),'metal');R(d,(38,35,40,38),'hair_hi');X(d,39,35,'ink');X(d,40,35,'skin_l');L(d,[(47,47),(42,49),(37,47)],'skin_sh',1);X(d,32,44,'skin_deep')
def jacket_front(d):
 Q(d,[(26,56),(39,53),(55,54),(68,61),(66,88),(36,90),(24,78)],'jacket_sh');Q(d,[(36,55),(53,55),(59,87),(37,87)],'jacket');L(d,[(39,57),(46,70),(48,87)],'jacket_hi',3);L(d,[(54,57),(50,68),(57,83)],'jacket_l',2)
 Q(d,[(41,55),(54,56),(49,73),(39,66)],'cream');R(d,(45,57,52,64),'cream_hi');L(d,[(45,64),(52,71)],'cream_sh',2);R(d,(52,65,55,68),'metal')
 Q(d,[(23,59),(33,61),(32,79),(25,88),(19,82),(20,68)],'jacket');R(d,(20,80,29,89),'skin');Q(d,[(61,58),(71,62),(71,80),(65,88),(59,80)],'jacket');R(d,(64,79,74,89),'skin_hi')
 R(d,(36,84,60,91),'jacket_sh');X(d,43,78,'metal');X(d,56,81,'metal')
def body_side(d,right=True):
 neck=48 if right else 44
 Q(d,[(neck-12,56),(neck+6,54),(neck+15,62),(neck+12,85),(neck-11,89),(neck-17,76)],'jacket_sh');Q(d,[(neck-4,56),(neck+7,56),(neck+8,85),(neck-8,87)],'jacket');L(d,[(neck,58),(neck+7,79)],'jacket_hi',3);L(d,[(neck+5,60),(neck+2,76),(neck+8,84)],'jacket_l',2)
 Q(d,[(neck-3,55),(neck+7,56),(neck+3,72),(neck-5,66)],'cream');R(d,(neck-1,57,neck+5,64),'cream_hi');L(d,[(neck+1,64),(neck+7,71)],'cream_sh',2);R(d,(neck+5,66,neck+8,69),'metal')
 if right:
  Q(d,[(neck+7,61),(neck+18,65),(neck+18,81),(neck+11,89),(neck+5,80)],'jacket');R(d,(neck+12,80,neck+22,90),'skin_hi');X(d,neck+15,72,'metal')
 else:
  Q(d,[(neck-7,61),(neck-18,65),(neck-18,81),(neck-11,89),(neck-5,80)],'jacket');R(d,(neck-22,80,neck-12,90),'skin_hi');X(d,neck-15,72,'metal')
 R(d,(neck-10,84,neck+10,91),'jacket_sh')
def frame(row,f):
 bob=1 if f in (1,3) else 0; stride=[0,3,-2,2][f] if row in (0,2) else [0,-3,2,-2][f]; c=Image.new('RGBA',(96,128),(0,0,0,0));d=ImageDraw.Draw(c);shadow(d,bob)
 if row==0:
  rod_pack(d,1,bob);cap_hair(d,1);face_front(d);jacket_front(d);feet(d,stride)
 elif row==1:
  rod_pack(d,-1,bob,True);cap_hair(d,-1,True);Q(d,[(31,28),(61,28),(64,44),(57,57),(41,56),(33,47)],'hair');R(d,(38,31,57,45),'hair_hi');Q(d,[(26,56),(42,54),(58,57),(67,64),(64,87),(36,89),(24,78)],'jacket_sh');Q(d,[(37,57),(54,57),(58,86),(37,87)],'jacket');L(d,[(37,58),(56,83)],'jacket_l',3);L(d,[(42,60),(49,86)],'cream_sh',2);R(d,(43,84,60,91),'jacket_sh');feet(d,stride)
 elif row==2:
  rod_pack(d,1,bob);cap_hair(d,1);face_side(d,True);body_side(d,True);feet(d,stride)
 else:
  rod_pack(d,-1,bob);cap_hair(d,-1);face_side(d,False);body_side(d,False);feet(d,stride)
 # tiny master-inspired stitch clusters, native 1px accents
 for x,y,col in [(35,59,'metal'),(58,64,'metal'),(31,71,'jacket_l'),(55,78,'cream_hi'),(27,86,'bag_l'),(40,88,'pants_l'),(58,96,'pants_hi')]:
  if 0<=x<96 and 0<=y<128 and c.getpixel((x,y))[3]: X(d,x,y,col)
 return c
def build():
 out=Image.new('RGBA',(384,512),(0,0,0,0))
 for r in range(4):
  for f in range(4): out.alpha_composite(frame(r,f),(f*96,r*128))
 return out
def ft(n):
 for f in ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf','/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf']:
  if Path(f).exists(): return ImageFont.truetype(f,n)
 return ImageFont.load_default()
def comparison(trace):
 b=Image.new('RGBA',(1780,720),(11,23,32,255));d=ImageDraw.Draw(b);d.text((32,18),'Master-guided 96×128 reconstruction · native clusters',font=ft(28),fill=(248,229,176,255));d.text((32,54),'visual guide only; manually traced face, navy cap, teal/cream jacket, orange trousers, pack and reel',font=ft(16),fill=(173,197,194,255))
 if not MASTER.exists(): raise FileNotFoundError(f'master reference missing: {MASTER}')
 master=Image.open(MASTER).convert('RGBA'); current=Image.open(BASE).convert('RGBA').crop((192,256,288,384)); traced=trace.crop((192,256,288,384)); front=trace.crop((0,0,96,128))
 cards=[('Generated master · guide',master),('Current eye-refined · profile',current),('New trace · profile',traced),('New trace · front',front)];x=28
 for title,im in cards:
  d.rounded_rectangle((x,88,x+420,594),radius=12,fill=(20,36,44,255),outline=(75,105,110,255),width=2);d.text((x+12,100),title,font=ft(19),fill=(240,220,165,255)); aw,ah=im.size;maxw,maxh=396,452;fit=min(maxw/aw,maxh/ah); scaled=im.resize((max(1,int(aw*fit)),max(1,int(ah*fit))),Image.Resampling.NEAREST);b.alpha_composite(scaled,(x+(420-scaled.width)//2,145+(452-scaled.height)//2));x+=435
 b.save(ART/'hero-master-trace-96x128-comparison.png')
def main():
 a=build();a.save(ART/'hero-fisherman-96x128-master-trace-atlas.png');p=Image.new('RGBA',(1536,2048),(12,26,35,255));p.alpha_composite(a.resize((1536,2048),Image.Resampling.NEAREST));p.save(ART/'hero-fisherman-96x128-master-trace-preview.png');comparison(a)
 (ART/'hero-master-trace-96x128-notes.md').write_text('''# Master-guided 96×128 reconstruction\n\n- The generated 16-bit fisherman is a visual master only; no master pixels are sampled into the atlas. The new 384×512 atlas is manually reconstructed at native 96×128 cells.\n- Clusters carry the master cues: expressive eye and nose profile, navy cap/hair, teal jacket with cream inner layer, orange trouser planes, brown boots, asymmetrical olive tackle bag and rod/reel.\n- Foot anchor remains local y=126 with the existing shadow/collider concept. Atlas preserves four facings × four walk frames and stride offsets.\n- Runtime files are untouched. If adopted, uncompressed atlas is 768 KiB and frame source/destination regions become 96×128; draw count/collider/map scale remain unchanged.\n''',encoding='utf-8')
 print('wrote',a.size)
if __name__=='__main__':main()
