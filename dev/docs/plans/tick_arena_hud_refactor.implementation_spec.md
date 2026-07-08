# Tick Arena HUD Refactor

Parent Plan: none (standalone spec)

## Goal

Replace the tick arena's prototype text HUD with a production-quality combat HUD that exposes player survival, action readiness, run progress, and compact build state without changing combat rules.

## Summary

The current HUD is a monolithic text label plus a right-corner Build button. This pass turns it into a dedicated tick-arena HUD surface with four stable zones: a top-left player status plaque, top-right settings access, a bottom-left build drawer button, and a bottom artifact/run-information dock. The result should read like a shippable combat interface, not a debug overlay with prettier labels.

The HP and Speed displays should follow the Arise-style resource-bar pattern rather than a plain Godot ProgressBar: a framed resource row with an icon/title/value header, texture-backed layered bars, immediate fill changes, and delayed/tweened trailing feedback for damage-like changes. HP uses a three-layer bar (under, delayed damage, current fill). Speed uses a two-layer or segmented energy bar with a distinct ready flare that does not reuse the Mobility Free Action refund feedback.

The implementation should add a HUD presenter/control that receives snapshots from the arena root and renders reusable resource widgets, cooldown chips, artifact cells, and run labels. Combat owners continue to own combat state; the HUD only displays it. The existing build inspection panel stays the detailed audit view, while the new artifact strip gives the Demon Lord-style "owned artifacts at a glance" row in a polished dock.

This is not final illustration, but it is an industry-level first UI pass. Use deliberate chrome, fixed dimensions, layered bars, icon slots, text hierarchy, hover/tooltips where supported, and responsive safe margins so later Japanese-inspired iconography can replace placeholder textures without another layout refactor.

## Requirements

1. The HUD shows HP, Speed meter, Dash cooldown, Smash cooldown, aim mode, mobility payload, tick count, current wave display, and short combat message as normal player-facing information in purpose-built widgets, not concatenated text.
2. The player character does not gain a floating status bar; player survival and energy live in the HUD while enemies keep their existing combat-readable HP/guard indicators.
3. HP is rendered as a layered resource bar with a current-fill layer and delayed damage layer, numeric value text, and a low-health state; it is modeled after Arise's health/resource HUD behavior but implemented locally for this project.
4. Owned artifacts appear as a compact bottom strip with icon, stack badge, and rarity/readability treatment; the full build inspection panel remains available from a bottom-left icon button.
5. The settings button appears in the top-right combat HUD area as compact icon-first chrome and opens the existing project settings overlay without duplicating settings state.
6. Debug controls remain separate from the player HUD and stay gated by the existing debug panel behavior.
7. Speed meter free-action readiness and Mobility Free Action refund feedback remain visually distinguishable so the two sources of skipped world advancement do not blur together.

## Relational Context

- TickArena remains the scene composition owner for wiring; it builds HUD snapshot data from the player, action controller, engine, run controller, and run build, then passes that data to the HUD presenter.
- The HUD presenter is read-only display state. It must not mutate player HP, cooldowns, Speed meter, run build artifacts, wave state, debug toggles, or settings values.
- TickPlayer owns HP, cooldowns, Smash windup state, and Speed meter values. HUD updates read those values through TickArena instead of caching a second truth.
- TickActionController owns aim mode, mobility-mode interpretation, and transient combat message text. HUD message display should read the controller's current message; it should not create an independent message queue.
- TickEngine owns world tick count. Free actions that skip world advancement must not fabricate tick changes just to update HUD labels.
- TickRunController owns wave/reward/death flow and wraps WaveController. If the HUD needs current wave display, expose a read method on TickRunController rather than letting the HUD reach into WaveController.
- RunBuild owns artifact registry, build totals, mobility payload, and mobility triggers. The compact artifact strip and detailed build panel both read from RunBuild through the existing formatter path or a small formatter extension.
- Resource bar widgets own animation state only: fill tween, delayed damage tween, ready flash, and bar layer visuals. They do not own combat state and must accept values through explicit HUD presenter update calls.
- BuildInspectionPanel remains the detailed audit surface. The new artifact strip is a separate compact summary and must not replace the panel's totals list.
- SettingsStore owns opening and closing the settings overlay. The HUD settings button should call the existing overlay toggle path and must not add a new settings lifecycle.
- DebugPanel remains visually and structurally separate from the player HUD; adding the presenter must not move debug-only controls into normal HUD layout.

## Scope

### Included

- New tick-arena HUD presenter/control and scene layout.
- New reusable HUD resource bar widget for HP and Speed-style resources.
- Replacement of the prototype stats and controls labels with grouped player-facing widgets.
- Compact owned-artifact strip plus bottom-left build-panel open button.
- Top-right settings button integration for the tick arena.
- Repositioning the detailed build inspection panel so it opens from the bottom-left/strip area without covering core combat state more than necessary.
- Production-quality first-pass HUD chrome, fixed dimensions, layered bars, and readable states.

### Excluded

- Final Japanese-inspired art assets, icon painting, sprite sheets, or shader polish.
- Combat rule changes, reward balance changes, new artifacts, or new class behavior.
- Reward card redesign beyond avoiding duplicated build-summary responsibility.
- Enemy sprite readability, enemy pattern expansion, and character class work.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `game/tick_arena/tick_arena.tscn` | Large | Replace prototype HUD nodes with the new presenter instance, reposition build inspection, and add top-right settings access. |
| `game/tick_arena/tick_arena.gd` | Medium | Build HUD snapshots from existing owners, wire build/settings buttons, and stop writing the monolithic stats/control labels. |
| `game/tick_arena/hud/tick_arena_hud.tscn` | Large | New player-facing HUD layout with top-left status plaque, top-right settings, bottom-left build access, bottom artifact strip, and run context. |
| `game/tick_arena/hud/tick_arena_hud.gd` | Medium | New read-only presenter API that renders state snapshots, coordinates resource widgets, and emits button signals. |
| `game/tick_arena/hud/hud_resource_bar.tscn` | Large | New reusable layered resource-bar widget for HP and Speed with icon/title/value row, under/fill/damage layers, and ready/low-state styling. |
| `game/tick_arena/hud/hud_resource_bar.gd` | Medium | New value-display and animation presenter for two-layer and three-layer resource bars; owns tween state only. |
| `game/tick_arena/hud/artifact_strip_item.tscn` | Medium | New compact artifact icon row item with stack badge and rarity/curse readability. |
| `game/tick_arena/hud/artifact_strip_item.gd` | Medium | New row presenter for one owned artifact entry. |
| `game/tick_arena/reward/build_inspection_panel.tscn` | Small | Re-anchor and resize the detailed panel to match the new build-button location and avoid the settings corner. |
| `game/tick_arena/reward/build_inspection_panel.gd` | Small | Preserve existing panel behavior; add only narrow API if the HUD needs explicit open/close coordination. |
| `game/tick_arena/reward/build_inspection_formatter.gd` | Small | Add compact artifact-strip row assembly only if the strip cannot reuse `build_artifact_rows()` directly. |
| `game/tick_arena/run/tick_run_controller.gd` | Small | Expose current wave display text through a read-only method if needed by the HUD snapshot. |

## Execution Outline

1. Create the reusable HUD resource bar first, using an Arise-inspired layered structure: icon/title/value row above a fixed-size bar, a full under layer, a current fill layer, and an optional delayed damage/trailing layer.
2. Create the HUD scene and script under the tick arena feature, with a snapshot-style API and signals for Build and Settings buttons before rewiring the arena scene.
3. Compose the top-left status plaque: HP resource bar, Speed resource bar or pips, cooldown chips for Dash/Smash, aim/mobility mode chips, and a short message lane with stable dimensions.
4. Add the compact artifact strip item and make the HUD render owned-artifact rows from RunBuild-derived formatter data; keep the empty state visually quiet but intentionally designed.
5. Update TickArena to reference the new HUD, construct snapshots in the existing refresh path, connect HUD button signals to the build panel and SettingsStore, and remove StatsLabel/ControlsLabel writes.
6. Re-anchor the build inspection panel and Build button flow around the new bottom-left/strip layout, preserving the panel's read-only RunBuild setup and refresh behavior.
7. Add or expose a read-only wave display path on the run controller if TickArena cannot already provide current wave text without reaching into the wave controller.
8. Verify that reward application, run reset, Speed spends, Mobility Free Action refunds, debug toggles, settings overlay, death overlay, and build panel open/close all refresh or block input correctly.

## Implementation Notes

- Snapshot shape should be plain data, not live owner references. Include derived display strings only when the derivation belongs to TickArena's glue layer; keep formatting that is already centralized in BuildInspectionFormatter there.
- Top-left status plaque target shape: a 300-380 px wide panel, 8 px or smaller corner radius, dark translucent background, 1 px border, 12-16 px interior margins, icon/title/value rows, and no text that spills during max-health or cooldown changes.
- HP bar behavior: current fill snaps or tweens immediately to the latest HP; a delayed damage layer stays behind for roughly 0.2-0.3 seconds after damage and then eases down over roughly 0.3-0.4 seconds; heals catch the delayed layer up quickly. This mirrors the Arise three-layer pattern without importing its assets.
- HP bar visuals: under layer is a dark trough, delayed damage layer is a warm warning color, fill layer is health red, and low-health state adds a restrained pulse or border color shift below an explicit threshold. Do not use a default `ProgressBar` with only a flat fill.
- Speed bar behavior: use the same resource-widget API in two-layer mode or a fixed pip strip. Full Speed should show a ready frame/glow and short text such as `READY` or an icon badge; spending Speed should produce a brief local flash, while Mobility Free Action refund stays in the message lane.
- Cooldowns should be compact chips or radial/slot badges beside the mobility payload label, not raw text in the HP line. A ready cooldown reads as a lit slot; an unavailable cooldown shows the remaining tick count in a fixed-size badge.
- Message lane should be one line, fixed width, and priority-aware: combat result/refund messages replace old text without resizing the plaque. It should not become a scrolling log.
- Bottom artifact dock should feel intentionally framed: build drawer icon at bottom-left, artifact cells in a horizontal strip with fixed icon cells, stack badges, rarity frame colors, and an overflow indicator when the row exceeds available width.
- Top-right settings should be a compact icon-first button. Text-only "Settings" is acceptable only as an interim fallback if no icon asset exists, and the spec implementer should still size it like a real button, not a debug label.
- Controls help text should not remain as a permanent bottom label. If control reminders are still needed, keep them out of the always-visible combat HUD or make them debug/tutorial-only in a later pass.
- Artifact strip rows can start with existing artifact icons and placeholder fallback. Do not invent final Japanese iconography in this spec.
- If the detailed build panel overlaps reward/death overlays, the higher-priority overlay should win by visibility or mouse filtering; do not allow a stale panel to intercept reward choices.
- Use existing theme type variations and local styleboxes conservatively. Local styleboxes/textures are acceptable for the HUD resource bars and chrome when the shared theme cannot express layered combat UI. If implementation changes theme resources or broad UI colors, read the project theme standards before editing those resources.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| The run has no artifacts | The strip shows an unobtrusive empty state or no item cells; the Build button still opens the detailed panel. |
| An artifact has no icon | The strip and panel use the existing placeholder icon and report the malformed authoring path through the current dev-error convention. |
| Max HP changes from rewards | HP bar maximum updates without visually losing the current HP ratio or leaving the delayed damage layer outside the new range. |
| Player takes damage repeatedly before the delay completes | The delayed damage layer restarts its delay/tween cleanly and never climbs above the old max or below the current fill. |
| Speed meter is full and the player uses mobility | Speed remains visibly ready because mobility does not spend it; Mobility Free Action refund feedback, if triggered, appears as a separate message/beat. |
| Reward or death overlay is visible | Combat HUD remains present or dimmed behind it, but overlay input is not blocked by HUD buttons or the build panel. |
| Debug mode is disabled | DebugPanel stays hidden and no debug-only actions appear in the player HUD. |

## Acceptance Criteria

1. The tick arena no longer relies on a single text label for combat state.
2. HP, Speed readiness, cooldowns, aim/mobility mode, tick count, wave state, and combat messages are readable at a glance during combat.
3. HP uses a layered, animated resource bar with delayed damage feedback and numeric value text, not a default flat ProgressBar.
4. Cooldowns, Speed readiness, artifacts, settings, and run context are styled as intentional HUD controls with fixed dimensions and no layout jitter.
5. Owned artifacts are visible as a compact row, and the existing detailed build inspection remains available.
6. Settings access is available from the top-right without displacing build inspection.
7. Player status is not duplicated as a floating bar on the player character.
8. Debug controls remain visually separate and debug-gated.
