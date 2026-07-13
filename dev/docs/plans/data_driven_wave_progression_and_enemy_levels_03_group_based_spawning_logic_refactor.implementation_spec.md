# Data-Driven Wave Progression And Enemy Levels 03: Group-Based Spawning Logic Refactor

Parent Plan: `data_driven_wave_progression_and_enemy_levels.md`

## Goal

Refactor wave authoring and runtime admission around reusable enemy groups with simple anchor-based placement. The first production pass must teach one role at a time, introduce two authored combined groups, then use overlapping single-role groups without restoring a deeply nested catalog or role-specific runtime branching.

## Summary

Wave content will move out of the monolithic catalog into external wave and group resources. A reusable `SpawnGroupDefinition` owns composition plus one placement strategy; a lightweight `WaveGroupSlot` references that group and owns only occurrence-specific scheduling, warning, level, and boss data. The root catalog references ten external demo waves and one external endless template directly, with no YAML generator or string registry.

The initial reusable groups are:

| Group                   | Composition                                   | Placement        |
| ----------------------- | --------------------------------------------- | ---------------- |
| Small                   | Three weighted Thrust/Slash enemies           | `PLAYER_RING`    |
| Ranged                  | Two Ranged enemies                            | `ANCHOR_CLUSTER` |
| Charge                  | Two Charge enemies                            | `SCATTER`        |
| Bomb                    | Two Bomb enemies                              | `SCATTER`        |
| Small + Ranged          | Two Thrust, one Slash, two Ranged             | `ANCHOR_CLUSTER` |
| Small + Ranged + Charge | Two Thrust, one Slash, one Ranged, one Charge | `ANCHOR_CLUSTER` |
| Boss                    | One Mode Boss placeholder at level offset 3   | `SCATTER`        |

The first demo/endless schedule is:

| Wave | Ordered slots                    | Population cap |
| ---- | -------------------------------- | -------------- |
| 1    | Small                            | 3              |
| 2    | Ranged                           | 2              |
| 3    | Small + Ranged combined          | 5              |
| 4    | Charge                           | 2              |
| 5    | Small + Ranged + Charge combined | 5              |
| 6    | Small, Ranged, Charge            | 6              |
| 7    | Ranged, Small, Charge            | 7              |
| 8    | Small, Ranged, Charge, Bomb      | 8              |
| 9    | Charge, Ranged, Small, Bomb      | 9              |
| 10   | Boss only                        | 1              |
| 11+  | Charge, Ranged, Small, Bomb      | 10             |

All non-Boss slots use one warning tick; Boss uses two. Every slot in waves 6–9 and Endless uses immediate overlap, but the ordered scheduler admits only the earliest waiting slot. A slot cannot enter spawn flow or show a telegraph until its entire remaining group fits population headroom and a complete legal cell plan exists.

At warning resolution, keep the current best-effort safety behavior: revalidate each cell, relocate an invalid member to another legal cell using the same anchor intent when possible, and requeue only members for which no legal replacement exists. SPAWNING telegraphs block enemy path planning on every path step, while player movement and non-spawn telegraphs remain unchanged.

## Relational Context

- `WaveCatalog` references external `WaveDefinition` resources; each wave owns inline schedule slots, and each slot references an external reusable `SpawnGroupDefinition`. Direct Resource references are the only identity mechanism.
- `SpawnGroupDefinition` owns composition and placement. `WaveGroupSlot` owns start condition, survivor threshold, warning ticks, level offset, and boss role. Runtime code must not inspect enemy scenes or scripts to infer placement.
- `WaveController` expands each slot's referenced group once, latches eligibility in authored order, and owns admission, warning, living membership, and requeue state. Eligibility does not imply schedulability.
- The earliest eligible slot blocks later slots until its entire remaining queue fits population headroom and `EnemySpawnPlanner` returns a complete legal plan. Failed admission creates no pending batch, telegraph, or partial spawn.
- `EnemySpawnPlanner` reads group placement data and the player-cell provider, selects an anchor when the strategy uses one, and returns all cells or failure. It does not mutate grid state or own scheduling.
- `WaveController` publishes admitted cells through `GridArena` as SPAWNING telegraphs. `GridArena` remains the telegraph authority and exposes a spawn-specific path-block query without adding warnings to occupancy or reservations.
- `EnemyPathPlanner` reads the spawn-path query for every traversed and destination cell. Player planning and other grid consumers continue to read normal walkability, occupancy, and reservation APIs and may enter SPAWNING cells.
- Warning resolution is intentionally weaker than admission atomicity: valid members spawn together, invalid cells relocate, and only unrecoverable members return to their original slot queue with level, boss, composition order, placement strategy, and anchor context intact.
- `EnemySpawner` and level projection retain their existing pre-ready contract; this refactor changes which entries and cells reach that boundary, not enemy initialization.

## Scope

### Included

- Reusable group and lightweight wave-slot schemas with external `.tres` content.
- Three placement strategies, group-atomic admission, warning revalidation, and enemy-only spawn-path blocking.
- The explicit wave 1–10 and fixed Endless content baseline above.
- Focused schema, scheduling, placement, pathing, and production-catalog tests.

### Excluded

- YAML or generated wave authoring, procedural group selection, adaptive difficulty, or random group-size ranges.
- Spawn-time player knockback, forced displacement, or changes to player movement legality.
- New enemy roles, bespoke Boss behavior, reward changes, or final numerical playtest tuning.

## Files to Change

| File                                                                        | Change Size | Purpose                                                                                                     |
| --------------------------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------- |
| `data/waves/definitions/spawn_group_definition.gd`                          | Medium      | Add reusable composition and placement data with validation.                                                |
| `data/waves/definitions/wave_group_slot.gd`                                 | Medium      | Add occurrence-specific scheduling data and a typed group reference.                                        |
| `data/waves/definitions/wave_group_definition.gd` and `.uid`                | Small       | Delete the superseded combined schema.                                                                      |
| `data/waves/definitions/wave_definition.gd` and `wave_catalog.gd`           | Medium      | Consume typed slots and validate external resources and atomic-cap compatibility.                           |
| `data/waves/groups/*.tres`                                                  | Medium      | Author the seven reusable production groups.                                                                |
| `data/waves/demo/*.tres` and `data/waves/endless/default_endless_wave.tres` | Large       | Author the initial demo schedule and fixed Endless template.                                                |
| `data/waves/default_wave_catalog.tres`                                      | Medium      | Replace nested subresources with direct external wave references.                                           |
| `game/tick_arena/wave/wave_controller.gd`                                   | Large       | Schedule whole remaining groups, preserve ordered blocking, and carry placement context through resolution. |
| `game/tick_arena/wave/enemy_spawn_planner.gd`                               | Large       | Produce complete anchor-aware group plans and strategy-aware replacements.                                  |
| `common/gameplay/grid/grid_arena.gd`                                        | Small       | Expose exact SPAWNING-phase path blocking without changing occupancy.                                       |
| `game/entities/enemies/enemy_path_planner.gd`                               | Medium      | Reject spawn-blocked cells throughout enemy BFS.                                                            |
| `test/unit/test_enemy_progression_data.gd`                                  | Medium      | Validate the split schema and external production catalog.                                                  |
| `test/unit/test_wave_controller.gd`                                         | Large       | Cover atomic admission, ordered blocking, revalidation, and explicit wave content.                          |
| `test/unit/test_enemy_spawn_planner.gd`                                     | Large       | Cover all strategies, full-plan failure, anchor retention, and legal replacement.                           |
| `test/unit/test_enemy_pathfinding.gd`                                       | Medium      | Cover enemy-only SPAWNING path blocking on interior and goal cells.                                         |

## Execution Outline

1. Introduce the split Resource schemas and validation, migrate catalog typing, and add focused schema fixtures before changing runtime scheduling.
2. Author reusable group resources, external demo/endless waves, and the shallow root catalog; validate exact roster order, counts, caps, warnings, and Boss-only wave 10.
3. Replace per-entry admission with complete group planning and headroom checks, retaining ordered eligibility, membership, level projection, completion, and single-warning ownership.
4. Implement the three planner strategies and resolution-time replacement using retained strategy/anchor context.
5. Add the exact SPAWNING query to the grid and reject those cells throughout enemy path search without changing player or generic occupancy behavior.
6. Rewrite focused tests, run standards lint on changed scripts, run the relevant unit suites, and manually verify waves 1–10 plus one continued Endless wave.

## Implementation Notes

- `PLAYER_RING` uses the player cell as its anchor and chooses legal cells in a Manhattan distance band of 2–4, preferring angular separation. `ANCHOR_CLUSTER` chooses one legal anchor in the player's Manhattan distance band of 3–5 and fills nearest legal cells around it. `SCATTER` chooses independent legal cells across LAND. All strategies exclude the player, occupants, reservations, duplicates, and non-LAND cells.
- A plan succeeds only with exactly as many distinct cells as remaining entries. Do not fall back to occupied cells or the player cell during admission.
- Resolve weighted composition before checking atomic fit. Validation rejects any authored group whose expanded fixed count or weighted total can exceed the referencing wave's population cap.
- Waves 6–9 and Endless intentionally latch all immediate-overlap slots, but one pending warning remains the maximum. Once a slot spawns, the next slot may warn immediately only if the whole group fits current headroom.
- Exact SPAWNING detection must inspect source phases, not only the visually highest phase, so overlapping telegraphs cannot hide the blocker. The start cell is allowed for an enemy already standing there; every newly traversed cell and candidate endpoint is rejected.
- At resolution, try the original cell, then a legal replacement preserving the stored anchor/strategy, then any legal cell. If neither replacement exists, prepend that entry to its original slot queue and give it a fresh admission plan and telegraph later.

## Edge Cases

| Case                                                      | Expected Handling                                                                                 |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Eligible group exceeds current headroom                   | It waits without telegraphing, and later groups do not bypass it.                                 |
| Headroom fits but no complete placement exists            | The group remains queued outside spawn flow with no warning.                                      |
| Player enters a warned cell                               | That member relocates at resolution; player movement was never blocked.                           |
| One warned cell becomes invalid and no replacement exists | Other resolvable members spawn; only that member requeues under the same slot.                    |
| Spawn warning overlaps an attack warning                  | Enemy pathing still treats the cell as spawn-blocked; presentation keeps existing phase priority. |
| Zero-warning test fixture                                 | It uses the same complete-plan admission and resolution path without publishing a telegraph.      |
| Boss wave begins                                          | Only the Boss group is present; no support-enemy phase is scheduled.                              |

## Acceptance Criteria

1. Designers can reuse external group resources across shallow external wave definitions without duplicating composition or editing a monolithic nested catalog.
2. Waves 1–5 teach the specified isolated and combined groups, waves 6–9 use ordered overlapping single-role groups, wave 8 introduces Bomb, and wave 10 spawns only the Boss placeholder.
3. Every Endless wave uses the unchanged wave-9 ordered group grammar with a fixed population cap of 10, with difficulty growth still coming only from existing level and Guard-tier systems.
4. An eligible group never telegraphs or partially enters spawn flow until its entire remaining membership fits headroom and has a complete legal placement plan; later groups never bypass it.
5. Small, Ranged, Charge, Bomb, and combined groups visibly follow their authored placement strategies without runtime role detection.
6. Warning resolution safely relocates invalid cells and requeues only unrecoverable members without losing slot identity, level, Boss role, placement intent, or eventual wave completion.
7. Enemies do not plan through or onto SPAWNING telegraphs, while the player can enter them and generic attack telegraphs do not become movement blockers.
