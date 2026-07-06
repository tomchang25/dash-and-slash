# Tick Combat Rework 05: Speed Stats

## Goal

Replace the earlier three-speed-stat sketch with a tighter tick-world speed layer: one general Speed Minor shared by movement and normal attacks, one Mobility Cooldown Minor for the mobility slot, and one conditional Mobility Free Action Major. The change keeps player timing visible and auditable: fast actions are explicit meter spends or earned refunds, never hidden fractional action costs.

## Relational Context

- `RunBuild` remains the run-scoped projection store. Numeric Speed and Mobility Cooldown rewards record channels there; consumers apply their own base values, caps, and floors when reading totals.
- `TickPlayer` owns the runtime Speed meter because the meter is player state, not reward-store state. `RunBuild` only answers how fast eligible actions fill it.
- The Speed meter is shared by move and normal attack only. Wait and mobility actions neither fill nor spend the meter.
- A full Speed meter makes the next eligible move or normal attack cost no world time, then spends the meter. If the player uses wait or mobility while the meter is full, the charge remains banked.
- Phase 05 must ship a minimal Speed meter truth display because meter state changes whether the next eligible action advances enemy time. This can be text or simple pips in the existing HUD; final HUD styling and applied-effect tables are phase 07 work.
- Windup reduction is out of scope for this phase. Smash is currently the only player windup and its windup is 1 tick, so reducing windup would erase the payload trade before there is enough windup-bearing content.
- `TickArena` owns the player verb contract. The current bool return (`consumed`) becomes a small action result that says whether the verb was consumed and whether the world should advance.
- `TickEngine` does not know about Speed, rewards, or free-action perks. It still advances the world only when `TickArena` calls it.
- Mobility Cooldown applies to whichever payload occupies the mobility slot. Dash and Smash keep separate base cooldowns but read the same RunBuild reduction and share a floor of 1 tick.
- The Mobility Free Action Major is a Major, not a stackable Minor. It registers through the existing MajorEffect/RunBuild cap and activates a payload-agnostic mobility trigger.
- Mobility free action is an immediate refund for the current mobility strike, not a token for a later verb. A mobility action that hits multiple targets can refund at most once.
- The refund condition is read from the same committed hit outcomes used for preview honesty: any mobility-slot strike that produces a kill, guard break, or back-angle hit makes that mobility action skip world advancement.
- Smash windup arming has no attack outcome and cannot refund. Smash release can refund if its resolved hits meet the Major condition.

## Scope

### Included

- General Speed meter, Speed Minor reward, and a minimal HUD/readability display showing current meter progress and whether the next eligible move or normal attack is free.
- Mobility Cooldown Minor projected through RunBuild and applied to Dash and Smash cooldown setting.
- Mobility Free Action Major, reward definition, trigger storage, committed-action refund handling, and tests.
- Updating phase, plan, and v0.5 GDD text to match the new speed model.

### Excluded

- Windup reduction rewards.
- Enemy speed changes or enemy double-action presentation.
- New mobility payloads beyond Dash and Smash.
- Final HUD art, the full phase 07 HUD refactor, or a persistent applied-effect stats table.

## Files to Change

| File                                                                    | Change Size | Purpose                                                                                                                                                                                                     |
| ----------------------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `game/scenes/stages/run_build.gd`                                       | Medium      | Add Speed and Mobility Cooldown channels plus the Mobility Free Action trigger flag.                                                                                                                        |
| `game/scenes/stages/tick_arena/tick_player.gd`                          | Medium      | Own Speed meter state, eligible-action fill/spend helpers, reset behavior, and HUD-readable state.                                                                                                          |
| `game/scenes/stages/tick_arena/tick_arena.gd`                           | Large       | Replace bool verb results with action results, apply Speed spends/fills for move/normal attack, project mobility cooldowns, refund qualifying mobility strikes, and surface minimal meter truth in the HUD. |
| `game/scenes/stages/rewards/wave_reward_choice_generator.gd`            | Medium      | Replace legacy cooldown/speed offerings for the tick arena with Speed, Mobility Cooldown, and Mobility Free Action definitions.                                                                             |
| `game/scenes/stages/rewards/effects/*`                                  | Medium      | Add RunBuild-backed Speed and Mobility Cooldown Minor effects plus the Mobility Free Action Major effect.                                                                                                   |
| `test/unit/*`                                                           | Medium      | Cover RunBuild channels/triggers, Speed meter fill/spend rules, mobility cooldown projection, and one-refund-per-mobility-action behavior.                                                                  |
| `dash_and_slash_gdd_v0_5.md` and `dev/docs/plans/tick_combat_rework.md` | Small       | Sync design truth and phase summary with the new model.                                                                                                                                                     |

## Implementation Notes

Use a shared helper shape for verb results, for example `{ "consumed": true, "advances_world": true }`. Illegal inputs stay consumed false. Free actions are consumed true and advances_world false.

Initial Speed tuning can keep the old phase-05 curve unless playtest rejects it: +10 meter per Speed stack per eligible action, capped at 50 per action, base 0. Spend happens before resolving the eligible action if the meter is full; fill happens after resolving an eligible action, including a free eligible action.

The first HUD pass should be deliberately plain and truthful: show numeric meter progress or stable pips, plus a clear ready state such as `NEXT MOVE/ATTACK FREE`. A short message or flash when a Speed spend or Mobility Free Action refund occurs is enough for feedback; do not build the phase 07 HUD refactor or final buff table here.

Mobility strike loops should collect outcomes from `_apply_player_hit()` instead of losing them. The helper can return the resolver result it already receives, allowing Dash and Smash to set a local `mobility_refunds_world_advance` flag once without duplicating hit math.

Preview does not need to predict whether the Mobility Free Action Major will refund enemy time unless the Major is active and the targeted mobility outcomes already show kill, break, or back-angle labels. The committed result remains authoritative, but visible labels must not contradict it.

## Edge Cases

| Case                                            | Expected Handling                                                                                            |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Speed meter full, player waits or uses mobility | Charge remains full and the action advances world normally unless mobility itself refunds through the Major. |
| Speed meter full, move/normal attack is illegal | Charge remains full; illegal input consumes no action.                                                       |
| Mobility action hits several qualifying targets | The current action refunds once.                                                                             |
| Smash is armed                                  | Windup arming never refunds; release may refund.                                                             |
| Mobility action refunds                         | The payload cooldown is still set, but no world tick passes and cooldowns do not tick down immediately.      |

## Acceptance Criteria

1. Speed stacks visibly increase the fill rate for one shared meter, and only move or normal attack can fill or spend it.
2. A full Speed meter makes exactly one eligible move or normal attack skip world advancement without changing any displayed enemy danger outcome.
3. The HUD always shows whether the next eligible move or normal attack is free; waiting or using mobility while full leaves that display ready.
4. Mobility Cooldown stacks reduce Dash and Smash cooldowns through the same stat, floored at 1 tick.
5. The Mobility Free Action Major makes a qualifying mobility strike skip world advancement once per mobility action, including consecutive qualifying actions.
6. Wait, empty mobility actions, and Smash windup arming do not fill Speed and do not refund time.
