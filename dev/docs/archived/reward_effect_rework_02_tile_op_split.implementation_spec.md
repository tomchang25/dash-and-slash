# Reward Effect Rework — Tile Op Split

## Goal

Move terrain mutation out of the reward-choice pool into an automatic, fixed-shape event that fires once per normal wave clear, replacing the current card-based Move Land / Break Land options.

## Relational Context

- `WaveRewardChoiceGenerator` (`game/scenes/stages/rewards/wave_reward_choice_generator.gd`) currently owns the `move_land`/`remove_land` definitions and offers them to the player. After this change, terrain mutation is triggered directly by the wave-completion scene code and never sourced from the generator's pool — no code path produces a terrain-mutation reward effect anymore.
- `DashAndSlashArena` (`game/scenes/stages/dash_and_slash_arena.gd`) already owns one automatic, non-choosable terrain mutation: `_grant_milestone_expand_land()`, fired from `_on_normal_wave_complete()` on milestone waves, calling `GridArena.add_random_connected_land()` directly. The new per-wave mutation must be triggered from the same call site, using the same terrain-authority API (`GridArena`), not routed through the reward-effect/applier pipeline — this keeps `GridArena` the single terrain-truth owner and matches how the existing periodic grant already bypasses the reward pipeline.
- `WaveRewardEffectDefinition.Kind` (`wave_reward_effect_definition.gd`) is shared between the generator (decides what to offer) and `WaveRewardApplier` (`wave_reward_applier.gd`, decides what to do when picked). Removing `MOVE_RANDOM_SAFE_LAND`/`REMOVE_RANDOM_SAFE_LAND` from the offerable pool requires removing their dispatch from both the generator's `_is_definition_applicable()` and the applier's `_apply_effect()` together — leaving one side stale would breach this project's match-exhaustiveness convention (`dev/foundation/platforms/godot/standards/naming_conventions.md` §10) by leaving explicit-but-dead arms in one file only.
- No new `GridArena` API is needed. `GridArena.move_random_safe_land()` and `GridArena.remove_random_safe_connected_land()` already exist, are already called by both the (soon-removed) reward applier path and the debug panel's manual tile buttons, and already no-op safely (return `false`) when no valid candidate cells exist.
- The removed `Kind` enum members are pure in-memory identifiers with no save/serialization dependency anywhere in the pipeline — deleting them outright, rather than leaving them unused, is safe and keeps both matches exhaustive over only the enum members that remain meaningful.

## Scope

### Included

- Remove terrain mutation from the reward-choice pool: delete the two definitions, their `Kind` enum members, and both systems' dispatch for those members.
- Add a fixed, automatic terrain mutation that fires once per normal wave clear, choosing between exactly two shapes with equal probability: relocate two land tiles, or remove one land tile.

### Excluded

- The periodic milestone land-expansion grant's own trigger condition or amount.
- Any change to `GridArena`'s terrain-mutation methods themselves.
- Manual terrain targeting, preview, or placement.

## Files to Change

| File                                                          | Change Size | Purpose                                                                  |
| ------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------ |
| `game/scenes/stages/rewards/wave_reward_choice_generator.gd`  | Small       | Remove the two terrain definitions and their applicability dispatch.     |
| `game/scenes/stages/rewards/wave_reward_effect_definition.gd` | Small       | Remove the two now-unused `Kind` enum members.                           |
| `game/scenes/stages/rewards/wave_reward_applier.gd`           | Small       | Remove the two terrain dispatch arms and their now-dead handler methods. |
| `game/scenes/stages/dash_and_slash_arena.gd`                  | Small       | Add the fixed per-wave terrain mutation, wired into wave-clear handling. |

## Implementation Notes

- Trigger the new mutation after the existing milestone land-expansion grant when both apply in the same wave, so freshly-added tiles from the milestone grant are eligible relocate/remove candidates for that same wave's mutation.
- Reuse the same RNG instance already used for the milestone grant and other automatic terrain calls, rather than introducing a second one.
- The 50/50 split between the two shapes is a first-pass balance choice, not a structural constraint — keep it as an easily-adjustable constant.

## Edge Cases

| Case                                                                                                    | Expected Handling                                                                                                     |
| ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| No valid candidate cells exist for the chosen shape (very small or very fragmented remaining landmass). | The underlying `GridArena` methods already no-op safely; no additional guard is needed at the call site.              |
| A wave clear is also a milestone wave.                                                                  | Run the milestone land-expansion grant first, then the new mutation, so the grant's added tiles are valid candidates. |

## Acceptance Criteria

1. Every normal wave clear mutates terrain exactly once, automatically; neither terrain shape appears as a choosable reward option.
2. On milestone waves, both the periodic expansion and the new mutation occur, in that order.
3. No enum member is left with dispatch logic present in one of the two systems (generator, applier) but missing from the other.
