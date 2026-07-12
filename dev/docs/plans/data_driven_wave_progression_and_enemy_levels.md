# Data-Driven Wave Progression And Enemy Levels

## Goal

Build a designer-authored wave progression that delivers a complete ten-wave demo, then transitions into an optional endless survival mode whose encounter grammar stays fixed while enemy levels and combat stats continue to rise. Replace opaque wave formulas, the flat spawn queue, and duplicate enemy-stat authorities with explicit ordered groups and one readable enemy-level model.

## Requirements

1. Waves must be authored as ordered groups rather than flattened into one queue so encounter composition, escalation order, and elite or boss entrances are intentional data instead of runtime exceptions.
2. Each group must define its enemy composition and when it may begin relative to the preceding group, including immediate overlap and previous-group-survivor thresholds, because elite and future boss entrances need encounter timing independent of the global population limit.
3. Each enemy must own one authored Level 1 data graph for HP, Guard, Defense, and attack profiles; combat components consume those values as runtime state instead of remaining competing tuning authorities.
4. Every spawned enemy must receive an integer level equal to the current one-based wave plus an authored non-negative group offset, and that level must drive HP, damage, and Defense through one data-driven progression profile while remaining available to debug inspection rather than normal combat UI. Guard follows the shared role profiles and wave-based lethal tiers defined by the Enemy Combat Roles And Counterpressure plan instead of continuous level projection.
5. Displayed enemy level and the explicit lethal Guard tier must be the only numeric enemy-strength progression: remove the legacy wave-tier scaling and all four enemy-pressure curses, channels, and forced single-curse confirmation rather than stacking hidden modifiers onto those readable systems.
6. Waves 1–10 must form the complete authored demo using the production roster and role grammar established by the Enemy Combat Roles And Counterpressure plan, ending at wave 10 with a boss encounter represented initially by a visually distinct Mode-enemy variant.
7. Clearing wave 10 must mark the current run as demo-complete and offer `End Run` or `Continue Endless`; continuing preserves that result, completes the normal wave-10 reward step, and enters wave 11 without finalizing the run.
8. Wave 11 onward must reuse one fixed authored endless encounter grammar and increase pressure only through advancing enemy level plus the explicit Guard tier beginning at wave 21; it must not introduce new enemy kinds, groups, counts, spawn overlap, population growth, curses, or other hidden escalation.
9. Balance must make wave 10 a fair official completion target, waves 11–20 a mastery extension, and wave 21 onward intentionally lethal territory where the simulation remains valid but ordinary mistakes can end a run rapidly.

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

One progression profile converts the final level into three independent outputs. HP and damage use multipliers over the enemy's authored base values; Defense adds a flat projected growth value to the enemy's authored base Defense because combat already applies Defense through nonlinear damage reduction. Guard max instead comes from the enemy's role profile and increases in discrete five-wave lethal tiers beginning at base wave 21; group level offsets do not advance that tier.

The initial curve has standard growth from Level 1 and a stronger lethal segment beginning at Level 10:

```text
growth(level) = standard_growth(max(level - 1, 0))
              + lethal_growth(max(level - 9, 0))
```

Each projected stat authors its own coefficients and exponents. Damage receives the strongest lethal acceleration; HP rises enough to preserve combat pressure without turning late waves into cleanup; Defense remains the shallowest curve so high-level enemies stay damageable. Guard's separate lethal tiers have no hidden maximum tier or stat cap.

### Demo progression

| Waves | Encounter purpose                                                                                                                                                                                                                   |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1–3   | Teach baseline movement, facing, telegraphs, Guard, and the initial Small-enemy patterns from the completed production roster.                                                                                                      |
| 4–6   | Add Ranged pressure through controlled authored groups after the baseline grammar is understood.                                                                                                                                     |
| 7–9   | Add Charge, Bomb, and Mode pressure in controlled groups, combining earlier threats without exceeding the readability cap.                                                                                                           |
| 10    | Deliver the demo boss encounter. The first version uses a separately authored, visually distinct Mode-enemy variant with a boss level offset and boss group timing so a future real boss can replace it without changing wave flow. |

Clearing wave 10 records run-local demo completion before presenting the branch. `End Run` and player death converge on one results flow with different terminal reasons. `Continue Endless` does not finalize the run; it preserves the current build, completes the normal milestone reward without the retired curse confirmation, and then starts wave 11.

### Endless progression

Wave 11 and later use one fixed endless wave template derived from the complete demo enemy roster. Its group order, group conditions, enemy composition, counts, warning timing, and population cap do not change by wave. The base wave level advances, fixed group offsets remain stable, and the explicit Guard tier advances every five waves beginning at wave 21.

The target experience is:

| Region      | Balance contract                                                                                       |
| ----------- | ------------------------------------------------------------------------------------------------------ |
| Waves 1–9   | Learnable authored escalation with enough recovery margin to reach the demo finale.                    |
| Wave 10     | Fair build check and official demo completion point as the stronger curve segment begins.              |
| Waves 11–20 | Optional mastery extension; increasingly unforgiving but still deliberately playable.                  |
| Wave 21+    | Lethal overtime; continued play is supported, but a missed read or bad position may end a run quickly. |

### Child overview

| Child | Focus                                                                                                         | Current document                                                                                            |
| ----- | ------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 01    | Wave/group schemas, unified enemy Level 1 authority, and deterministic level projection                       | `data_driven_wave_progression_and_enemy_levels_01_progression_data_model.implementation_spec.md`            |
| 02    | Ordered-group runtime, level application, pressure-curse retirement, demo completion, and boss placeholder    | `data_driven_wave_progression_and_enemy_levels_02_group_runtime_and_demo_completion.implementation_spec.md` |
| 03    | Authored demo encounters, fixed endless template, and final stat/Guard-tier balance after the enemy-role plan | `data_driven_wave_progression_and_enemy_levels_03_demo_and_endless_balance.sketch.md`                       |

Recommended landing order: establish the data and Level 1 authority first; migrate runtime spawning, retire pressure curses, and add the wave-10 completion branch second. Defer Child 03 until the Enemy Combat Roles And Counterpressure plan establishes the final production roster, Guard profiles, and role-aware formation vocabulary, then author and playtest the complete demo and endless curve against those stable seams.

## Non-Goals

1. Do not implement the final bespoke boss; the distinct Mode-enemy variant is the wave-10 placeholder.
2. Do not create or redesign enemy kinds in this plan; consume the production roster established by the Enemy Combat Roles And Counterpressure plan.
3. Do not add post-demo encounter mechanics, larger population caps, new group conditions, procedural group generation, or reward-driven encounter modifiers.
4. Do not build the future forced three-choice trade-off curse system or its persistent Nemesis-style hunter as part of this plan.
5. Do not copy another game's exact scaling constants or formulas; the survival-mode reference informs the escalating-level concept, not its numerical implementation.
6. Do not balance unrelated player rewards or fix separate gameplay and audio chores as part of this plan.
7. Do not add Coin, save-backed completion, character unlocks, or artifact unlock progression; the Meta Progression plan consumes this plan's run outcome after the runtime cutover establishes it.

## Acceptance Criteria

1. Designers can change wave composition, group order, overlap thresholds, level offsets, population caps, the three level curves, and Guard lethal-tier settings without changing runtime logic.
2. Groups enter strictly in authored order, respect their predecessor-survivor condition and population headroom, and complete the wave only after every authored group and living member is cleared.
3. Enemy authored data is the single Level 1 tuning authority, while runtime combat components retain ownership of live HP, Guard, attacks, and Defense consumption.
4. Enemy level is retained for debug inspection and consistently projects HP, damage, and Defense, while Guard follows its role profile and base-wave lethal tier; no legacy tier bonus or enemy-pressure curse also modifies those stats.
5. Waves 1–10 follow the authored roster progression and wave 10 ends with the visually distinct boss placeholder.
6. Clearing wave 10 records run-local `Demo Complete` exactly once and offers functional `End Run` and `Continue Endless` choices.
7. Death and `End Run` produce one results flow with the correct terminal reason and highest completed wave, while continuing does not finalize the run.
8. Continuing completes the normal wave-10 reward step and uses the fixed endless encounter grammar for every later wave; comparing two endless waves shows only level-derived HP, damage, and Defense plus the explicit wave-21-and-later Guard tier changing.
9. Playtest results support wave 10 as the official completion target, waves 11–20 as increasingly unforgiving mastery play, and wave 21 onward as valid but intentionally high-lethality overtime.
