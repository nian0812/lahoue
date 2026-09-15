# Asset Integration Specification

## Package roles
- `assets/lahoue_assets/`: production baseline assets that may be imported/used.
- `references/approved_concepts/`: visual/layout references only. Do **not** place these full sheets into runtime scenes.
- Existing project crop/UI/data assets not duplicated here remain valid and should be reused.

## Environment/entity separation
Keep these strictly separate:
- Restaurant != tables/customers/dishes.
- Chicken Coop/Cow Barn/Pig Pen != animals.
- Aquaculture pond/facility != seafood entities.
- Truck Depot != truck.
- Farm Plot != crop.

Gameplay-state visuals should be instantiated/overlaid by scene/state, not baked into environment art.

## Current runtime state map from supplied scripts
### Player
- loop: `idle`, `walk_<direction>`.

### Staff
- gameplay `moving`/`returning` → visual `walk`.
- `cleaning_table` → `clean`.
- `off_duty` → `off_duty`.
- completed job one-shots use job names: `cook`, `serve`, `payment`, `clean`, `harvest`, `collect_animal`, `collect_aquaculture`.

### Customer
- walking flags → `walk`.
- `eating` → `eat`.
- `seated`, `ordering`, `waiting_food` → `seated_idle`.
- arrival one-shot → `sit`.
- payment one-shot → `payment`.

### Animal
- current observer baseline: `idle`, `completed`.
- event one-shots: `production`, `collect`.
- roaming/peck/eat is a presentation extension and must not alter production state/timing.

### Aquaculture
- empty pond → `empty`; stocked/growing/ready → visual `idle` baseline.
- collect event → `collect`.
- creature swim movement is presentation-only.

### Truck
- `ready`, `outbound`, `delivering`, `returning`.
- Derive visual facing from actual route movement rather than mirroring blindly.

### Helicopter
- `ready`, `departing`, `importing`, `returning`, `arrived`.

### Restaurant kitchen
- current observer can expose `cook` while any cooking job is active.
- one-shots include cooking_started / food_ready / cooking_canceled.

## Direction convention
`animation_state_observer.gd` currently resolves 8 directions: `e, se, s, sw, w, nw, n, ne`.
Do not rename these globally. If available artwork only supports four isometric directions, provide a deterministic nearest-direction mapping at presentation level rather than changing gameplay movement.

## Approved visual direction
- Fixed 2.5D isometric camera language.
- Semi-realistic / realistic-stylized, warm natural daylight.
- Rustic practical farm/logistics materials: wood, concrete, stone, metal; slightly dusty/weathered but maintained.
- Strong silhouettes and readable scale at gameplay zoom.
- Restaurant may be more polished/premium but must remain part of the same rural world.

## Concept reference notes
- Restaurant reference is for level massing, open-air rooftop and circulation; table graphics shown in a concept do not override fixed-slot runtime rules.
- Barn/coop/pen references are for enclosure growth and footprint; never bake animals into final scene composition.
- Aquaculture references are for facility growth; keep water free for runtime creatures.
- Truck reference is for progression/direction language; current production truck PNGs remain the safe baseline unless true directional variants are available.
- Helicopter reference shows desired parts/progression; existing production helicopter PNGs are the safe baseline.
- Terrain reference is for palette/material rhythm; never use any concept cell containing a baked crop as the farm-plot base.
- Character/staff concept sheet is pose guidance only; current production character PNGs are the safe baseline until real frame libraries exist.

## Missing frame policy
The supplied project has animation presentation infrastructure but may not have complete frame-by-frame libraries. This must not block project completion.
1. Keep state observer/presenter architecture.
2. Use existing static artwork as fallback.
3. Add safe procedural presentation where appropriate (movement facing, subtle bob, shadow/altitude, wheel/rotor feel) without changing gameplay timing.
4. Never invent unrelated new gameplay systems merely to compensate for missing art.
