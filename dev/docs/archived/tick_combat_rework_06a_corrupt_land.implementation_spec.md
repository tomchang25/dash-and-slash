# Tick Combat Rework 06a: Corrupt Land

## Goal

Add Corrupt Land as a tick-arena terrain-state feature after the main run loop is stable. Corrupt Land damages a non-dashing player during the world-resolution status stage, making terrain pressure part of the readable tick puzzle without changing enemy telegraph truth.

## Relational Context

- `GridArena` currently owns only land/sea terrain truth, mutation validity, occupancy, reservation, and telegraph state; Corrupt Land must extend terrain truth there or through a terrain-state owner that `GridArena` exposes, not through view-only state.
- `GridTerrainView` currently draws land, water, grid lines, and telegraphs from `GridArena`; Corrupt Land presentation must read terrain truth and remain visually distinct from enemy danger telegraphs.
- `TickEngine` owns world-advance resolution order; Corrupt Land damage belongs in the status stage after the player action and enemy detonations, not in input handling or frame processing.
- `TickArena` or the post-6f run controller may pass whether the just-resolved player action was a dash/leap-style mobility action; terrain damage must not infer dash immunity from animation or tween state.
- Terrain mutation helpers currently add, move, and remove connected land cells; corrupting a cell must preserve land connectivity because it changes state, not walkability.
- Corrupt Land is not a reward card or manual terrain targeting feature in this spec; it is the terrain-state mechanic that later content can use.

## Scope

### Included

- Corrupt terrain state, query, mutation helper, presentation, and tick-stage damage.
- Dash/pass-through immunity for the action that moved through or landed via mobility.

### Excluded

- Reward cards that create Corrupt Land.
- Manual terrain targeting UI.
- New enemy behavior that creates Corrupt Land.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/grid/grid_arena.gd` or post-6f terrain owner | Medium | Own corrupt terrain state and expose queries/mutations. |
| `common/gameplay/grid/grid_terrain_view.gd` or post-6f view path | Medium | Draw corrupt cells distinctly from telegraphs. |
| `game/tick_arena/combat/tick_engine.gd` | Medium | Apply terrain damage in the tick status stage. |
| `game/tick_arena/combat/tick_action_controller.gd` | Small | Report whether the current action has terrain-damage immunity. |
| `test/unit/*` | Medium | Cover corrupt terrain queries, mutation persistence, and tick damage/immunity. |

## Implementation Notes

Represent Corrupt Land as a state layered on land, not as a replacement for land. A corrupt cell is still walkable land unless a later spec changes that rule.

Keep the damage trigger tied to a committed world-advancing tick. Free actions that do not advance the world should not run the terrain status stage, matching the telegraph contract.

The player should take damage when standing on Corrupt Land at terrain-damage resolution unless the action that led to that resolution was an immune mobility pass-through or landing.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Player uses a free mobility refund and lands on Corrupt Land | No world tick resolves, so no terrain damage fires. |
| Player waits on Corrupt Land | The wait advances the world and terrain damage applies. |
| Terrain mutation removes a corrupt land cell | The corrupt state is cleared with the removed land. |

## Acceptance Criteria

1. Corrupt Land is visible, walkable, and distinct from enemy telegraphs.
2. A non-immune player standing on Corrupt Land takes damage during tick world resolution.
3. Dash-style mobility pass-through immunity prevents Corrupt Land damage for that resolving action.
4. Connected-land mutation rules remain valid with corrupt cells present.
