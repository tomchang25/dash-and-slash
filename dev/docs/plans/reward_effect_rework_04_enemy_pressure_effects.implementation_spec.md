# Reward Effect Rework — Enemy Pressure Effects

## Goal

Backfill the reward pool slot vacated by removing terrain mutation (Phase 2) with new enemy-toughness pressure effects — health, damage, and defense — added as new effect objects on the Phase 3 architecture, backed by permanent wave/run accumulators. Depends on Phase 3, since these are authored as effect subclasses, not switch arms.

## Relational Context

- Each new pressure effect is one more subclass in the Phase 3 effect hierarchy: it carries its balance metadata (point cost, per-stack magnitude, allowed profiles, min wave), an `is_applicable(context)` that is always true (no grid/player dependency), and an `apply(context, stacks)` that mutates the wave/run owner. Adding these touches no switch — that is the payoff of Phase 3 landing first.
- Enemy-toughness pressure is wave/run-progression state, owned by `WaveController` (`game/scenes/stages/waves/wave_controller.gd`), not by the player and not by the applied-effect store's stat projection — per `dev/standards/runtime_ownership.md`, this is the same category as the existing future-enemy-count pressure (`_future_enemy_count_modifier` / `add_future_enemy_count()`), so it lives on the same owner as a permanent accumulator. No behavior-changing effect ever touches enemy stats, so this side needs no cap/conflict/projection machinery — a plain monotonic accumulator is correct.
- `WaveController._apply_wave_scaling()` applies `WaveScaling`'s formula-driven baseline (HP/damage/defense by wave tier) to every spawned enemy. The new pressure bonuses are additive on top of that formula's output, evaluated at that same call site, and persist for the rest of the run once picked — matching how future-enemy-count pressure already persists. `WaveScaling` (`wave_scaling.gd`) stays a stateless static-formula class; do not add mutable state there.
- The pressure effects reach `WaveController` through the Phase 3 context bundle, which must therefore carry the wave/run owner. In the current pre-Phase-3 code the applier reaches wave/run state only through a single-purpose callback supplied by `DashAndSlashArena` (`dash_and_slash_arena.gd`); Phase 3 replaces that with the context bundle, so this phase adds the wave/run owner to that bundle rather than adding more callbacks.
- Health and damage magnitudes are authored as percents in the effect's balance data; `WaveScaling`'s multipliers and `WaveController`'s accumulators expect fractional bonuses. The percent-to-fraction conversion belongs in the effect's `apply`, not in `WaveController`, so the accumulator API stays unit-consistent with the formulas it feeds. Defense magnitude is authored flat, matching the defense formula's flat convention, and passes through unconverted.

## Scope

### Included

- Three new effect subclasses (health, damage, defense), each a pure permanent-pressure downside available in the same risk tiers terrain used to occupy.
- Three new permanent accumulators on `WaveController`, layered on top of `WaveScaling`'s formulas, with their adders and reset.
- Adding the wave/run owner to the Phase 3 context bundle.

### Excluded

- Any change to `WaveScaling`'s tier formulas.
- Any change to the existing future-enemy-count effect or its accumulator.
- Routing enemy-toughness pressure through the player-stat projection.

## Files to Change

| File                                                                   | Change Size | Purpose                                                                                        |
| ---------------------------------------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------- |
| New effect subclass files under `game/scenes/stages/rewards/effects/`  | Small       | Three enemy-pressure effect classes.                                                           |
| `game/scenes/stages/rewards/wave_reward_choice_generator.gd`           | Small       | Add the three to the authored pool with their balance numbers and profile restriction.         |
| `game/scenes/stages/waves/wave_controller.gd`                          | Small       | Three permanent accumulators, their adders, their use in `_apply_wave_scaling()`, their reset. |
| `game/scenes/stages/rewards/wave_reward_applier.gd` / context assembly | Small       | Ensure the context bundle carries the wave/run owner.                                          |
| `test/unit/test_wave_controller.gd`                                    | Small       | Accumulate, negative-clamp, and reset coverage mirroring the future-enemy-count tests.         |

## Implementation Notes

- Three independent effects, not one compound effect: every effect maps to a single scalar magnitude; a compound one would need a vector magnitude that breaks the point-budget math.
- Restrict the three to the same risk tiers the removed terrain downside occupied; the lowest-risk tier offers no pure-downside pressure.
- Point cost and per-stack magnitude are first-pass balance numbers, not locked. Flagged explicitly: giving these the same point cost as the future-enemy-count effect is very likely mis-tuned, because "+X% health across the whole wave" and "one more enemy" are not equal-impact trades. Calibrate with eyes open against the point-budget upside/downside thresholds; treat parity with the enemy-count cost as a starting guess to be corrected in playtest, not a default to accept.

## Edge Cases

| Case                                                 | Expected Handling                                                                  |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------- |
| A negative or zero magnitude reaches an accumulator. | Clamped to zero, matching the future-enemy-count accumulator.                      |
| A run resets.                                        | All three accumulators reset to zero, matching the future-enemy-count accumulator. |

## Acceptance Criteria

1. All three enemy-toughness dimensions can appear as reward options in the risk tiers that previously offered terrain downside, and not in the lowest-risk tier.
2. Picking one permanently raises that dimension for every enemy spawned for the rest of the run, on top of the existing wave-tier formula.
3. The existing future-enemy-count effect's behavior is unchanged.
