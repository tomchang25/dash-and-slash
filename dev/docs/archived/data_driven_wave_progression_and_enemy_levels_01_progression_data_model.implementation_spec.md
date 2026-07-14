# Data-Driven Wave Progression And Enemy Levels 01: Progression Data Model

Parent Plan: `data_driven_wave_progression_and_enemy_levels.md`

## Goal

Establish the authored wave/group schema, one enemy-owned Level 1 tuning authority, and a deterministic four-stat level projection contract so the later runtime migration can consume verified data rather than inventing structure while rewriting wave flow.

## Summary

This slice adds a wave-domain Resource graph that can represent ten explicit demo waves and one endless template using ordered groups, fixed or weighted composition, predecessor conditions, warning timing, population caps, and group level offsets. It also adds a pure progression profile whose standard growth begins at Level 1 and whose stronger segment begins at Level 10.

`EnemyData` becomes the single authored root for base max HP, max Guard, Defense, and the existing per-attack profiles. Health and Guard continue to own live combat state; attack data continues to own each attack variant's base damage. A typed projection result preserves that separation by returning projected max HP, max Guard, Defense, and one damage multiplier shared by all attacks.

The current flat wave controller and legacy tier scaling remain operational during this slice. Enemy scenes migrate off duplicated HP/Guard tuning, while the existing pre-ready wave-scaling call is bridged onto the new base authority until Child 02 replaces it with level projection. No production wave catalog, final balance constants, curse removal, group scheduler, or visible-level UI lands here.

## Relational Context

- The catalog owns ten demo waves, one endless template, and one progression profile; each wave owns its cap and ordered groups, and each group owns condition, timing, offset, composition mode, and entries. The wave controller does not consume them until Child 02.
- Composition entries reference the PackedScene required by the spawn boundary. Spawned scenes expose EnemyData; wave data never duplicates enemy stats.
- EnemyData owns base HP, Guard, Defense, and attack profiles; each EnemyAttackData owns its attack's base damage. Health and Guard own live state, while GridEnemy configures them from EnemyData and preserves per-attack differences through one damage multiplier.
- The profile reads EnemyData plus final level and returns a typed projection without mutating authored data or combat state.
- Enemy scenes retain generic Health/Guard components but no enemy-specific max overrides.
- The existing pre-ready legacy scaling call remains. GridEnemy applies it after EnemyData initialization so HP, damage, and Defense stay compatible until Child 02; legacy scaling still does not affect Guard.
- This slice leaves RunBuild pressure and reward flow untouched. Focused tests cover new data/projection contracts; existing wave tests cover legacy compatibility.

## Scope

### Included

- Validated wave/group/composition/curve/profile schemas and typed projection output.
- EnemyData base-stat authority, production data migration, component initialization, and legacy compatibility.
- Focused schema, projection, production-data, and compatibility tests.

### Excluded

- Production wave content, final coefficients, group runtime, debug-level display, completion/endless flow, pressure removal, replacement curses, and new enemies.

## Files to Change

| File                                                                          | Change Size | Purpose                            |
| ----------------------------------------------------------------------------- | ----------- | ---------------------------------- |
| `data/waves/definitions/wave_catalog.gd`                                      | Medium      | Catalog root                       |
| `data/waves/definitions/wave_definition.gd`                                   | Small       | Wave schema                        |
| `data/waves/definitions/wave_group_definition.gd`                             | Medium      | Group schema                       |
| `data/waves/definitions/wave_composition_entry.gd`                            | Small       | Composition schema                 |
| `data/waves/definitions/enemy_stat_growth_curve.gd`                           | Small       | Per-stat curve                     |
| `data/waves/definitions/enemy_level_progression_profile.gd`                   | Medium      | Projection profile                 |
| `game/tick_arena/wave/enemy_level_projection.gd`                              | Small       | Typed result                       |
| `data/enemies/definitions/enemy_data.gd`                                      | Medium      | Level 1 authority                  |
| `common/gameplay/combat/health.gd`                                            | Small       | Initialization seam                |
| `common/gameplay/combat/guard.gd`                                             | Small       | Initialization seam                |
| `game/entities/enemies/grid_enemy.gd`                                         | Medium      | Data consumption and compatibility |
| `game/entities/enemies/data/*.tres`                                           | Small       | All seven enemy bases              |
| `game/entities/enemies/{small_enemy,charge_enemy,mode_enemy,puff_enemy}.tscn` | Small       | Remove stat overrides              |
| `test/unit/test_enemy_progression_data.gd`                                    | Large       | Focused coverage                   |

## Execution Outline

1. Add and test the validated wave schema graph for ten demo waves, one endless template, all conditions, and both composition modes.
2. Add and test curves, profile, and typed projection across Level 1, the Level 9-to-10 boundary, rounding, offsets, and high levels.
3. Move base stats into EnemyData resources, add component initialization seams, and bridge GridEnemy's legacy scaling onto those bases.
4. Remove scene stat overrides, add production integration coverage, lint all touched files, and run focused plus wave compatibility tests.

## Implementation Notes

- Fixed mode validates positive entry counts; weighted mode validates positive total and weights. The first group is wave-start eligible by position; later groups validate their predecessor condition and applicable non-negative threshold.
- Catalog validation requires ten demo waves, endless template, profile, positive caps, non-empty groups, non-negative offsets/timing, and valid entries.
- HP/damage/Guard multiplier: `1 + standard_coefficient * max(level - 1, 0) ^ standard_exponent + lethal_coefficient * max(level - 9, 0) ^ lethal_exponent`. Guard rounds once. Defense adds both curve terms to base Defense. Coefficients are non-negative, exponents positive, and outputs uncapped.
- Levels below 1 report a development error and normalize to Level 1; missing/invalid authored data fails validation.
- Preserve bases: Small 100 HP/16 Guard, Charge 150/32, Mode 180/16, Puff 30/16, all 0 Defense.
- GridEnemy never mutates Resources. Pre-ready legacy modifiers wait until EnemyData initializes full Health/Guard, then apply legacy HP multiplier and Defense addition. Component initialization is separate from combat/reset operations.

## Edge Cases

| Case                                                   | Expected Handling                                           |
| ------------------------------------------------------ | ----------------------------------------------------------- |
| First group has a predecessor condition                | Position still makes it wave-start eligible                 |
| Count, weight, threshold, offset, or timing is invalid | Validation fails                                            |
| Projection receives Level 0 or lower                   | Report the error and return Level 1 values                  |
| EnemyData is missing                                   | Report the error and retain safe generic component defaults |
| Legacy scaling arrives before ready                    | Retain it until EnemyData initialization completes          |
| Very high level is projected                           | Return finite, non-negative, uncapped outputs               |

## Acceptance Criteria

1. A validated catalog can represent ten ordered demo waves and one endless template using fixed or weighted groups, all three predecessor conditions, warning timing, population caps, and non-negative level offsets.
2. Every production enemy's Level 1 HP, Guard, Defense, and attack graph has one authored authority, while live Health and Guard state remains component-owned.
3. A valid profile deterministically returns Level 1 identity values and applies the stronger segment beginning at Level 10 to HP, damage, Guard, and Defense.
4. All attack variants preserve their authored base-damage differences under one projected enemy damage multiplier.
5. Existing enemy scenes spawn with their current Level 1 HP and Guard values, and the untouched legacy wave path still produces its current HP, damage, and Defense behavior.
6. Invalid catalog, group, enemy, curve, or projection input is reported and cannot silently become trusted authored data.
7. No ordered-group scheduler, final wave content, pressure-curse removal, completion UI, or replacement curse mechanic is introduced by this slice.
