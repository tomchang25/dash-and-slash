# Tick Combat Rework 06c: Run-Build Tick Reward Channels

## Goal

Move remaining legacy player-stat reward effects onto run-build channels and add tick-side readers. This keeps reward content alive in the tick arena without merging the tick player with the legacy real-time player.

## Relational Context

- `RunBuild` already owns run-scoped contribution channels for Speed, Mobility Cooldown, future enemy count, enemy toughness, Major capacity, mobility payload override, and mobility triggers.
- Several reward effects still inherit `PlayerStatEffect`, which requires `WaveRewardContext.player` and calls legacy real-time player stat methods; those effects are filtered out in the tick arena because the tick reward context passes no legacy player.
- `TickArena` currently owns base normal attack, dash damage, smash damage, dash range, and smash range constants; after this spec, it or the action controller projects final combat values from `RunBuild`.
- `TickPlayer` owns runtime hp and max-health-like truth in the tick arena; max health rewards should project or apply through the tick player owner rather than through the legacy health component API.
- `WaveRewardContext` should stop treating a legacy `Player` as the gate for rewards that are valid in the tick arena; tick-compatible effects should depend on `run_build` or a tick player context instead.
- Attack Range is removed from the tick reward pool in this phase. The tick normal attack is currently an adjacent-cell verb, and extending its geometry belongs with future weapon/attack-shape work rather than this run-loop conversion.
- Dash-named damage and range rewards become mobility-slot rewards conceptually: the player-facing copy may be cleaned up later, but the run-build channels and tick readers should use mobility wording because Dash and Smash both occupy the slot.
- Legacy arena compatibility is not a goal once this branch is in the tick conversion path; do not preserve old real-time reward application by duplicating effect implementations.

## Scope

### Included

- Run-build channels for normal attack damage, mobility attack damage, mobility range, and max health.
- Tick-side projection readers for those channels.
- Reward offer/apply eligibility updates so tick-compatible rewards appear in the tick arena.
- Removal of Attack Range from the tick reward pool.

### Excluded

- New reward cards or rarity systems.
- Final HUD build summary.
- Legacy player merge.

## Files to Change

| File                                                                            | Change Size | Purpose                                                                  |
| ------------------------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------ |
| `game/scenes/stages/run_build.gd`                                               | Medium      | Add tick-compatible player reward channels.                              |
| `game/scenes/stages/rewards/wave_reward_context.gd`                             | Medium      | Remove or reduce legacy player dependency for tick-compatible rewards.   |
| `game/scenes/stages/rewards/effects/player_stat_effect.gd`                      | Medium      | Retire, narrow, or replace the legacy player-stat base.                  |
| `game/scenes/stages/rewards/effects/*damage*_effect.gd`                         | Medium      | Record damage contributions to run build.                                |
| `game/scenes/stages/rewards/effects/dash_range_effect.gd`                       | Medium      | Convert dash range contribution into a mobility range run-build channel. |
| `game/scenes/stages/rewards/effects/attack_range_effect.gd`                     | Small       | Remove from tick reward generation or retire if no longer used.          |
| `game/scenes/stages/rewards/effects/max_health_effect.gd`                       | Medium      | Apply through tick-compatible max-health ownership.                      |
| `game/scenes/stages/tick_arena/tick_action_controller.gd` or current arena root | Medium      | Read final damage and range projections.                                 |
| `game/scenes/stages/tick_arena/tick_player.gd`                                  | Medium      | Own max-health projection/application if kept.                           |
| `test/unit/*`                                                                   | Medium      | Cover channel recording and tick-side projections.                       |

## Implementation Notes

Do not add passthrough methods to `TickPlayer` solely to mimic legacy `Player`. Add tick-native projection methods only where the tick player owns the state.

Damage and range readers should apply clamps at the consumer, matching the existing run-build pattern where the store records contributions but does not own base values.

Dash attack damage and dash range should become mobility attack damage and mobility range at the run-build/channel layer. Smash reads those same mobility-slot projections with its own base values and clamps.

Attack Range should not be remapped in this spec. Remove it from default tick reward generation so the reward pool does not offer a stat with no honest tick-side meaning.

## Edge Cases

| Case                                                | Expected Handling                                           |
| --------------------------------------------------- | ----------------------------------------------------------- |
| A reward total would reduce a value below its floor | The tick-side reader clamps the final projected value.      |
| A reward is rolled with no legacy player in context | Tick-compatible effects still offer and apply.              |
| Attack Range would be rolled                        | It is excluded from the tick reward pool.                   |
| A legacy-only effect remains                        | It must be explicitly excluded from tick reward generation. |

## Acceptance Criteria

1. Tick-compatible Minor rewards offer and apply in the tick arena without a legacy player object.
2. Normal attack damage, mobility damage, mobility range, and max health rewards change tick-arena behavior through run-build projections.
3. Reward effects no longer require merging `TickPlayer` with the legacy player.
