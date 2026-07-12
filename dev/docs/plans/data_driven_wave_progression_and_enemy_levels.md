# Data-Driven Wave Progression And Enemy Levels

## Goal

Build a designer-authored wave progression that delivers a complete ten-wave demo, then transitions into an optional endless survival mode whose encounter grammar stays fixed while enemy levels and combat stats continue to rise. Replace opaque wave formulas, the flat spawn queue, and duplicate enemy-stat authorities with explicit ordered groups and one readable enemy-level model.

## Requirements

1. Waves must be authored as ordered groups rather than flattened into one queue so encounter composition, escalation order, and elite or boss entrances are intentional data instead of runtime exceptions.
2. Each group must define its enemy composition and when it may begin relative to the preceding group, including immediate overlap and previous-group-survivor thresholds, because elite and future boss entrances need encounter timing independent of the global population limit.
3. Each enemy must own one authored Level 1 data graph for HP, Guard, Defense, and attack profiles; combat components consume those values as runtime state instead of remaining competing tuning authorities.
4. Every spawned enemy must receive a visible integer level equal to the current one-based wave plus an authored non-negative group offset, and that level must drive HP, damage, Guard, and Defense through one data-driven progression profile.
5. Enemy level must be the only numeric enemy-strength progression: remove the legacy wave-tier scaling and all four enemy-pressure curses, channels, and forced single-curse confirmation rather than stacking hidden modifiers onto displayed level.
6. Waves 1–10 must form the complete authored demo: waves 1–3 introduce Small enemies, waves 4–6 add Charge enemies, waves 7–9 add Mode enemies, and wave 10 ends with a boss encounter represented initially by a visually distinct Mode-enemy variant.
7. Clearing wave 10 must mark the demo complete and offer `End Run` or `Continue Endless`; continuing enters wave 11 without revoking or duplicating the completion result.
8. Wave 11 onward must reuse one fixed authored endless encounter grammar and increase pressure only through the advancing enemy level; it must not introduce new enemy kinds, groups, counts, spawn overlap, population growth, curses, or other hidden escalation.
9. Balance must make wave 10 a fair official completion target, waves 11–19 a mastery extension, and wave 20 onward intentionally lethal territory where the simulation remains valid but ordinary mistakes can end a run rapidly.

## Design

### Wave and group grammar

A wave owns an ordered list of groups and a concurrent-population safety cap. The cap protects board readability but does not define encounter order. A group owns its enemy composition, a level offset, warning timing, and one start condition relative to the immediately preceding group.

Groups support two authored composition shapes without conflating them. Fixed composition assigns explicit counts to entries for staged encounters such as elite and boss groups. Weighted composition assigns a total count and selection weights for mixed support groups while remaining deterministic under the run seed.

The initial start-condition vocabulary is deliberately small:

| Condition                          | Behavior                                                                                  |
| ---------------------------------- | ----------------------------------------------------------------------------------------- |
| Previous group cleared             | Start only when no living enemy from the preceding group remains.                         |
| Previous group survivors at most N | Start once the preceding group has N or fewer living enemies.                             |
| Immediate overlap                  | Become eligible with the preceding group, still respecting available population headroom. |

Once a group becomes eligible, its members may enter through warning batches as population headroom becomes available. Later groups cannot bypass an earlier ineligible group. Enemies remain associated with their source group until death so survivor thresholds are based on group membership rather than total enemies alive.

### Enemy authority and level projection

Each enemy's authored data is the root authority for Level 1 max HP, max Guard, Defense, and attack profiles. Individual attacks retain their own base damage so one shared level multiplier preserves the intended differences between attack variants. Health, Guard, attack execution, and hit resolution own runtime behavior and state but do not author independent enemy defaults.

The normal enemy level is the one-based wave number. A group may add a non-negative level offset for an elite, boss, or deliberately stronger reinforcement. The displayed level is this final value; hidden stat-only level bonuses are not allowed.

One progression profile converts the final level into four independent outputs. HP, damage, and Guard use multipliers over the enemy's authored base values; Defense adds a flat projected growth value to the enemy's authored base Defense because combat already applies Defense through nonlinear damage reduction.

The initial curve has standard growth from Level 1 and a stronger lethal segment beginning at Level 10:

```text
growth(level) = standard_growth(max(level - 1, 0))
              + lethal_growth(max(level - 9, 0))
```

Every stat authors its own coefficients and exponents. Guard rounds to an integer after projection. Damage receives the strongest lethal acceleration; HP and Guard rise enough to preserve combat pressure without turning late waves into cleanup; Defense remains the shallowest curve so high-level enemies stay damageable. The profile has no hidden maximum level or stat cap.

### Demo progression

| Waves | Encounter purpose                                                                                                                                                                                                                   |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1–3   | Teach baseline movement, facing, telegraphs, Guard, and Small-enemy pattern recognition.                                                                                                                                            |
| 4–6   | Add Charge enemies as later or overlapping groups so committed line pressure enters after the baseline grammar is understood.                                                                                                       |
| 7–9   | Add Mode enemies in controlled groups, combining earlier threats without exceeding the readability cap.                                                                                                                             |
| 10    | Deliver the demo boss encounter. The first version uses a separately authored, visually distinct Mode-enemy variant with a boss level offset and boss group timing so a future real boss can replace it without changing wave flow. |

Clearing wave 10 records demo completion before presenting the branch. `End Run` closes the run through the normal results flow. `Continue Endless` preserves the current build and starts wave 11.

### Endless progression

Wave 11 and later use one fixed endless wave template derived from the complete demo enemy roster. Its group order, group conditions, enemy composition, counts, warning timing, and population cap do not change by wave. Only the base wave level advances, plus any fixed group offsets already present in the template.

The target experience is:

| Region      | Balance contract                                                                                       |
| ----------- | ------------------------------------------------------------------------------------------------------ |
| Waves 1–9   | Learnable authored escalation with enough recovery margin to reach the demo finale.                    |
| Wave 10     | Fair build check and official demo completion point as the stronger curve segment begins.              |
| Waves 11–19 | Optional mastery extension; increasingly unforgiving but still deliberately playable.                  |
| Wave 20+    | Lethal overtime; continued play is supported, but a missed read or bad position may end a run quickly. |

### Child overview

| Child | Focus                                                                                                      | Current document                                                                                 |
| ----- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| 01    | Wave/group schemas, unified enemy Level 1 authority, and deterministic level projection                    | `data_driven_wave_progression_and_enemy_levels_01_progression_data_model.implementation_spec.md` |
| 02    | Ordered-group runtime, level application, pressure-curse retirement, demo completion, and boss placeholder | `data_driven_wave_progression_and_enemy_levels_02_group_runtime_and_demo_completion.sketch.md`   |
| 03    | Authored demo encounters, fixed endless template, and level-only balance curve                             | `data_driven_wave_progression_and_enemy_levels_03_demo_and_endless_balance.sketch.md`            |

Recommended landing order: establish the data and Level 1 authority first; migrate runtime spawning, retire pressure curses, and add the wave-10 completion branch second; author and playtest the complete demo and endless curve only after both seams are stable.

## Non-Goals

1. Do not implement the final bespoke boss; the distinct Mode-enemy variant is the wave-10 placeholder.
2. Do not add new enemy kinds beyond the existing Small, Charge, and Mode roster.
3. Do not add post-demo encounter mechanics, larger population caps, new group conditions, procedural group generation, or reward-driven encounter modifiers.
4. Do not build the future forced three-choice trade-off curse system or its persistent Nemesis-style hunter as part of this plan.
5. Do not copy another game's exact scaling constants or formulas; the survival-mode reference informs the escalating-level concept, not its numerical implementation.
6. Do not balance unrelated player rewards or fix separate gameplay and audio chores as part of this plan.

## Acceptance Criteria

1. Designers can change wave composition, group order, overlap thresholds, level offsets, population caps, and all four level curves without changing runtime logic.
2. Groups enter strictly in authored order, respect their predecessor-survivor condition and population headroom, and complete the wave only after every authored group and living member is cleared.
3. Enemy authored data is the single Level 1 tuning authority, while runtime combat components retain ownership of live HP, Guard, attacks, and Defense consumption.
4. Enemy level is visible and consistently projects HP, damage, Guard, and Defense; no legacy tier bonus or enemy-pressure curse also modifies those stats.
5. Waves 1–10 follow the authored roster progression and wave 10 ends with the visually distinct boss placeholder.
6. Clearing wave 10 records `Demo Complete` exactly once and offers functional `End Run` and `Continue Endless` choices.
7. Continuing uses the fixed endless encounter grammar for every later wave; comparing two endless waves shows only level-derived numerical pressure changing.
8. Playtest results support wave 10 as the official completion target, waves 11–19 as increasingly unforgiving mastery play, and wave 20 onward as valid but intentionally high-lethality overtime.
