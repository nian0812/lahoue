# LaHoue — final runtime pass, 2026-09-13

## 1. COMPLETED / sign-off boundary

Runtime implementation and regression are complete on Godot **4.7.1.stable.official.a13da4feb**, continuing the current project. Full illustrated visual sign-off remains blocked by the supplied asset gaps listed below. In particular, the single truck view cannot correctly face every road segment; the restaurant/table/depot are explicit simple fallbacks pending clean modular artwork. This report does **not** claim every visual Definition of Done item is complete.

Read the pack's README_FIRST, FINAL_SCOPE, ASSET_INTEGRATION_SPEC, RUNTIME_STATE_MAP and manifests. Reference copies are in `reports/final_scope/`. No Git commands were used. No VFX/audio pass or replacement managers were introduced. The ZIP's production PNGs matched the already integrated files; 25 differing manifests were updated, recorded in `reports/final_asset_import.json`. Concept/poster references were not imported as runtime sprites.

## 2. Main files changed

| Area | Files |
| --- | --- |
| Canonical final limits | `data/progression.json`; `scenes/world/zones/farm_zone.tscn` |
| Backward-compatible layout conversion | `autoload/save_manager.gd`; new `scripts/world/layout_migration.gd`; `autoload/inventory_manager.gd`; `scripts/ui/inventory_panel.gd` |
| Restaurant fixed ownership, circulation and serving | `scripts/restaurant/restaurant.gd`, `restaurant_table.gd`, `customer.gd`; new `scripts/visual/restaurant_presentation.gd`; `scripts/ui/restaurant_panel.gd`; `scenes/restaurant/restaurant_table.tscn` |
| Animal/aquaculture presentation | `scripts/visual/animation_state_observer.gd`; `scripts/animals/animal.gd`; `scenes/buildings/coop.tscn`, `pig_pen.tscn`; `scenes/aquaculture/aquaculture_container.tscn` |
| Vehicles/depot | `scripts/truck/truck_manager.gd`; `scripts/vehicles/vehicle_visual.gd`; `scripts/world/hub_building.gd`; new `scripts/visual/depot_presentation.gd` |
| World/camera/rendering | `project.godot`; `scenes/world/main_world.tscn`; `scripts/world/main_world.gd`; `scripts/visual/zone_ground_visual.gd`; `scripts/farming/farm_tile.gd`; mipmap import options on 327 production PNGs |
| Dev shortcut/profile/UI | `autoload/game_manager.gd`; `scripts/ui/day_summary_panel.gd` |
| Settings, completed earlier and revalidated | `autoload/settings_manager.gd`; `scripts/ui/main_menu.gd`; `scenes/ui/main_menu.tscn`; `tests/resolution_settings_test.gd` |
| Focused validation | New `tests/final_scope_test.gd/.tscn`, `final_visual_capture.gd/.tscn`, `final_profile_smoke.gd/.tscn`; contractual assertions updated in farming/modular world/ground/progression/upgrade/vehicle regression tests |

All paths above are relative to `D:\Game\LaHoue`.

## 3. Systems completed/fixed

- **Farm/world:** 28 actual fixed plot nodes, 7×4, existing IDs 01–28 retained. Unowned plot beds are hidden at runtime, including the one-plot starter state. Crop overlays remain separate. Dusty ground variation and worn transitions replace the strong flat green field; collision/route data was not shifted for artwork.
- **Restaurant:** five levels with capacities 2/4/7/11/15 and rooftop capacity 0/0/3/6/9. Purchased slots reveal in fixed order. Bar and Food Pass are separate; the pass starts empty, shows only actual ready jobs with the existing recipe mapping, and empties on pickup. Served food follows the assigned table during eating. Manual service and existing waiter dispatch remain functional. Customer entry/departure and staff presentation use the stair corridor without adding gameplay delays. The supplied baked restaurant and dining-table images are hidden in favor of clean geometric fallbacks.
- **Table price / kitchen:** the new per-table purchase price is explicitly data-driven at **100,000 VNĐ**, since FINAL_SCOPE specified table buying without a price. Original first-five restaurant unlocks/upgrade prices remain. Five kitchen tiers reach the former maximum six cooking slots and 80% cook duration. Individual recipe data is unchanged.
- **Animals:** capacities 4/8/12/16/20 for coop and 2/4/6/8/10 for pig/cow. Logical entities remain exact; visible populations are limited to five coop animals and three per other enclosure, with bounded gentle movement and grouped product information. Existing repeating production/collection logic remains. Legacy over-capacity populations are preserved through a saved allowance; new purchases obey canonical capacity.
- **Aquaculture:** fish/shrimp/crab/squid/octopus stay separate from their ponds; bounded small motion and smaller ready markers. Existing finalized five-pond, three-speed-tier progression is retained under FINAL_SCOPE's canonical-data exception.
- **Truck:** up to three vehicles; existing prices/capacities/timers and Ready/Outbound/Delivering/Returning logic preserved. Smooth acceleration/braking follows existing route markers; return no longer flips the whole isometric sprite. Whole-image opaque bounds retain the complete cab. Lv1 uses isolated Lv2 artwork because the supplied Lv1 PNG is a whole depot. Directional hooks exist, but missing directional artwork prevents full visual orientation sign-off.
- **Helicopter:** existing ready/departing/importing/returning/arrived timings and shipment logic remain. Safe altitude and shadow changes communicate takeoff/flight/landing. No fake rotor slicing or fabricated animation frames.
- **Staff/characters:** existing presentation foundation reads movement/state/job events. Work labels and short acknowledgement gestures do not delay cook/serve/payment/clean/harvest/collect results. Static fallback remains for unavailable full poses. Deferred feedback labels now free correctly when New Game retires a template before attachment.
- **Settings:** resolution presets 1280×720, 1366×768, 1600×900, 1920×1080, 2560×1440 plus detected native; native fullscreen and selected windowed-size restoration; centering where the display can accommodate the window. Resolution/fullscreen/master/music/SFX persist only in `user://settings.cfg`; responsive `canvas_items` stretch and 1280×720 logical viewport are retained.
- **Camera/rendering:** player and child Camera2D share physics interpolation; Camera2D physics callback with extra position smoothing disabled. Render-driven NPC roots avoid inappropriate double interpolation. Global pixel snapping stays off. The imported sprites previously requested mipmap filtering while their textures had no mipmaps; all 327 production texture imports now generate mipmaps. This addresses the camera cadence and minification causes rather than patching individual sprite positions. Camera behavior is consistent with the [Godot Camera2D reference](https://docs.godotengine.org/en/4.6/classes/class_camera2d.html); validation uses the actual 4.7.1 executable.
- **UI/progression:** normal Lv1–55, 50 recipes, achievements, tutorial and seven warehouse levels are preserved. P remains Market. Day Summary exposes Enter. Backspace is gated by `OS.is_debug_build()` and has no Tutorial/Help/Shortcut hint. No new dish guesses: 40 placeholders remain intentional.
- **Save migration:** optional `layout_version=2` remains within compatible save_version 1. Retired purchased farm plots refund their purchase price; ripe crops recover yield, unfinished crops recover seeds. Removed restaurant tiers refund their old costs. Ingredients for interrupted meals on retired tables go to a persistent recovery reserve, so a full warehouse cannot discard them. Inventory exposes a claim button. Paths/claims are reconstructed safely; animation frames, offsets, rotor/wheel phase and roaming targets are not saved. Legacy ten-table ownership remains ten when maximum capacity becomes fifteen. Duplicate retired plot IDs are rejected before refunds; normalization is idempotent.
- **Personal profile:** the real existing save remains **Lv100 / 1,000,000,000 VNĐ**, using its pre-existing explicit profile override. Earning EXP no longer makes that exceptional profile invalid. The normal game cap remains 55. Actual AppData save was only read/copied for isolated validation; its SHA-256 remained `4D26F8136F96E353E837AC3D43C52B12DB8CD743267BD488D8AF423AF15C33C1`.

## 4. Tests PASS / FAIL

| Validation | Result / evidence |
| --- | --- |
| Full existing regression plus new final-scope coverage | **25/25 PASS**, `reports/final_regression.txt` |
| Focused 28 plots, exact housing/table/warehouse tiers, purchases, rooftop distribution and clear landings | PASS, `tests/final_scope_test.gd` |
| Empty/cooking/ready Food Pass, known dish binding, manual pickup, meal at table, payment; existing waiter jobs | PASS, final-scope + cooking/staff/restaurant tests |
| Legacy 40 plots / 20 tables / Lv10 restaurant, active retired-table meal, exact refunds, reserve recovery, repeat load, purchased tables | PASS; 211.2M exact retired tier/plot refund fixture, no lost crop/ingredients; malformed duplicate/layout inputs rejected |
| Representative animal bounds and non-persistent motion; bounded swimming | PASS, final-scope test |
| Staff stair presentation leaves logical travel/job save state unchanged; cancellation resets offsets | PASS, final-scope test |
| Truck timing/return/skip-day and premium helicopter shipment loop | PASS, existing progression/vehicle/premium tests |
| Actual standalone resolution and native fullscreen restoration | PASS at all five presets, `.work/logs/settings_write.log` |
| Two subsequent standalone restarts, all five settings and no Settings clipping | PASS, `.work/logs/settings_read-windowed.log`, `settings_read-fullscreen.log` |
| Actual legacy personal Lv100 save, reward, save, Continue on isolated copy | PASS, `.work/logs/profile_smoke.log`; real save untouched |
| Production-root import and main-menu smoke | PASS, `.work/logs/root_import.log`, `root_smoke.log` |
| NVIDIA/OpenGL standalone rendering and camera stress at 20 physics Hz / 120 FPS limit | PASS: 115/120 sub-tick movement frames, zero backward frames; `reports/final_camera_validation.json` |
| Latest standalone shutdown after capture/template teardown fixes | PASS; no script/RID/ObjectDB leak errors in `.work/logs/capture_console.log` |
| Final illustrated truck facing / clean modular restaurant artwork | **BLOCKED by external artwork**, not passed by the automated suite |

Render evidence: `.work/final_restaurant.png`, `final_farm.png`, `final_animals.png`, `final_truck_road.png`, `final_camera_motion.png`. Screenshots were inspected, including a meal on a table and another ready on the pass. The numerical camera test confirms continuous interpolated movement; it is not a claim that absent animation artwork has been completed.

Tests used isolated project/user-data directories in `.work`, with the production asset directory shared read-only during runtime. The Windows Godot executable emits a certificate-store diagnostic in this environment; it did not block gameplay/tests. Expected negative-save/unknown-item diagnostics remain in the corresponding regression tests.

Reproduction runners: `.work/run_tests.ps1`, `.work/run_standalone.ps1` (settings), and `.work/run_standalone.ps1 -Capture`. The profile smoke accepts the path to a copied fixture and requires an isolated custom user directory containing `lahoue_codex_profile_smoke`.

## 5. Remaining true blockers

Full visual completion requires clean modular restaurant/table/depot artwork and correctly authored truck directions. The provided pack does not contain them. No further gameplay/runtime blocker was found in the regression and standalone checks. Missing full character/animal animation frames and rotor parts use the authorized fallback and did not stop runtime completion.

## 6. Exact missing external assets/files

See [final_missing_assets.md](D:/Game/LaHoue/reports/final_missing_assets.md) for verified supplied paths, required replacements, proposed delivery filenames, actual road directions and animation/rotor/frame contracts. The ten existing dish bindings and 40 intentionally unresolved mappings are documented in [dish_icon_crosswalk.md](D:/Game/LaHoue/reports/dish_icon_crosswalk.md).
