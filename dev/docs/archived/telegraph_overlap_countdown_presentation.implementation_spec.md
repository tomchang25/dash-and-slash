# Telegraph Overlap Countdown Presentation

Parent Plan: none (standalone spec)

## Goal

Make overlapping danger countdowns readable on each grid cell by aggregating equal timers instead of drawing labels over one another. The nearest danger remains dominant while later distinct timers stay visible as smaller corner badges.

## Summary

Each cell will build a sorted countdown summary from every danger source that covers it. The smallest countdown is drawn at the current central emphasis size; duplicate sources at that timer add a small `×N` suffix, so three attacks resolving in two ticks read as `2 ×3`. Later distinct timers use smaller badges in the cell corners, with their own duplicate counts. When the player occupies the cell, its primary countdown moves to a smaller badge at the player's 12 o'clock outer ring instead of drawing through the player body.

Danger fills, countdown truth, charge destination diamonds, spawn warnings, and detonation timing remain unchanged. This is a presentation aggregation pass over the existing danger payloads.

## Requirements

1. Each cell must display its smallest active countdown once at the center because the next resolving danger is the player's primary decision signal, except a player-occupied cell moves that primary label to the player's 12 o'clock outer ring.
2. Sources with the same countdown on the same cell must collapse into one label with a small `×N` suffix when N is greater than one.
3. Later distinct countdowns must appear in ascending order as smaller corner badges so overlapping future attacks remain inspectable without covering the central number.
4. Aggregation must not change danger timing, telegraph fills, source ownership, or charge destination markers.
5. Rendering must be deterministic regardless of the order danger sources arrive in.

## Relational Context

- Enemy tick runtimes and the spawn-warning owner remain authoritative for cells and countdown values. They continue emitting one danger dictionary per pending source or warning batch.
- The arena root continues collecting danger dictionaries without merging them; it also continues mirroring enemy cells into grid telegraph-fill ownership.
- `TickGridView` owns only countdown and destination presentation. It aggregates the supplied snapshot per cell immediately before drawing and never writes back to gameplay state.
- `GridArena` remains authoritative for the player's current logical cell. The view reads that cell only to choose the primary-label position; player occupancy does not change the countdown data or tile telegraph.
- One danger dictionary counts as one source for each distinct cell it contains. A duplicate cell accidentally repeated inside one source must not inflate `×N`.
- Spawn-warning payloads participate in the same visual aggregation because they already share the danger snapshot, while their yellow fill remains owned by the production telegraph layer.
- Charge destination diamonds remain source-level markers and are drawn once per destination after countdown aggregation.
- Do not change the grid's highest-phase fill resolution to solve label overlap; fill priority and countdown multiplicity represent different information.

## Scope

### Included

- Per-cell countdown aggregation, sorting, multiplicity suffixes, central/corner layout, player-occupied primary badge placement, and focused pure-data tests.

### Excluded

- Telegraph colors, phase priority, warning durations, attack timing, or destination-marker redesign.
- Player preview and predicted-hit badges.
- Aggregating different cells belonging to one attack into one label.

## Files to Change

| File                                                  | Change Size | Purpose                                                                          |
| ----------------------------------------------------- | ----------- | -------------------------------------------------------------------------------- |
| `game/tick_arena/view/tick_grid_view.gd`              | Medium      | Aggregate danger sources per cell and draw central plus corner countdown labels. |
| `test/unit/test_tick_grid_view_danger_aggregation.gd` | New Medium  | Cover ordering, multiplicity, source de-duplication, and per-cell independence.  |

## Execution Outline

1. Extract a deterministic pure-data aggregation helper that maps each covered cell to ascending `{ticks, count}` entries, then add focused tests before changing drawing.
2. Replace the per-source countdown draw loop with one per-cell draw pass: central earliest label, player 12 o'clock primary badge when occupied, small multiplicity suffix, then later corner badges.
3. Preserve the separate source-level destination-diamond pass and run focused tests plus standards lint.

## Implementation Notes

- Use integer countdown keys and sort ascending. Skip invalid/non-positive countdown payloads defensively rather than drawing a misleading zero.
- De-duplicate cells within each danger dictionary before incrementing counts. Two separate danger dictionaries still count as two sources.
- Draw no suffix for a count of one. Draw `×N` in a font materially smaller than its countdown and offset it to the countdown's right so `2 ×3` reads as one grouped label.
- When the player occupies the cell, use a smaller primary badge centered at the 12 o'clock outer-ring position. Do not draw the normal center label through the player body; the badge keeps the same countdown and multiplicity data.
- Use the four corners in stable clockwise order for the four nearest later distinct countdowns. If more than four later values exist, omit the farther values; current authored timers stay below this capacity, and nearest danger remains the priority.
- Corner entries use a smaller countdown font and an even smaller multiplicity suffix. Keep them inside the cell boundary and clear of the centered label.
- Aggregation must not choose telegraph color. The production grid view continues resolving fill phase independently.

## Edge Cases

| Case                                        | Expected Handling                                             |
| ------------------------------------------- | ------------------------------------------------------------- |
| Three sources cover one cell at two ticks   | Center shows `2 ×3` once.                                     |
| Timers 1, 2, and 3 overlap                  | `1` is centered; `2` and `3` occupy the first two corners.    |
| Two cells have different overlaps           | Each cell builds and displays an independent summary.         |
| One source repeats a cell                   | It contributes one count for that cell.                       |
| Player occupies a telegraphed cell          | The primary countdown moves to the player's 12 o'clock badge. |
| More than five distinct timers cover a cell | Show the earliest center value and four nearest later values. |
| No valid danger remains                     | Draw no countdown label.                                      |

## Acceptance Criteria

1. Overlapping labels never draw on top of one another at the cell center.
2. The smallest countdown is always the dominant central value.
3. Equal countdowns display one value plus the correct small `×N` source count.
4. Later distinct countdowns remain readable in ascending corner order within the supported capacity.
5. A player standing on a telegraphed cell does not have countdown text drawn through their body; the same primary value and multiplicity appear at the player's 12 o'clock outer ring.
6. Telegraph fills, attack resolution timing, spawn warnings, and charge destination markers behave as before.
