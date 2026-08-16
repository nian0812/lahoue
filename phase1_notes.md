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

## remaining unresolved design values

The source specification does not define these values, so they are deliberately left unresolved rather than invented:

- starting money: `null` in `progression.json`; technical new-game state currently starts at `0`
- recipe cooking times: `null`
- recipe EXP: `null`
- several seafood/drink/premium recipe ingredient lists: `null`

Before those systems become active, these values should be confirmed and then filled in data.

## phase 4 animal data defaults

The animal foundation keeps livestock balance in `data/animals.json`. Because the
original cow values were unresolved, Phase 4 uses conservative functional defaults:

- dairy cow: 1 milk per day
- beef cow: 10-day lifecycle and 1 beef at end of life

These values are gameplay data and can be balanced later without changing the animal
state machine or save format.

## phase 8 customer data defaults

Customer flow balance is stored in `data/customers.json`. The source specification
does not provide exact timing values, so Phase 8 uses conservative functional defaults:

- one regular customer attempts to spawn every 30 seconds while the restaurant is open
- regular customers wait 60 seconds for food
- timed-out customers reduce reputation by 0.1
- leaving customers remain in the lifecycle for 2 seconds before despawning

These values can be rebalanced without changing the customer/order state machine or
save format.

## phase 9 cooking data defaults

The source specification leaves every recipe cooking time unresolved. Phase 9 assigns
a temporary 10-second cooking time only to recipes that already have complete,
validated ingredient data. Recipes with unresolved ingredients remain unavailable.

This is a technical gameplay default, not final balance, and can be changed in
`data/recipes.json` without changing the cooking state machine or save format.

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
