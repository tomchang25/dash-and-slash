# Tick Arena HUD Refactor

Parent Plan: none (standalone spec)

## Goal

Replace the tick arena's prototype text HUD with a coherent combat information layer that exposes player survival, action readiness, run progress, and compact build state without changing combat rules.

## Summary

The current HUD is a monolithic text label plus a right-corner Build button. This pass turns it into a dedicated tick-arena HUD control with four stable zones: top-left player combat state, top-right settings, bottom-left build access, and bottom artifact strip/run context. The result should read closer to a minimal action board HUD than a debug overlay.

The implementation should add a HUD presenter/control that receives snapshots from the arena root and renders bars, pips, labels, and artifact rows. Combat owners continue to own combat state; the HUD only displays it. The existing build inspection panel stays the detailed audit view, while the new artifact strip gives the Demon Lord-style "owned artifacts at a glance" row.

The visual treatment is still structural, not final art. Use restrained project theme styling and stable dimensions so later Japanese-inspired iconography can replace placeholder controls without another layout refactor.

## Requirements

1. The HUD shows HP, Speed meter, Dash cooldown, Smash cooldown, aim mode, mobility payload, tick count, current wave display, and short combat message as normal player-facing information.
2. The player character does not gain a floating status bar; player survival and energy live in the HUD while enemies keep their existing combat-readable HP/guard indicators.
3. Owned artifacts appear as a compact bottom strip with icon, stack badge, and rarity/readability treatment; the full build inspection panel remains available from a bottom-left Build button.
4. The settings button appears in the top-right combat HUD area and opens the existing project settings overlay without duplicating settings state.
5. Debug controls remain separate from the player HUD and stay gated by the existing debug panel behavior.
6. Speed meter free-action readiness and Mobility Free Action refund feedback remain visually distinguishable so the two sources of skipped world advancement do not blur together.

## Relational Context

- TickArena remains the scene composition owner for wiring; it builds HUD snapshot data from the player, action controller, engine, run controller, and run build, then passes that data to the HUD presenter.
- The HUD presenter is read-only display state. It must not mutate player HP, cooldowns, Speed meter, run build artifacts, wave state, debug toggles, or settings values.
- TickPlayer owns HP, cooldowns, Smash windup state, and Speed meter values. HUD updates read those values through TickArena instead of caching a second truth.
- TickActionController owns aim mode, mobility-mode interpretation, and transient combat message text. HUD message display should read the controller's current message; it should not create an independent message queue.
- TickEngine owns world tick count. Free actions that skip world advancement must not fabricate tick changes just to update HUD labels.
- TickRunController owns wave/reward/death flow and wraps WaveController. If the HUD needs current wave display, expose a read method on TickRunController rather than letting the HUD reach into WaveController.
- RunBuild owns artifact registry, build totals, mobility payload, and mobility triggers. The compact artifact strip and detailed build panel both read from RunBuild through the existing formatter path or a small formatter extension.
- BuildInspectionPanel remains the detailed audit surface. The new artifact strip is a separate compact summary and must not replace the panel's totals list.
- SettingsStore owns opening and closing the settings overlay. The HUD settings button should call the existing overlay toggle path and must not add a new settings lifecycle.
- DebugPanel remains visually and structurally separate from the player HUD; adding the presenter must not move debug-only controls into normal HUD layout.

## Scope

### Included

- New tick-arena HUD presenter/control and scene layout.
- Replacement of the prototype stats and controls labels with grouped player-facing widgets.
- Compact owned-artifact strip plus bottom-left build-panel open button.
- Top-right settings button integration for the tick arena.
- Repositioning the detailed build inspection panel so it opens from the bottom-left/strip area without covering core combat state more than necessary.
- Minimal structural styling only.

### Excluded

- Final Japanese-inspired art assets, icon painting, sprite sheets, or shader polish.
- Combat rule changes, reward balance changes, new artifacts, or new class behavior.
- Reward card redesign beyond avoiding duplicated build-summary responsibility.
- Enemy sprite readability, enemy pattern expansion, and character class work.

## Files to Change

| File                                                   | Change Size | Purpose                                                                                                                                        |
| ------------------------------------------------------ | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `game/tick_arena/tick_arena.tscn`                      | Large       | Replace prototype HUD nodes with the new presenter instance, reposition build inspection, and add top-right settings access.                   |
| `game/tick_arena/tick_arena.gd`                        | Medium      | Build HUD snapshots from existing owners, wire build/settings buttons, and stop writing the monolithic stats/control labels.                   |
| `game/tick_arena/hud/tick_arena_hud.tscn`              | Large       | New player-facing HUD layout with top-left combat state, top-right settings, bottom-left build access, bottom artifact strip, and run context. |
| `game/tick_arena/hud/tick_arena_hud.gd`                | Medium      | New read-only presenter API that renders state snapshots and emits button signals.                                                             |
| `game/tick_arena/hud/artifact_strip_item.tscn`         | Medium      | New compact artifact icon row item with stack badge and rarity/curse readability.                                                              |
| `game/tick_arena/hud/artifact_strip_item.gd`           | Medium      | New row presenter for one owned artifact entry.                                                                                                |
| `game/tick_arena/reward/build_inspection_panel.tscn`   | Small       | Re-anchor and resize the detailed panel to match the new build-button location and avoid the settings corner.                                  |
| `game/tick_arena/reward/build_inspection_panel.gd`     | Small       | Preserve existing panel behavior; add only narrow API if the HUD needs explicit open/close coordination.                                       |
| `game/tick_arena/reward/build_inspection_formatter.gd` | Small       | Add compact artifact-strip row assembly only if the strip cannot reuse `build_artifact_rows()` directly.                                       |
| `game/tick_arena/run/tick_run_controller.gd`           | Small       | Expose current wave display text through a read-only method if needed by the HUD snapshot.                                                     |

## Execution Outline

1. Create the HUD scene and script under the tick arena feature, with a snapshot-style API and signals for Build and Settings buttons before rewiring the arena scene.
2. Add the compact artifact strip item and make the HUD render owned-artifact rows from RunBuild-derived formatter data; keep the empty state visually quiet.
3. Update TickArena to reference the new HUD, construct snapshots in the existing refresh path, connect HUD button signals to the build panel and SettingsStore, and remove StatsLabel/ControlsLabel writes.
4. Re-anchor the build inspection panel and Build button flow around the new bottom-left/strip layout, preserving the panel's read-only RunBuild setup and refresh behavior.
5. Add or expose a read-only wave display path on the run controller if TickArena cannot already provide current wave text without reaching into the wave controller.
6. Verify that reward application, run reset, Speed spends, Mobility Free Action refunds, debug toggles, settings overlay, death overlay, and build panel open/close all refresh or block input correctly.

## Implementation Notes

- Snapshot shape should be plain data, not live owner references. Include derived display strings only when the derivation belongs to TickArena's glue layer; keep formatting that is already centralized in BuildInspectionFormatter there.
- HP and Speed bars should use stable min/max dimensions. Speed full should have a clear ready state such as a bright frame, ready label, or filled pips; Mobility Free Action should remain message/refund feedback, not the same visual state as full Speed.
- Controls help text should not remain as a permanent bottom label. If control reminders are still needed, keep them out of the always-visible combat HUD or make them debug/tutorial-only in a later pass.
- Artifact strip rows can start with existing artifact icons and placeholder fallback. Do not invent final Japanese iconography in this spec.
- If the detailed build panel overlaps reward/death overlays, the higher-priority overlay should win by visibility or mouse filtering; do not allow a stale panel to intercept reward choices.
- Use existing theme type variations and local styleboxes conservatively. If implementation changes theme resources or broad UI colors, read the project theme standards before editing those resources.

## Edge Cases

| Case                                             | Expected Handling                                                                                                                                       |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The run has no artifacts                         | The strip shows an unobtrusive empty state or no item cells; the Build button still opens the detailed panel.                                           |
| An artifact has no icon                          | The strip and panel use the existing placeholder icon and report the malformed authoring path through the current dev-error convention.                 |
| Speed meter is full and the player uses mobility | Speed remains visibly ready because mobility does not spend it; Mobility Free Action refund feedback, if triggered, appears as a separate message/beat. |
| Reward or death overlay is visible               | Combat HUD remains present or dimmed behind it, but overlay input is not blocked by HUD buttons or the build panel.                                     |
| Debug mode is disabled                           | DebugPanel stays hidden and no debug-only actions appear in the player HUD.                                                                             |

## Acceptance Criteria

1. The tick arena no longer relies on a single text label for combat state.
2. HP, Speed readiness, cooldowns, aim/mobility mode, tick count, wave state, and combat messages are readable at a glance during combat.
3. Owned artifacts are visible as a compact row, and the existing detailed build inspection remains available.
4. Settings access is available from the top-right without displacing build inspection.
5. Player status is not duplicated as a floating bar on the player character.
6. Debug controls remain visually separate and debug-gated.
