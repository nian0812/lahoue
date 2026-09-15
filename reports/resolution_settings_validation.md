# Resolution Settings — PASS

Revalidated during the 2026-09-13 final pass in standalone windows. Current logs: `.work/logs/settings_write.log`, `.work/logs/settings_read-windowed.log`, `.work/logs/settings_read-fullscreen.log`. Earlier `.tmp` paths below refer to the original Settings implementation run.

Validated on Windows with Godot 4.7.1 and the OpenGL compatibility renderer.

- Existing main-menu Settings panel: one Resolution row added beside Fullscreen. Original panel dimensions, styling, anchors, logical 1280×720 viewport and `canvas_items` stretch retained.
- Actual window client sizes verified: 1280×720, 1366×768, 1600×900, 1920×1080 and 2560×1440.
- Current desktop resolution detected and included exactly once, including when outside the preset list.
- Fullscreen uses the monitor desktop resolution. Changing the selector during fullscreen preserves fullscreen and updates the size to restore on exit.
- Fullscreen → windowed restored the chosen 1600×900 and 1366×768 sizes. Windows that fit the usable monitor area were centered; larger windows retain accessible top/left positioning.
- Three separate engine processes verified initial changes, windowed restart, and fullscreen restart. Resolution, fullscreen and all three volume preferences survived.
- Master volume applied to the active bus. Music/SFX preferences remain adjustable and persistent even before those buses exist; bus application was also checked with test-only buses.
- Visible Settings controls fit the panel at all five sizes and fullscreen. Rendered screenshots were inspected at every preset, with no internal clipping. A window larger than the physical desktop can naturally extend beyond the display; the selected client resolution is retained.
- Settings are stored only in `user://settings.cfg`. Tests confirmed gameplay save contents were unchanged; no save migration was added.

Test: `tests/resolution_settings_test.tscn`, then new processes with user arguments `read-windowed` and `read-fullscreen`. Requires a graphical backend and an isolated `user://` directory containing `lahoue_codex_settings_test`.

Local validation logs: `.tmp/settings_write.log`, `.tmp/settings_read-windowed.log`, `.tmp/settings_read-fullscreen.log`. Screenshots: `.tmp/test_appdata/lahoue_codex_settings_test/settings_*.png`.

Implementation references: [Godot DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) and [ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html).
