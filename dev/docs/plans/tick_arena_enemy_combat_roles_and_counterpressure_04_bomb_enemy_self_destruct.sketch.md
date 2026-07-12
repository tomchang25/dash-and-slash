# Tick Arena Enemy Combat Roles And Counterpressure 04: Bomb Enemy Self-Destruct

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Add a guardless Bomb role that creates a kill-or-evade deadline instead of another Guard-and-Stagger target.

## Summary

Bomb approaches until the player is inside the adjacent ring, locks a three-by-three explosion centered on itself, winds up for three player-action ticks, deals 50 damage on detonation, and then kills itself. Killing Bomb before detonation disarms it; it has no Guard, Stagger, or post-Stagger protection.

## Sketch

- Bomb should use the shared tick runtime for a committed footprint and countdown, but its self-kill must happen after detonation damage and use the normal death/wave bookkeeping path.
- The explosion remains locked to the Bomb's commit cell. Player movement can escape it, and the attack must not follow the player's new position.
- The guardless contract likely requires hit snapshots and status presentation to treat absent or zero-max Guard as no Guard rather than a permanently blocking empty Guard component.
- Bomb movement should stop once the fuse commits. Death before detonation must clear the warning and prevent damage; detonation must clear presentation exactly once before self-death.
- The role replaces standalone Puff and Small Burst production pressure, but Mode may keep its own area attack language.
- Candidate files to inspect include the shared grid enemy and tick runtime, current area-threat behavior, attack data vocabulary, enemy scene/data/presenter patterns, wave death bookkeeping, danger display, and focused detonation/death tests.

## Non-Goals

1. Do not give Bomb Guard, Stagger, Enrage, persistent hazards, chain explosions, collision damage, or ally damage in the first version.
2. Do not replace Mode's existing area mode.
3. Do not finalize Bomb counts or wave placement before the formation child.

## Acceptance Criteria

1. Bomb clearly commits a three-tick three-by-three explosion and cannot move or retarget during the fuse.
2. Killing Bomb before detonation removes the threat; an unresolved Bomb deals 50 damage in its locked footprint and then dies through normal bookkeeping.
3. Bomb never displays Guard, receives blocked-hit reduction, enters Stagger, or starts post-Stagger protection.
