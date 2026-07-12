# Tick Arena Enemy Combat Roles And Counterpressure 05: Ranged Enemy Cross Pressure

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Add one stable Ranged role that pressures distant cells and retreats from adjacent players, breaking the all-enemies-chase convergence without introducing hidden pattern variants.

## Summary

Ranged uses the Small Guard profile, cannot attack inside the adjacent ring, may target within six cells, and locks one Cross footprint around the selected target cell during windup. The first version has one authored attack and one visible identity; additional patterns and Curse Artifact delivery are excluded.

## Sketch

- Planning should operate on an attack annulus rather than ordinary adjacency: seek a legal attack position inside maximum range, retreat or reposition when the player enters minimum range, and avoid oscillating between equivalent cells.
- Commit should snapshot the target cell and Cross footprint. The player may leave during windup; detonation checks the locked cells and never retargets.
- Verify whether range uses Chebyshev distance consistently with the existing adjacent-ring language and whether terrain or occupied cells may appear inside the footprint without blocking the shot.
- Ranged should use one stable warning duration, damage value, and presenter identity so the first tactical read is role and footprint rather than random attack selection.
- The shared hit-facing response still applies outside committed windup, but Ranged path planning after facing should preserve its distance-band goal instead of falling back to melee approach.
- Candidate files to inspect include shared path planning and attack-cell helpers, grid enemy planning seams, attack data, telegraph/danger presentation, spawn data, and range/retreat/locked-target tests.

## Non-Goals

1. Do not add single-cell, three-by-three, or randomly selected Ranged variants in the first version.
2. Do not introduce Ranged through Curse Artifacts or change endless composition based on rewards.
3. Do not add projectiles, line-of-sight walls, ammo, cover, or persistent hazards.

## Acceptance Criteria

1. Ranged seeks and preserves a readable two-to-six-cell engagement band instead of joining melee chase behavior.
2. Ranged locks one Cross footprint, never retargets during windup, and resolves preview and committed cells identically.
3. An adjacent player prevents firing and causes a meaningful retreat or reposition attempt.
