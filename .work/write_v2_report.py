from pathlib import Path
import json, csv, hashlib

root = Path('D:/Game/LaHoue')
out = root / 'reports/visual_completion_v2'
runtime = root / 'assets/lahoue_assets'
pack = root / 'assets/LaHoue_Final_Asset_Pack_2026-09-13/LaHoue_Final_Asset_Pack'
contract = json.loads((out/'contract/docs/MISSING_ASSET_CONTRACT.json').read_text(encoding='utf-8-sig'))
missing = []
scene_map = {'restaurant':'scenes/restaurant/restaurant.tscn (VisualRoot/ModularRestaurant)', 'tables':'scenes/restaurant/restaurant_table.tscn', 'truck_depot':'scenes/buildings/truck_depot.tscn', 'trucks':'scenes/vehicles/truck_visual.tscn'}
for group, values in contract['blocking_visual_assets'].items():
    paths = values if isinstance(values,list) else [values['pattern'].format(level=l,direction=d) for l in values['levels'] for d in values['required_directions']]
    for relative in paths:
        matches = list(pack.rglob(Path(relative).name))
        assert not (runtime/relative).exists() and not matches, relative
        missing.append({'missing_path':str(runtime/relative).replace('\\','/'),'runtime_element':scene_map[group],'classification':'ARTWORK REQUIRED','pack_filename_matches':0})
(out/'missing_production_assets.json').write_text(json.dumps(missing,indent=2),encoding='utf-8')
trace=json.loads((out/'captures/runtime_texture_evidence.json').read_text())
wired={}
for capture in trace['captures']:
    for sprite in capture['visible_sprite_sources']:
        wired.setdefault(sprite['texture'],set()).add(sprite['node'])
with (out/'runtime_asset_bindings.csv').open('w',newline='',encoding='utf-8') as f:
    writer=csv.writer(f);writer.writerow(['texture','runtime_node'])
    for path,nodes in sorted(wired.items()):
        for node in sorted(nodes):writer.writerow([path,node])
logs=['v2_root_standalone.log','v2_profile_smoke.log','settings_write.log','settings_read-windowed.log','settings_read-fullscreen.log','visual_completion_capture.log','final_scope_test.log']
for name in logs:
    (out/name).write_bytes((root/'.work/logs'/name).read_bytes())
captures='\n'.join(f"- [{c['id']}](captures/{c['id']}.png) — zoom {c['camera_zoom']}" for c in trace['captures'])
(out/'SCREENSHOTS.md').write_text('# Runtime screenshot evidence — 2026-09-13\n\n20 standalone 1920×1080 viewport captures, Godot 4.7.1 / NVIDIA GTX 1660 Ti. Controlled isolated fixtures exercise real runtime nodes and production textures. HUD is hidden for inspection; settings clipping is tested separately. These show both integrated art and remaining fallbacks, and are not a visual completion sign-off. The 0.65 overview is deliberately zoomed out beyond normal play.\n\n'+captures+'\n\n`captures/runtime_texture_evidence.json` records texture paths and nodes visible in the scene tree; this includes nodes outside the current camera viewport. Truck/helicopter shots place actual presentation at controlled phase values; shipment timers are covered by regression tests.\n',encoding='utf-8')
missing_rows='\n'.join(f"| `{m['missing_path']}` | `{m['runtime_element']}` | ARTWORK REQUIRED |" for m in missing)
assets='\n'.join(f'- `{path}`' for path in sorted(wired))
report=f'''# 1. STATUS: BLOCKED — ARTWORK REQUIRED

The V2 prompt and entire six-document kit are the latest contract. All available production artwork in the named project pack was inventoried and compared with runtime copies. Required visual fallbacks remain visible; successful runtime tests do not mean visual completion. No Git commands were used.

# 2. Integration summary

The nested production source is `D:/Game/LaHoue/assets/LaHoue_Final_Asset_Pack_2026-09-13/LaHoue_Final_Asset_Pack/assets/lahoue_assets/`. Its 135 PNGs and 25 JSON manifests already exist byte-for-byte at `D:/Game/LaHoue/assets/lahoue_assets/`. All 160 comparisons match SHA-256. There are no overlooked new production files to copy. The wider runtime folder has 327 PNGs including previously integrated UI/crop assets. The ten approved concept sheets remain references and are not used as sprites. The V2 kit itself has zero artwork.

Fixed an actual aquaculture integration bug: species artwork was centered over the pond's rear structure. It now fits the authored water interior, with a smaller separate sprite and restrained drift. Only presentation position, scale and drift changed. A strengthened test projects every species sprite corner into the pond PNG and checks 300 motion samples per pond against its water interior, while asserting production/save state remains identical.

Verified 28 separate production plot sprites; restaurant purchased-only slots and 2/4/7/11/15 capacities; rooftop slots and clear stairs; visible kitchen/bar props; Food Pass empty → exact known ready dish → cleared on pickup with dish at table; separate bounded creatures; three trucks and actual route phases; helicopter altitude states. Restaurant/table/depot geometry, directional truck/static animation and ground-art requirements remain unsigned.

# 3. Exact files changed in this pass

Runtime:
- `D:/Game/LaHoue/scenes/aquaculture/aquaculture_container.tscn`
- `D:/Game/LaHoue/scripts/visual/animation_state_observer.gd`

Tests:
- `D:/Game/LaHoue/tests/final_scope_test.gd`
- `D:/Game/LaHoue/tests/visual_completion_capture.gd` (new)
- `D:/Game/LaHoue/tests/visual_completion_capture.tscn` (new)

Evidence/report files under `D:/Game/LaHoue/reports/visual_completion_v2/`: `FINAL_INTEGRATION_REPORT.md`, `STATUS.md`, `SCREENSHOTS.md`, `project_pack_inventory.csv`, `runtime_asset_bindings.csv`, `missing_production_assets.json`, `captures/runtime_texture_evidence.json`, the 20 PNGs listed in SCREENSHOTS.md, and copied logs {', '.join('`'+n+'`' for n in logs)}. Regenerated `D:/Game/LaHoue/reports/final_regression.txt` and `D:/Game/LaHoue/reports/final_camera_validation.json`. Local report helper: `D:/Game/LaHoue/.work/write_v2_report.py`.

No production PNG was changed, fabricated or unnecessarily recopied. No gameplay schema, collision, route, timer, ownership, economy or actual player save/settings file was changed.

# 4. Exact assets found and wired

[All 160 source/runtime comparisons](project_pack_inventory.csv) and [exact texture-to-runtime-node bindings](runtime_asset_bindings.csv). The following {len(wired)} distinct texture sources were observed through the capture fixtures (existing integration, with the aquaculture placement corrected in this pass):

{assets}

`world/buildings/restaurant.png` has baked tables/food and cannot supply purchased-only slots or an empty Food Pass. `world/props/outdoor_dining_set_atlas.png` contains served meals and cannot supply the required empty furniture. `world/buildings/truck_depot.png` and `vehicles/trucks/truck_lv1.png` include a baked parked vehicle/depot composition. The Lv1 moving vehicle consequently still uses the isolated Lv2 truck fallback. Existing Lv2–5 trucks have a single authored view. Existing helicopter PNGs have baked rotors. None is a substitute for the V2 separated/directional assets.

# 5. Remaining blockers

Exact named missing paths, checked both at runtime and throughout the project pack:

| Missing file | Affected scene/runtime element | Classification |
| --- | --- | --- |
{missing_rows}

Additional ARTWORK REQUIRED:
- `D:/Game/LaHoue/assets/lahoue_animations/` and `D:/Game/LaHoue/resources/animations/` are absent. Player/staff/customer presenters retain static poses; genuine eight-direction idle/walk and role/customer action sets are missing (768 locomotion source frames plus actions). Animals retain static representative sprites (400 contracted source frames missing); aquaculture has restrained sprite translation but no 36-frame idle libraries.
- `scenes/vehicles/helicopter_visual.tscn`: all five levels lack body-without-rotors, main/tail rotor parts, required hub/mask pieces or coherent phase frames and placement metadata. Altitude translation of a flattened sprite remains a fallback.
- `scenes/vehicles/truck_visual.tscn`: wheel parts/frames and axle/body-under-wheel artwork are missing in addition to the 20 directional PNGs above.
- Restaurant cooking presentation lacks authored utensil/pan/lid layers or the contracted six-frame `cook_default` loop. Static kitchen props do exist.
- World `GroundVisual`: authored full ground fill and road/ground transitions suitable for the actual layout are still missing. Available `world/environment/road_tiles_kit.png` provides discrete isometric pieces already used in paths, not the complete required ground coverage/directions. Dusty geometric fills and ribbons remain visible. The V2 documents do not specify exact filenames for this additional terrain set; filenames must be supplied with its atlas/placement contract.

Exact frame filenames beyond the 29 named PNGs are not assigned by the contract; do not invent them. Full identities, directions, anchors, rates and layer requirements remain in [animation supplemental contract](contract/docs/animation_supplemental_assets.md). The 40 intentionally unresolved dish mappings remain unchanged.

The aquaculture placement INTEGRATION BUG found in this pass is fixed and tested. Remaining items above are missing suitable production artwork, not missing copies of delivered files. Complete visual sign-off and frame-level animation QA remain blocked.

# 6. Test results

- Godot 4.7.1 focused final-scope test including all five aquatic sprite bounds: PASS.
- Existing full regression after the final change: **25/25 PASS**, see `../final_regression.txt`.
- Standalone root launch at 1280×720: PASS, real NVIDIA OpenGL backend, normal exit.
- Standalone window sizes 1280×720, 1366×768, 1600×900, 1920×1080, 2560×1440: PASS. Native entry deduplication, centering, native fullscreen, fullscreen → selected windowed restoration: PASS. Settings panel/control/text bounds: PASS.
- Settings persistence across windowed and fullscreen restarts, master/music/SFX restoration, unchanged stretch/logical viewport and untouched gameplay save: PASS. See three settings logs.
- Copy of current Lv100 profile loads, earns XP, saves and continues: PASS in isolation. Actual current wallet is 988,500,000; this pass did not reset it to an earlier balance. Actual source save SHA-256 remained `28F4A6C05861F9384205E0829A0EA632EF63ACB219F1F00051C235993F4A6FA4` before/after validation.
- Camera stress: PASS, 20 Hz physics / 120 FPS render limit, 116 interpolated frames out of 120, zero backward frames. This is transform/cadence evidence, not a guarantee about unfinished artwork.
- New standalone capture fixture: PASS, zero functional capture failures, 20 screenshots. **Visual acceptance: BLOCKED**, as required by V2.

All test save/settings writes used isolated APPDATA/custom user directories. Logs include the existing Windows root-certificate-store diagnostic; no script/parse failure occurred in the final passing runs.

# 7. Screenshot evidence

[All 20 screenshots with labels](SCREENSHOTS.md), [runtime source trace](captures/runtime_texture_evidence.json).

Key evidence: [28 individual plots](captures/farm_28_normal_scale.png), [corrected separate aquatic species](captures/creatures_motion_0.png), [empty Food Pass and remaining restaurant fallback](captures/food_pass_empty_lv5.png), [ready dish](captures/food_pass_ready_lv5.png), [three trucks and remaining depot fallback](captures/depot_three_parked.png), [helicopter altitude with static rotor limitation](captures/helicopter_departing.png).
'''
(out/'FINAL_INTEGRATION_REPORT.md').write_text(report,encoding='utf-8')
status=out/'STATUS.md'
old=status.read_text(encoding='utf-8-sig')
notice='> Latest project-pack integration and standalone validation: [FINAL_INTEGRATION_REPORT.md](FINAL_INTEGRATION_REPORT.md). The notes below describe the earlier kit-only audit; current changes, tests and captures are in the linked report.\n\n'
if notice not in old:status.write_text(notice+old,encoding='utf-8')
print(f'Report written: {len(missing)} absent PNGs; {len(wired)} observed texture sources; {len(trace["captures"])} screenshots')
