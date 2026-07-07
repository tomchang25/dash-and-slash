# Tick Combat Rework 06b: Tick Arena Ownership

## Goal

Extract the tick arena root's three most unstable responsibility lines into scene-scoped controllers without changing gameplay behavior. This is a stabilization pass for Phase 6: the arena root should wire collaborators, while action resolution, preview presentation, and the temporary run bridge each get a narrower owner before the full wave loop lands.

## Relational Context

- `TickArena` currently owns input dispatch, player verbs, committed hit resolution, preview calculation, fixed enemy spawning, reward bridge flow, wave banner timing, reset behavior, debug controls, and HUD message text; this spec reduces it to scene composition, signal wiring, and small UI glue that has not yet earned a controller.
- `TickActionController` owns consumed verb resolution: move, normal attack, mobility payloads, wait, Speed meter spends/fills, Mobility Free Action refunds, hit application, action messages, and the decision to call the engine for world advancement.
- `TickActionController` may mutate `TickPlayer`, `RunBuild`, enemy health through the existing hit path, and `TickGridView` feedback flashes; it may request world advancement from `TickEngine`, but it must not own tick count, actor energy, wave state, reward state, spawn queues, or terrain cadence.
- `TickPreviewController` owns read-only gameplay preview calculation: mouse cell/aim resolution, dash plan previews, smash previews, and predicted outcome badges; it writes only view payloads and must not mutate player state, enemy state, run-build state, wave state, or world time.
- `TickPreviewController` and `TickActionController` may share pure planning/result helpers only when those helpers have no side effects; if a helper applies damage, moves the player, changes cooldowns, or emits gameplay signals, it belongs to the action controller.
- `TickRunController` is deliberately transitional in this spec: it owns the Phase 4c fixed-enemy bridge, wave-clear handling, reward open/apply flow, banner delay, and reset hook seam, but it does not convert to the real wave controller until Phase 6d/6e.
- `TickInput` continues to emit verbs and stays outside ownership of action results; it should connect to the action controller rather than the arena root.
- `TickEngine` remains the only world-advance scheduler and actor registry owner; controllers can register/unregister actors only through narrow methods and cannot duplicate actor lists as scheduling truth.
- `TickPlayer` remains the player runtime-state owner for cell, hp, cooldowns, speed meter, smash windup, and animation movement; controllers read or mutate it through explicit methods rather than by becoming alternate owners of those fields.
- Debug controls should write through `RunBuild` or the same controllers real gameplay uses, so debug behavior remains representative instead of becoming a second behavior path.

## Scope

### Included

- Extract `TickActionController`, `TickPreviewController`, and transitional `TickRunController`.
- Move existing arena-root method bodies into those owners with behavior preserved.
- Define controller setup, signals, and allowed read/write boundaries.

### Excluded

- Wave controller conversion, spawn retuning, or terrain cadence.
- Reward channel migration.
- `game/tick_arena/` folder relocation; Phase 6f owns path cleanup.
- Final HUD refactor.

## Files to Change

| File                                                       | Change Size | Purpose                                                                                                                                      |
| ---------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `game/scenes/stages/tick_arena/tick_arena.gd`              | Large       | Reduce to composition root, controller setup, signal wiring, debug-panel glue, and remaining HUD updates.                                    |
| `game/scenes/stages/tick_arena/tick_action_controller.gd`  | Large       | Own verb dispatch, committed player actions, hit application, cooldown/speed/free-action logic, action feedback, and world-advance requests. |
| `game/scenes/stages/tick_arena/tick_preview_controller.gd` | Medium      | Own per-frame preview calculation, outcome prediction payloads, and calls to the preview view path.                                          |
| `game/scenes/stages/tick_arena/tick_run_controller.gd`     | Medium      | Own the current fixed-spawn reward bridge, wave-clear banner flow, reward apply continuation, and reset seam.                                |
| `game/scenes/stages/tick_arena/tick_arena.tscn`            | Medium      | Add controller nodes or exported controller references and wire required scene dependencies.                                                 |
| `test/unit/*`                                              | Medium      | Update or add focused tests for action-result behavior and preview/result consistency where practical.                                       |

## Implementation Notes

Use node-backed controllers. They need scene references, signals, and in the preview controller's case per-frame updates; using Nodes also keeps setup visible in the scene before Phase 6f relocates files.

The first extraction target is the action controller. Move the verb methods and their support helpers together so the consumed/advances-world contract remains local. The arena root should receive high-level signals such as message changed, HUD changed, enemy killed, or wave cleared rather than inspecting every verb result.

The preview controller should be second. It may duplicate some pure planning code initially if sharing would pull side effects across the boundary; correctness beats premature helper consolidation here. A later cleanup can merge pure helpers once the ownership split is stable.

The run controller should be thin and transitional. It can keep the fixed enemy composition and current reward bridge so behavior stays stable, but it should expose seams that Phase 6d/6e can replace with the real wave controller and terrain/death/restart flow.

Do not move files to `game/tick_arena/` in this spec. Keeping paths stable makes the review about ownership rather than resource relocation.

## Edge Cases

| Case                                                        | Expected Handling                                                                        |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| A free action is consumed                                   | The action controller emits state/message refresh signals without advancing the engine.  |
| A preview helper needs data also used by a committed action | Share only pure calculation; side-effectful commit logic stays in the action controller. |
| Debug toggles change mobility payload or triggers           | Action and preview controllers read the updated run build and stay in sync.              |
| Reset occurs while a reward/banner delay is pending         | The run controller owns cancellation so stale callbacks cannot reopen reward flow.       |

## Acceptance Criteria

1. The tick arena root no longer contains the player verb method bodies, preview calculation bodies, or fixed reward-bridge flow bodies.
2. Action resolution, preview calculation, and transitional run flow have explicit owners with documented read/write boundaries.
3. Existing Phase 4c/5 behavior is preserved: fixed enemy set, rewards after clear, speed meter, mobility refunds, debug controls, and reset still work.
4. Phase 6d and 6e can replace the transitional run controller seams without adding more run-loop behavior back into the arena root.
