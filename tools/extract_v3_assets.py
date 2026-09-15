"""Deterministic crops of user-approved V3 sheets; no generated/repainted artwork.
Coordinates are in original PNG pixels. Source hashes and crop rectangles are
recorded so each runtime image is reviewable against its approved source.
"""
from pathlib import Path
from PIL import Image
import numpy as np
import json, hashlib

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'assets/LaHoue_Final_Approved_Asset_Pack_V3'
DEST = ROOT/'assets/lahoue_v3'
DEST.mkdir(parents=True,exist_ok=True)
entries = {}
images = {}
def largest_component(mask):
    parents = [0]; counts = [0]; runs = []; previous = []
    def find(n):
        while parents[n] != n:
            parents[n] = parents[parents[n]]; n = parents[n]
        return n
    for y,row in enumerate(mask):
        edges = np.flatnonzero(np.diff(np.r_[False,row,False].astype(np.int8)))
        current = []
        for left,right in zip(edges[::2],edges[1::2]):
            overlaps = [find(label) for a,b,label in previous if a < right and b > left]
            if overlaps:
                label = overlaps[0]
                for other in overlaps[1:]:
                    other=find(other);label=find(label)
                    if other != label: parents[other]=label;counts[label]+=counts[other]
            else:
                label=len(parents);parents.append(label);counts.append(0)
            counts[find(label)] += int(right-left)
            current.append((left,right,label));runs.append((y,left,right,label))
        previous=current
    if len(parents)==1:return mask
    winner=max((i for i in range(1,len(parents)) if parents[i]==i),key=lambda i:counts[i])
    result=np.zeros_like(mask)
    for y,left,right,label in runs:
        if find(label)==winner:result[y,left:right]=True
    expanded=result.copy()
    expanded[1:] |= result[:-1];expanded[:-1] |= result[1:]
    expanded[:,1:] |= result[:,:-1];expanded[:,:-1] |= result[:,1:]
    return expanded

def crop(key, source, box, canvas=None):
    im = images.setdefault(source, Image.open(SOURCE/source).convert('RGBA'))
    part = im.crop(box)
    exclusions = {'buildings/depot':[(0,0,285,40)], 'restaurant/level_5':[(0,0,190,17)], 'helicopters/body_1':[(255,135,285,318)]}
    for rect in exclusions.get(key,[]): part.paste((0,0,0,0),rect)
    # Remove disconnected fragments of neighbouring labels/objects entering a
    # rectangular crop. Keep original RGBA within the selected object component.
    rgba = np.array(part)
    keep = largest_component(rgba[:,:,3] > 8)
    rgba[~keep,3] = 0
    part = Image.fromarray(rgba)
    # Transparent margins only; preserve original pixels inside the crop.
    bound = part.getbbox()
    if bound: part = part.crop(bound)
    if canvas:
        target = Image.new('RGBA',canvas)
        assert part.width <= canvas[0] and part.height <= canvas[1], key
        target.paste(part,((canvas[0]-part.width)//2,canvas[1]-part.height))
        part = target
    path = DEST/(key+'.png'); path.parent.mkdir(parents=True,exist_ok=True)
    part.save(path)
    entries[key]={'file':'res://assets/lahoue_v3/'+key+'.png','source':source,'crop':box,'exclude_neighbours':exclusions.get(key,[]),'component':'largest alpha-connected approved object; retain adjacent antialias pixels','trim':bound,'canvas':canvas,'source_sha256':hashlib.sha256((SOURCE/source).read_bytes()).hexdigest()}

character='characters/restaurant_simulation_character_sprite_sheet.png'
rows=[(0,155),(190,339),(373,530),(560,706),(742,881),(913,1045)]
for who,(top,bottom) in zip(['player','waiter','chef','customer','customer_woman','vip_customer'],rows):
    crop(f'characters/{who}/idle_static',character,(204,top,315,bottom))
    for state,left,right in [('idle',204,315),('walk_0',366,477),('walk_1',536,652),('carry',696,840)]:
        crop(f'characters/{who}/{state}',character,(left,top,right,bottom),(150,165))
    # Seated illustrations contain a complete table and food, not clean actor
    # layers. Preserve as review crops; never display them over a runtime table.
    for state,left,right in [('sit_composite',880,1030),('eat_composite',1042,1205),('pay_composite',1220,1430)]:
        crop(f'review/{who}_{state}',character,(left,top,right,bottom))

animal='animals/farm_animal_sprite_sheet.png'
for who,(top,bottom) in zip(['layer_chicken','meat_chicken','pig','dairy_cow','beef_cow'],[(15,204),(205,392),(394,578),(580,796),(791,1005)]):
    for state,(left,right) in zip(['idle','walk_0','walk_1','eat'],[(195,423),(430,668),(670,923),(925,1184)]):
        crop(f'animals/{who}/{state}',animal,(left,top,right,bottom),(265,220))

housing='animals/isometric_farm_building_progression_sheet.png'
for kind,(top,bottom) in zip(['coop','cow_barn','pig_pen'],[(48,345),(439,707),(775,1007)]):
    for level,(left,right) in enumerate([(0,272),(273,536),(538,818),(819,1116),(1117,1448)],1):
        crop(f'buildings/{kind}_{level}',housing,(left,top,right,bottom))

pond='aquaculture/aquaculture_facility_asset_sheet.png'
for level,box in enumerate([(5,68,398,334),(403,0,877,333),(885,0,1448,379),(84,372,699,718),(727,338,1439,746)],1):
    crop(f'buildings/pond_{level}',pond,box)
for who,columns in [('fish',[7,75,143,210,271]),('shrimp',[282,351,421,486,558]),('crab',[566,639,710,785,853]),('squid',[872,938,1006,1069,1136]),('octopus',[1152,1227,1299,1370,1448])]:
    for state,index in [('walk_0',0),('walk_1',1),('idle',2)]:
        crop(f'aquaculture/{who}/{state}',pond,(columns[index],803,columns[index+1],882),(86,84))

truck='logistics/lahoue_truck_depot_asset_sheet.png'
crop('buildings/depot',truck,(0,137,777,733))
for level,(top,bottom) in enumerate([(310,407),(445,548),(582,690),(722,834),(870,988)],1):
    for direction,(left,right) in zip(['w','e','s','n'],[(851,1021),(1023,1186),(1190,1299),(1301,1448)]):
        crop(f'trucks/truck_{level}_{direction}',truck,(left,top,right,bottom),(180,125))

heli='logistics/lahoue_logistics_helicopter_asset_sheet.png'
for level,(left,right) in enumerate([(4,289),(289,579),(579,875),(875,1161),(1161,1448)],1):
    crop(f'helicopters/body_{level}',heli,(left,0,right,318))
    crop(f'helicopters/main_{level}',heli,(left,393,right,548))
    crop(f'helicopters/tail_{level}',heli,(left,590,right,773))
for state,box in [('slow',(18,829,309,985)),('medium',(310,829,593,985)),('fast',(596,829,881,985))]:
    crop('helicopters/rotor_'+state,heli,box)

rest='restaurant/lahoue_restaurant_isometric_asset_sheet.png'
for key,box in {'table_empty':(721,15,1024,224),'bar':(4,429,392,763),'food_pass':(396,472,724,762),'kitchen':(1061,455,1448,730),'kitchen_work':(1059,695,1448,967),'planter':(410,760,505,921),'railing':(288,924,543,1078)}.items():
    crop('restaurant/'+key,rest,box)
levels='restaurant/lahoue_restaurant_upgrade_levels.png'
for level,box in enumerate([(142,75,680,469),(704,24,1370,471),(0,518,450,1007),(451,510,927,1011),(928,496,1448,1012)],1):
    crop(f'restaurant/level_{level}',levels,box)

terrain='terrain/isometric_fantasy_settlement_tileset.png'
for name,box in {'grass':(5,56,287,276),'dusty_grass':(292,54,577,276),'dry':(582,55,865,276),'plot':(868,55,1154,276),'watered_plot':(1158,55,1448,276),'road':(290,318,573,531),'corner':(575,317,858,531),'junction':(1157,317,1448,531),'worn':(7,568,279,786),'shoulder':(282,568,560,786),'transition':(562,568,827,786),'weed':(1090,561,1200,706),'rock':(1099,706,1183,790)}.items():
    crop('terrain/'+name,terrain,box)

crop('terrain/base_surface','terrain/isometric_dry_earth_terrain_tile.png',(400,460,800,660))
crop('terrain/grass_surface',terrain,(94,123,199,177))
(DEST/'manifest.json').write_text(json.dumps(entries,indent=2),encoding='utf-8')
print(f'Extracted {len(entries)} approved crops to {DEST}')
