# Tick Combat Rework 06: Run Loop Recalibration

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Bring the full run loop — waves, rewards, terrain cadence, death and restart — into the tick arena, recalibrated for tick pacing where each enemy is a puzzle piece and density past legibility is noise.

## Requirements

1. The wave controller, spawn planner, and spawner convert in place and rehome into the tick arena scene, keeping their data-driven counts and pressure projections intact; what changes is clock and pacing math, not ownership.
2. Concurrent enemies are capped low: initial formula clamp(3 + floor(wave / 5), 3, 6), replacing the real-time era's 12 + floor(wave/5)*4; overflow spawns queue exactly as today. Wave *size\* can exceed the cap — the cap shapes simultaneous pressure, the wave total shapes duration.
3. Spawn telegraphs count in ticks (initial: 2) and spawn cells resolve against occupancy at detonation like any other telegraph.
4. Terrain cadence carries over unchanged conceptually: Tile Op once per normal wave clear, Expand Land x10 on milestone waves, land connectivity as the only hard rule. Corrupt Land converts to the tick rule: standing on it when stage 3 resolves deals its tick damage; dash pass-through is immune.
5. Milestone scaling (Def/HP/Damage, never Guard) and the elite schedule carry over; the reward overlay and death/restart flow are reused as-is — reward choice and wave gaps are real-time UI moments, which is safe because with no enemies acting the world is effectively frozen anyway.
6. Arena size shrinks to the prototype-proven scale: initial 12x12 grid with 10x10 starting land (down from 16x16/8x8), because a one-cell-per-tick player experiences the old arena as empty travel time; Expand Land growth still fits within bounds.
7. The phase preserves the production grid presentation attached in phase 1a while retuning grid dimensions and terrain cadence; terrain mutation must refresh the same TileMapLayer/autotile path rather than introducing run-loop-specific drawing.

## Design

- Wave pressure knobs in tick world, in priority order: composition (which kinds spawn together), spawn geometry (where they enter relative to the player), then counts. Reward pressure effects keep raising future counts/toughness exactly as they do today.
- Every existing reward effect must still offer and apply correctly; stats redefined by the pivot (attack range, dash range, cooldowns already re-based in earlier phases) get explicit re-mapping notes in the phase spec.
- The wave-balance chore in the TODO (retune scaling constants toward the 20/30-wave target curve) folds into this phase's playtest rather than surviving as separate real-time-era work.

## Sketch (non-normative)

- `WaveScaling` constants and `EnemySpawnPlanner` counts get a tick-world tuning pass; formulas stay, numbers change.
- Spawn telegraph state moves onto the engine's danger display path so spawn warnings render in the same countdown language as attacks.
- `GridArena` export sizes change in the tick arena scene; the legacy arena has been non-functional since phase 2 and keeps its stale values until phase 7 deletes it.
- Corrupt Land damage hooks into stage 3 of the engine's resolution instead of a wall-clock 0.5 s timer.
- Terrain mutation continues to notify the production grid presentation path introduced in phase 1a, so Add/Move/Remove Land and milestone expansion preserve connected-autotile visuals during a run.

## Non-Goals

1. No spawn-weight data drive, no pattern director, no new reward cards — separate follow-up work.
2. No reward-choice UI rework.
3. No difficulty director; growth stays simple formula-based.

## Acceptance Criteria

1. A full run — waves, rewards, terrain mutation, milestone elites, death, restart — plays end to end in the tick arena.
2. Concurrent enemies never exceed the cap; overflow queues and drains as kills free slots.
3. Every reward effect existing at conversion time offers and applies correctly, with re-mapped stats explicitly accounted for.
4. Corrupt Land damages only a standing (non-dash) player, on the tick, visibly distinct from enemy telegraphs.
5. Add/Move/Remove Land and Expand Land update the production TileMapLayer/autotile presentation correctly in the tick arena.
