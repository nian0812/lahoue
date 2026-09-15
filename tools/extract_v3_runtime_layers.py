"""Extract furniture-free actor masks and architectural materials from approved V3.

No painting or generative edits. Coordinates and masks are recorded in manifest.
Run after extract_v3_assets.py to add these runtime layers.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageChops

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/LaHoue_Final_Approved_Asset_Pack_V3'
DEST = ROOT / 'assets/lahoue_v3'
manifest = json.loads((DEST / 'manifest.json').read_text())

def extract(key, source, box, mask=None, canvas=None):
    im = Image.open(SOURCE / source).convert('RGBA').crop(box)
    if mask:
        matte = Image.new('L', im.size)
        ImageDraw.Draw(matte).polygon(mask, fill=255)
        im.putalpha(ImageChops.multiply(im.getchannel('A'), matte))
    if canvas:
        target = Image.new('RGBA', canvas)
        target.paste(im, ((canvas[0] - im.width) // 2, canvas[1] - im.height))
        im = target
    path = DEST / (key + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    manifest[key] = dict(file='res://assets/lahoue_v3/' + key + '.png', source=source,
                         crop=box, mask=mask, canvas=canvas,
                         source_sha256=hashlib.sha256((SOURCE / source).read_bytes()).hexdigest())

sheet = 'characters/restaurant_simulation_character_sprite_sheet.png'
rows = [(0,155),(190,339),(373,530),(560,706),(742,881),(913,1045)]
# Upper body masks intentionally stop where the runtime tabletop occludes the
# seated actor. Chairs, dishes and source tables never enter the actor layer.
for who, (top, bottom) in zip(['player','waiter','chef','customer','customer_woman','vip_customer'], rows):
    for state, left, points in [
        ('sit', 880, [(40,5),(88,5),(94,48),(101,60),(96,72),(75,76),(67,89),(48,85),(40,59)]),
        ('eat', 1042, [(38,4),(84,4),(90,37),(99,52),(91,66),(76,65),(69,90),(39,91),(30,74),(30,39)]),
        ('payment', 1220, [(22,7),(73,7),(78,41),(101,49),(100,62),(75,67),(71,130),(24,132),(14,86),(12,41)])]:
        extract(f'characters/{who}/{state}', sheet, (left,top,left+112,min(bottom,top+135)), points, (150,165))

rest = 'restaurant/lahoue_restaurant_isometric_asset_sheet.png'
extract('restaurant/floor_material', 'restaurant/cozy_isometric_restaurant_asset_sheet.png', (112,110,207,155))
extract('restaurant/wall_material', rest, (148,639,205,685))
extract('restaurant/pillar', rest, (1083,898,1172,1078))
extract('restaurant/railing_back', rest, (292,913,547,1078))
extract('restaurant/stair', 'restaurant/lahoue_restaurant_upgrade_levels.png', (940,677,1069,909),
        [(9,0),(41,14),(57,48),(74,81),(93,119),(121,167),(128,190),(105,224),(67,214),(58,172),(36,129),(14,80),(0,30)])
(DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print('Added furniture-free V3 actor layers and architectural materials')
