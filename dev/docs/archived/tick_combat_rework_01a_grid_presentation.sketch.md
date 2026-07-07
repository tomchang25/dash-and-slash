# Tick Combat Rework 01a: Production Grid Presentation

Skeleton sketch written after phase 1 landed; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Move the phase 1 tick arena off grey-box grid drawing and onto the existing production grid presentation path before shared enemy systems convert in place, so the branch's playable tick arena keeps production terrain readability while later phases replace combat systems.

## Requirements

1. The tick arena uses the existing production terrain presentation stack for land, water, grid lines, arena bounds, telegraph colors, and terrain refreshes; the grid authority remains the same gameplay grid already used by phase 1.
2. TileMapLayer autotile behavior carries over for land and water, including local redraws when terrain cells mutate, because phase 6 terrain cadence should not need a second presentation migration.
3. Enemy danger telegraphs, spawn telegraphs, and player preview overlays remain visually separable: production danger telegraphs keep their enemy-danger palette, while player previews keep the phase 1/prototype player-side palette.
4. Grey-box drawing is retained only for debug-only prototype affordances that still have no production equivalent; it must not be the primary terrain renderer after this phase.
5. This phase does not change tick scheduling, player verbs, enemy conversion, wave flow, or reward flow — it is a presentation bridge between phase 1 and phase 2.

## Design

The tick arena should now look like a production arena with a tick player, not like the isolated prototype. This is deliberately a small bridge phase: it keeps the phase 1 tick contract stable while replacing the most disposable grey-box surface with the reusable presentation stack that already knows how to draw connected land, water, arena bounds, and telegraph phases.

## Sketch (non-normative)

- Proposed scene work: wire the tick arena scene to the existing `GridTerrainView` + `TileMapLayer` setup used by the legacy arena, pointed at the phase 1 `GridArena`.
- The existing `proto_grid_view` / tick grey-box view either shrinks to player-preview/debug overlay responsibilities or is replaced by a small tick preview renderer; terrain, water, arena bounds, and enemy danger telegraphs should no longer be drawn there.
- Keep the grid presentation reusable: do not add tick-specific terrain drawing paths when `GridArena` signals and `GridTerrainView` redraw hooks already express the needed updates.
- If phase 1 used smaller prototype grid dimensions, preserve those gameplay dimensions while attaching the production renderer; phase 6 owns the final arena-size tuning pass.

## Non-Goals

1. No enemy conversion; interim grey-box actors can remain until phase 2.
2. No combat VFX/SFX pass beyond preserving existing telegraph readability.
3. No new art assets, tilesets, terrain types, or UI redesign.

## Acceptance Criteria

1. The tick arena renders land, water, grid lines, arena bounds, and telegraphs through the production grid presentation path rather than grey-box terrain drawing.
2. Terrain cell changes refresh the production TileMapLayer/autotile presentation correctly in the tick arena.
3. Player previews and enemy danger telegraphs remain visually distinct and readable.
