# Debug Panel Tick Arena Actions

Parent Plan: none (standalone spec)

## Goal

Add the requested tick-arena debug actions for killing enemies and selecting player god-mode behavior, while upgrading the shared debug panel layout so future actions can grow without overflowing the screen.

## Summary

The tick arena already has most of the gameplay seams this work needs: `WaveController` can force-kill alive enemies, enemy death already routes through `Health.kill()`, and the shared `DebugPanel` self-gates visibility and callbacks through `Debug.enabled`. The missing piece is exposing those seams from the panel and adding equivalent god-mode state to `TickPlayer`, whose HP is currently local tick-arena state rather than a `Health` node.

This change should add four debug controls: `Instant Kill All Enemies`, `God Mode - No Damage`, `God Mode - Undead`, and `God Mode - Disable`. God-mode controls are mutually exclusive. No Damage preserves hit feedback while leaving HP unchanged; Undead allows damage but floors HP at 1; Disable returns to normal damage and death behavior.

The panel should also move from a fixed bottom-right vertical button stack to a bounded, scrollable, sectioned debug tool. Existing call sites must keep working through `add_action(label, callback)`, while new call sites can provide a section label so controls are grouped into areas such as `Combat`, `Player`, and `Build`. The result should feel like a compact internal tool: readable, bounded to the viewport, and safe to extend with more debug actions later.

## Requirements

1. The four requested controls are visible only when `Debug.enabled` is true, and every mutating handler still guards with `if not Debug.enabled: return` because release exports must never execute debug actions.
2. Killing all enemies uses the existing wave/enemy ownership path so wave bookkeeping, grid occupancy cleanup, engine unregistering, elite-cleared signals, and wave completion continue to behave as if enemies died normally.
3. Tick-player god mode is owned by `TickPlayer` because tick-arena player HP is currently local state, not a shared `Health` component.
4. DebugPanel layout remains reusable and game-agnostic; tick-arena-specific action labels and callbacks stay in `tick_arena.gd`.
5. DebugPanel growth is bounded by viewport-safe maximum dimensions and uses scrolling rather than allowing actions to extend outside the visible screen.

## Relational Context

- `DebugPanel` owns debug UI layout and callback gating, but it does not own or know tick-arena gameplay state; `tick_arena.gd` registers tick-arena actions into it.
- `tick_arena.gd` owns the debug glue for this scene: it keeps button references only when text or active styling must be refreshed, and it calls run/player APIs rather than mutating their private fields directly.
- `TickRunController` owns the active `WaveController` instance, so the arena root should call a debug wrapper on `TickRunController` instead of reaching through to `WaveController`.
- `WaveController` owns alive enemy tracking, spawn queue state, and death-side wave progression. The kill-all action must use its existing force-kill path and must not iterate scene-tree enemies from the panel or arena root.
- `TickPlayer` owns tick-arena HP, damage feedback, death return value, and reset behavior. God-mode state belongs there so `TickEngine.damage_player()` can keep its current call direction through `TickPlayer.take_damage()`.
- `Debug.enabled` is the only debug gate. Do not check `OS.is_debug_build()` or `SettingsStore.debug_mode` from scene or gameplay code.
- DebugPanel may gain a richer generic registration API, but existing `add_action(label, callback)` callers must remain valid.
- Static panel layout belongs in the debug panel scene where possible. Runtime theme overrides should be limited to dynamic active/inactive state, using Godot 4 `add_theme_*_override()` methods in GDScript if needed.

## Scope

### Included

- Add the four requested tick-arena debug actions.
- Add tick-player god-mode support for Off, Undead, and No Damage.
- Add a scene-safe debug kill-all wrapper through the run controller.
- Upgrade the shared debug panel to sectioned, scrollable, viewport-bounded layout while preserving the current registration API.
- Refresh debug button state when rewards, run reset, or god-mode changes affect displayed active state.

### Excluded

- Replacing tick-arena player HP with the shared `Health` component.
- Adding hotkeys, search, command palette behavior, draggable windows, or persistent panel position.
- Changing release/debug settings behavior or the Settings Overlay debug-mode toggle.
- Adding new gameplay cheats beyond the four requested controls.

## Files to Change

| File                                         | Change Size | Purpose                                                                                                                                       |
| -------------------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `game/shared/debug_panel/debug_panel.tscn`   | Medium      | Replace the fixed button stack with sectioned scrollable layout and viewport-safe sizing defaults.                                            |
| `game/shared/debug_panel/debug_panel.gd`     | Medium      | Preserve `add_action()`, add optional section support, manage section containers, and expose a generic active-state styling helper if needed. |
| `game/tick_arena/player/tick_player.gd`      | Medium      | Own tick-player god-mode state and apply it inside `take_damage()` and reset behavior.                                                        |
| `game/tick_arena/run/tick_run_controller.gd` | Small       | Add a debug-only wrapper that delegates enemy kill-all to the owned wave controller.                                                          |
| `game/tick_arena/tick_arena.gd`              | Medium      | Register the new controls, group all debug actions by section, guard handlers, and refresh button active states.                              |
| `TODO.md`                                    | Small       | Keep the standalone spec discoverable until the work ships.                                                                                   |

## Execution Outline

1. Update `DebugPanel` first so the existing and new actions can be registered into sections without changing gameplay behavior yet. Keep the old `add_action(label, callback)` signature working by giving the section argument a default.
2. Add tick-player god-mode state and make `take_damage()` implement Off, Undead, and No Damage semantics without changing the existing movement, cooldown, speed, or reset responsibilities.
3. Add the run-controller debug wrapper for kill-all, delegating to the existing wave-controller path and guarding the wrapper with `Debug.enabled`.
4. Rewire `tick_arena.gd` debug registration into `Combat`, `Player`, and `Build` sections; add the four requested handlers and keep active button state refreshed alongside existing payload/trigger refreshes.
5. Run the project standards linter on changed files and, if available in the local environment, run the focused Godot parse/test command normally used for changed GDScript.

## Implementation Notes

- For `DebugPanel`, prefer a `ScrollContainer` containing a vertical section list. Each section can be a header label plus a `VBoxContainer` of buttons. The root panel should clamp to a maximum size rather than relying on a fixed bottom offset large enough for current content.
- Keep `DebugPanel.clear_actions()` clearing all registered sections/actions, not just the old flat action list.
- If active styling is added, make it generic, such as `set_action_active(button, active)`, so `tick_arena.gd` does not encode style details. Text may still change when the label itself needs a readable state, but avoid appending state text as the only active indicator for new controls.
- `TickPlayer.reset()` should clear god mode unless implementation intentionally keeps debug god mode across run resets and the buttons clearly reflect that. Prefer clearing on reset so a fresh run starts from normal rules unless the user re-enables a mode.
- `TickPlayer.take_damage()` should still trigger the existing red flash for No Damage and Undead hits so test feedback remains visible.

## Edge Cases

| Case                                       | Expected Handling                                                                                                                      |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| Kill-all is pressed with no alive enemies  | No-op with no errors and no wave state corruption.                                                                                     |
| Kill-all is pressed during a spawn warning | Alive enemies die through the wave path; queued or pending spawns are not implicitly cleared unless existing wave progression does so. |
| No Damage receives lethal incoming damage  | Player flashes, HP remains unchanged, and death is not emitted.                                                                        |
| Undead receives lethal incoming damage     | Player flashes, HP becomes at least 1, and death is not emitted.                                                                       |
| Debug is disabled while the panel exists   | Panel hides and callbacks do not execute.                                                                                              |
| Actions exceed panel height                | Panel remains on-screen and actions are reachable by scrolling.                                                                        |

## Acceptance Criteria

1. The debug panel shows the requested enemy kill and god-mode controls in logical sections while debug mode is enabled.
2. Instant kill removes all currently alive enemies through normal enemy death handling and preserves wave progression behavior.
3. God Mode - No Damage prevents HP loss while still showing hit feedback.
4. God Mode - Undead allows HP loss but prevents player death by flooring HP at 1.
5. God Mode - Disable restores normal player damage and death behavior.
6. Adding enough debug actions to exceed the panel body height produces a scrollable panel that remains fully within the viewport.
7. Existing debug actions for mobility payloads and major triggers still work after the panel API/layout upgrade.
