# Tick Combat Rework 06e: Terrain, Death, And Restart Integration

## Goal

Complete the tick run loop around the converted wave system: reward choice, terrain cadence, milestone expansion, death, restart, and end-to-end run reset.

## Relational Context

- The legacy arena currently owns terrain mutation after reward choice, including normal-wave move/remove selection, milestone land expansion, player recentering, and reward overlay notes.
- `GridArena` owns terrain truth and already emits terrain-change signals consumed by the production grid view; terrain cadence must mutate through that authority.
- The reward controller pauses the tree while choices are visible; tick run flow should treat reward choice as a UI pause with no enemy action.
- The tick run controller should own current wave-complete and pending terrain-mutation flow; the wave controller should own wave progression and enemy queue, not reward UI.
- `TickEngine` emits player death after resolving the current tick; the tick arena must show a death overlay with a restart button instead of silently instant-resetting the run.
- Restart from the death overlay must clear actors, pending spawn warnings, pending reward/banner callbacks, player runtime state, run-build state, and terrain state consistently.
- Restart should create a fresh run-build state; do not clear the existing store in place unless the scene deliberately reuses the same object after all readers are rewired.
- Terrain mutation must not break connected-land validity and must refresh through the existing terrain presentation path.

## Scope

### Included

- Reward-open/apply flow after wave clear.
- Automatic terrain mutation after reward choice.
- Milestone expansion.
- Death overlay and restart button flow for the tick arena.
- Fresh run reset semantics.

### Excluded

- Final HUD refactor.
- Corrupt Land.
- Manual terrain targeting.

## Files to Change

| File                                                   | Change Size | Purpose                                                                      |
| ------------------------------------------------------ | ----------- | ---------------------------------------------------------------------------- |
| `game/scenes/stages/tick_arena/tick_run_controller.gd` | Large       | Own wave clear, reward open/apply, terrain cadence, death, and restart flow. |
| `game/scenes/stages/tick_arena/tick_arena.gd`          | Medium      | Wire run-controller signals and scene UI nodes.                              |
| `game/scenes/stages/tick_arena/tick_arena.tscn`        | Medium      | Add death overlay, restart button, and terrain note support if needed.       |
| `game/scenes/stages/rewards/wave_reward_overlay.gd`    | Small       | Preserve terrain mutation note behavior in tick arena.                       |
| `common/gameplay/grid/grid_arena.gd`                   | Small       | Add any reset helper needed to regenerate a fresh run terrain safely.        |
| `test/unit/*`                                          | Medium      | Cover terrain cadence selection, reset state, and run-build freshness.       |

## Implementation Notes

Apply pending terrain mutation after the reward is selected, not before, so the player reads reward and terrain shift as one between-wave transition.

Use one RNG owner for reward choice and terrain cadence within a run controller unless a later spec deliberately splits deterministic streams.

On restart, prefer rebuilding fresh run-scoped objects and resetting terrain to initial generation rather than partially clearing each owner in arbitrary order.

Death should lock or ignore further combat input while the overlay is visible. Restart is the only player-facing recovery path in this phase.

## Edge Cases

| Case                                                       | Expected Handling                                           |
| ---------------------------------------------------------- | ----------------------------------------------------------- |
| Player dies while reward overlay is pending                | Close or suppress reward flow and show death/restart state. |
| Terrain mutation has no valid candidate                    | No-op safely and continue the run.                          |
| Restart happens during a banner/tween delay                | Cancel pending callbacks before creating the fresh run.     |
| Player presses combat input while death overlay is visible | Ignore combat input until restart is pressed.               |

## Acceptance Criteria

1. Clearing a wave opens reward choice, applies the selected reward, mutates terrain, and starts the next wave.
2. Milestone waves expand land by ten cells without breaking connected terrain.
3. Player death shows a death overlay with a restart button, and restart begins from fresh run state.
4. Terrain changes redraw through the production grid presentation.
