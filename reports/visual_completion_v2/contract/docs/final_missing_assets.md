# LaHoue — remaining external artwork, 2026-09-13

The supplied ZIP was inspected against FINAL_SCOPE. These are asset delivery gaps, not a request to generate images in code. No concept/poster sheet is used as a runtime sprite. Existing gameplay IDs remain authoritative.

## Assets preventing full visual sign-off

| Existing supplied file | Verified limitation | Required delivery |
| --- | --- | --- |
| `assets/lahoue_assets/world/buildings/restaurant.png` | Whole building includes baked dining furniture/food. It cannot serve as the required empty modular environment. | Empty ground-floor restaurant shell; separate open-air rooftop floor/railings; stair run and landings. Cover Lv1–2 single floor and Lv3–5 rooftop layouts. No tables, customers or finished food in these layers. |
| `assets/lahoue_assets/world/props/outdoor_dining_set_atlas.png` and `manifests/atlases/outdoor_dining_set_atlas.json` | Furnished umbrella-table components contain finished meals. | Empty table and separate chairs with clean transparent backgrounds, authored seat/foot anchors, same camera perspective. No food/customer baked in. |
| `assets/lahoue_assets/vehicles/trucks/truck_lv1.png` | Contains the complete depot environment, not an isolated Lv1 truck. | Isolated Lv1 truck, intact cab and wheels, transparent canvas. Current Lv1 runtime uses the verified isolated Lv2 truck as a disclosed visual fallback; capacity/timer/cost remain Lv1. |
| `assets/lahoue_assets/vehicles/trucks/truck_lv2.png` through `truck_lv5.png` | Single camera-facing poses; no authored set for all real road directions. | For each of the five truck identities: screen-space E/S/W/N views, including parked E. Route is `(460,740) → (1300,740) → (1300,950) → (1920,950)` and the reverse. Optional NE/SE/SW/NW frames improve corner changes. Keep cab complete and canvas/ground anchor identical. Supply authored wheel frames or separate wheels with pivots and artwork behind them. |
| `assets/lahoue_assets/world/buildings/truck_depot.png` | Baked vehicle conflicts with independently parked/moving trucks. | Empty east-facing bay with separate foreground occlusion layer, supporting the existing three spawn markers `(460,740)`, `(460,780)`, `(460,820)`. No baked truck. |

Current runtime uses explicitly simple geometric restaurant/table/depot fallbacks to satisfy separation and interaction requirements. These are not claimed as final illustrated artwork. In particular, truck facing is still a static fallback on segments whose facing is absent, so the visual truck-orientation item in FINAL_SCOPE is **not signed off**.

Suggested new delivery filenames (requested outputs, not files claimed to exist):

- `world/buildings/restaurant_ground_empty.png`, `restaurant_rooftop_empty.png`, `restaurant_stairs.png`, `restaurant_front_occlusion.png`.
- `world/props/dining_table_empty.png`, `dining_chair_ne.png`, `dining_chair_sw.png` with an atlas manifest if bundled.
- `world/buildings/truck_depot_empty_e.png` and `truck_depot_foreground_e.png`.
- `vehicles/trucks/truck_lv{1..5}_{e,s,w,n}.png` plus wheel metadata/frames.

Preserve the existing main scene's footprint/collision boundaries. Match presentation coordinates in `scripts/visual/restaurant_presentation.gd`, `scripts/restaurant/restaurant.gd`, and `scripts/visual/depot_presentation.gd`; artist-supplied anchors should resolve differences without moving gameplay routes. Supply transparent RGBA PNGs with fixed canvases and manifest bounds; never deliver a flattened promotional sheet as the replacement sprite.

## Missing animation frames/parts — safe fallbacks already run

The exact frame counts, clip naming, anchors and eight-direction contract are in [animation_supplemental_assets.md](D:/Game/LaHoue/reports/animation_supplemental_assets.md). That earlier Phase 1 document is an authoring contract; this document supersedes its old statement that the runtime has no bounded movement.

| Existing static identities | Missing authored content |
| --- | --- |
| `characters/player.png` | Idle/walk in eight directions. |
| `characters/waiter.png`, `chef.png`, `farm_worker.png`, `animal_worker.png`, `aquaculture_worker.png` | Idle/walk; role-specific cook/serve/payment/clean/harvest/collect clips, without gameplay completion callbacks. |
| `characters/customer.png`, `vip_customer.png` | Walk, sit transition, seated idle/wait, eat, payment and stand/leave clips. Character body, chair and meal must stay separable. Static standing artwork plus state labels currently communicate gameplay; genuine seated/eating body motion is not fabricated. |
| `animals/layer_chicken.png`, `meat_chicken.png`, `pig.png`, `dairy_cow.png`, `beef_cow.png` | Idle/walk plus chicken peck and cattle eat, production/collection acknowledgement. Supply frame sets or complete layered rigs with joint-overlap artwork. Bounded representative drift is already implemented. |
| `aquaculture/fish.png`, `shrimp.png`, `crab.png`, `squid.png`, `octopus.png` | Optional authored species locomotion frames. Current separate species sprites already have bounded subtle movement; this is not a runtime blocker. |
| `vehicles/helicopters/helicopter_lv1.png` through `helicopter_lv5.png` | Body without baked rotors, main rotor, tail rotor, pivots, overlap/occlusion and rotation plane metadata; alternatively a complete authored rotor frame set per identity. Altitude/flight/landing/shadow presentation already runs with the static rotor fallback. |

No production `SpriteFrames` libraries were supplied for these identities. Optional delivery location: `assets/lahoue_animations/<identity>/` plus `resources/animations/<identity>.tres`, assigned to the existing presenter's `frame_library`. Supply FPS, loop flags, frame order and foot/seat/hand anchors. Do not force mirroring of missing views or create occluded anatomy by slicing a flattened pose.

## Dish mapping data

The ten existing recipe-to-dish bindings remain unchanged; the other 40 recipes deliberately retain `DISH`. See [dish_icon_crosswalk.md](D:/Game/LaHoue/reports/dish_icon_crosswalk.md). To resolve them, supply an authoritative mapping of the remaining current `recipe_id` values to the existing `dish_id` values, or new matching artwork. No inferred assignments were added.
