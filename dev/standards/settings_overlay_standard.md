# Settings Overlay Standard

This document defines project-wide settings and the shared settings overlay.

---

# 1. Ownership

`SettingsStore` owns user/device preferences and persists them to `user://settings.json`. These preferences are not gameplay save data and must not be stored in `SaveManager` sections.

Settings-store data includes volume, fullscreen, debug preference, and input preferences such as dash direction mode. Gameplay save data includes player progression, unlocks, arena state, and any future run/profile state.

---

# 2. Overlay Lifecycle

The settings UI is `game/shared/settings_overlay/settings_overlay.tscn`, instantiated by `SettingsStore.toggle_overlay()`.

The overlay pauses the tree while open and restores the previous paused state when closed. Its root uses `PROCESS_MODE_ALWAYS`, so controls remain usable while the tree is paused.

Open settings from menus with:

```gdscript
SettingsStore.toggle_overlay()
```

Gameplay screens may instance `game/shared/settings_button_overlay/settings_button_overlay.tscn` when a visible settings affordance is needed.

---

# 3. Persistence Rules

Settings save immediately when changed. Do not require a separate Apply button unless the setting is destructive or platform-specific.

`user://settings.json` is global to the local user/device. Starting a new arena session must not reset audio, display, or debug preferences.

---

# 4. Adding Settings

When adding a new project-wide setting:

- Add a field to `SettingsStore` with a sensible default.
- Read/write it in `load_settings()` and `save_settings()`.
- Add UI to `settings_overlay.tscn` and connect it in `settings_overlay.gd`.
- Apply the setting immediately from the overlay signal handler or a dedicated `SettingsStore.apply_*()` method.

Do not put arena-session state in the settings overlay unless it is truly a global user preference.
