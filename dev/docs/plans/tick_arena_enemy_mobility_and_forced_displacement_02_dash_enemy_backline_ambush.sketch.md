# Tick Arena Enemy Mobility And Forced Displacement 02: DashEnemy Backline Ambush

Parent Plan: `tick_arena_enemy_mobility_and_forced_displacement.md`

## Goal

Explore a new five-cell DashEnemy that commits to a visible through-player landing, teleports across the player, and attacks from the opposite side only when the locked landing remains available.

## Summary

DashEnemy should reuse the tick arena's committed-warning grammar and player Dash's line/landing readability without copying player mobility code into an enemy. Its identity is positional threat rather than collision force: it reserves no right to displace blockers, cancels when the landing becomes unavailable, and attacks the locked player cell without retargeting.

Because the player has no combat facing, "behind" means the cell one step beyond the player along DashEnemy's cardinal approach line. This geometric definition stays honest with the existing player contract and makes the telegraph sufficient to understand the attack.

## Sketch

- The candidate commit check searches a cardinal line up to five cells and requires both the player cell and the one-cell-beyond landing to be valid at windup start. Under the shared enemy-action contract, commitment derives and presents the approach direction in the same funded action rather than paying a separate facing turn.
- The committed data likely needs the approach direction, locked player cell, path through the player, and locked landing cell. The warning display should distinguish the danger cell from the landing marker.
- The landing validity check should use the same land/occupancy truth as player Dash and enemy movement, but DashEnemy must not inherit player Dash victims, Mobility rewards, range bonuses, or cooldown rules.
- At detonation, revalidate only the committed landing cell. If it is non-land or occupied by the player, another enemy, or a future blocking actor, cancel the attack, clear presentation, and enter normal recovery without teleporting or dealing damage.
- If the landing remains valid, update DashEnemy logical occupancy immediately, play a teleport/dash visual to the locked landing, and resolve its attack against the locked player cell. A player who moved during windup is not followed and takes no hit.
- The teleport itself does not damage actors along the approach line and does not push anything. Those behaviors belong to ChargeEnemy and future explicit effects.
- DashEnemy needs a readable body/marker distinct from ChargeEnemy's Skull charge language, but final art selection can remain placeholder presentation inside the later implementation spec.
- Candidate files to inspect: `game/entities/enemies/charge_enemy.gd` for committed-line hooks, `game/tick_arena/combat/tick_action_planner.gd` for player Dash geometry concepts, `game/entities/enemies/grid_enemy.gd`, `game/entities/enemies/enemy_tick_runtime.gd`, `common/gameplay/grid/grid_arena.gd`, `game/tick_arena/combat/tick_engine.gd`, enemy spawn data/pool ownership, and new focused DashEnemy tests.

## Non-Goals

1. No collision damage, blocker displacement, or player push.
2. No player-facing combat direction; behind remains approach-relative geometry.
3. No retarget after windup.
4. No invisible fallback teleport when the committed landing is occupied.
5. No Viking Smash Knockback or ChargeEnemy collision rework inside this child.

## Acceptance Criteria

1. DashEnemy commits only when the player and the approach-relative landing are within the readable five-cell cardinal setup.
2. Windup shows the locked attack cell and landing before resolution.
3. An occupied landing at detonation cancels the attack with no teleport or damage.
4. A valid detonation places DashEnemy across the locked player cell and damages only a player who remained in that cell.
5. DashEnemy turns and commits without a separate FaceTarget action, and never pushes blockers, damages path occupants, reads player facing, or retargets during windup.

