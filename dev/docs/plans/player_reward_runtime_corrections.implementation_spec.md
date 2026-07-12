# Player Reward Runtime Corrections

Parent Plan: none (standalone spec)

## Goal

Correct Chain Dash and Max Health rewards so they update the player-owned runtime state their descriptions imply. Chain Dash should prepare the existing Speed free-action state and remove Dash cooldown instead of directly refunding the triggering Dash, while Max Health should immediately heal by the amount of maximum HP gained.

## Summary

- A qualifying Chain Dash still uses the existing back-hit, guard-break, staggered-target, or kill conditions. The triggering Dash now advances the world normally, clears Dash cooldown, and fills the existing Speed meter; the next eligible move or normal attack spends that meter and becomes free.
- A Max Health contribution immediately adds the same positive amount to current HP, clamped to the newly projected maximum. A `+20` pick therefore grants `+20` current HP rather than healing to full.
- Player state stays owned by the player. The run-build store reports contribution changes, and the run controller coordinates Max Health projection without putting a player reference into generic artifact effects or the store.

## Requirements

1. A qualifying Chain Dash must clear Dash cooldown and fill the existing Speed meter because its reward is a prepared follow-up plus immediate Dash availability, not a direct world-time refund.
2. The Dash that triggers Chain Dash must advance the world normally; only the later eligible move or normal attack becomes free when it spends the full Speed meter.
3. Multiple qualifying victims in one Dash must apply the Chain Dash state change once, while the existing qualifier set remains unchanged.
4. A positive Max Health contribution must increase current HP by exactly that contribution and clamp at the newly projected maximum, so stacked or double-stack rewards grant their full authored amount without becoming a full heal.
5. Non-Max-Health channels and rejected artifact acquisitions must not change current HP.

## Relational Context

- `RunBuild` remains the authority for accumulated reward-channel contributions and trigger ownership. It may publish a contribution-recorded signal, but it must not hold or mutate `TickPlayer`.
- `TickRunController` owns the relationship between the shared run-build store and the scene's player. It connects once to contribution notifications and forwards positive Max Health gains to the player owner.
- `TickPlayer` remains the sole owner of current HP, cooldown fields, and Speed-meter state. New public operations should express “prepare Speed free action” and “apply Max Health gain” rather than letting controllers assign those fields ad hoc.
- `TickActionController` remains the authority for committed verb timing. It evaluates the existing typed Dash outcomes once, applies Chain Dash state after the Dash resolves, and returns a normal world-advancing result for the triggering Dash.
- `TickHitResolver` remains the sole authority for whether an outcome qualifies. Its back, guard-break, staggered, kill, and multi-victim folding behavior does not change; only consumers and refund-oriented naming/comments change.
- Speed eligibility remains unchanged: only movement and normal attack spend a full meter. Wait, Dash, and Smash do not consume the prepared free action.
- Reward application remains data-driven through channel effects. Do not special-case the Vital Spark artifact ID or add player mutation to `ArtifactEffect`.

## Scope

### Included

- Chain Dash timing, cooldown, Speed-meter state, content description, comments, and focused tests.
- Max Health contribution notification, immediate HP gain, clamping, and focused tests.

### Excluded

- New Chain Dash qualifiers, preview labels, VFX, or SFX.
- Changing which actions can spend Speed.
- Negative Max Health effects or a general healing reward system.
- Other reward balance changes.

## Files to Change

| File                                               | Change Size | Purpose                                                                                       |
| -------------------------------------------------- | ----------- | --------------------------------------------------------------------------------------------- |
| `game/tick_arena/player/tick_player.gd`            | Medium      | Own the explicit Speed-ready and Max-Health-gain mutations.                                   |
| `game/tick_arena/combat/tick_action_controller.gd` | Medium      | Replace Chain Dash world refund with cooldown clear plus Speed readiness.                     |
| `game/tick_arena/combat/tick_combat_projection.gd` | Small       | Update Chain Dash semantics documentation while preserving the trigger read.                  |
| `game/tick_arena/combat/tick_hit_resolver.gd`      | Small       | Rename refund-oriented qualifier documentation/helpers if needed without changing conditions. |
| `game/tick_arena/run/run_build.gd`                 | Small       | Publish accepted channel contribution changes without gaining player ownership.               |
| `game/tick_arena/run/tick_run_controller.gd`       | Small       | Observe positive Max Health contributions and forward them to the player.                     |
| `game/tick_arena/wave/wave_controller.gd`          | Small       | Remove stale documentation that treats Chain Dash as a direct world refund.                   |
| `data/rewards/artifacts/chain_dash.tres`           | Small       | Describe prepared Speed and cleared Dash cooldown instead of skipped world time.              |
| `test/unit/test_tick_action_controller_verbs.gd`   | Medium      | Cover the new Chain Dash timing and state transition.                                         |
| `test/unit/test_tick_hit_resolver_chain_dash.gd`   | Small       | Preserve qualifier and one-trigger folding coverage under updated terminology.                |
| `test/unit/test_tick_player_max_health.gd`         | Medium      | Cover exact HP gain and clamping at the projected maximum.                                    |
| `test/unit/test_run_build_reward_channels.gd`      | Small       | Cover contribution notification payloads and channel isolation.                               |

## Execution Outline

1. Add player-owned operations for filling Speed to ready and applying a positive Max Health gain against the projected post-contribution maximum, with focused player tests.
2. Add a run-build contribution notification and wire the run controller's Max Health-only response, then cover positive, stacked, non-Max-Health, and capped-heal behavior.
3. Change committed Dash resolution so one qualifying result clears cooldown and prepares Speed while the Dash still advances the world; update action and qualifier tests.
4. Update Chain Dash content text and stale refund comments, then run focused reward/action tests and standards lint.

## Implementation Notes

- Chain Dash state applies after the normal Dash cooldown is projected, so a qualifying Dash leaves cooldown at zero. Filling an already full Speed meter is idempotent.
- The triggering Dash must return `advances_world = true` whether it qualifies or not. Do not preserve a second hidden refund alongside the filled meter.
- A full meter survives further Dash, Smash, or Wait actions because those actions are not Speed-eligible today; the next legal move or normal attack consumes it through the existing spend path.
- The run-build notification should include channel, accepted delta, and resulting channel total. Emit only after the contribution is recorded.
- Max Health handling uses the positive recorded delta, not the artifact's display magnitude, so a two-stack pick that records `+40` heals `40` once. Clamp current HP against the maximum projected from the resulting total.
- Clearing the run build during reset must not heal; the subsequent player reset already restores base run state.

## Edge Cases

| Case                                  | Expected Handling                                           |
| ------------------------------------- | ----------------------------------------------------------- |
| Several Dash victims qualify          | Cooldown clears and Speed fills once.                       |
| Chain Dash trigger is inactive        | Dash sets its normal cooldown and timing remains unchanged. |
| Speed is already full                 | It stays full; no additional token is created.              |
| Max Health is gained while damaged    | Current HP increases by exactly the positive gain.          |
| Max Health is gained near the new cap | Current HP clamps to the new projected maximum.             |
| A reward acquisition is rejected      | No contribution notification or HP gain occurs.             |

## Acceptance Criteria

1. A qualifying Dash advances enemy/world clocks once, ends with zero Dash cooldown, and leaves the Speed meter visibly ready.
2. The next eligible move or normal attack spends that meter and skips world advancement exactly once.
3. Chain Dash qualification remains back hit, guard break, staggered target, or kill, with one state application per Dash.
4. Each positive Max Health gain adds the same amount to current HP without exceeding the newly projected maximum.
5. Other reward channels and run reset preserve existing behavior.
