# Tick Arena Enemy Mobility And Forced Displacement 03: Viking Smash Knockback

Parent Plan: `tick_arena_enemy_mobility_and_forced_displacement.md`

## Goal

Explore Viking's first Smash-required Major as a one-cell radial knockback applied after Smash damage, using forced-displacement and occupancy behavior proven by the ChargeEnemy collision rework.

## Summary

Smash Knockback belongs to Viking's class-exclusive Major pool and never replaces Mobility. The favored direction is a one-cell push away from the locked Smash landing center for every surviving victim in the 3x3 impact area, with damage resolving first and blocked pushes leaving the victim in place without extra collision damage.

This child intentionally lands after ChargeEnemy proves the shared forced-displacement contract. The later spec should reuse that relocation/occupancy seam while keeping Smash-specific radial planning and preview inside tick-arena combat code.

## Sketch

- The artifact should require Smash eligibility, so only Viking can roll it under the fixed-Mobility class model.
- The existing Smash resolution already locks a landing, previews a 3x3 victim set, applies damage, and then moves the player. Knockback likely belongs after each surviving hit outcome is known but before the final presentation settles.
- Direction is the sign of each victim's offset from the Smash center, allowing all eight neighboring directions. The landing center is required to be open for the player, so a living enemy should not occupy the zero-offset cell when the Smash releases.
- Push distance is exactly one cell. A destination must be in-bounds land and unoccupied by player, enemy, or blocking actor; otherwise the victim stays in place.
- Blocked knockback causes no extra damage, stagger, bounce, chain push, or Environment damage in the first version.
- If several victims are pushed, compute the victim set from the pre-knockback Smash snapshot and resolve destinations deterministically so iteration order cannot change eligibility. The later spec should verify whether radial one-cell destinations can ever conflict and define a stable fallback if future larger bodies make that possible.
- Committed preview should show the post-hit destination or blocked state for every predicted surviving victim. It must share the same displacement planner as commit rather than drawing a cosmetic arrow from separate math.
- Forced movement clears each enemy's planned path/reservation and updates logical occupancy before tween/VFX presentation, matching the contract proven by ChargeEnemy.
- Candidate files to inspect after the ChargeEnemy slice lands: `game/tick_arena/combat/tick_action_controller.gd`, `game/tick_arena/combat/tick_preview_controller.gd`, `game/tick_arena/combat/tick_hit_outcome.gd`, `game/tick_arena/view/tick_grid_view.gd`, the landed forced-displacement helper/owner, reward artifact data, and focused Smash Major tests.

## Non-Goals

1. No additional ChargeEnemy or DashEnemy behavior inside this child.
2. No push distance upgrades, collision damage, chain reactions, or destructible Environment.
3. No change to Smash's windup, target range, 3x3 damage area, cooldown, or player landing.
4. No generic access from Ninja/Dash; this is a Smash-required Viking Major.

## Acceptance Criteria

1. Viking can roll Smash Knockback and Ninja cannot.
2. Smash damage resolves before each surviving victim attempts a one-cell radial push.
3. Valid destinations relocate victims and clear stale movement plans; invalid destinations leave victims in place without bonus damage.
4. Preview and committed knockback destinations agree for every victim.
5. Smash windup, damage area, player landing, cooldown, and non-knockback behavior remain unchanged when the Major is absent.
