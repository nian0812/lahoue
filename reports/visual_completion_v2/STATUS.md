> Latest project-pack integration and standalone validation: [FINAL_INTEGRATION_REPORT.md](FINAL_INTEGRATION_REPORT.md). The notes below describe the earlier kit-only audit; current changes, tests and captures are in the linked report.

# STATUS: BLOCKED — ARTWORK REQUIRED

V2 is the latest visual contract and supersedes the earlier asset-pack instructions. Runtime regression PASS does not establish visual completion. No required visible geometric/static fallback is signed off.

## Read and inventory

- Read the entire external `LaHoue_Visual_Completion_Prompt_V2.txt`, the kit's prompt, README_FIRST, MISSING_ASSET_CONTRACT, and all three required reports.
- All three reports in the kit are byte-identical to the project reports read during this audit (SHA-256 comparison).
- The supplied kit contains **six text documents and zero production artwork/frame/resource files**. README_FIRST explicitly describes it as an authoring/integration contract. The external prompt is an additional text file.
- Contract copies are preserved in `reports/visual_completion_v2/contract/`; source inventory and hashes are in `kit_inventory.json`.
- No new visual item could be integrated: no production art was delivered. No gameplay, scenes, save data, runtime scripts, settings or assets were changed in this audit. No Git commands were used.

## Exact absent named production PNGs

All 29 paths below were checked and are absent under `D:/Game/LaHoue/assets/lahoue_assets/`. None is supplied anywhere in the V2 kit.

```text
world/buildings/restaurant_ground_empty.png
world/buildings/restaurant_rooftop_empty.png
world/buildings/restaurant_stairs.png
world/buildings/restaurant_front_occlusion.png
world/props/dining_table_empty.png
world/props/dining_chair_ne.png
world/props/dining_chair_sw.png
world/buildings/truck_depot_empty_e.png
world/buildings/truck_depot_foreground_e.png
vehicles/trucks/truck_lv1_e.png
vehicles/trucks/truck_lv1_s.png
vehicles/trucks/truck_lv1_w.png
vehicles/trucks/truck_lv1_n.png
vehicles/trucks/truck_lv2_e.png
vehicles/trucks/truck_lv2_s.png
vehicles/trucks/truck_lv2_w.png
vehicles/trucks/truck_lv2_n.png
vehicles/trucks/truck_lv3_e.png
vehicles/trucks/truck_lv3_s.png
vehicles/trucks/truck_lv3_w.png
vehicles/trucks/truck_lv3_n.png
vehicles/trucks/truck_lv4_e.png
vehicles/trucks/truck_lv4_s.png
vehicles/trucks/truck_lv4_w.png
vehicles/trucks/truck_lv4_n.png
vehicles/trucks/truck_lv5_e.png
vehicles/trucks/truck_lv5_s.png
vehicles/trucks/truck_lv5_w.png
vehicles/trucks/truck_lv5_n.png
```

## Additional absent production sets

Neither `assets/lahoue_animations/` nor `resources/animations/` exists in the current project. No animation files or separated vehicle parts were delivered in the kit. The contract defines the following identities/clips/parts, but does not assign exact individual PNG filenames for these sets; filenames must be supplied with their frame/anchor manifests rather than invented in this report.

| Required set | Missing production content |
| --- | --- |
| `player`, `waiter`, `chef`, `farm_worker`, `animal_worker`, `aquaculture_worker`, `customer`, `vip_customer` | Eight-direction idle/walk libraries: 768 locomotion frames plus contracted role-specific work and customer sit/seated/eat/payment/stand actions. |
| `layer_chicken`, `meat_chicken`, `pig`, `dairy_cow`, `beef_cow` | Contracted idle/walk/production/collect libraries: 400 source frames, or approved complete layered rigs. |
| `fish`, `shrimp`, `crab`, `squid`, `octopus` | Contracted species-only idle libraries: 36 frames, fixed canvases/anchors. |
| `truck_lv1` through `truck_lv5` | Authored wheel layers or frame sets, axle pivots and body artwork behind wheels. Required by MISSING_ASSET_CONTRACT, beyond the directional PNG list above. |
| `helicopter_lv1` through `helicopter_lv5` | Finished body without rotors, main/tail rotor layers or coherent phase frames, required hub/mask parts and placement/phase metadata. |
| Cooking station | Authored pan/pot/utensil/lid layers and pivots as needed, or six-frame `cook_default` at 8 FPS, for the supplemental contract's visible cooking loop. |

Detailed direction, FPS, looping, anchor and part requirements remain in the copied `contract/docs/animation_supplemental_assets.md`. No missing direction is synthesized by mirroring. The 40 unresolved dish mappings remain unchanged and must not be guessed.

## Tests and captures

- Last recorded full regression: **25/25 PASS**, [final_regression.txt](D:/Game/LaHoue/reports/final_regression.txt). Tests were not rerun for this documents-only audit; this is explicitly the existing baseline result, not a new execution.
- Re-inspected baseline standalone [restaurant capture](D:/Game/LaHoue/.work/final_restaurant.png): geometric shell/table fallbacks and static customers remain visible. **Fails V2 visual sign-off.**
- Re-inspected baseline standalone [truck/depot capture](D:/Game/LaHoue/.work/final_truck_road.png): geometric depot and static truck-facing fallback remain visible. **Fails V2 visual sign-off.**
- Other existing evidence: [animals](D:/Game/LaHoue/.work/final_animals.png), [camera motion](D:/Game/LaHoue/.work/final_camera_motion.png). These are prior captures, not new V2 QA evidence.
- No new V2 captures were produced because there is no supplied artwork to integrate. The complete V2 capture matrix—world, restaurant Lv1/Lv5, Food Pass empty/ready/picked-up, trucks E/S/W/N, creatures, helicopter phases and moving camera—remains required after production delivery.

The next dependency is actual approved production artwork matching the above list and frame/part contract. Project visual completion remains blocked.
