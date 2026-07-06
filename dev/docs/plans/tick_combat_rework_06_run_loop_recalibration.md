# Tick Combat Rework 06: Run Loop Recalibration

## Goal

Convert Phase 6 from a single oversized implementation pass into the run-loop conversion umbrella for the tick arena. The phase replaces the temporary fixed-wave reward bridge with a complete tick-paced run loop while keeping each ownership-heavy change reviewable as its own implementation spec.

## Requirements

1. The tick arena root becomes a thin composition layer before the full run loop is wired, because action handling, previews, run flow, reward application, and debug controls have grown past what one scene root can own safely.
2. Reward effects use the run-scoped build store as their cross-system truth, including player-facing numeric rewards, so the tick player does not inherit legacy real-time player APIs just to keep old reward cards alive.
3. Wave spawning converts to player-action counted timing, including spawn warnings, low concurrent-enemy caps, overflow queues, milestone elites, and enemy stat scaling, because tick combat pressure must come from readable composition and geometry rather than real-time density.
4. Reward gaps, death, and restart are integrated into the tick arena as run-loop behavior, while automatic terrain mutation is frozen because highly random or fragmented terrain can create dead boards or clumsy turns in the current semi-puzzle tick combat model.
5. File and folder structure is cleaned after the behavioral ownership has stabilized, promoting the tick arena into its own feature root so combat, player, wave, reward, view, and HUD code no longer live as a tangled stage subfolder.
6. Corrupt Land is split into Phase 6a instead of being included in the main run-loop conversion, because it needs a new terrain-state concept rather than a simple hook into the existing land/sea grid.

## Design

Phase 6 ships through child implementation specs rather than one monolithic spec:

| Phase | Focus                                   | Description                                                                                                                                                              |
| ----- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 6b    | Tick arena ownership                    | Split the scene root into scene-scoped controllers for action resolution, previews, and run flow while keeping the tick player as the player-state owner.                |
| 6c    | Run-build reward channels               | Move legacy player-stat rewards onto run-build channels and add tick-side readers for damage, range, and health projections.                                             |
| 6d    | Tick wave controller                    | Convert wave progression and spawning to tick pacing: player-action counted spawn warnings, low population cap, queue draining, milestone elite scheduling, and scaling. |
| 6e    | Reward, death, and restart integration  | Connect reward application, wave gaps, death, restart, and end-to-end run reset in the tick arena while leaving terrain mutation frozen.                                   |
| 6f    | File and folder structure               | Move the stabilized tick arena into a feature-root layout and repair resource paths without changing behavior.                                                           |
| 6a    | Corrupt Land                            | Add damaging terrain as a follow-up terrain-state feature after the main run loop and structure cleanup.                                                                 |

The intended implementation order is 6b, 6c, 6d, 6e, 6f, then 6a. Phase 6a is numbered as a sibling because it came from the original run-loop sketch, but it should not block the core playable run loop.

Concurrent-enemy tuning starts from the tick-design target of three to six enemies alive at once. Wave size may exceed the concurrent cap so run duration can grow separately from moment-to-moment board readability.

Spawn warnings count in player actions. Reward choice screens and between-wave UI pauses may remain real-time UI moments because no enemies act while the run is paused or waiting for a reward.

Terrain progression is no longer part of the main Phase 6 run-loop conversion. A future map-shaping pass should explore stable obstacle-grid alternatives instead of random land add/move/remove cadence.

## Non-Goals

1. No new enemy kinds, spawn-weight data drive, pattern director, or difficulty director.
2. No final HUD refactor; Phase 7 owns the durable player-facing HUD and build summary.
3. No legacy player merge; the tick player survives as the production player candidate, while legacy real-time player dependencies are removed from tick reward and wave flow.
4. No Corrupt Land inside the main Phase 6 run-loop path.

## Acceptance Criteria

1. A full tick-arena run plays from wave start through combat, reward choice, milestone waves, death, and restart without automatic terrain mutation.
2. Tick-arena actions, previews, run flow, wave spawning, and rewards have clear scene-scoped ownership instead of accumulating in the arena root.
3. Existing reward content that still belongs in the tick design offers and applies through the run-scoped build model, with re-mapped player stats accounted for explicitly.
4. Concurrent enemies stay within the low tick-world cap while queued wave enemies drain as space opens.
5. The run loop no longer applies automatic terrain mutation or milestone expansion during reward continuation.
6. The tick arena code is organized under a feature-root layout after behavior is stable.
