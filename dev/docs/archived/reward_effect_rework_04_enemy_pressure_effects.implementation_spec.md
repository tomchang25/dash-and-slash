# Reward Effect Rework — Enemy Pressure Effects

## Goal

Backfill the reward pool slot vacated by removing terrain mutation (Phase 2) with new enemy-toughness pressure effects — health, damage, and defense — added as new effect objects on the Phase 3 architecture, backed by permanent `RunBuild` channels that `WaveController` reads. Depends on Phase 3, since these are authored as effect subclasses recording to the shared store, not switch arms.

## Relational Context

- Each new pressure effect is one more subclass in the Phase 3 effect hierarchy: it carries its balance metadata (point cost, per-stack magnitude, allowed profiles, min wave), an `is_applicable(context)` that is always true (no grid/player dependency), and an `apply(context, stacks)` that records to a `RunBuild` channel — the same shape the future-enemy-count effect already uses after Phase 3. Adding these touches no switch — that is the payoff of Phase 3 landing first.
- Enemy-toughness pressure is run-scoped modifier state living in `RunBuild` (`game/scenes/stages/run_build.gd`) as three new channels, exactly like the future-enemy-count channel Phase 3 established — not a player stat and not owned by `WaveController`. Per `dev/foundation/core/standards/runtime_ownership.md` §3, `RunBuild` is the single owner of applied-effect contributions and `WaveController` is a reader. No behavior-changing effect ever touches enemy stats, so this side needs no cap/conflict machinery — a plain monotonic channel sum is correct.
- `WaveController._apply_wave_scaling()` (`game/scenes/stages/waves/wave_controller.gd`) applies `WaveScaling`'s formula-driven baseline (HP/damage/defense by wave tier) to every spawned enemy. The new pressure bonuses are read from the three `RunBuild` channels and added on top of that formula's output at that same call site, and persist for the rest of the run because the store entries persist — matching how future-enemy-count pressure already persists. `WaveScaling` (`wave_scaling.gd`) stays a stateless static-formula class; do not add mutable state there.
- The pressure effects reach the store through the Phase 3 `WaveRewardContext`, which already carries `run_build`; this phase adds no new owner to the context and no new callback. `WaveController` already holds an injected `RunBuild` reference from Phase 3, so it only adds the two extra channel reads.
- Health and damage magnitudes are authored as percents in the effect's balance data; `WaveScaling`'s multipliers and `WaveController`'s reads expect fractional bonuses. The percent-to-fraction conversion belongs in the effect's `apply` before it records to the channel, not in `WaveController`, so the channel value stays unit-consistent with the formulas it feeds. Defense magnitude is authored flat, matching the defense formula's flat convention, and is recorded unconverted.

## Scope

### Included

- Three new effect subclasses (health, damage, defense), each a pure permanent-pressure downside available in the same risk tiers terrain used to occupy.
- Three new `RunBuild` channels for enemy hp/damage/defense pressure, read in `WaveController._apply_wave_scaling()` on top of `WaveScaling`'s formulas.

### Excluded

- Any change to `WaveScaling`'s tier formulas.
- Any change to the existing future-enemy-count effect or its channel.
- Any change to `RunBuild`'s core store shape or the `WaveRewardContext` — both are complete from Phase 3; this phase only adds channel constants and effect subclasses.
- Reading enemy-toughness pressure into any player-stat getter — these channels are read only by `WaveController`.

## Files to Change

| File                                                                  | Change Size | Purpose                                                                                                        |
| --------------------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------- |
| New effect subclass files under `game/scenes/stages/rewards/effects/` | Small       | Three enemy-pressure effect classes, each recording a percent/flat value to its `RunBuild` channel.            |
| `game/scenes/stages/rewards/wave_reward_choice_generator.gd`          | Small       | Add the three to the authored pool with their balance numbers and profile restriction.                         |
| `game/scenes/stages/run_build.gd`                                     | Small       | Add the three enemy-pressure channel-name constants.                                                           |
| `game/scenes/stages/waves/wave_controller.gd`                         | Small       | Read the three channels in `_apply_wave_scaling()` and add them on top of the `WaveScaling` output.            |
| `test/unit/test_wave_controller.gd`                                   | Small       | Coverage that a recorded pressure channel raises the scaled enemy stat, mirroring the future-enemy-count test. |

## Implementation Notes

- Three independent effects, not one compound effect: every effect maps to a single scalar magnitude; a compound one would need a vector magnitude that breaks the point-budget math.
- Restrict the three to the same risk tiers the removed terrain downside occupied; the lowest-risk tier offers no pure-downside pressure.
- Point cost and per-stack magnitude are first-pass balance numbers, not locked. Flagged explicitly: giving these the same point cost as the future-enemy-count effect is very likely mis-tuned, because "+X% health across the whole wave" and "one more enemy" are not equal-impact trades. Calibrate with eyes open against the point-budget upside/downside thresholds; treat parity with the enemy-count cost as a starting guess to be corrected in playtest, not a default to accept.

## Edge Cases

| Case                                       | Expected Handling                                                                                    |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| A negative or zero pressure total is read. | `WaveController` clamps the read to zero, matching the future-enemy-count channel read.              |
| A run resets.                              | A fresh `RunBuild` (new scene per run) zeroes all channels, matching the future-enemy-count channel. |

## Acceptance Criteria

1. All three enemy-toughness dimensions can appear as reward options in the risk tiers that previously offered terrain downside, and not in the lowest-risk tier.
2. Picking one permanently raises that dimension for every enemy spawned for the rest of the run, on top of the existing wave-tier formula.
3. The existing future-enemy-count effect's behavior is unchanged.
