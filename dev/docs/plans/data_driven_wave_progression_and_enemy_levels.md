# Data-Driven Wave Progression And Enemy Levels

## Goal

Build a designer-authored wave progression that delivers a complete ten-wave demo, then transitions into an optional endless survival mode whose encounter grammar stays fixed while enemy levels and combat stats continue to rise. Replace opaque wave formulas, the flat spawn queue, and duplicate enemy-stat authorities with explicit ordered groups and one readable enemy-level model.

## Requirements

1. Waves must reference reusable spawn groups through lightweight ordered slots rather than flattening enemies into one queue or duplicating composition in every wave, so encounter composition, escalation order, and elite or Boss entrances remain intentional and maintainable data.
2. Each slot must define when its referenced group may begin relative to the preceding slot, including immediate overlap and previous-group-survivor thresholds, while the whole remaining group must fit population headroom and receive a complete legal placement before any spawning telegraph appears.
3. Each enemy must own one authored Level 1 data graph for HP, Guard, Defense, and attack profiles; combat components consume those values as runtime state instead of remaining competing tuning authorities.
4. Every spawned enemy must receive an integer level equal to the current one-based wave plus an authored non-negative group offset, and that level must drive HP, damage, and Defense through one data-driven progression profile while remaining available to debug inspection rather than normal combat UI. Guard follows the shared role profiles and wave-based lethal tiers defined by the Enemy Combat Roles And Counterpressure plan instead of continuous level projection.
5. Displayed enemy level and the explicit lethal Guard tier must be the only numeric enemy-strength progression: remove the legacy wave-tier scaling and all four enemy-pressure curses, channels, and forced single-curse confirmation rather than stacking hidden modifiers onto those readable systems.
6. Waves 1–10 must form the complete authored demo using the production roster and role grammar established by the Enemy Combat Roles And Counterpressure plan, ending at wave 10 with a boss encounter represented initially by a visually distinct Mode-enemy variant.
7. Clearing wave 10 must mark the current run as demo-complete and offer `End Run` or `Continue Endless`; continuing preserves that result, completes the normal Minor wave-10 reward step, and enters wave 11 without finalizing the run.
8. Wave 11 onward must reuse one fixed authored endless encounter grammar and increase pressure only through advancing enemy level plus the explicit Guard tier beginning at wave 21; it must not introduce new enemy kinds, groups, counts, spawn overlap, population growth, curses, or other hidden escalation.
9. Balance must make wave 10 a fair official completion target, waves 11–20 a mastery extension, and wave 21 onward intentionally lethal territory where the simulation remains valid but ordinary mistakes can end a run rapidly.
10. Major reward offers must occur after every third completed wave independently of Boss identity, while all other waves use the normal Minor offer and no Curse flow returns.

## Design

### Wave and group grammar

The root catalog directly references ten external demo-wave resources and one external Endless template. A wave owns a concurrent-population safety cap plus lightweight ordered slots. Each slot references one external reusable spawn-group resource and owns only its occurrence-specific start condition, survivor threshold, warning timing, level offset, and Boss role. A spawn group owns composition plus one simple placement strategy: a ring around the player, a cluster around a distant anchor, or independent scatter. YAML generation, string IDs, and runtime enemy-role inspection are unnecessary for this first authoring model.

Spawn groups support fixed and weighted composition without conflating the two. Fixed composition assigns explicit counts for combined, staged, or Boss groups. Weighted composition assigns a total count and selection weights for families such as Thrust and Slash while remaining deterministic under the run seed.

The initial start-condition vocabulary is deliberately small:

| Condition                          | Behavior                                                                                  |
| ---------------------------------- | ----------------------------------------------------------------------------------------- |
| Previous group cleared             | Start only when no living enemy from the preceding group remains.                         |
| Previous group survivors at most N | Start once the preceding group has N or fewer living enemies.                             |
| Immediate overlap                  | Become eligible with the preceding group, still respecting available population headroom. |

Eligibility is latched separately from schedulability. Once a slot becomes eligible, its entire remaining group must fit population headroom and receive a complete legal cell plan before it enters spawn flow or shows a warning. The earliest eligible waiting slot blocks every later slot. Enemies remain associated with their source slot until death so survivor thresholds are based on group membership rather than total enemies alive.

Admission is atomic, but warning resolution preserves the existing best-effort safety behavior: a cell that became invalid is replaced near the intended anchor when possible, then by any legal cell, and only a member with no replacement is requeued. SPAWNING telegraphs count as blocked cells for enemy path planning only; they do not become generic occupancy and do not block the player.

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

| Wave | Encounter purpose |
| ---- | ----------------- |
| 1 | Teach the three-enemy weighted Thrust/Slash Small group around the player. |
| 2 | Isolate a two-enemy Ranged anchor cluster. |
| 3 | Introduce one combined Small + Ranged cluster. |
| 4 | Isolate a two-enemy Charge scatter group. |
| 5 | Introduce one combined Small + Ranged + Charge cluster. |
| 6–7 | Shift to multiple immediate-overlap single-role groups under ordered atomic admission. |
| 8–9 | Add a two-enemy Bomb scatter group to the multi-group grammar and rehearse the full non-Boss roster. |
| 10 | Spawn only the visually distinct Mode Boss placeholder at level offset 3, with no support-enemy phase. |

Clearing wave 10 records run-local demo completion before presenting the branch. `End Run` and player death converge on one results flow with different terminal reasons. `Continue Endless` does not finalize the run; it preserves the current build, completes the normal Minor wave-10 reward without a Curse confirmation, and then starts wave 11.

### Endless progression

Wave 11 and later use one fixed endless wave template derived from the complete demo enemy roster. Its group order, group conditions, enemy composition, counts, warning timing, and population cap do not change by wave. The base wave level advances, fixed group offsets remain stable, and the explicit Guard tier advances every five waves beginning at wave 21.

The target experience is:

| Region      | Balance contract                                                                                       |
| ----------- | ------------------------------------------------------------------------------------------------------ |
| Waves 1–9   | Learnable authored escalation with enough recovery margin to reach the demo finale.                    |
| Wave 10     | Fair build check and official demo completion point as the stronger curve segment begins.              |
| Waves 11–20 | Optional mastery extension; increasingly unforgiving but still deliberately playable.                  |
| Wave 21+    | Lethal overtime; continued play is supported, but a missed read or bad position may end a run quickly. |

### Reward cadence

Completed waves divisible by three use the existing Major milestone offer: one Minor x2 choice plus up to two eligible Majors, with unavailable Major slots falling back to distinct Minor x2 choices. Every other wave uses the normal three-Minor offer. Boss identity and demo completion do not define reward rarity, so wave 10 is a normal Minor reward when the player continues and wave 12 is the first Endless Major reward. Curse support remains dormant and the production catalog stays Curse-free.

### Child overview

| Child | Focus                                                                                                         | Current document                                                                                            |
| ----- | ------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 01    | Wave/group schemas, unified enemy Level 1 authority, and deterministic level projection                       | `data_driven_wave_progression_and_enemy_levels_01_progression_data_model.implementation_spec.md`            |
| 02    | Ordered-group runtime, level application, pressure-curse retirement, demo completion, and boss placeholder    | `data_driven_wave_progression_and_enemy_levels_02_group_runtime_and_demo_completion.implementation_spec.md` |
| 03    | Reusable groups, anchor placement, atomic admission, external demo/endless content, and spawn-path blocking | `data_driven_wave_progression_and_enemy_levels_03_group_based_spawning_logic_refactor.implementation_spec.md` |
| 04    | Every-third-wave Major reward cadence decoupled from Boss identity                                          | `data_driven_wave_progression_and_enemy_levels_04_major_reward_cadence.implementation_spec.md`              |

Recommended landing order: establish the data and Level 1 authority first; migrate runtime spawning, retire pressure curses, and add the wave-10 completion branch second. Land the group-based spawning refactor after the production roster is stable, then apply the independent reward cadence change. Numerical playtest tuning follows these structural children.

## Non-Goals

1. Do not implement the final bespoke boss; the distinct Mode-enemy variant is the wave-10 placeholder.
2. Do not create or redesign enemy kinds in this plan; consume the production roster established by the Enemy Combat Roles And Counterpressure plan.
3. Do not add post-demo encounter mechanics, larger population caps, new group conditions, procedural group generation, or reward-driven encounter modifiers.
4. Do not build the future forced three-choice trade-off curse system or its persistent Nemesis-style hunter as part of this plan.
5. Do not copy another game's exact scaling constants or formulas; the survival-mode reference informs the escalating-level concept, not its numerical implementation.
6. Do not rebalance Artifact effects, Major offer composition, legendary capacity, or reward RNG beyond the explicit cadence change.
7. Do not add Coin, save-backed completion, character unlocks, or artifact unlock progression; the Meta Progression plan consumes this plan's run outcome after the runtime cutover establishes it.

## Acceptance Criteria

1. Designers can reuse external spawn groups and change wave composition, slot order, overlap thresholds, placement strategy, level offsets, population caps, the three level curves, and Guard lethal-tier settings without changing runtime logic.
2. Groups enter strictly in authored order, respect predecessor conditions, wait outside spawn flow until the whole remaining group is schedulable, and complete the wave only after every authored slot and living member is cleared.
3. Enemy authored data is the single Level 1 tuning authority, while runtime combat components retain ownership of live HP, Guard, attacks, and Defense consumption.
4. Enemy level is retained for debug inspection and consistently projects HP, damage, and Defense, while Guard follows its role profile and base-wave lethal tier; no legacy tier bonus or enemy-pressure curse also modifies those stats.
5. Waves 1–9 follow the authored isolated, combined, and multi-group progression; Bomb first appears at wave 8; wave 10 contains only the visually distinct Boss placeholder.
6. Clearing wave 10 records run-local `Demo Complete` exactly once and offers functional `End Run` and `Continue Endless` choices.
7. Death and `End Run` produce one results flow with the correct terminal reason and highest completed wave, while continuing does not finalize the run.
8. Continuing completes the normal Minor wave-10 reward step and uses the fixed endless encounter grammar for every later wave; comparing two Endless waves shows only level-derived HP, damage, and Defense plus the explicit wave-21-and-later Guard tier changing.
9. Playtest results support wave 10 as the official completion target, waves 11–20 as increasingly unforgiving mastery play, and wave 21 onward as valid but intentionally high-lethality overtime.
10. Major offers occur exactly after waves divisible by three, including Endless waves, while Boss identity never changes reward rarity and no Curse flow is reachable.
