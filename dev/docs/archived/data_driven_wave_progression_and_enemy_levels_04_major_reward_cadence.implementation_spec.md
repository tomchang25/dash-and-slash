# Data-Driven Wave Progression And Enemy Levels 04: Major Reward Cadence

Parent Plan: `data_driven_wave_progression_and_enemy_levels.md`

## Goal

Move Major reward opportunities from the wave-10 Boss milestone to a predictable every-three-wave cadence. Boss identity and demo completion must remain independent from reward rarity.

## Summary

Completed waves divisible by three—3, 6, 9, 12, and so on—will open the existing three-card Major milestone offer. All other waves, including Boss wave 10, open the normal three-Minor offer.

The offer shape does not change: one Minor x2 baseline plus up to two eligible Majors, with each unavailable Major slot falling back to a distinct Minor x2 choice. The legendary cap and class eligibility continue to apply, and no Curse content or confirmation flow is added or restored.

Reward cadence moves fully into `TickRunController`. `WaveController` continues to identify Boss waves for display and Boss signals but no longer labels Boss presence as a reward milestone or passes that decision through wave-completion signals.

## Relational Context

- `WaveController` owns authored Boss identity, Boss display text, spawning, and completion. It emits the completed wave number but does not decide reward rarity or cadence.
- `TickRunController` owns post-wave presentation and computes Major cadence from the one-based completed wave number. Demo completion at wave 10 remains a separate branch.
- `WaveRewardChoiceGenerator` filters eligible Minor and Major artifacts, while `RunBuild` remains authoritative for owned artifacts, exclusivity, and the four-Legendary cap. This change reuses those contracts unchanged.
- `WaveRewardChoiceController` applies one selected offer and reports completion. No forced confirmation step follows either reward kind.
- Continuing after wave 10 opens that wave's normal Minor offer, then starts wave 11. Wave 12 is the first Endless Major-cadence reward.
- The production artifact registry remains Curse-free. Dormant generic Curse types and presentation support are not a reason to create content or reconnect a run-flow path.

## Scope

### Included

- Every-third-wave Major cadence for demo and Endless play.
- Boss/reward terminology and signal decoupling.
- Focused wave-completion and reward-sequence tests.

### Excluded

- Curse artifacts, Curse offers, forced confirmations, or trade-off design.
- Changes to reward card composition, Major eligibility, legendary cap, artifact effects, or reward RNG.
- Changes to the wave-10 End Run / Continue Endless branch.

## Files to Change

| File                                                    | Change Size | Purpose                                                                             |
| ------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------- |
| `game/tick_arena/wave/wave_controller.gd`               | Medium      | Rename Boss semantics and stop exporting a reward-milestone decision on completion. |
| `game/tick_arena/run/tick_run_controller.gd`            | Medium      | Compute every-third-wave cadence and preserve demo-flow ordering.                   |
| `test/unit/test_wave_controller.gd`                     | Medium      | Separate Boss identity/display coverage from reward cadence.                        |
| `test/unit/test_tick_run_controller_reward_sequence.gd` | Medium      | Cover waves 3, 6, 9, 10, and 12 plus existing offer fallback behavior.              |

## Execution Outline

1. Rename wave-level milestone semantics to Boss semantics and simplify completion signals to carry only the completed wave number.
2. Make the run controller derive Major cadence with an explicit every-three-wave predicate and route wave 10 through the normal reward path after Continue Endless.
3. Update focused tests and comments, then run standards lint and the wave/reward unit suites.

## Implementation Notes

- Use the one-based completed wave number: `wave_number > 0 and wave_number % 3 == 0`. Do not infer cadence from catalog groups, Boss flags, demo completion, or current wave after it advances.
- Keep the existing milestone offer builder and fallback behavior; naming may change from milestone to Major reward where that removes the obsolete Boss association.
- The banner and input lock remain unchanged. Only the offer chosen after the banner/demo branch changes.
- Wave 10 still displays `BOSS`, emits Boss lifecycle signals, marks demo completion, and offers End Run or Continue Endless. Continuing opens a normal Minor offer because 10 is not divisible by three.

## Edge Cases

| Case                                       | Expected Handling                                                              |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| No eligible Major or legendary cap is full | Each unavailable Major slot falls back to a distinct eligible Minor x2 choice. |
| Player selects End Run at wave 10          | The run finalizes without opening any reward, matching current behavior.       |
| Player continues after wave 10             | A normal Minor offer opens, then wave 11 starts after selection.               |
| Wave 12 completes                          | The existing Major milestone offer opens even though the wave has no Boss.     |
| Production Curse pool is empty             | Nothing changes; no empty Curse card or confirmation appears.                  |

## Acceptance Criteria

1. Waves 3, 6, 9, 12, and every later wave divisible by three present the existing Major milestone offer.
2. All other completed waves present the normal Minor offer; continuing after Boss wave 10 specifically presents Minor and then starts wave 11.
3. Boss display, spawning, completion, and demo branching remain correct without serving as reward-cadence inputs.
4. Existing Major eligibility, legendary cap, Minor x2 baseline, per-slot fallback, deterministic reward rolling, and one-choice application behavior remain unchanged.
5. No production Curse content or run-flow confirmation is introduced or restored.
