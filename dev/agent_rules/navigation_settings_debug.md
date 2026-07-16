# Navigation, Settings, And Debug Rule

Read this before changing scene navigation, the Main Menu, settings UI/storage, or debug-only behavior.

## Required References

- Scene navigation: read `dev/foundation/platforms/godot/standards/scene_routing_standard.md` and use `dev/foundation/platforms/godot/skills/scene_router_usage.md`.
- Main Menu: read `dev/standards/main_menu_standard.md`.
- Settings: read `dev/foundation/platforms/godot/standards/settings_overlay_standard.md` and use `dev/foundation/platforms/godot/skills/settings_overlay_usage.md`.
- Debug code: read `dev/foundation/platforms/godot/standards/debug_standard.md` and use `dev/foundation/platforms/godot/skills/debug_mode_usage.md`.

## Hard Rules

- Do not put scene routing back into `GameManager`.
- Do not bypass `SceneRouter` from production gameplay screens.
- Do not store user/device preferences in gameplay saves; `SettingsStore` owns `user://settings.json`.
- Do not add debug behavior outside `Debug.enabled`.
- Keep Main Menu code limited to pre-game flow, settings, and quit actions.

## Tickstrike Specifics

- The Play button routes to the `arena` route via `SceneRouter.go_to_arena()`.
- The project entry scene is `game/meta/main_menu/main_menu_scene.tscn`.
- The `arena` route in `scene_router.tscn` still points at `game/scenes/stages/dash_and_slash_arena.tscn`, which has been deleted (legacy, tick-combat rework cutover pending). The route is broken until the cutover phase rewires it to the tick arena.
