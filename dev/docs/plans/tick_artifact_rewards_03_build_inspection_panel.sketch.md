# Tick Artifact Rewards 03: Build Inspection Panel

Parent Plan: `tick_artifact_rewards.md`

## Goal

Give the player an on-demand panel that lists owned artifacts and the current build's summed effect totals, so a stacking build stays legible. This is the MVP inspection surface — the later full HUD refactor absorbs and polishes it.

## Summary

- **Legibility gap:** Once rewards become stackable artifacts, the player needs a way to audit both individual pickups and aggregate build totals outside the reward choice moment.
- **Likely direction:** Add a lightweight persistent toggle, following the existing settings-overlay style, that opens a read-only panel in the tick arena HUD layer.
- **Data shape:** The panel reads the run build directly: owned artifacts for the item list, non-zero channel totals for the aggregate list, and active payload/trigger state as separate lines.
- **Expected result:** Artifacts are inspectable as soon as the artifact system ships, while the later HUD refactor can absorb and polish this MVP instead of building a parallel summary.

## Sketch

- **Toggle** mirrors the existing settings-button overlay pattern: a persistent HUD-corner button shows or hides a panel. Reuse that interaction shape rather than inventing a new one.
- **Panel content** has two lists fed from the run build:
  - Owned artifacts: iterate the run build's owned-artifact registry from child 01, one row each with icon, display name, stack count, and description. Rarity drives row color, matching reward card colors.
  - Effect sum: iterate build channels and show each non-zero total with a readable channel label, plus active payload and triggers as their own lines.
- **Data source** is the run build directly. No new store, no cached snapshot; reopening recomputes from current build state.
- **Rows** can follow the reusable-component `setup()` shape if a per-row scene is used. A plain rebuilt VBox is acceptable for the MVP list.
- **Channel labels** need a StringName-to-display-name map. Keep it beside the panel for now, and move it to shared metadata only if the HUD refactor wants the same labels.

## Non-Goals

1. No combat-critical HUD state like HP, cooldowns, or Speed — that is the HUD refactor.
2. No reordering, filtering, tooltips, or artifact removal — read-only list only.
3. No bespoke art beyond the artifact placeholder icons and rarity colors.

## Acceptance Criteria

1. A persistent control opens and closes a panel listing every owned artifact with icon, name, stack count, and description.
2. The panel shows the current build's non-zero channel totals plus active payload and triggers.
3. Opening, reading, and closing the panel never changes run state; reopening reflects the latest build.
