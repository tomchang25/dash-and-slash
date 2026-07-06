# Tick Combat Rework: Cutover And Closeout

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Make the tick arena the production arena: remove the real-time player path, route production scenes to the tick arena, synchronize the design document, and close out the rework.

## Requirements

1. Scene routing sends production play to the tick arena; no production scene routes to the real-time arena, and the routing change follows the scene-routing standard.
2. The real-time player path is deleted: the free-movement player controller and its states, the old arena scene (non-functional since phase 2's in-place enemy conversion), and the prototype folder (its job ended when phase 1 productionized it). Deletion happens only after run-loop parity is confirmed in phase 6.
3. The physics combat path retires where the tick world made it dead: player-side attack hitboxes and enemy-to-player hit volumes are gone; components that still carry live responsibilities (health, guard, status bars, VFX) stay. Every removal is verified dead by search, not assumption.
4. The forward surface is re-anchored: TODO Draft entries written against the real-time world (sprite readability scaffold, pattern director, spawn ratio drive, weapon class variants) are reworded to tick-world terms or retired; anything superseded by shipped rework phases is deleted.
5. The design document is synchronized to shipped reality: the v0.5 draft banner comes off, resolved deferred-list items close with their outcomes, and v0.5 stands as the single design truth.
6. The rework closes out through the standard closeout workflow: shipped-work history entries, plan and phase files archived, no open-work pointer left behind.

## Design

- Cutover is the point of no return for the file tree, which is why it is last. Rollback has been version control plus the exported baseline build ever since phase 2's in-place enemy conversion broke the legacy arena; this phase only deletes the already-dead remains.
- Save compatibility: run state is not persisted mid-run today, so cutover carries no save-migration risk; the settings and meta save surfaces are untouched by the rework. If any phase before this changed a persisted shape, its own spec owns the migration note (save-migration rules apply).

## Sketch (non-normative)

- Routing: `SceneRouter` arena target swaps to `tick_arena.tscn`; main-menu flow untouched.
- Deletion sweep: `game/entities/player/` free-movement controller and states, `dash_and_slash_arena.tscn/.gd`, `game/scenes/prototype/tick_combat/`; grep for dangling references (preloads, debug panel actions, tests) before each removal.
- Collision-layer cleanup: player attack hitbox and enemy hit-volume layers removed from physics config where no live consumer remains.
- Docs pass: GDD v0.5 header/§11.3 sync, TODO Draft rewrite, CHANGELOG entries per shipped phase, archive `tick_combat_rework.md`, the numbered phase sketches/specs, and this cutover closeout sketch.
- Weapon-class follow-up rewrite: any remaining real-time attack-speed language is translated into tick-world weapon data such as windup ticks, cooldown ticks, damage, shape, and guard profile; do not keep continuous attack-speed percentages or hidden variable player action costs as the planned direction.

## Non-Goals

1. No new features of any kind — this phase only removes, routes, and documents.
2. No new art or audio asset pass; this phase preserves the reused grid/VFX/SFX seams landed earlier but does not create new content.

## Acceptance Criteria

1. Production play routes only to the tick arena; the old arena, old player path, and prototype folder no longer exist in the repo.
2. No dead references remain (project loads clean, lint passes, no missing-resource errors on boot and a full run).
3. The design document matches shipped behavior with the draft banner removed, and after closeout no open-work pointer to the rework or its phase files remains outside the archive.
