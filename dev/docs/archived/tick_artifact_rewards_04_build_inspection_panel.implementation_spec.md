# Tick Artifact Rewards 04: Build Inspection Panel

Parent Plan: `tick_artifact_rewards.md`

## Goal

Give the player an on-demand build panel that lists owned artifacts and the current run build's aggregate effect totals. The panel makes stacking artifact builds legible without waiting for the later full HUD refactor.

## Summary

Child 03 establishes reward-card identity: one visible card equals one artifact, artifacts own placeholder icon data, and rarity/curse state has a consistent visual language. This spec uses that language in a compact inspection surface: the arena HUD gets a persistent build button, the button toggles a read-only panel, and the panel refreshes from the live `RunBuild` reference whenever it opens or the run build changes.

The panel has two content regions. The owned-artifact region shows one compact row per owned artifact using the artifact icon, display name, stack badge, rarity/curse indicator, and stack-scaled description. The build-total region shows non-zero channel totals in a fixed readable order, then the active mobility payload and active mobility triggers. It does not show combat HUD state such as current HP, cooldown counters, Speed meter fill, or tick count.

The implementation must not add a second build store, snapshot cache, or reward history list. `RunBuild` remains the only authority for owned artifacts, channel totals, mobility payload, and mobility triggers; the panel is only a view over that state.

## Relational Context

- `TickArena` owns the shared `RunBuild` instance and wires it into combat, preview, run flow, and this inspection panel. The panel receives that reference through setup and never constructs or replaces `RunBuild`.
- `RunBuild` owns applied state. The panel reads `get_owned_artifacts()`, `total(channel)`, `get_mobility_payload()`, and `has_mobility_trigger(trigger_id)` only; it does not write to the build or infer state from reward history.
- `TickRunController` emits `reward_applied` and `run_reset_finished`. `TickArena` should refresh the panel after those signals when the panel is visible, so an open panel reflects newly picked artifacts and reset clears.
- `BuildInspectionPanel` owns presentation and formatting orchestration. It may rebuild row instances on refresh, but it must not keep authoritative copies of owned artifacts or totals between refreshes.
- Artifact rows read `Artifact` display data created by child 03: icon, display name, rarity, curse flag, magnitude, and description template. Missing icon data should fall back to the child-03 placeholder and report a developer-visible data error.
- Channel labels and formatting are panel-owned metadata for this MVP. Do not add channel display fields to `RunBuild`, `ArtifactEffect`, or artifact resources unless a later shared HUD pass needs them.
- The panel uses the child-03 card visual language in compact form. It should not embed full reward cards, but rows should share icon, rarity/curse indicator, and stack badge conventions.
- UI structure that exists for the scene lifetime belongs in `.tscn` files. Dynamic owned-artifact rows and effect-total rows may be instantiated or rebuilt at runtime because their count depends on live build data.

## Scope

### Included

- Persistent tick-arena HUD button that toggles the build inspection panel.
- Read-only panel with owned artifact rows and aggregate build totals.
- Compact artifact row component using child-03 icon, rarity/curse, and stack-badge language.
- Formatter or panel-owned metadata for channel labels, signed numeric values, percent values, payload names, and trigger names.
- Refresh on open, reward application, and run reset.
- Focused tests for formatting or refresh data assembly where practical.

### Excluded

- Full HUD refactor, combat-critical stat widgets, or replacing the existing `StatsLabel`.
- Artifact sorting controls, filtering, removal, tooltips, hover expansion, or drag interactions.
- New reward data, new effects, new channels, or changes to effect application.
- Persisting build history outside `RunBuild`.
- Reworking reward-card offer UI from child 03.

## Files to Change

| File                                                        | Change Size  | Purpose                                                                                                                                                  |
| ----------------------------------------------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `game/tick_arena/reward/build_inspection_panel.tscn`        | New Medium   | Define the toggleable panel shell, title, close button, owned-artifact list container, totals list container, and empty-state labels.                    |
| `game/tick_arena/reward/build_inspection_panel.gd`          | New Medium   | Store the injected `RunBuild`, open/close/toggle the panel, rebuild visible rows from live build state, and expose `refresh()` for `TickArena`.          |
| `game/tick_arena/reward/build_inspection_artifact_row.tscn` | New Small    | Define a compact previewable row with icon, rarity/curse strip, name, stack badge, and description.                                                      |
| `game/tick_arena/reward/build_inspection_artifact_row.gd`   | New Small    | Apply one owned-artifact entry to the row using child-03 artifact display data and stack-scaled description text.                                        |
| `game/tick_arena/reward/build_inspection_total_row.tscn`    | New Small    | Define a compact previewable label/value row for channel totals, payload, and trigger lines.                                                             |
| `game/tick_arena/reward/build_inspection_total_row.gd`      | New Small    | Apply one label/value/style tuple to the totals row.                                                                                                     |
| `game/tick_arena/reward/build_inspection_formatter.gd`      | New Small    | Own channel ordering, labels, display units, payload labels, trigger labels, and row-data assembly that can be unit-tested without the panel scene.      |
| `game/tick_arena/tick_arena.tscn`                           | Medium       | Add the build toggle button and pre-place the build inspection panel under the existing HUD layer with unique names.                                     |
| `game/tick_arena/tick_arena.gd`                             | Small        | Wire the button and panel to the shared `RunBuild`, refresh the panel after reward application/reset, and keep the existing HUD refresh behavior intact. |
| `global/theme/main_theme.tres`                              | Small/Medium | Add reusable card-row/panel styles only if child-03 theme styles are not enough for the compact inspection rows.                                         |
| `test/unit/test_build_inspection_formatter.gd`              | New Small    | Cover non-zero channel filtering, percent formatting, signed values, payload/trigger labels, and owned-artifact row data.                                |

## Execution Outline

1. Add `BuildInspectionFormatter` first and cover it with focused unit tests using a fresh `RunBuild` populated with representative channel totals, owned artifacts, payload, and triggers.
2. Add the reusable artifact row and total row component scenes with visible neutral placeholder content, then implement their `setup()` / `_apply()` scripts.
3. Add the panel scene with static structure in `.tscn`: title, close button, scrollable owned-artifact list, scrollable totals list, and explicit empty states. The root may start hidden because it is a toggleable overlay panel.
4. Implement the panel script so `setup(run_build)` stores the live reference, `open()` shows and refreshes, `close()` hides, `toggle()` switches state, and `refresh()` rebuilds rows only when node-ready.
5. Add the build toggle button and panel instance to `tick_arena.tscn`, keeping the button in the HUD corner but below fullscreen reward/death overlays in interaction priority.
6. Wire `TickArena` so `_ready()` passes `_run_build` into the panel, the build button toggles the panel, `_on_reward_applied()` refreshes it if visible, and `_on_run_reset_finished()` refreshes or closes it so stale rows cannot persist.
7. Run standards lint on changed docs/code/scenes/resources and the focused formatter test. Use manual editor verification for visual overlay behavior if there is no existing reliable UI scene test seam.

## Implementation Notes

- Channel rows should be emitted in a stable order: normal attack damage, normal attack cooldown, mobility attack damage, dash cooldown, attack range, mobility range, max health, speed, mobility cooldown, future enemy count, enemy health pressure, enemy damage pressure, enemy defense pressure. Show only non-zero channel totals.
- Display flat additive values with explicit signs, for example `+10`, `-1`, or `+20`. Display percent-authored range channels as percentage points from their stored totals, for example `+10%`. Display enemy health and damage pressure by multiplying stored fraction totals by `100`, so a stored `0.05` reads `+5%`.
- Suggested labels: `Normal Attack Damage`, `Normal Attack Cooldown`, `Mobility Damage`, `Dash Cooldown`, `Attack Range`, `Mobility Range`, `Max Health`, `Speed Energy`, `Mobility Cooldown`, `Future Enemies`, `Enemy Health`, `Enemy Damage`, and `Enemy Defense`.
- Payload summary should always show the active payload: `Mobility Payload: Dash`, `Smash`, or `Debug Stub` when debug has forced the placeholder payload. Trigger summary should show active triggers as separate rows: `Guard Shredder`, `Execution`, and `Flowing Strike`; if none are active, show `Mobility Triggers: None`.
- Artifact rows should consume the dictionaries returned by `RunBuild.get_owned_artifacts()`. If an entry is malformed, skip the row and show a developer-visible error rather than crashing or rendering fake data.
- For artifact descriptions, reuse the stack-scaled description path established for reward cards in child 03. If no shared helper exists after child 03 lands, extract one small formatter instead of duplicating inconsistent math in the card and inspection panel.
- Rebuilding dynamic row children is acceptable, but use packed row scenes for artifact and total rows. Add runtime `add_child()` markers if the linter requires them for instantiated or ephemeral rows.
- The panel should not pause the tree, lock player input, or consume combat verbs beyond normal UI mouse focus while open. Closing the panel restores no gameplay state because it changed none.
- Keep the panel read-only. No row button should apply, remove, reorder, or inspect deeper artifact state in this slice.
- Empty states should be explicit: before any reward, owned artifacts shows a message such as `No artifacts yet`; totals shows non-zero state only plus default payload/trigger summary.

## Edge Cases

| Case                                        | Expected Handling                                                                                                    |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| No artifacts owned                          | Owned list shows an explicit empty state; totals still show active payload and trigger summary.                      |
| Only channel totals exist                   | Totals list shows each non-zero channel in stable order; owned list remains empty if no artifact entries exist.      |
| Only payload/trigger effects exist          | Totals list shows payload and active trigger rows even when no numeric channels are non-zero.                        |
| Panel is already open when a reward applies | Visible content refreshes immediately from the same `RunBuild` reference.                                            |
| Run resets while panel is open              | Content refreshes to the empty/default build state or the panel closes; stale artifact rows must not remain visible. |
| Artifact has a missing icon                 | Row uses the shared placeholder icon and reports a developer-visible data error.                                     |
| Long artifact description                   | Description wraps within the row without changing the row into a full reward card or overlapping adjacent rows.      |
| Unknown payload or trigger value appears    | Formatter displays an `Unknown` label and reports a developer-visible data error, while the panel stays usable.      |

## Acceptance Criteria

1. The tick arena HUD has a persistent control that opens and closes a read-only build inspection panel.
2. The panel lists every owned artifact with icon, display name, stack count, rarity/curse visual state, and stack-scaled description.
3. The panel shows every non-zero build channel total with readable labels and correctly formatted flat or percent values.
4. The panel shows the active mobility payload and active mobility triggers, including an explicit none state when no trigger is active.
5. Opening and closing the panel never changes run state, pauses the tree, applies rewards, or affects combat input state beyond UI mouse focus.
6. Reopening the panel recomputes from the live run build, and an already-open panel refreshes after reward application or run reset.
7. The implementation uses scene-defined panel/row components and a formatter/data-assembly seam, not one multiline placeholder label.
8. Focused formatter tests and standards lint pass.
