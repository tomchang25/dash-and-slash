# Tick Combat Rework 01: Tick Core And Player Controller

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Productionize the prototype's tick scheduler, player verbs, and input feel as a parallel tick arena scene — the scene later phases grow into the production arena.

## Requirements

1. A parallel arena scene, reachable through debug means only until cutover, carries the full tick contract: any executed player verb advances the world exactly one tick, mouse aiming is free, and an illegal input is soft-denied without consuming a tick.
2. The three-stage resolution order — player action, then zero-countdown detonations checked against the player's post-action cell, then enemy actions and new telegraphs — is owned by one scene-scoped engine rather than scattered across actors, because phases 2-6 all plug consumers into it.
3. Input feel carries the prototype's validated specs: hold-repeat around 7 inputs per second, edge presses fire immediately, a single-slot verb buffer captures the next committed input during tween playback, tweens of roughly 100 ms or less never block input collection, and the two-channel grammar (mouse selects parameters for free, keys execute verbs).
4. Occupancy rules carry over: one actor per tile, enemies block ordinary player steps, dash passes through, and the existing grid authority remains terrain and coordinate truth.
5. The engine schedules non-player actors and explicit extra-action/free-step rules on the energy skeleton while preserving the public tick contract: player verbs do not carry hidden fractional or multi-tick costs, so phase 2's enemy speeds and phase 5's player speed stats plug in without making telegraphs lie.
6. The player actor has no combat facing; mouse aim is a free verb parameter for attacks and mobility targeting, while facing and turn-rate depth live on enemies.

## Design

The prototype scene is the reference implementation; this phase is a re-house, not a redesign. The grey-box controller's responsibilities split three ways — engine (resolution order, actor registry, tick counter), input layer (verb polling, repeat, buffering), player actor (cell, hp, cooldowns, windup state) — because production gains consumers (enemies, previews, run loop) that the prototype monolith would tangle.

Verbs stay: step (4-directional), normal attack (mouse-quantized to 4 directions), mobility slot, wait. The mobility slot payload is a plain dash stub in this phase; the override seam arrives in phase 3.

"Slow" is not implemented as a larger player action cost in this phase. Any future slow verb must be expressed as a visible windup arm/release sequence, and any future fast verb must be expressed as a visible free-step or Major-grade free action, because enemy countdowns are defined in committed player inputs.

## Sketch (non-normative)

- Proposed home: `game/scenes/stages/tick_arena/` — `tick_arena.tscn/.gd` (scene root and wiring), `tick_engine.gd` (resolution + actor registry), `tick_input.gd` (verb layer), `tick_player.gd` (player actor).
- Migration path: copy the prototype scripts from `game/scenes/prototype/tick_combat/`, rename `proto_` → `tick_`, split the controller into the three roles above. The prototype folder stays untouched as the playable reference until phase 7 deletes both old paths.
- `GridArena` is reused directly. The prototype's `ProtoCombatRules` grid math survives as-is here and is formalized into the shared hit resolver in phase 3.
- Engine shape: `execute_verb(verb)` runs stage 1, then detonations, then grants world-advance energy to registered non-player actors and any explicit extra-action consumers. Actors register with the engine instead of being iterated by the scene root; the player path never passes a variable action-cost scalar into world advancement.
- The grey-box view (`proto_grid_view` drawing) is carried along as the interim presentation; real presentation is not this phase's problem.

## Non-Goals

1. No production enemy kinds (phase 2), no override seam or outcome-preview formalization beyond what the prototype already does (phase 3), no Majors (phase 4), no speed stats (phase 5), no run loop (phase 6), no routing changes (phase 7).

## Acceptance Criteria

1. The tick arena scene reproduces prototype behavior — verbs, resolution order, occupancy, input feel — with the engine/input/player split in place.
2. The real-time production arena remains untouched and playable.
3. Attack, move, mobility, wait, and buffered repeat inputs all preserve the same public one-input-one-tick contract; no player verb advances enemies by a hidden fractional or multi-tick amount.
4. Standards lint passes on every new file.
