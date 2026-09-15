# LaHoue Final Asset Pack — 2026-09-13

This pack is prepared for the final Godot 4.7.1 integration pass.

## What is production-ready in this pack
Use `assets/lahoue_assets/` as the usable production baseline. It contains the current verified world/building, vehicle, character, animal, aquaculture, food presentation and manifest assets needed by the final integration pass.

## What is reference-only
`references/approved_concepts/` contains the visual/layout concepts approved for the final pass. These are **design references**, not sprites to drop directly into gameplay. Do not import the full poster/reference sheets as runtime sprites.

Use them to guide scene composition, scale, progression and orientation while keeping runtime assets modular.

## Source-of-truth order
1. Existing gameplay/data/save logic in the project.
2. `docs/FINAL_SCOPE.md` for final gameplay/visual requirements.
3. `docs/ASSET_INTEGRATION_SPEC.md` for asset separation and state mapping.
4. Existing manifests under `assets/lahoue_assets/manifests/`.
5. Approved concept sheets for visual direction only.

## Critical rules
- Godot 4.7.1.
- No Git commands.
- Preserve save compatibility.
- No duplicate managers/systems.
- Environment assets must not bake gameplay entities into them.
- Backspace remains hidden dev-only.
- Missing frame animation must not block completion; keep static fallback and finish runtime logic/presentation.

The concise Codex/Astra instruction is included as `GPT6_ASTRA_FINAL_PROMPT.txt`.
