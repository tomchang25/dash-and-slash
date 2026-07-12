# Tick Arena Enemy Combat Roles And Counterpressure 07: Role-Aware Spawn Formations

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Add authored placement intent so completed enemy roles enter as coherent pressure groups instead of uniformly scattered actors that chase and die one by one.

## Summary

The favored extension lets each authored group choose a formation or distance-band placement policy while preserving its composition, eligibility, warning timing, and population cap. Melee roles form an arc or cluster, Ranged occupies a backline band, and Bomb enters from a flank or overlapping follow-up group.

## Sketch

- The current spawn planner intentionally spreads batch members around the player. The later spec should verify a minimal authored placement vocabulary such as spread, cluster, arc, backline, and flank rather than introducing a general encounter director.
- A group should resolve one placement anchor and then assign its members relative to that anchor, preserving deterministic ordering and legal-cell revalidation. Invalid members must retain source-group and formation identity when requeued.
- Placement intent must not bypass earlier eligible group queues, reserve more than one warning batch, exceed population headroom, or change fixed endless composition between waves.
- Melee clusters should remain readable and avoid unavoidable body walls. Ranged backline placement should respect its attack annulus. Bomb flank placement must preserve the player's escape space at warning time.
- This child should integrate the provisional production roster and remove retired Pierce, Burst, and standalone Puff entries, but must stop before final counts, weights, warning durations, and curve tuning.
- Candidate files to inspect include wave group schemas and validation, authored wave content, spawn planning and revalidation, group queue entry identity, telegraph presentation, deterministic RNG boundaries, and formation-specific scheduling tests.

## Non-Goals

1. Do not finalize demo or endless balance, population caps, group counts, role weights, or level curves.
2. Do not add procedural wave generation, adaptive difficulty, reward-driven formations, or new group start conditions.
3. Do not expand the roster beyond Thrust, Slash, Charge, Bomb, Ranged, Mode, and the placeholder Boss.

## Acceptance Criteria

1. Authored groups can request readable melee, backline, and flank placement without changing ordered scheduling semantics.
2. Formation batches remain deterministic, population-safe, revalidation-safe, and associated with their source group after requeue.
3. Production content uses the completed roster and placement vocabulary while leaving final balance to the deferred wave-progression child.
