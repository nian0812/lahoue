# lahoue phase 1

## scope

This package contains only the agreed phase 1 bootstrap:

- project configuration
- folder structure
- autoload managers
- data-driven JSON foundation
- minimal `main_world`
- 240-second day timer foundation
- single `finish_day()` entry point
- save/load foundation
- inventory capacity foundation

No polished UI, final assets, crop scene, animal scene, restaurant gameplay, customer logic, or cooking logic is included yet.

## unresolved design values

The source specification does not define these values, so they are deliberately left unresolved rather than invented:

- starting money: `null` in `progression.json`; technical new-game state currently starts at `0`
- dairy cow daily milk amount: `null`
- recipe cooking times: `null`
- recipe EXP: `null`
- several seafood/drink/premium recipe ingredient lists: `null`

Before those systems become active, these values should be confirmed and then filled in data.

## test

1. Open `project.godot` in Godot 4.x.
2. Run the project.
3. Confirm `main_world` opens without missing-resource errors.
4. Open Remote scene tree and confirm:
   - `main_world`
   - `hub`
   - `farm`
   - `restaurant`
   - `player`
   - `camera`
   - `ui`
5. Confirm autoloads exist:
   - `data_manager`
   - `game_manager`
   - `inventory_manager`
   - `save_manager`
6. Press ESC: scene tree should pause/unpause.
7. Press Backspace while gameplay is active: `day` increments and `day_timer` resets to `0`.
8. Close the running game: `user://savegame.json` should be written.
