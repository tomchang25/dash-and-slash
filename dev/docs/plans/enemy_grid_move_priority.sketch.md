# Enemy Grid Move Priority

## Goal

Add a simple priority rule for enemies competing for the same grid destination so movement near the player stays predictable when enemy density rises.

## Requirements

1. When multiple enemies want to move into the same grid cell, the enemy with an attack-committed move has the highest priority, because committed attacks should not be invalidated by ordinary repositioning.
2. Attack-priority movement may ignore a blocked destination only for the committed attack case, so the exception does not turn ordinary chasing into overlap chaos.
3. Among non-attack moves, the enemy closer to the player has higher priority so pressure near the player resolves before distant movement.
4. When distance is tied, the enemy that registered or planned earlier wins so resolution is deterministic.
5. Losing enemies must replan, idle, or keep their previous cell safely rather than overlapping or entering an invalid grid state.
6. The first version should remain easy to inspect in debug mode because movement-priority bugs are most visible when several enemies crowd the same target cell.

## Design

Priority should resolve at the moment enemies reserve or commit to a destination, not after they have already moved. Treat priority as a tuple sorted by attack intent, distance to player, and registration order. A higher-priority claimant owns the contested cell; lower-priority claimants must clear that reservation and choose a fallback on their next planning cycle.

Attack intent means an enemy is committing to an attack-position or attack-motion destination, not merely walking toward the player. The blocked-cell exception should be narrow: an attack that is allowed to enter the player grid or a target-occupied grid may do so only while its attack state expects that behavior.

## Sketch (non-normative)

Suggested priority tuple:

```gdscript
priority = {
    "is_attack": true,
    "distance_to_player": 2,
    "registration_index": 41,
}
```

Suggested implementation steps:

1. Give grid reservations enough metadata to compare two claims for the same cell.
2. Add a monotonic registration index on the grid or enemy setup path so equal-distance ties are deterministic.
3. Let enemy planning submit reservation intent as ordinary move or attack-committed move.
4. When a new claim conflicts, compare priority and either replace the old claim or reject the new claim.
5. If a claim is replaced, notify or allow the old enemy to clear its planned path before it moves.
6. Keep debug drawing or labels available for contested cells so playtests can see why one enemy won.

## Non-Goals

1. No full squad AI, formation behavior, or crowd steering.
2. No replacement of the current grid pathfinding algorithm.
3. No priority rules for enemies larger than one grid cell unless a later enemy type requires it.

## Acceptance Criteria

1. Two ordinary enemies targeting the same cell do not overlap; one wins and the other replans or waits.
2. A committed attacking enemy wins over an ordinary repositioning enemy for the same destination.
3. Distance to the player resolves ordinary movement conflicts before registration order is used.
4. Equal-distance conflicts resolve consistently across repeated runs with the same enemy registration order.
5. The grid never ends a movement resolution frame with two enemies owning the same ordinary occupancy cell.
