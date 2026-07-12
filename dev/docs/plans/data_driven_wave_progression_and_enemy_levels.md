# Data-Driven Wave Progression And Enemy Levels

## Goal

Build a designer-authored wave progression that delivers a complete ten-wave demo, then transitions into an optional endless survival mode whose encounter grammar stays fixed while enemy levels and combat stats continue to rise. Replace opaque wave-tier stat bumps and the flat spawn queue with explicit ordered groups, spawn conditions, and one readable enemy-level model.

## Requirements

1. Waves must be authored as ordered groups rather than flattened into one queue so encounter composition, escalation order, and elite or boss entrances are intentional data instead of runtime exceptions.
2. Each group must define its enemy composition and when it may begin relative to the preceding group, including immediate overlap and previous-group-survivor thresholds, because elite and future boss entrances need encounter timing independent of the global population limit.
3. Every spawned enemy must receive a visible integer level derived from the current wave plus an authored group offset, and that level must drive HP, damage, Guard, and Defense through one data-driven progression profile.
4. The existing direct per-wave/tier stat growth must be replaced by level scaling rather than stacked with it, while reward-driven future-enemy pressure remains an explicit modifier after level projection so displayed enemy level retains a stable meaning.
5. Waves 1–10 must form the complete authored demo: waves 1–3 introduce Small enemies, waves 4–6 add Charge enemies, waves 7–9 add Mode enemies, and wave 10 ends with a boss encounter represented initially by a visually distinct Mode-enemy variant.
6. Clearing wave 10 must mark the demo complete and offer `End Run` or `Continue Endless`; continuing enters wave 11 without revoking or duplicating the completion result.
7. Wave 11 onward must reuse a fixed authored endless encounter grammar and increase pressure only through enemy level and its four scaled stats; it must not introduce new enemy kinds, groups, spawn overlap, population growth, or other hidden encounter-complexity escalation.
8. Balance must make wave 10 a fair official completion target, waves 11–19 a mastery extension, and wave 20 onward intentionally lethal territory where the simulation remains valid but ordinary mistakes can end a run rapidly.

## Design

### Wave and group grammar

A wave owns an ordered list of groups and a concurrent-population safety cap. The cap protects board readability but does not define encounter order. A group owns an enemy composition, count or weighted composition entries, a level offset, and one start condition relative to the immediately preceding group.

The initial start-condition vocabulary is deliberately small:

| Condition                          | Behavior                                                                                  |
| ---------------------------------- | ----------------------------------------------------------------------------------------- |
| Previous group cleared             | Start only when no living enemy from the preceding group remains.                         |
| Previous group survivors at most N | Start once the preceding group has N or fewer living enemies.                             |
| Immediate overlap                  | Become eligible with the preceding group, still respecting available population headroom. |

Once a group becomes eligible, its members may enter through warning batches as population headroom becomes available. Later groups cannot bypass an earlier ineligible group. Enemies remain associated with their source group until death so survivor thresholds are based on group membership rather than total enemies alive.

### Enemy level and stat projection

The normal enemy level is the one-based wave number. A group may add a non-negative level offset for an elite, boss, or deliberately stronger reinforcement. The displayed level is the final wave level plus this offset; hidden stat-only level bonuses are not allowed.

Each enemy kind supplies Level 1 base HP, attack damage, Guard, and Defense. One authored progression profile converts level into four independent outputs. HP, damage, and Guard use multipliers over their base values; Defense uses a flat projected value because combat already applies Defense through nonlinear damage reduction.

Each output uses a continuous piecewise growth shape with breakpoints after demo completion and at the lethal threshold:

```text
progress(level) = base_growth(level - 1)
                + endless_growth(max(level - 10, 0))
                + lethal_growth(max(level - 20, 0))
```

Every term has independently authored coefficients and exponent per stat. This keeps the formula data-driven while making the three balance regions explicit. Guard is rounded to an integer after projection. Damage receives the strongest endless and lethal acceleration; HP and Guard rise enough to preserve combat pressure without turning late waves into pure attrition; Defense grows most conservatively so high-level enemies remain damageable and the endless failure mode is lethality rather than a soft lock.

Reward-driven enemy-health, enemy-damage, and enemy-defense pressure applies after level projection. Enemy-count pressure may add members only within the currently eligible group and never unlock a later group or raise the population safety cap.

### Demo progression

| Waves | Encounter purpose                                                                                                                                                                                                                 |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1–3   | Teach baseline movement, facing, telegraphs, Guard, and Small-enemy pattern recognition.                                                                                                                                          |
| 4–6   | Add Charge enemies as later or overlapping groups so committed line pressure enters after the baseline grammar is understood.                                                                                                     |
| 7–9   | Add Mode enemies in controlled groups, combining earlier threats without exceeding the readability cap.                                                                                                                           |
| 10    | Deliver the demo boss encounter. The first version uses a separately authored, visually distinct Mode-enemy variant with boss-level offset and boss group timing so a future real boss can replace it without changing wave flow. |

Clearing wave 10 records demo completion before presenting the branch. `End Run` closes the run through the normal results flow. `Continue Endless` preserves the current build and starts wave 11.

### Endless progression

Wave 11 and later use one fixed endless wave template derived from the complete demo enemy roster. Its group order, group conditions, enemy composition, counts, warning timing, and population cap do not change by wave. Only the base wave level advances, plus any fixed group level offsets already present in the template.

The target experience is:

| Region      | Balance contract                                                                                         |
| ----------- | -------------------------------------------------------------------------------------------------------- |
| Waves 1–9   | Learnable authored escalation with enough recovery margin to reach the demo finale.                      |
| Wave 10     | Fair build check and official demo completion point.                                                     |
| Waves 11–19 | Optional mastery extension; increasingly unforgiving but still deliberately playable.                    |
| Wave 20+    | Lethal overtime; continued play is supported, but a missed read or bad position may end the run quickly. |

### Child overview

| Child | Focus                                                                           | Current document                                                                               |
| ----- | ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| 01    | Wave, group, spawn-condition, and enemy-level data model                        | `data_driven_wave_progression_and_enemy_levels_01_progression_data_model.sketch.md`            |
| 02    | Ordered-group runtime, level application, demo completion, and boss placeholder | `data_driven_wave_progression_and_enemy_levels_02_group_runtime_and_demo_completion.sketch.md` |
| 03    | Authored demo encounters, fixed endless template, and balance curve             | `data_driven_wave_progression_and_enemy_levels_03_demo_and_endless_balance.sketch.md`          |

Recommended landing order: establish the data and level projection contract first; migrate runtime spawning and the wave-10 completion branch second; author and playtest the complete demo and endless curve only after both seams are stable.

## Non-Goals

1. Do not implement the final bespoke boss; the distinct Mode-enemy variant is the wave-10 placeholder.
2. Do not add new enemy kinds beyond the existing Small, Charge, and Mode roster.
3. Do not add post-demo encounter mechanics, larger population caps, new group conditions, or procedural group generation.
4. Do not copy another game's exact scaling constants or formulas; the survival-mode reference informs the escalating-level concept, not its numerical implementation.
5. Do not balance unrelated player rewards or fix the separate gameplay and audio chores as part of this plan.

## Acceptance Criteria

1. Designers can change wave composition, group order, group overlap thresholds, level offsets, population caps, and all four level curves without changing runtime logic.
2. Groups enter strictly in authored order, respect their predecessor-survivor condition and population headroom, and complete the wave only after every authored group and living member is cleared.
3. Enemy level is visible and consistently projects HP, damage, Guard, and Defense from Level 1 base stats; no legacy wave-tier stat bonus is also applied.
4. Waves 1–10 follow the authored roster progression and wave 10 ends with the visually distinct boss placeholder.
5. Clearing wave 10 records `Demo Complete` exactly once and offers functional `End Run` and `Continue Endless` choices.
6. Continuing uses the fixed endless encounter grammar for every later wave; comparing two endless waves shows only level-derived numerical pressure changing unless an explicit reward modifier is active.
7. Playtest results support wave 10 as a fair completion target, waves 11–19 as increasingly unforgiving mastery play, and wave 20 onward as valid but intentionally high-lethality overtime.
