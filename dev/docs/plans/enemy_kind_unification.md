# Unify Enemy Attack And State Behavior Across Enemy Kinds

## Goal

Bring the four enemy kinds onto one consistent shape for attack execution, attack-data fallbacks, charge movement, and state-identity wiring. The prior enemy consolidation work introduced a shared attack-data resource and a shared state-machine lifecycle, but stopped partway: one enemy kind still runs a private near-duplicate of the shared tile-attack component, two kinds bypass shared preparation entirely for their single-hitbox attacks, charge movement is implemented twice, and every kind carries copy-pasted state-identity overrides and a mixed node-lookup convention. This plan closes that gap by giving attacks exactly two shared preparation paths — one for tile-footprint attacks, one for single-hitbox attacks — so "how an enemy attacks" and "how an enemy's state machine is wired" are each expressed once per delivery family.

## Requirements

1. Attack preparation splits into two shared executors by delivery shape, not one universal component, because tile-footprint attacks and single-hitbox attacks are genuinely different mechanics rather than variations of the same one. A tile executor owns computing a cell footprint from an attack profile, showing the per-cell telegraph, and placing one stationary hitbox per cell — every enemy kind whose attack occupies a set of readable grid cells uses this same executor instead of a private near-duplicate. A point executor owns configuring a single hitbox's damage, damage interval, and guard profile from an attack profile and enabling/disabling it for the active window — every enemy kind whose attack rides a single hitbox (dashing along with the enemy, expanding in place, or in the future traveling independently as a projectile) uses this same executor instead of hand-rolling the same configuration step per kind. Bespoke delivery — a charging enemy's dash traversal, a hazard enemy's expand/shrink visual, a future projectile's travel path — stays owned by its enemy or state in both cases, since only the preparation plumbing is duplicated today, not the delivery itself.
2. Compatibility default attack profiles (used only when an enemy scene has no authored attack data) come from one shared default-profile source instead of four separately hardcoded copies, so a future tuning change does not require hunting through every enemy script. The currently-authored per-enemy data resources remain the source of truth during normal play and are unaffected; the shared source only changes where the never-exercised fallback numbers live.
3. The behavior of driving an enemy through a sequence of grid cells at charge speed — including mid-charge visual feedback and per-cell telegraph clearing — is implemented once and used by every enemy performing a charge-style attack, so a dedicated charging enemy and a mode-switching enemy's charge choice look and feel identical to the player.
4. State-identity queries that only restate the shared default (the enemy kind does not actually change which state ID a lifecycle step uses) are removed from individual enemy kinds; a query stays overridden on a specific kind only when that kind's behavior for that step genuinely differs from the shared default.
5. Every enemy kind locates its attack-related child nodes (hitboxes, telegraph) through the same lookup convention, so wiring or auditing an enemy's attack nodes does not depend on remembering which of two lookup styles that particular kind uses.

## Design

Attack behavior for any enemy kind splits into three responsibilities: **profile selection** (which attack, and when to commit to it), **preparation** (turning a profile into hitboxes, damage values, and telegraph cells), and **delivery** (the per-kind movement or visual flourish that plays out while the attack is active). Profile selection and bespoke delivery are legitimately different per kind and stay on the enemy or its state.

Preparation is not one shape, though — it is two. A **tile attack** occupies a discrete set of grid cells: the footprint is computed once from the profile, telegraphed cell by cell so the player reads exactly where damage will land, and delivered as one stationary hitbox per cell. This is the readable, board-legible attack family and is the one intended to carry the most future attack variety, since a player can learn a cell footprint the way they cannot learn a free-form area. A **point attack** delivers damage through a single hitbox whose position is driven by something other than a cell array — it rides along with a dashing body, expands in place around the enemy, or, for a future projectile, travels independently from an origin. Both families still compute a cell footprint internally where one is meaningful (a charge's line, a hazard's range check), but only the tile family turns that footprint into the literal set of damage-dealing objects; the point family turns it into at most a telegraph and otherwise uses it only for planning.

Each family gets exactly one shared executor. The **tile attack executor** covers cell computation, per-cell telegraph display, and per-cell hitbox lifecycle. The **point attack executor** covers stamping damage/interval/guard-profile values from a profile onto the one hitbox a point attack uses, and enabling/disabling it for the active window; it optionally drives the same cell-based telegraph when the attack has a footprint worth warning about, and is skipped when the attack telegraphs itself through body or VFX changes instead.

For a mode-switching enemy, this means each per-mode attack becomes "pick a profile, then hand it to whichever shared executor matches that mode's family" rather than a parallel implementation that duplicates cell-shape math, damage constants, and no-data fallback geometry for all three modes at once.

For a dedicated charging enemy and a mode-switching enemy's charge choice, both currently step through the same kind of cell sequence at charge speed under the point family, but only one of the two plays the mid-charge streak feedback and reads as a fully realized attack. Consolidating the traversal behavior means both read identically: same arrival snapping, same per-cell telegraph clear, same visual feedback, driven from a single implementation rather than one polished copy and one simplified copy.

For a hazard enemy whose attack is an expanding zone rather than a directional hitbox, it adopts the point executor for its damage/interval/guard-profile plumbing like every other point-family attack, but skips the shared cell-based telegraph — its circular hitbox geometry and its expand/shrink visual lifecycle are genuinely unique among the four kinds and are not being forced into either executor's telegraph or footprint-to-hitbox path.

Fallback default profiles exist purely as a safety net for a scene that ships without authored attack data; every enemy scene in the project already ships authored data today, so this path is not exercised in normal play. Consolidating the fallback source is about removing duplicated dead numbers, not changing behavior — the shared source should reproduce the exact values each kind hardcodes today.

State-identity queries (which state ID represents idle, reposition, facing, recovery, staggered, dead, and so on for a given enemy kind) are already meant to be inherited from the shared lifecycle unless a kind's behavior diverges. Several kinds currently restate the inherited value anyway, and one kind restates most of them but skips one — this plan removes the restatements that carry no behavioral difference, so the presence of an override becomes a reliable signal that the kind actually does something different at that step.

## Non-Goals

1. No balance or numeric changes — every authored and fallback attack value is numerically identical after consolidation.
2. The hazard enemy's expand/shrink visual lifecycle and its circular hitbox geometry stay bespoke; only its damage/telegraph-adjacent plumbing is in scope.
3. No new enemy kinds, no spawn-weighting or wave-system changes.
4. No change to the values already authored in per-enemy data resources.
5. No change to guard, stagger, health, or death handling, which is already shared and unaffected by this plan.

## Acceptance Criteria

1. Every tile-family attack across every enemy kind is prepared by the one shared tile executor, and every point-family attack across every enemy kind is prepared by the one shared point executor; no enemy kind hand-configures a hitbox's damage fields outside its family's shared executor.
2. A charge-style attack looks and behaves identically — traversal, per-cell telegraph clearing, mid-charge visual feedback — regardless of which enemy kind performs it.
3. Exactly one place produces compatibility default attack profiles; no enemy kind hardcodes its own fallback numbers.
4. No enemy kind overrides a state-identity query unless its behavior for that lifecycle step actually differs from the shared default.
5. All enemy kinds use the same child-node lookup convention for attack-related nodes.
6. Existing gameplay behavior — damage numbers, timings, attack shapes — is unchanged for every currently authored enemy attack profile after the consolidation.
