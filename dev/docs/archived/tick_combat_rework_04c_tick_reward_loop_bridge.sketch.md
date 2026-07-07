# Tick Combat Rework 04c: Tick Reward Loop Bridge

Skeleton sketch split out during Phase 4 planning; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Restore a minimal tick-arena loop from wave completion to reward choice to next wave so the real Major effects added across Phase 4 through Phase 04b can be earned and applied in the playable tick arena before speed stats arrive.

## Requirements

1. When the current tick-arena enemy set is cleared, the scene opens the existing reward choice flow instead of ending at a static "all enemies down" state, because Phase 4's Majors need an in-arena acquisition path before the full run loop is recalibrated.
2. Applying a reward updates the same run-scoped applied-effect store that tick verbs read, so selected Smash, Guard Shredder, or Execution effects change subsequent tick-arena behavior without debug controls.
3. After a reward is applied, the tick arena starts another enemy set using the current simple spawn composition; no pacing, terrain cadence, arena-size, or enemy-density retuning happens here because Phase 6 owns the full run-loop recalibration.
4. Debug Major controls remain available for development validation, but they must not be the only way to exercise Major behavior once this bridge ships.

## Design

This bridge is deliberately smaller than the Phase 6 run loop. It proves the reward application path in the tick arena and keeps iteration playable, but it does not decide final wave pacing. The player should be able to clear a local board, choose a reward, and immediately test how that run build changes the next local board.

## Sketch (non-normative)

- Reuse the existing reward generator, applier, context, and overlay flow rather than creating a tick-only reward UI.
- The tick arena should own one run-scoped build store for the session and pass it to reward context and tick combat readers.
- The existing debug enemy spawn set can remain the next-wave source for this bridge; Phase 6 replaces it with calibrated wave controller, planner, spawner, scaling, terrain cadence, and final arena-size tuning.

## Non-Goals

1. No wave pacing retune, terrain cadence retune, arena-size retune, or final enemy composition pass.
2. No new reward-choice UI design.
3. No speed-stat Minor effects; those stay Phase 5.

## Acceptance Criteria

1. Clearing the tick-arena enemies opens a reward choice, selecting a reward closes it, and another enemy set starts without resetting the run build.
2. Majors selected through the reward flow affect later tick-arena actions the same way as debug-enabled equivalents.
3. The bridge does not replace Phase 6's full run-loop recalibration boundary.
