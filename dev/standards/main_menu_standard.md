# Main Menu Standard

The Main Menu is the shared project entry point.

---

# 1. Role

The Main Menu is a neutral title screen. It starts the arena, opens Settings, and quits. It must not contain combat, spawning, wave, inventory, or gameplay-state rules.

The Main Menu lives at `game/meta/main_menu/main_menu_scene.tscn` and is the `run/main_scene` in `project.godot`.

---

# 2. Required Actions

- Play calls `SceneRouter.go_to_arena()`.
- Settings calls `SettingsStore.toggle_overlay()`.
- Quit calls `get_tree().quit()`.

---

# 3. Extension Rule

Add menu features only when they belong to pre-game choice or global project flow. Examples: controls screen, stage select, credits, or accessibility options. If a button mutates arena state or spawns entities, that belongs in an arena/debug screen behind `Debug.enabled`.

When adding persistent UI nodes to the Main Menu, define them in `.tscn` and reference them with `%UniqueName` from the script.
