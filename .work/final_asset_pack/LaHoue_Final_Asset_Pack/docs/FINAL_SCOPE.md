# LaHoue — Final Scope / Definition of Done

## Global
- Engine: Godot 4.7.1.
- Keep the current modular architecture and all working gameplay systems.
- Preserve `user://savegame.json` backward compatibility.
- Settings belong in `user://settings.cfg`.
- Level cap is 55; Lv55 title `LaHoue Empire`, EXP shows `MAX`, endless play continues.
- Starter state remains 200,000 VNĐ + Rice x10 + Wheat x10 + Warehouse + one visible/owned farm plot + Truck #1.
- Level = unlock permission; money = ownership/expansion/upgrades.
- Sales EXP = `floor(revenue / 10000)`, cap 1000 per sale transaction. No sales EXP for purchases/imports/building ownership/upgrades/transfers.
- Backspace is dev-only and must never appear in player-facing UI/tutorial/help.

## Farm / World
- Final maximum farm plots: 28, individually represented and saved; target layout approximately 7x4 while respecting the actual isometric world.
- Crops remain overlays/stages; never bake crop into plot artwork.
- Plot visual states: empty/dry, tilled, watered where applicable; selected/locked as overlays.
- Replace the large flat green look with dusty grass/earth/road transitions and worn working-farm ground while retaining readable zones.
- Do not alter gameplay footprints/collisions merely to make artwork larger; prefer VisualRoot scale/placement corrections.

## Restaurant final progression
- Lv1: 2 ground tables.
- Lv2: 4 ground tables.
- Lv3: 4 ground + 3 rooftop = 7.
- Lv4: 5 ground + 6 rooftop = 11.
- Lv5: 6 ground + 9 rooftop = 15.
- Lv1–2 one floor; Lv3–5 have a real open-air rooftop dining floor.
- Tables are fixed slots, not free placement. Buying a table reveals the next valid slot.
- The stair landing/path must always remain clear; never put a table at the stair foot/landing.
- Base restaurant/environment contains no baked customer tables, customers or completed dishes.
- Ground floor visibly includes a Bar and a separate Food Pass.
- Food Pass is empty by default. When cooking completes, the correct existing dish/drink visual appears; pickup removes it. Waiter serves automatically if hired; otherwise player can serve manually.
- Customer visible flow: enter/walk → assigned purchased table → sit → order/wait → eat → payment → leave.
- Customers may order only unlocked recipes.

## Staff
- Preserve current gameplay roles: Waiter, Chef, Farm Worker, Animal Worker, Aquaculture Worker.
- Farm Worker stays harvest-only unless current data explicitly says otherwise.
- Presentation states should cover idle/walk plus job gestures (cook, serve, payment, clean, harvest, collect) without delaying gameplay completion.

## Animals
- Repeating-production animals remain after collection.
- Chicken Coop capacity: 4/8/12/16/20 for Lv1–5.
- Pig Pen capacity: 2/4/6/8/10.
- Cow Barn capacity: 2/4/6/8/10.
- Enclosures contain environment only; animals are separate runtime entities.
- Animals stay inside enclosure movement bounds. Representative visual population is allowed; logical count remains exact.
- Chicken: idle/walk/peck. Pig: idle/walk. Cow/Dairy Cow: idle/walk/eat.
- Avoid overlapping labels; prefer hover/selected/grouped information.

## Aquaculture
- Species: Fish, Shrimp, Crab, Squid, Octopus.
- Facility capacity target by level: 4/8/12/16/20 unless current canonical progression data intentionally differs; keep canonical data if already finalized.
- Ponds contain water/environment only; creatures are separate.
- Movement stays inside water bounds: fish swim, shrimp subtle movement, crab short sideways movement, squid/octopus subtle swim/bob.
- Ready/product marker should be smaller and positioned so it does not cover the pond/creatures.

## Truck / Depot
- Depot bay faces the actual main road so trucks start parked logically and join the route without an awkward immediate 180-degree turn.
- Up to 3 trucks.
- Truck phases remain Ready → Outbound → Delivering → Returning.
- Truck levels: Lv1 10/50s; Lv2 20/40s 200K; Lv3 35/30s 500K; Lv4 60/20s 1M; Lv5 100/10s 3M. Truck #2 2M; #3 4M.
- Use proper movement direction presentation; do not mirror with `scale.x = -1` if it breaks isometric perspective.
- Fix parked/outbound/return orientation, cropped cab, wheel-motion feel and acceleration/cruise/brake/settle presentation without changing delivery timing.
- Fast Forward/skip-day must remain compatible.

## Premium Market / Helicopter
- Preserve current Premium/International Market gameplay.
- Helicopter phases remain ready/departing/importing/returning/arrived.
- Progression: Lv1 cap10/60s purchase 100M; Lv2 20/50s 50M; Lv3 35/40s 100M; Lv4 50/30s 200M; Lv5 75/20s 500M.
- Presentation: spool-up, takeoff, flight, return, landing, spool-down. If separate rotor artwork is unavailable, keep a safe static fallback and complete motion/state presentation without blocking the pass.

## Warehouse
- 7 gameplay levels: 75 start; 150@Lv5; 300@Lv10; 500@Lv18; 750@Lv28; 1000@Lv38; 1500@Lv50.
- Do not collapse gameplay to five levels because a concept sheet shows five visual tiers.
- Normalize visual scale if needed; preserve capacity/save/economy logic.

## UI / Tutorial / Achievements
- Preserve Inventory, Shop, Upgrade, Recipes, Restaurant, Staff, Truck, Premium Market, Achievements, Tutorial, Day Summary, notifications and toolbar.
- P remains the Market shortcut.
- Day Summary clearly exposes Enter to continue to the next day.
- No Backspace hint in player-facing UI.
- Keep achievements/tutorial working after layout changes.

## Resolution / Settings
- Supported presets at minimum: 1280x720, 1366x768, 1600x900, 1920x1080, 2560x1440 plus native when available.
- Windowed resolution must resize the standalone game window.
- Fullscreen uses the native display; leaving fullscreen restores selected windowed resolution.
- Persist resolution/fullscreen/master/music/SFX in `user://settings.cfg`; restart must restore them.
- Do not diagnose resize behavior only from Godot Embedded Game because embedded windows may refuse resize/move.

## Camera / Rendering
- Fix root cause of movement jitter/shimmer/subpixel instability. Audit Camera2D smoothing, viewport/content scale/stretch, pixel snapping/interpolation and parent transforms.
- Do not patch individual sprites as a substitute for fixing the transform/camera root cause.

## Save / Migration
- Preserve New Game/Continue and legacy save loading.
- Save persistent ownership/progression; do not save transient animation frame/direction/rotor/wheel/roaming targets.
- Legacy saves with old farm/table layouts must not crash or lose money/items.

## Definition of Done
- No parse/runtime blockers.
- Core loop works end to end.
- Exactly 28 maximum farm plots.
- Restaurant capacities 2/4/7/11/15 and stair circulation is clear.
- Bar/Food Pass/manual+waiter serving work visually and logically.
- Animals/aquaculture have sensible scale/bounds and do not escape containers.
- Truck/Depot orientation and return path look correct.
- Helicopter state presentation works.
- Resolution/fullscreen persistence works in standalone.
- Camera no longer visibly jitters/shimmers during movement.
- Save/Continue, Tutorial and Achievements still pass.
- Existing regression suite passes, plus focused tests for changed behavior.
