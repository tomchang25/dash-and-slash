# Tick Arena Enemy Combat Roles And Counterpressure 01: Guard Profiles And Lethal Resilience

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Replace level-scaled Guard break thresholds with shared role profiles and make post-Stagger protection a visible, preview-accurate combat state. This keeps Front, Side, and Back break counts learnable through wave 20 while allowing deliberate lethal Guard growth from wave 21 onward.

## Summary

Guard damage becomes fixed at Front 4, Side 16, and Back 32. Authored enemy data references shared Small, Heavy, Elite, or Boss Guard profiles instead of carrying an independent max-Guard value; no profile is a supported guardless role.

The level projection continues to own HP, outgoing damage, and Defense. Wave spawning supplies its base wave number so the projection can place profile-derived max Guard in its existing result. Guard is unchanged through wave 20, grows one profile-specific step in waves 21–25, and grows another step each later five-wave band; group level offsets never alter this calculation.

After Stagger ends, refilled Guard receives five world ticks of visible protection. Protection halves ordinary Guard damage, does not alter HP damage or impose a hidden minimum, and is bypassed by Guard Shredder. The status view and preview read the same snapshot value as committed resolution.

## Relational Context

- `EnemyData` owns an enemy's selected Guard profile; `Guard` owns only live current/max values, Stagger, enabled state, and protection derived from that data.
- `WaveController` owns the current base wave number and passes it with final enemy level into catalog projection before the spawner puts an enemy in the tree; group offsets affect HP, damage, and Defense only.
- `EnemyLevelProgressionProfile` writes resolved max Guard into `EnemyLevelProjection`; `GridEnemy` remains the pre-ready consumer that initializes Health, Guard, damage multiplier, and Defense from the projection.
- `GridEnemy` supplies immutable hit snapshots to `TickHitResolver`; the resolver powers both preview and commit, so protection must be in the snapshot rather than applied only during `take_hit()`.
- Guard Shredder replaces reduced Guard damage with current Guard after ordinary protection would apply, preserving its instant-back-break contract without changing Execution priority.
- A disabled Guard component is guardless: snapshots report no Guard, status bars show no shields, and the resolver deals normal HP damage. Do not infer Guard from the reusable scene node alone.
- `TickEngine.advance_world()` is the only clock for enemy status. Speed free moves and attacks cannot consume protection ticks.

## Scope

### Included

- Shared Guard profile data, production profile assignments, and removal of continuous Guard curves.
- Fixed angle Guard damage, post-Stagger protection, guardless readiness, and status/preview agreement.
- Base-wave lethal Guard tiers and focused profile, projection, resolver, and runtime tests.

### Excluded

- Hit-facing, new enemy roles, Mode retaliation, formation placement, and final encounter balance.
- HP, outgoing-damage, Defense, or reward tuning.
- Bespoke boss mechanics beyond allowing boss data to select a profile.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `data/enemies/definitions/guard_profile.gd` | Medium | Define reusable profile validation and base-wave max-Guard calculation. |
| `data/enemies/guard_profiles/*.tres` | Small | Author Small, Heavy, Elite, and default Boss profiles. |
| `data/enemies/definitions/enemy_data.gd` | Medium | Replace per-enemy max Guard with an optional profile reference. |
| `game/entities/enemies/data/*.tres` | Medium | Assign profiles to current guarded production and placeholder enemies. |
| `data/waves/definitions/enemy_level_progression_profile.gd` | Medium | Project HP, damage, Defense, and profile-derived Guard from final level plus base wave. |
| `game/tick_arena/wave/enemy_level_projection.gd` | Small | Preserve the typed resolved max-Guard delivery field. |
| `game/tick_arena/wave/wave_controller.gd` | Small | Supply current base wave to pre-ready projection. |
| `common/gameplay/combat/guard.gd` | Medium | Own enabled/guardless state and five-tick protection lifecycle. |
| `game/entities/enemies/grid_enemy.gd` | Large | Initialize profile Guard, consume projection, publish snapshots, and sync presentation. |
| `game/tick_arena/combat/tick_combat_rules.gd` | Small | Replace max-Guard-derived angle damage with fixed values. |
| `game/tick_arena/combat/tick_hit_resolver.gd` | Medium | Apply snapshot protection while preserving Shredder and existing HP rules. |
| `common/gameplay/view/enemy_status_bars.gd` | Medium | Show protected Guard distinctly and no shields for guardless targets. |
| `data/waves/default_wave_catalog.tres` | Small | Remove authored continuous Guard curve content. |
| `test/unit/test_enemy_progression_data.gd` | Large | Cover profiles, tiers, projection, assignments, and pre-ready application. |
| `test/unit/test_tick_hit_resolver_dash_triggers.gd` | Medium | Cover protected normal/Mobility hits and Shredder bypass. |
| `test/unit/test_guard.gd` | Medium | Cover exact Stagger-recovery and protection timing. |

## Execution Outline

1. Add profile resource/assets and migrate enemy data away from independent max-Guard values before changing runtime consumers.
2. Convert projection and wave spawning to resolve Guard from base wave, then remove the obsolete Guard curve from catalog data and validation.
3. Extend Guard/GridEnemy state for guardless and post-Stagger protection, then expose it to resolver snapshots and status presentation.
4. Replace angle math, add protection/Shredder coverage, and update progression fixtures and production-data assertions.

## Implementation Notes

- Profiles are Small `32/+8`, Heavy `64/+16`, Elite `96/+24`, and default Boss `128/+32`, all with Stagger duration 3, protection duration 5, and multiplier 0.5. Tier is 0 through wave 20; waves 21–25 are tier 1 and each further five-wave band adds one with no cap.
- Map Line, Sweep, Pierce, Burst, and legacy Puff to Small until later roster children change them; map Charge to Heavy, Mode to Elite, and the Mode-boss placeholder to Boss. The later Bomb has no profile.
- Retain `EnemyLevelProjection.max_guard` as the runtime delivery field; delete `guard_curve` instead of leaving ignored authored content. Direct instantiation without a pre-ready projection uses the selected profile's wave-1 maximum.
- Start protection only after Guard refills at Stagger end. Each later status pass consumes one count; the Stagger-end tick itself is not one of the five protected ticks.
- Resolver ordering is Execution on an already staggered target, then Shredder current-Guard replacement, otherwise fixed damage times snapshot protection before break evaluation. Do not round upward or impose a minimum.
- Use the existing shield status view for the protected indicator and refresh it on protection state, Guard disable, Stagger/reset, and pool reset without creating another combat authority.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| A group has a high level offset in wave 20 | HP, damage, and Defense increase, but Guard remains profile base. |
| A protected target has 16 Guard and takes a Back hit | Normal Back damage resolves as 16 and breaks Guard. |
| A protected back Dash has Guard Shredder | It breaks immediately for current Guard, ignoring protection. |
| A Speed free action hits a protected enemy | Protection remains active because world time does not advance. |
| A guardless enemy has a Guard node in its scene | It is disabled, reports no Guard, and cannot show shields or enter Stagger. |

## Acceptance Criteria

1. Through wave 20, Small, Heavy, Elite, and default Boss break after documented 1/2/8, 2/4/16, 3/6/24, and 4/8/32 Back/Side/Front hits.
2. Waves 21–25 add one correct profile step, each later five-wave band adds another, and group offsets never advance it.
3. Refilled Guard is visibly protected for exactly five later world ticks; normal and Mobility Guard damage halve while HP damage and Guard Shredder remain intact.
4. Previewed Guard damage, break outcome, shields, and committed result always agree.
5. Missing profile produces direct HP damage with no shields, Guard break, or Stagger.
