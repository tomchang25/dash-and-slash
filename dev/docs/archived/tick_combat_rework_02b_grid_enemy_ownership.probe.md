**GridEnemy ownership concentration**

Status: Archived probe.

Decision: resolved into dev/docs/plans/tick_combat_rework_02c_enemy_ownership.md — the base keeps grid identity, occupancy/reservations, health/guard/death bridging, and the actor facade; tick combat state moves to a per-enemy runtime, and path planning plus hit resolution become stateless helpers.

`GridEnemy` has become the central aggregation point for enemy runtime behavior. It is no longer only a shared grid enemy base class. In the tick conversion it accumulated grid occupancy, reservation interaction, path planning, tick actor scheduling hooks, telegraph and detonation state, player-hit prediction and resolution, guard/stagger bridging, feedback routing, and death cleanup.

This concentration reduced duplication during the conversion, but it also made `GridEnemy` the place every future enemy rule wants to land. Any change to enemy behavior, attack timing, guard handling, movement arbitration, presentation cleanup, or tick scheduling is tempted to become another method, flag, or override hook on the base class.

- **Base class as runtime system** — `GridEnemy` now acts like the enemy runtime system while also being inherited by every production enemy kind. That means kind scripts inherit a wide surface area of state and side effects whether they need all of it or not.

- **Hidden sequence coupling** — Kind scripts rely on base-side ordering around `begin_committed_action()`, `_attack_tiles`, `_attack_ticks`, `_recovery_ticks`, reservation refresh, guard break cleanup, and death cleanup. The behavior is understandable while reading the whole class, but each individual override depends on more context than its local code shows.

- **Multiple responsibilities change together** — Movement, attack intent, hit prediction, damage feedback, and status gating all share the same object. A small fix in one area can accidentally perturb another area because the same base state participates in several workflows.

- **Testing pressure rises with every enemy kind** — The more `GridEnemy` owns, the harder it is to test one behavior without constructing the rest of the enemy runtime. A pathing change can require attack state awareness; an attack timing change can require guard and recovery awareness; a hit preview change can depend on facing, grid, and health state.

- **Future phases amplify the pressure** — Pattern director work, mobility previews, windup/major enemies, speed stats, and run-loop recalibration all need to touch enemy timing or presentation. If the base class remains the only integration point, each phase increases the size and risk of `GridEnemy`.

The discussion target is to identify which responsibilities are truly intrinsic to a grid enemy entity and which should become a separate collaboration boundary. Candidate boundaries include movement/path planning, tick combat runtime, attack presentation/runtime, and hit prediction/resolution. The goal is not abstraction for its own sake; the goal is to stop every enemy rule from coupling through one object.

Open question: what is the smallest responsibility set `GridEnemy` should retain as the shared base for production enemies?

Open question: should tick combat state become a component-like runtime owned by each enemy, a scene-scoped system coordinated by `TickEngine`, or a set of state-owned behaviors inside the FSM?
