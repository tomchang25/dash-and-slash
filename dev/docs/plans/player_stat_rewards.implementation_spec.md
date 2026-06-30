# Player Stat Rewards Implementation Spec

## Goal

Create a small run-scoped player stat path so wave reward cards can modify numeric player combat values without hard-coding buff values into UI code. Add the first Minor stat rewards, including normal attack cadence, while keeping the Major class-change placeholder safe and non-functional.

## Relational Context

- The active arena scene coordinates one run, but it does not need a broad RunSystem for this slice. Wave flow and future enemy pressure remain scene-local wave controller state.
- Player owns runtime player stat mutation because the affected values are player combat behavior. It creates a run-local mutable copy from the exported PlayerStatsData resource when the run starts.
- PlayerStatsData is a simple authored resource with direct fields for max health, normal attack damage, normal attack cooldown, dash attack damage, and dash cooldown. It is not a generic stat registry, stat set, or operation system.
- Health remains the owner of current health and health signals. PlayerStatsData stores max-health tuning, while max-health buffs route through Player so the Health component can update maximum and current health together.
- Reward generation keeps explicit effect kinds for each supported buff. Reward application calls narrow Player methods such as damage up or cooldown down, and does not own player stat state.
- Major placeholder resolution remains a no-op gameplay mutation. It may display honest prototype copy, but it must not change class, weapon, or attack behavior.

## Scope

### Included

- A manually authored `.tres` PlayerStatsData resource for first-pass player combat values.
- Player-owned run-local stat mutation for normal attack damage, normal attack cooldown, dash attack damage, dash cooldown, and max health.
- Minor reward effects/cards for the supported player stats, routed through explicit Player methods.
- Cooldown clamping for attack and dash cooldown buffs.

### Excluded

- Persistent progression, save migration, checkpoint restore, and run resume.
- Real class changes, weapon attack variants, rarity, deck economy, or manual terrain targeting.
- A broad RunSystem, PlayerStore, generic stat registry, stat-id map, or stat operation framework.
- YAML generation, DataPaths constants, and registry/autoload plumbing for player stats.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `data/definitions/player_stats_data.gd` | Small | Direct resource schema for first-pass player combat stat fields. |
| `game/entities/player/player_stats.tres` | Small | Manually authored first-pass stat resource used by the player. |
| `game/entities/player/player.gd` | Medium | Own the run-local stat copy and expose explicit buff methods used by rewards. |
| `game/entities/player/player.tscn` | Small | Remove prototype damage overrides that now belong in the stats resource. |
| `game/entities/player/states/player_attack_state.gd` | Small | Use player-provided normal attack duration/cadence instead of the fixed constant. |
| `game/scenes/stages/dash_and_slash_arena.gd` | Small | Ensure player run stats are initialized before rewards can apply. |
| `game/scenes/stages/rewards/*.gd` | Medium | Add explicit player buff effect kinds, generation, UI text, and applier routing through Player. |
| `test/unit/*player_stats*` and reward tests | Medium | Cover Player run stat mutation, max-health behavior, cooldown clamps, and reward application routing. |

## Implementation Notes

Cooldown-down cards carry positive magnitudes and call explicit reduce methods. Player clamps normal attack cooldown and dash cooldown to first-pass minimums.

When dash cooldown decreases during an active cooldown, clamp the remaining cooldown to the new maximum. When max health increases, increase current health by the same amount through the Health component.

Do not place this first-pass manual stat resource under `data/tres`, because that directory is tool-owned by the YAML pipeline. Keep the authored `.tres` feature-local for now; a later data-pipeline pass can promote it if the stat list grows.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Cooldown modifier would go below the first-pass minimum | Resolved cooldown clamps to the minimum. |
| Dash cooldown decreases while the dash is already cooling down | Remaining cooldown clamps to the new maximum. |
| Max health increases while damaged | Current health increases by the same amount, capped by the new maximum. |
| Major placeholder is selected | The choice resolves and the next wave can start, with no gameplay stat or class mutation. |

## Acceptance Criteria

1. Minor stat rewards can modify normal attack damage, normal attack cooldown, dash attack damage, dash cooldown, and max health through explicit Player-owned run stat mutation.
2. Player combat behavior reflects modified run stat values.
3. Dash cooldown reductions clamp active remaining cooldown to the new maximum.
4. Max-health rewards increase both maximum and current health by the defined amount.
5. Manually authored base stat values load from the first-pass `.tres` resource and runtime mutations stay run-local.
6. The Major placeholder remains selectable and resolves safely without changing class or weapon behavior.
