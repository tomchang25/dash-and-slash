# Player Stat Rewards Implementation Spec

## Goal

Create a run-scoped, data-driven player stat path so wave reward cards can modify numeric player combat values without direct reward-to-player field mutation. Add the first Minor stat rewards, including normal attack cadence, while keeping the Major class-change placeholder safe and non-functional.

## Relational Context

- The active arena scene coordinates collaborators for one run, but it does not become the owner of player stat truth; it creates or wires the player stat owner for the active player and lets that owner die with the scene.
- Do not introduce a broad RunSystem in this slice. Wave flow and future enemy pressure remain scene-local wave controller state until save/checkpoint or cross-scene run resume exists.
- PlayerStatStore is the single run-scoped owner for player stat definitions, run modifiers, min clamps, and resolved values. Reward code writes stat changes only through this owner.
- Player remains the owner of action execution and health component wiring. It reads resolved damage/cooldown values from PlayerStatStore and applies max-health changes through the Health component so health signals and HUD snapshots stay consistent.
- Reward generation may keep its existing generator-owned effect definitions in this slice, but player-stat effects must reference stat ids that resolve through the data-backed stat path. Reward application mutates terrain, wave pressure, or PlayerStatStore depending on effect kind.
- Data definitions and registries answer what player stats exist. Runtime stores answer current run values. Do not put mutable run modifiers into Resource definitions or registries.
- Major placeholder resolution remains a no-op gameplay mutation. It may display honest prototype copy, but it must not change class, weapon, or attack behavior.

## Scope

### Included

- Data-backed player stat definitions for normal attack damage, normal attack cooldown, dash attack damage, dash cooldown, and max health.
- A run-scoped PlayerStatStore with additive modifier support and min-value clamping.
- Minor reward effects/cards for the supported player stats, routed through the stat owner.
- Player reads for attack damage, dash damage, attack cadence, dash cooldown, and max health.

### Excluded

- Persistent progression, save migration, checkpoint restore, and run resume.
- Real class changes, weapon attack variants, rarity, deck economy, or manual terrain targeting.
- A broad RunSystem or PlayerStore.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `data/definitions/player_stat_data.gd` | Small | Designer-authored schema for base stat values and min clamps. |
| `data/yaml/player_stats.yaml` | Small | Source data for first-pass player stats. |
| `global/constants/data_paths.gd` | Small | Add the generated player stat resource directory path. |
| `global/autoloads/registries/player_stat_registry.gd` | Small | Typed registry for player stat definitions. |
| `project.godot` | Small | Register the player stat registry autoload before gameplay reads it. |
| `game/entities/player/player_stat_store.gd` | Medium | Run-scoped stat owner that resolves base values plus modifiers. |
| `game/entities/player/player.gd` | Medium | Wire stat store reads into combat damage, cooldown, attack cadence, and max health behavior. |
| `game/entities/player/states/player_attack_state.gd` | Small | Use player-provided normal attack duration/cadence instead of the fixed constant. |
| `game/scenes/stages/dash_and_slash_arena.gd` | Small | Create/wire the run-scoped stat store and pass it to reward application. |
| `game/scenes/stages/rewards/*.gd` | Medium | Add player-stat effect metadata, generation, UI text, and applier routing through PlayerStatStore. |
| `test/unit/*player_stat*` and reward tests | Medium | Cover stat resolving, max-health behavior, cooldown clamps, and reward application routing. |

## Implementation Notes

Use additive modifiers first. For cooldown stats, cards should add negative values and the store clamps to the stat minimum. Normal attack cooldown maps to the current attack cadence/duration path; do not add a separate attack cooldown timer unless the existing player state flow requires it after inspection.

When dash cooldown decreases during an active cooldown, clamp the remaining cooldown to the new resolved maximum. When max health increases, increase current health by the same amount through the Health component.

Generated `.tres` files remain tool-owned. Add YAML/resource definitions, then regenerate through the data pipeline rather than hand-editing `data/tres`.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Unknown stat id in a reward effect | The effect is rejected with a warning and no player field is mutated directly. |
| Cooldown modifier would go below the stat minimum | Resolved cooldown clamps to the minimum. |
| Max health increases while damaged | Current health increases by the same amount, capped by the new maximum. |
| Major placeholder is selected | The choice resolves and the next wave can start, with no gameplay stat or class mutation. |

## Acceptance Criteria

1. Minor stat rewards can modify normal attack damage, normal attack cooldown, dash attack damage, dash cooldown, and max health through a single run-scoped stat owner.
2. Player combat behavior reflects resolved stat values without reward code directly mutating player combat fields.
3. Dash cooldown reductions clamp active remaining cooldown to the new maximum.
4. Max-health rewards increase both maximum and current health by the defined amount.
5. Data-backed stat definitions load through the registry path and runtime modifiers are not stored in data resources.
6. The Major placeholder remains selectable and resolves safely without changing class or weapon behavior.
