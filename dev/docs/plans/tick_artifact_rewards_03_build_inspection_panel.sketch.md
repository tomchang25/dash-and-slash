# Tick Artifact Rewards 03: Build Inspection Panel

## Goal

Give the player an on-demand panel that lists owned artifacts and the current build's summed effect totals, so a stacking build stays legible. This is the MVP inspection surface — the later full HUD refactor absorbs and polishes it.

## Requirements

1. A persistent, always-reachable control opens and closes the panel, in the same lightweight way the settings button opens the settings overlay.
2. The panel lists every owned artifact — icon, name, stack count, description — grouped or ordered so rarity reads at a glance.
3. The panel shows the current build's summed effect totals per channel, so the player can audit the aggregate, not just the individual pickups.
4. The panel is read-only and pausing-optional; opening it never mutates run state.

## Design

This is deliberately minimal: a toggle button plus a panel holding a couple of lists. It is not the durable combat HUD — that is the separate HUD refactor plan, which later reuses this panel's model and replaces its grey-box layout. Keeping it simple now means the artifact build is inspectable the moment artifacts ship, without waiting on the HUD pass.

## Sketch (non-normative)

- **Toggle** mirrors the existing settings-button overlay pattern (a persistent button in a HUD corner that shows/hides a panel). Reuse that pattern rather than inventing a new one; the button lives in the tick arena HUD layer.
- **Panel content** is two lists fed from the run build:
  - Owned artifacts: iterate the run build's owned-artifact registry (child 01), one row each — `icon`, `display_name`, `×stacks`, `description`. Rarity drives row color, matching the reward card colors.
  - Effect sum: iterate the build's channels and show each non-zero `total(channel)` with a readable channel label, plus active payload and triggers as their own lines.
- **Data source** is the run build directly; the panel reads projections it already exposes (`total`, the artifact registry, payload/trigger state). No new store, no cached snapshot — reopen recomputes.
- **Rows** follow the reusable-component `setup()` shape if a per-row scene is used; a plain rebuilt VBox is acceptable for an MVP list.
- **Channel labels** need a StringName→display-name map; keep it beside the panel for now, promote to shared metadata if the HUD refactor wants the same labels.

## Non-Goals

1. No combat-critical HUD state (HP, cooldowns, Speed) — that is the HUD refactor.
2. No reordering, filtering, tooltips, or artifact removal — read-only list only.
3. No bespoke art beyond the artifact placeholder icons and rarity colors.

## Acceptance Criteria

1. A persistent control opens and closes a panel listing every owned artifact with icon, name, stack count, and description.
2. The panel shows the current build's non-zero channel totals plus active payload and triggers.
3. Opening, reading, and closing the panel never changes run state; reopening reflects the latest build.
