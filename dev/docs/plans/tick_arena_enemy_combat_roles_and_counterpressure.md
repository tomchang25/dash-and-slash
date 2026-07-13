# Tick Arena Enemy Combat Roles And Counterpressure

## Goal

Make enemy combat resistant to repeat Guard-lock while giving each roster role a distinct tactical purpose and encounter position. The plan replaces interchangeable chase-and-attack pressure with predictable Guard classes, reactive facing, specialized Bomb and Ranged threats, elite retaliation, and role-aware spawn formations before final wave balance resumes.

## Requirements

1. Guard break timing must be predictable by combat class through fixed Front, Side, and Back Guard damage and shared Small, Heavy, Elite, and default Boss Guard profiles, because positional decisions must remain learnable through waves 1–20.
2. Recovering from Stagger must grant a visible five-tick protection window that halves incoming Guard damage without preventing damage or secretly clamping Guard, so repeat Stagger requires substantially more commitment without appearing bugged.
3. A living enemy hit outside a committed windup must prepare to spend its next funded action facing the player, because repeatedly attacking the same exposed side must provoke a readable response rather than preserve an infinite flank.
4. The production roster must consist of tactically distinct roles: Thrust and Slash as the Small melee family, Charge as Heavy, Ranged using the Small Guard profile, Mode as Elite, a guardless Bomb as Special, and individually authored bosses using a default or custom Boss policy.
5. Mode enemies must retaliate after Stagger with protection plus one visible empowered combat cycle, while bosses remain individually authored so a shared elite rule does not flatten bespoke encounter phases.
6. Enemy groups must enter in role-aware formations and distance bands instead of uniformly scattered weighted batches, because adding new enemy scripts alone cannot solve isolated chase-and-pick-off encounters.
7. Wave 21 onward must add discrete class-based Guard increments every five waves without using group level offsets, because lethal overtime may erode the waves 1–20 break-count contract while demo and mastery waves must preserve it.
8. Preview, committed resolution, Guard bars, status presentation, and debug inspection must agree on Guard damage, protection, lethal tier, facing response, and empowered attacks so no tactical rule exists only in hidden runtime state.

## Design

### Guard damage and shared profiles

Player attacks deal fixed Guard damage by angle:

| Angle | Guard damage |
| ----- | -----------: |
| Front |            4 |
| Side  |           16 |
| Back  |           32 |

Standard enemy roles reference shared Guard profiles instead of independently drifting values:

| Guard profile | Base max Guard | Back hits | Side hits | Front hits | Lethal Guard step |
| ------------- | -------------: | --------: | --------: | ---------: | ----------------: |
| Small         |             32 |         1 |         2 |          8 |                +8 |
| Heavy         |             64 |         2 |         4 |         16 |               +16 |
| Elite         |             96 |         3 |         6 |         24 |               +24 |
| Boss default  |            128 |         4 |         8 |         32 |               +32 |

Thrust, Slash, and Ranged use the Small profile. Charge uses Heavy. Mode uses Elite. A boss may use the default Boss profile or an encounter-specific replacement. Bomb is guardless and is damaged directly rather than participating in Guard and Stagger.

### Post-Stagger protection

Stagger recovery refills Guard and begins five normal world ticks of protection. Incoming Guard damage is multiplied by 0.5 during this window; normal and Mobility attacks share the reduction, while Guard Shredder preserves its explicit instant-break contract. Free player actions neither consume protection ticks nor bypass the reduction.

Protection never clamps current Guard or makes the enemy invulnerable. Its active state must be visible through the enemy and Guard presentation, and previews must show the reduced Guard damage and resulting break outcome before the player commits.

### Lethal Guard progression

Guard remains at its shared profile base through wave 20. Wave 21 begins lethal Guard tier 1, and each five-wave band adds another profile step:

| Wave band | Lethal Guard tier |
| --------- | ----------------: |
| 1–20      |                 0 |
| 21–25     |                 1 |
| 26–30     |                 2 |
| 31–35     |                 3 |

The tier continues without a cap. Max Guard is the profile base plus its lethal Guard step multiplied by the tier. This calculation reads the one-based wave number rather than final enemy level, so group level offsets still strengthen HP, damage, and Defense without granting early lethal Guard.

### Hit-facing response

After a hit resolves, an enemy that remains alive, did not enter Stagger, and has no committed windup clears stale movement intent and prepares its existing one-step facing behavior. A normal player action may let that facing response execute during the following enemy resolution; a free action changes the visible pending behavior but does not grant the enemy an unfunded turn. Repeated hits do not stack extra facing costs, and committed attacks, Stagger, and death retain priority.

### Roster roles

| Role   | Tactical contract                                                                                                                                                                                          |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Thrust | Small-profile melee that threatens a three-cell forward lane and rewards lateral movement.                                                                                                                 |
| Slash  | Small-profile melee that threatens a three-cell cross-lane in front and rewards longitudinal spacing.                                                                                                      |
| Charge | Heavy-profile committed line threat; collision and forced-displacement behavior remains owned by the separate enemy-mobility plan.                                                                         |
| Bomb   | Guardless Special that approaches the player's adjacent ring, locks a three-by-three explosion for three ticks, deals 50 damage on detonation, then kills itself. Killing it before detonation disarms it. |
| Ranged | Small-profile backline threat that cannot attack within the adjacent ring, targets within six cells, retreats when crowded, and locks one Cross attack footprint during windup.                            |
| Mode   | Elite-profile multi-attack enemy that combines established attack languages and gains post-Stagger retaliation.                                                                                            |
| Boss   | Individually authored encounter using the default Boss Guard profile only when no bespoke policy replaces it; the existing Mode-based boss remains a placeholder.                                          |

Pierce and Burst leave the production roster because Pierce does not create a sufficiently distinct positioning problem and Burst overlaps Bomb's close-area role. Their reusable assets may remain parked until a later cleanup explicitly removes them.

### Elite retaliation

When Mode recovers from Stagger, it receives the common protection window and empowers its next committed combat cycle. The empowered attack uses one fewer warning tick, never below one, and deals 1.25 times damage; the modifiers are fixed when the attack commits and cannot shorten an already visible warning. The empowerment ends when that attack resolves or is cancelled and must have a distinct presentation. Bosses may opt into, replace, or omit this policy per encounter.

### Role-aware encounter placement

Authored groups choose a formation or distance-band intent in addition to composition and start timing. Melee roles should enter as readable arcs or clusters, Ranged should occupy a backline band, and Bomb should enter from a flank or overlapping follow-up group. Formation changes placement only; ordered eligibility, warning reservations, population headroom, and fixed endless grammar remain intact.

Final counts, group timing, weights, and growth curves remain deferred to the existing wave-balance child. This plan establishes the stable roles and placement language that balance will consume.

### Child overview

| Child | Focus                                                                                            | Current document                                                                                      |
| ----- | ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| 01    | Shared Guard profiles, fixed angle damage, protection, preview agreement, and lethal Guard tiers | `tick_arena_enemy_combat_roles_and_counterpressure_01_guard_profiles_and_lethal_resilience.implementation_spec.md` |
| 02    | Hit-triggered facing response and action-order preservation                                      | `tick_arena_enemy_combat_roles_and_counterpressure_02_hit_reaction_facing.implementation_spec.md` |
| 03    | Thrust and Slash consolidation plus Pierce and Burst production retirement                       | `tick_arena_enemy_combat_roles_and_counterpressure_03_small_roster_consolidation.implementation_spec.md` |
| 04    | Guardless Bomb self-destruct threat                                                              | `tick_arena_enemy_combat_roles_and_counterpressure_04_bomb_enemy_self_destruct.implementation_spec.md` |
| 05    | Small-profile Ranged enemy with fixed Cross pressure                                             | `tick_arena_enemy_combat_roles_and_counterpressure_05_ranged_enemy_cross_pressure.sketch.md`          |
| 06    | Mode retaliation and per-boss policy seam                                                        | `tick_arena_enemy_combat_roles_and_counterpressure_06_elite_retaliation_and_boss_policy.sketch.md`    |
| 07    | Role-aware group formations and provisional roster integration                                   | `tick_arena_enemy_combat_roles_and_counterpressure_07_role_aware_spawn_formations.sketch.md`          |

Recommended landing order: establish Guard and protection first, then add the shared hit-facing response. Consolidate the Small roster before adding Bomb and Ranged so each new role has a unique tactical slot. Add Mode retaliation after the shared protection contract is stable, then introduce formation-aware placement and hand the resulting roster and grammar to the deferred wave-balance child.

## Non-Goals

1. Do not perform final wave 1–10 composition, endless counts, population-cap tuning, or HP, damage, and Defense curve balance; the deferred wave-balance child owns those decisions after this plan stabilizes.
2. Do not implement a bespoke final boss; preserve the placeholder while establishing a per-boss policy seam.
3. Do not implement Charge collision displacement, DashEnemy, or Viking Smash knockback; the separate enemy-mobility plan owns them.
4. Do not add Ranged variants, enemy-introducing Curse Artifacts, hidden reward-driven roster changes, or post-wave procedural enemy escalation.
5. Do not add Meta Progression, Coin, saves, character unlocks, or Artifact pool persistence; Meta Progression consumes the finalized run outcome separately.
6. Do not redesign player normal attacks, Mobility damage, or reward balance except where preview and Guard Shredder must preserve the new Guard contract.

## Acceptance Criteria

1. Through wave 20, every standard enemy breaks in the documented number of Front, Side, or Back hits for its Guard profile, and identical profiles never drift between enemy scenes.
2. Stagger recovery visibly halves Guard damage for five world ticks, previews the reduction correctly, and never hides a Guard floor or blocks HP damage.
3. Wave 21 and every fifth wave thereafter add the correct profile-specific Guard step based on wave number, while group level offsets do not trigger lethal Guard early.
4. A non-breaking hit outside committed windup prepares a one-step facing response without granting an unfunded action, stacking response costs, or cancelling higher-priority combat state.
5. Thrust, Slash, Charge, Bomb, Ranged, Mode, and the placeholder Boss each present a distinct positioning or timing problem; Pierce and Burst are absent from production encounters.
6. Bomb can be killed to disarm it, otherwise resolves its locked explosion and self-destructs without entering Guard or Stagger.
7. Ranged maintains its minimum range, locks a readable Cross footprint within six cells, and retreats rather than using melee behavior when crowded.
8. Mode's first post-Stagger attack visibly uses the empowered warning and damage contract, while bosses can define a different policy without changing shared elite behavior.
9. Role-aware groups enter in readable formations without violating ordered eligibility, warning revalidation, population headroom, wave completion, or fixed endless-template rules.
10. The deferred wave-balance work can author final encounters using the completed roster, Guard rules, retaliation policies, and formation vocabulary without adding another runtime exception.
