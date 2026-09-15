from pathlib import Path
import json,re,shutil
r=Path(r'D:\Game\LaHoue')
def edit(path,fn):
 p=r/path; old=p.read_text(encoding='utf-8-sig'); new=fn(old)
 if new!=old:
  b=r/'.work/before_final'/path;b.parent.mkdir(parents=True,exist_ok=True)
  if not b.exists(): shutil.copy2(p,b)
  p.write_text(new,encoding='utf-8')
def progression(s):
 d=json.loads(s);d['farm_plots']['maximum']=28
 d['farm_plots']['level_limits']={k:min(v,28) for k,v in d['farm_plots']['level_limits'].items()}
 for key,step in [('coop',4),('pig_pen',2),('cow_barn',2)]:
  for level,x in d[key]['levels'].items():x['capacity']=int(level)*step
 for key in ['restaurant','kitchen']:
  d[key]['levels']={k:v for k,v in d[key]['levels'].items() if int(k)<=5}
 for level,cap in enumerate([2,4,7,11,15],1): d['restaurant']['levels'][str(level)]['tables']=cap
 # Retain max kitchen throughput when old ten restaurant tiers become five.
 for level,(slots,speed) in enumerate([(1,100),(2,94),(3,88),(4,84),(6,80)],1):
  d['kitchen']['levels'][str(level)].update(cooking_slots=slots,speed_percent=speed)
 return json.dumps(d,indent=2)+'\n'
edit('data/progression.json',progression)
def farm(s):
 def tile(m):
  n=int(m[1])
  if n>28:return ''
  return f'[node name="tile_{n:02}" parent="." instance=ExtResource("2_tile")]\nposition = Vector2({590+(n-1)%7*60}, {370+(n-1)//7*60})\ntile_id = "farm_{n:02}"\n'
 return re.sub(r'\[node name="tile_(\d+)"[^\n]*\]\nposition = Vector2\([^\n]+\)\ntile_id = "[^"]+"\n',tile,s)
edit('scenes/world/zones/farm_zone.tscn',farm)
edit('scripts/world/main_world.gd',lambda s:s.replace('maximum = 40','maximum = 28'))
edit('scripts/visual/zone_ground_visual.gd',lambda s:s.replace('Color("#31583a")','Color("#66674a")').replace('range(5):\n\t\tfor column: int in range(8):','range(4):\n\t\tfor column: int in range(7):').replace('row * 8 + column','row * 7 + column').replace('for row: int in range(4):\n\t\tvar y:', 'for row: int in range(3):\n\t\tvar y:').replace('Color(0.12, 0.24, 0.14, rng.randf_range(0.025, 0.060))','Color(0.27, 0.29, 0.17, rng.randf_range(0.06, 0.14))').replace('Color(0.46, 0.58, 0.30, rng.randf_range(0.018, 0.045))','Color(0.62, 0.50, 0.33, rng.randf_range(0.08, 0.18))'))
edit('scripts/ui/day_summary_panel.gd',lambda s:s.replace('Continue to Next Day"','Continue to Next Day (Enter)"'))
edit('autoload/game_manager.gd',lambda s:s.replace('current_exp += amount','if profile_level_override and level > data_manager.get_max_player_level():\n\t\treturn true\n\tcurrent_exp += amount'))
# Rendering: player runs at physics cadence; interpolate the world once and run camera at physics cadence.
edit('project.godot',lambda s:s.replace('[rendering]','[physics]\n\ncommon/physics_interpolation=true\n\n[rendering]').replace('renderer/rendering_method="gl_compatibility"','textures/default_filters/use_nearest_mipmap_filter=false\n2d/snap/snap_2d_transforms_to_pixel=false\n2d/snap/snap_2d_vertices_to_pixel=false\ntextures/canvas_textures/default_texture_filter=2\nrenderer/rendering_method="gl_compatibility"'))
edit('scenes/world/main_world.tscn',lambda s:s.replace('position_smoothing_enabled = true','process_callback = 0\nposition_smoothing_enabled = false'))
edit('scripts/truck/truck_manager.gd',lambda s:s.replace('visual_trucks[i].scale.x = -1.0','visual_trucks[i].scale.x = 1.0').replace('clampf(t, 0.0, 1.0) * route_length','smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0)) * route_length'))
edit('scenes/aquaculture/aquaculture_container.tscn',lambda s:s.replace('target_rect = Rect2(-22, -18, 44, 38)','target_rect = Rect2(-10, -7, 20, 14)').replace('[node name="product_visual" type="Polygon2D" parent="VisualRoot"]','[node name="product_visual" type="Polygon2D" parent="VisualRoot"]\nposition = Vector2(26, -24)\nscale = Vector2(0.3, 0.3)'))
edit('scripts/animals/animal.gd',lambda s:s.replace('name_lbl.visible = (current_state != state_completed)','name_lbl.visible = false').replace('body.scale.y = 1.0 + sin(_idle_offset * 2.0) * 0.05','body.scale.y = 1.0').replace('body.scale.x = 1.0 + cos(_idle_offset * 1.5) * 0.02','body.scale.x = 1.0'))
# Existing regressions follow the newly approved capacities; assertions remain active.
edit('tests/farming_foundation_test.gd',lambda s:s.replace('== 40','== 28').replace('all 40','all 28'))
edit('tests/progression_full_loop_test.gd',lambda s:s.replace('get_farm_plot_maximum() == 40','get_farm_plot_maximum() == 28').replace('35: 30, 40: 34, 45: 37, 50: 40','35: 28, 40: 28, 45: 28, 50: 28').replace('get_restaurant_table_capacity(10) == 20','get_restaurant_table_capacity(5) == 15'))
edit('tests/upgrade_level_test.gd',lambda s:s.replace('"restaurant": 10, "kitchen": 10','"restaurant": 5, "kitchen": 5').replace('.size() == 20 and int(restaurant.get("kitchen_level")) == 10','.size() == 15 and int(restaurant.get("kitchen_level")) == 5').replace('get("restaurant_level")) == 10','get("restaurant_level")) == 5'))
