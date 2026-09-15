# Animation Phase 1 — supplemental asset requirements

Historical Phase 1 status below. The 2026-09-13 final runtime pass now includes bounded creature movement, staff/customer presentation and vehicle motion. See [current runtime report](D:/Game/LaHoue/reports/final_complete_project_pass.md) and [current missing assets](D:/Game/LaHoue/reports/final_missing_assets.md). The frame/anchor delivery contract below remains applicable; no production animation frame sets have been supplied.

Status: presentation foundation connected; no production animation frame libraries assigned. Existing artwork, asset bindings, shadows, normalized placement and animal breathing remain the visual baseline. No artwork was generated or reconstructed in code.

## Delivery contract

- Add new animation resources under `assets/lahoue_animations/` and `resources/animations/` when approved assets arrive. Do not overwrite the approved static PNGs or repurpose crop stages/UI atlases as animation frames.
- Preferred character/animal delivery: transparent RGBA PNG frame sets, with a Godot `SpriteFrames` resource for each identity. No backgrounds, baked contact shadows, labels, effects, or audio.
- Use a fixed canvas, identical subject scale and fixed ground/foot anchor across every frame of an identity. Supply canvas dimensions and the normalized foot anchor `(x / width, y / height)`; default is `(0.5, 1.0)`. Do not independently trim frames. Provide enough transparent margins for limbs/tools without shifting the anchor.
- Match the current approved identity, proportions, clothing/materials and 2.5D camera angle. Keep foreground/back limb ordering consistent. At current game scale, silhouettes and contact poses must remain readable.
- Direction suffixes: `e`, `se`, `s`, `sw`, `w`, `nw`, `n`, `ne`, measured in screen space (positive Y down). Supply all eight for walking. No automatic mirroring, invented back views, or perspective rotation of a single pose.
- Use `<action>_<direction>` clip names, e.g. `walk_ne`. Explicit `<action>_default` clips are accepted for directionless actions only. Missing clips retain static artwork. Each resource lists clip FPS, loop flag, frame order, and anchor. Frame counts below are the production target, not existing assets.
- The presenter fits a fixed authored canvas against the approved static footprint. Review scale and contact alignment against the original before assigning any library. It never changes actor transforms, physics, markers or save data.

## Character frame sets

| Identity / binding | Required clips | Directions | Frames and playback |
| --- | --- | --- | --- |
| `player` | `idle`, `walk` | All 8 | Idle: 4 frames at 4 FPS, loop. Walk: 8 at 10 FPS, loop (96 frames total). |
| `waiter` | `idle`, `walk`, `off_duty` | Idle/walk: all 8; off-duty can reuse authored idle explicitly | Same 96-frame locomotion set; off-duty is a presentation state, not a new role. |
| `chef` | `idle`, `walk`, `off_duty` | Same | Same 96-frame locomotion set. |
| `farm_worker` | `idle`, `walk`, `off_duty` | Same | Same 96-frame locomotion set. |
| `animal_worker` | `idle`, `walk`, `off_duty` | Same | Same 96-frame locomotion set. |
| `aquaculture_worker` | `idle`, `walk`, `off_duty` | Same | Same 96-frame locomotion set. |
| `customer` (gameplay `regular`) | `idle`, `walk` | All 8 | Same 96-frame locomotion set. |
| `vip_customer` (gameplay `vip`) | `idle`, `walk` | All 8 | Same 96-frame locomotion set, preserving VIP identity. |

Locomotion subtotal: eight identities × 96 = **768 source frames**. Off-duty can be a resource alias of the delivered idle frames, without new artwork.

Additional action sets:

| Identity | Clip | Directions / frame target | Trigger and restrictions |
| --- | --- | --- | --- |
| Waiter | `serve`, `payment` | 8 × 6 frames each, 12 FPS, non-looping | Successful job completion. The gesture may finish while the actor begins returning; do not hold the gameplay actor at the table. |
| Waiter | `clean` | 8 × 6 frames, 8 FPS, loop | Existing cleaning state and timer. Stop at job cancellation/completion. |
| Chef and waiter fallback | `cook` | 8 × 6 frames each identity, 12 FPS, non-looping | Starting a cooking job releases the worker immediately. This is a brief start gesture, not a new worker occupation timer. |
| Farm worker | `harvest` | 8 × 6 frames, 12 FPS, non-looping | Successful harvest only; failed/full-storage attempts do not play success. |
| Animal worker | `collect_animal` | 8 × 6 frames, 12 FPS, non-looping | Successful collection only. |
| Aquaculture worker | `collect_aquaculture` | 8 × 6 frames, 12 FPS, non-looping | Successful worker collection/restart result. |
| Customer and VIP | `sit` | 8 × 6 frames per identity, 10 FPS, non-looping | Actual `arrived_at_table`, not the early logical `seated` state. |
| Customer and VIP | `seated_idle` | 8 × 4 frames per identity, 4 FPS, loop | Ordering/waiting after arrival. Include a seat-contact anchor and per-direction hand/table anchor metadata. |
| Customer and VIP | `eat` | 8 × 8 frames per identity, 8 FPS, loop | Existing eating state; stop when gameplay leaves it. No minimum meal duration is introduced. |
| Customer and VIP | `payment` | 8 × 6 frames per identity, 12 FPS, non-looping | Successful `payment_collected` event only. Never infer payment from leaving, because timeouts also leave. |
| Customer and VIP | `stand` | 8 × 6 frames per identity, 10 FPS, non-looping | Supplemental asset for the later transition pass. It must fit existing departure timing; its selection is not implemented in Phase 1. |

Walking out uses the same authored walk set. The current arrival direction is observable, but a dedicated seated facing/occlusion review is still required before enabling seat clips. That review may use artwork offsets only; `seat_marker`, table ownership, table release and customer routes remain unchanged. Chairs, dishes and cutlery must not be baked into the character body; provide separable props with hand/seat anchors if the pose needs them.

## Farm animal frame sets

Bindings remain: `chicken` → `layer_chicken`, `meat_chicken` → `meat_chicken`, `pig` → `pig`, `dairy_cow` → `dairy_cow`, `cow` → `beef_cow`.

For **each of those five visual identities**, supply:

- `idle_default`: 4 frames, 4 FPS, loop, matching its currently approved camera-facing pose. Species-specific breathing/head/ear/tail motion, with stable ground contact.
- `walk_<direction>`: 8 frames × all 8 directions, 8 FPS, loop. These are for the later small visual movement pass; Phase 1 does not add animal wandering or alter animal positions/collision areas.
- `production_default`: 6 frames, 10 FPS, non-looping; a small body/head reaction, with no product, particles, sparkles or floating icons embedded.
- `collect_default`: 6 frames, 12 FPS, non-looping; a restrained acknowledgement. The existing product signals decide when it is requested.
- Total target: **80 frames per identity / 400 frames**. Completed lifecycle remains the existing static presentation; no death/slaughter sequence is requested.

An alternative layered rig requires intact torso, head/neck, each visible limb/wing, tail, and species-specific ears/udder only where visible, with overlap artwork behind joints. Supply joint pivots, draw order and authored poses. Do not slice a flattened image and invent occluded anatomy in code. Choose frame sets or a reviewed rig per identity, not both by default. Rig playback is a later adapter, not shipped in Phase 1.

## Aquaculture

Five separate identities: `fish`, `shrimp`, `crab`, `squid`, `octopus`.

- `idle_default`: fish 8 frames / 6 FPS (tail/fin); shrimp 6 / 5 FPS (antennae/appendages); crab 6 / 4 FPS (small limb motion); squid 8 / 5 FPS (mantle/tentacles); octopus 8 / 5 FPS (arms/mantle). All loop and retain the existing approved perspective. These frame counts total 36.
- Optional later `collect_default`: 4 frames / 10 FPS per species, non-looping; no splash or other VFX.
- Transparent species-only frames, with the same fixed canvas and anchor contract. Animate only within the existing pond interior/visual footprint. Empty/unowned ponds must not show animated species. Existing water/pond artwork is not replaced.

## Helicopter — five level variants

Supply a separate complete set for `helicopter_lv1` through `helicopter_lv5`. Each current helicopter texture is flattened, with rotor blades baked into it. The fallback rotor line is not a usable artwork layer.

Required layers per level:

1. **Body without main/tail rotor blades**, with the body/background areas exposed by blade removal finished by the artist; retain skid geometry and current approved identity.
2. **Main rotor hub**, separate only if it must remain stationary relative to spinning blades; label intended ownership.
3. **Main rotor blades** on a transparent fixed canvas, pivot at the hub. Preferred: 8 perspective-correct phase frames for a full turn, same hub position in every frame. A flat 2D rotation must not distort the isometric rotor plane.
4. **Tail rotor**: 8 phase frames in its actual plane, pivot at the tail hub, with near/far occlusion defined.
5. **Mask/occlusion layers** where a rotor passes behind the body, supplied explicitly if needed. No baked ground shadow.

Metadata for every level: body canvas dimensions, ground/skid anchor, main/tail hub pixel coordinates, rotor plane orientation, frame phase order, layer draw order and body-to-rotor offsets. Deliver a parked reference composite to verify the assembled result matches the approved original.

Later rotor speed ramps and body lift/attitude use the existing departing/returning phase progress. Importing remains offscreen; ready/arrived use the helipad marker. No new flight duration, route point, shipment state or rotor save field is required. If layered source cannot be provided, supply complete coherent frame sets (`ready_default`, `departing_default`, `returning_default`, `arrived_default`) for each level instead, with the same fixed contact anchor and metadata. The layered rotor adapter is intentionally deferred until real parts arrive.

## Truck and cooking props

- Truck Lv1–5: existing bodies can support later small suspension/settling transforms. Actual wheel rotation requires separately drawn body-without-wheels and wheel layers, with axle pivots per level; no wheel artwork is fabricated.
- Kitchen: ongoing cooking belongs to `restaurant.cooking_jobs`, because the chef is released after starting a job. The scene currently has a kitchen marker and bundled static kitchen atlas, but no independent moving utensil/pot rig. For a visible cooking loop, supply a pan/pot, utensil, lid and hand/contact pivots as needed, or 6-frame `cook_default` station artwork at 8 FPS. Specify one fixed canvas and the kitchen-marker-relative visual placement. Assembly must be additive; the restaurant building and marker remain unchanged.
- Cooking-ready/canceled/served events carry customer and recipe IDs. Any later dish props use existing verified mappings only; all 40 unresolved recipes retain DISH placeholders.

## Foundation interfaces and next gate

`animation_presentation` is a child observer in the player, staff, customer, animal, aquaculture, truck, helicopter and restaurant scenes. It exposes a read-only snapshot, `loop_changed`, and `action_requested`; the restaurant observer exposes current cooking jobs and cooking events. No animation completion callback changes gameplay.

Frame-library entries are keyed by the exact visual identity above. No production entries exist yet. Missing direction/action/identity uses the integrated static image, without per-frame warnings. Approved frame libraries can be assigned after resource/anchor review; separated rigs need their asset-specific adapter later.

Next gate: deliver/review the player idle/walk set first, then extend to workers and customers. Detailed locomotion, seated action and rotor animation remain pending real supplemental artwork. Phase 1 is not a claim that those animations have been completed.
