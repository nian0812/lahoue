# LaHoue Static Asset Package — Final Structure Corrected

This archive is prepared for Codex/Godot integration. This pass changes package structure, extraction, naming, metadata and manifests only; it does not regenerate approved artwork.

## Verified canonical totals
- Characters: **8 / 8**
- Farm animals: **5 / 5**
- Aquaculture species: **5 / 5**
- Crops: **18 families / 90 PNGs**
- Dish icons: **50 / 50**
- Trucks: **5 levels**
- Helicopters: **5 levels**
- `world/buildings/restaurant.png`: present
- `animals/pig.png`: present

## Canonical structure corrections
- Farm animals live only in `animals/`.
- Fish, shrimp, crab, squid and octopus live only in `aquaculture/`.
- `building_purchase_upgrade_construction_kit.png` authoritative path: `ui/progression/building_purchase_upgrade_construction_kit.png`.
- `map_zone_expansion_visual_kit.png` authoritative path: `ui/progression/map_zone_expansion_visual_kit.png`.
- Dish IDs 21–50 were rebuilt from the approved source sheets using canonical recipe filenames.
- Canonical final dishes include `dish_48_ca_phe_sua_da.png`, `dish_49_com_hai_san_hoang_gia.png`, and `dish_50_lahoue_imperial_feast.png`.

## Atlas metadata
Every remaining PNG whose filename is an atlas, kit, sheet, or module set has a corresponding JSON file under `manifests/atlases/`. Coordinates use top-left pixel origin and include `x`, `y`, `width`, `height`, and `semantic_id`.

## Manifests
- `manifests/asset_manifest.json`
- `manifests/character_manifest.json`
- `manifests/animal_manifest.json`
- `manifests/aquaculture_manifest.json`
- `manifests/crop_manifest.json`
- `manifests/dish_manifest.json`
- `manifests/vehicle_manifest.json`
- `manifests/world_manifest.json`
- `manifests/ui_manifest.json`
- `manifests/atlas_manifest.json`
- `manifests/validation_report.json`

Codex should use the manifests as the authoritative mapping layer and should attach textures to existing visual nodes without rebuilding gameplay systems.
