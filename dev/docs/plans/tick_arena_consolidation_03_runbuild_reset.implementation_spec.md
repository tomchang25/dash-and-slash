# Tick Arena Consolidation 03: Run Store In-Place Reset

Parent Plan: `tick_arena_structure_consolidation.md`

## Goal

Construct the run-scoped `RunBuild` once per arena scene and reset it in place on restart, deleting the fresh-instance re-wiring chain where every holder must be re-pointed and one missed holder is a silent stale-state bug.

## Summary

- **Restart risk:** Replacing `RunBuild` on every restart forces multiple collaborators to be re-pointed, and one missed holder silently keeps stale run state.
- **Reset shape:** The arena scene constructs one `RunBuild`; restart clears that store in place, so the arena root, run controller, action controller, preview controller, reward context, and wave controller keep their original injected reference.
- **Control flow:** Restart handling moves into the run controller for the death-overlay button and the root's debug R-key path, while `run_reset_finished` stays as the root-facing refresh signal for HUD and debug-panel state.
- **Result:** A restarted run starts from default build state without any collaborator re-wiring; the replacement path is deleted entirely so the old stale-reference bug class cannot survive as a second reset mode.

## Relational Context

- Today the arena root constructs a fresh `RunBuild` per restart and re-wires every reader: `_restart_run()` re-runs `setup()` on the action and preview controllers, then `reset_run(reason, fresh_run_build)` re-points the run controller's own reference, the reward context's `run_build` field, and the wave controller via `set_run_build()`. After this change all five holders keep one stable reference for the scene's lifetime, injected once at `_ready`-time setup.
- `RunBuild.clear()` already resets everything a fresh instance provides: channel entries, Major records, the mobility payload override (back to the Dash default), and the trigger set. Its docstring currently declares it "not used on the production restart path" — that claim inverts and must be rewritten, and the arena-root/run-controller docstrings that document the wholesale-replacement doctrine rewrite with it.
- Restart has two entry points: the death overlay's restart button (run controller territory) and the debug R key (arena root). The `restart_requested` signal exists only so the root can construct the fresh store; with in-place reset the run controller handles its own restart button directly and the signal is deleted. The root's R-key path calls the run controller's reset directly.
- `run_reset_finished` stays: the root still refreshes HUD and debug-panel button state after a reset.
- `reset_run(reason)` loses its `fresh_run_build` parameter; the reward context and wave controller re-pointing lines inside it are deleted, not moved.
- Wrong shape to avoid: keeping both reset paths (replacement and clear) "for safety" — that recreates the two-truths problem this spec removes. `clear()` becomes the only reset path.

## Scope

### Included

- In-place reset semantics, `restart_requested` deletion, docstring/doctrine updates.

### Excluded

- Any other `RunBuild` API or semantic change; reward flow, wave flow, and death overlay behavior.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `game/tick_arena/tick_arena.gd` | Medium | Stop rebuilding the store; `_restart_run` delegates to the run controller; drop `restart_requested` wiring; update header doctrine |
| `game/tick_arena/run/tick_run_controller.gd` | Medium | `reset_run(reason)` clears the store in place; restart button handled locally; drop the signal; update header doctrine |
| `game/tick_arena/run/run_build.gd` | Small | `clear()` docstring reflects production use |
| `test/unit/*` | Small | Cover `clear()` resetting entries, majors, payload override, and triggers together |

## Implementation Notes

- Preserve the existing reset order with `clear()` slotted where the re-pointing was: cancel pending wave flow → unregister/free actors → clear the store → `player.reset()` with the projected max-health total → action-controller reset → wave-controller reset → start wave. After `clear()` the max-health total is 0.0, exactly what a fresh instance yields today, so player reset behavior is unchanged.
- The run controller already holds the store reference from setup; `reset_run` needs no new parameters.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Restart while the wave banner or reward overlay is pending | Existing cancellation path runs unchanged before the store clears; no stale callback can apply a reward onto the cleared store |
| Restart with owned Majors / payload override / triggers | `clear()` drops them; `run_reset_finished` still drives the root's debug-button and HUD refresh |
| Death overlay restart vs debug R key | Both converge on the same run-controller reset method |

## Acceptance Criteria

1. A restarted run starts from default build state — no inherited rewards, Majors, payload override, or triggers — with no collaborator re-pointed.
2. Exactly one reset path exists, and no production code constructs a second `RunBuild` for the same arena scene.
3. Gameplay is observably unchanged; lint and unit tests pass.
