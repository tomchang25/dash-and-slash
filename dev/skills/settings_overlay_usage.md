# Settings Overlay Usage

Use this when adding user-facing settings.

## Open settings

```gdscript
SettingsStore.toggle_overlay()
```

For gameplay screens that need a fixed button, instance `game/shared/settings_button_overlay/settings_button_overlay.tscn` in the screen `.tscn`.

## Add a setting

1. Add a field and default in `SettingsStore`.
2. Add it to `save_settings()` and `load_settings()`.
3. Add controls to `settings_overlay.tscn`.
4. Connect controls in `settings_overlay.gd`.
5. Apply immediately and call `SettingsStore.save_settings()`.

Use `user://settings.json` for device/user preferences. Use `SaveManager` only for gameplay state tied to a save file or run/profile.
