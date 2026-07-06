# Tick Combat Rework 06e: Reward, Death, And Restart Integration

## Goal

Complete the tick run loop around the converted wave system: reward choice, death, restart, and end-to-end run reset. Terrain mutation is intentionally removed from this phase because highly random or fragmented terrain can create dead boards or clumsy turns in the current semi-puzzle tick combat model.

## Relational Context

- The reward controller pauses the tree while choices are visible; tick run flow should treat reward choice as a UI pause with no enemy action.
- The tick run controller should own wave-complete reward flow; the wave controller should own wave progression and enemy queue, not reward UI.
- Terrain cadence is frozen for this phase. The run controller should not apply automatic add/move/remove land operations after reward choice, and milestone waves should not expand land here.
- `TickEngine` emits player death after resolving the current tick; the tick arena must show a death overlay with a restart button instead of silently instant-resetting the run.
- Restart from the death overlay must clear actors, pending spawn warnings, pending reward/banner callbacks, player runtime state, and run-build state consistently.
- Restart should create a fresh run-build state; do not clear the existing store in place unless the scene deliberately reuses the same object after all readers are rewired.
- Grid terrain should reset to the stable starting layout for a fresh run; no procedural terrain progression is introduced in this spec.

## Scope

### Included

- Reward-open/apply flow after wave clear.
- Death overlay and restart button flow for the tick arena.
- Fresh run reset semantics.

### Excluded

- Automatic terrain mutation after reward choice.
- Milestone land expansion.
- Procedural map progression.
- Final HUD refactor.
- Corrupt Land.
- Manual terrain targeting.

## Files to Change

| File                                                   | Change Size | Purpose                                                                                        |
| ------------------------------------------------------ | ----------- | ---------------------------------------------------------------------------------------------- |
| `game/scenes/stages/tick_arena/tick_run_controller.gd` | Large       | Own wave clear, reward open/apply, death, and restart flow.                                    |
| `game/scenes/stages/tick_arena/tick_arena.gd`          | Medium      | Wire run-controller signals and scene UI nodes.                                                |
| `game/scenes/stages/tick_arena/tick_arena.tscn`        | Medium      | Add death overlay and restart button if not already present.                                   |
| `test/unit/*`                                          | Medium      | Cover reward continuation, death overlay state, restart cancellation, and run-build freshness. |

## Implementation Notes

Opening reward choice should remain a real-time UI pause: no enemies act while the overlay is visible, and the next wave starts only after a reward is selected.

Do not apply a terrain mutation when reward choice is applied. The previous terrain-note UI should be removed, hidden, or left unused in the tick arena path so the player is not promised a terrain shift that no longer occurs.

On restart, prefer rebuilding fresh run-scoped objects and resetting the grid to its stable starting layout rather than partially clearing each owner in arbitrary order.

Death should lock or ignore further combat input while the overlay is visible. Restart is the only player-facing recovery path in this phase.

## Edge Cases

| Case                                                       | Expected Handling                                           |
| ---------------------------------------------------------- | ----------------------------------------------------------- |
| Player dies while reward overlay is pending                | Close or suppress reward flow and show death/restart state. |
| Restart happens during a banner/tween delay                | Cancel pending callbacks before creating the fresh run.     |
| Player presses combat input while death overlay is visible | Ignore combat input until restart is pressed.               |
| Reward overlay terrain note still exists in the scene      | Hide it or leave it blank for tick reward flow.             |

## Acceptance Criteria

1. Clearing a wave opens reward choice, applies the selected reward, and starts the next wave without mutating terrain.
2. Player death shows a death overlay with a restart button, and restart begins from fresh run state.
3. Pending reward, banner, and spawn-warning callbacks cannot reopen stale flow after death or restart.
4. Tick run flow no longer depends on automatic terrain mutation or milestone land expansion.
