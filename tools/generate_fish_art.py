from PIL import Image, ImageDraw
from pathlib import Path

OUT = Path('assets/fish')
OUT.mkdir(parents=True, exist_ok=True)
PAL = {
    'ink':'#13253a','deep':'#18374d','shadow':'#254b64','sea':'#2f7290','teal':'#65b6a6',
    'moon':'#a6d7ea','gold':'#f4d37b','coral':'#d97762','pink':'#eaa27b','purple':'#9d8bc8',
    'foam':'#e6ead3','sand':'#c9a36a','red':'#c95a56','orange':'#e28b4b','white':'#fff2c6'
}
W,H = 96,64

def base(name):
    im = Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(im)
    # soft pixel-water shadow and two glints ground the portrait on the collection card
    d.ellipse((11,49,84,58), fill=(19,37,58,90))
    d.line((18,56,76,56), fill=PAL['sea'], width=2)
    d.line((28,59,62,59), fill=(101,182,166,150), width=1)
    return im,d

def finish(im,name):
    im.save(OUT/f'{name}.png')

# Sand goby: small, mottled bottom-dweller with raised eye and sandy fins
im,d=base('sand_goby')
d.polygon([(15,34),(22,24),(47,20),(67,27),(78,34),(67,43),(45,47),(23,42)], fill=PAL['sand'], outline=PAL['ink'])
d.polygon([(16,34),(3,22),(7,42)], fill=PAL['shadow'], outline=PAL['ink'])
d.polygon([(37,23),(40,11),(48,21)], fill=PAL['teal'], outline=PAL['ink'])
d.polygon([(47,43),(54,55),(59,44)], fill=PAL['teal'], outline=PAL['ink'])
d.polygon([(67,27),(77,23),(76,32)], fill=PAL['pink'], outline=PAL['ink'])
for x,y in [(29,30),(39,37),(52,28),(60,37),(68,31)]: d.rectangle((x,y,x+5,y+5), fill=PAL['coral'])
d.rectangle((22,28,27,33), fill=PAL['ink']); d.rectangle((23,28,24,29), fill=PAL['white'])
d.line((25,40,62,40), fill=PAL['sand'], width=2)
finish(im,'sand_goby')

# Silver sprat: bright schooling fish with forked tail and silver-blue bands
im,d=base('silver_sprat')
d.polygon([(17,31),(30,19),(61,20),(76,30),(61,42),(31,43)], fill=PAL['moon'], outline=PAL['ink'])
d.polygon([(17,31),(4,19),(7,31),(4,43)], fill=PAL['sea'], outline=PAL['ink'])
d.polygon([(44,21),(48,10),(54,21)], fill=PAL['foam'], outline=PAL['ink'])
d.polygon([(48,41),(54,53),(60,41)], fill=PAL['sea'], outline=PAL['ink'])
for x in [30,39,48,57]: d.line((x,21,x+5,42), fill=PAL['sea'], width=2)
d.line((26,28,68,28), fill=PAL['white'], width=2)
d.rectangle((64,27,69,32), fill=PAL['ink']); d.rectangle((65,27,66,28), fill=PAL['white'])
d.rectangle((77,29,79,32), fill=PAL['gold'])
finish(im,'silver_sprat')

# Moonfin trout: large blue-purple fish with luminous crescent fin and spots
im,d=base('moonfin_trout')
d.polygon([(12,34),(25,18),(59,16),(77,26),(86,34),(74,44),(46,50),(23,45)], fill=PAL['sea'], outline=PAL['ink'])
d.polygon([(13,34),(0,20),(3,35),(0,49)], fill=PAL['purple'], outline=PAL['ink'])
d.polygon([(39,20),(43,5),(52,19)], fill=PAL['moon'], outline=PAL['ink'])
d.polygon([(49,46),(58,59),(64,44)], fill=PAL['purple'], outline=PAL['ink'])
d.polygon([(65,22),(76,11),(77,29)], fill=PAL['moon'], outline=PAL['ink'])
for x,y in [(27,27),(38,35),(51,25),(57,37),(68,31),(43,17)]: d.ellipse((x,y,x+5,y+5), fill=PAL['gold'])
d.arc((53,16,72,37), 210, 330, fill=PAL['foam'], width=2)
d.rectangle((73,28,79,34), fill=PAL['ink']); d.rectangle((74,28,75,29), fill=PAL['white'])
finish(im,'moonfin_trout')

# Coral bream: warm reef fish, deep-bodied with striped coral and turquoise fins
im,d=base('coral_bream')
d.polygon([(13,34),(25,17),(54,16),(76,25),(83,34),(73,45),(49,50),(23,45)], fill=PAL['coral'], outline=PAL['ink'])
d.polygon([(14,34),(1,18),(4,33),(2,49)], fill=PAL['pink'], outline=PAL['ink'])
d.polygon([(30,20),(31,5),(39,18)], fill=PAL['teal'], outline=PAL['ink'])
d.polygon([(48,46),(57,59),(64,43)], fill=PAL['teal'], outline=PAL['ink'])
d.polygon([(68,22),(81,13),(77,31)], fill=PAL['gold'], outline=PAL['ink'])
for x in [29,39,49,59]: d.line((x,17,x+3,46), fill=PAL['gold'], width=3)
d.line((22,32,73,32), fill=PAL['pink'], width=2)
d.rectangle((72,28,78,34), fill=PAL['ink']); d.rectangle((73,28,74,29), fill=PAL['white'])
finish(im,'coral_bream')

# Rainbow Kingfish: legendary trophy, iridescent body and crown-like dorsal fin
im,d=base('rainbow_kingfish')
d.polygon([(8,34),(21,14),(62,11),(83,24),(91,34),(79,45),(45,53),(20,47)], fill=PAL['white'], outline=PAL['ink'])
d.polygon([(10,34),(0,15),(3,34),(0,53)], fill=PAL['purple'], outline=PAL['ink'])
d.polygon([(31,17),(33,0),(40,15),(47,-1),(51,15),(60,3),(63,20)], fill=PAL['gold'], outline=PAL['ink'])
d.polygon([(43,47),(52,63),(59,45)], fill=PAL['purple'], outline=PAL['ink'])
cols=[PAL['coral'],PAL['orange'],PAL['gold'],PAL['teal'],PAL['moon'],PAL['purple']]
for i,x in enumerate([22,30,38,46,54,62]): d.polygon([(x,13),(x+7,14),(x+2,49),(x-4,48)], fill=cols[i], outline=PAL['ink'])
d.polygon([(66,16),(82,8),(77,29)], fill=PAL['moon'], outline=PAL['ink'])
d.rectangle((77,27,84,34), fill=PAL['ink']); d.rectangle((78,27,79,28), fill=PAL['white'])
d.line((16,52,73,52), fill=PAL['gold'], width=2)
finish(im,'rainbow_kingfish')

print('generated', ', '.join(sorted(p.name for p in OUT.glob('*.png'))))
