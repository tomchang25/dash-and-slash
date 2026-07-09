# Tick Arena Visual Readability 01: Enemy Sprite Readability Scaffold

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Explore the first visual-readability child: replacing pure prototype enemy bodies with low-cost state sprites that make enemy state, facing, and attack intent readable before expanding enemy pattern count.

## Summary

The favored first pass is a scaffold, not a final animation pass. SmallEnemy should gain four-direction, low-frame state presentation for Idle, Move, Prepare Attack, and Attack while continuing to rely on existing telegraph, guard, and tick-combat behavior. Motion can be sold with offset, squash/stretch, rotation, flash, windup VFX, and attack VFX rather than full animation.

The later implementation spec should verify the current enemy scene and base-class presentation hooks. Codebase context gathered so far suggests SmallEnemy still uses a simple Polygon2D body and facing arrow, while GridEnemy already owns shared guard/status and attack windup cleanup paths.

## Sketch

- Candidate shape: add a small visual presenter under each supported enemy scene, starting with SmallEnemy, that can switch state/facing visuals without taking ownership of AI, tick runtime, guard, health, or attack resolution.
- SmallEnemy is the first target because it is already the 1x1 pattern enemy and currently uses a prototype square body plus facing arrow in its scene.
- Four state groups are enough for the first pass: Idle, Move, Prepare Attack, Attack. Stagger/death can keep existing feedback unless the later spec finds a cheap reuse path.
- Four directions should be authored or generated per state so front/side/back combat remains readable. The facing arrow can remain during the scaffold if sprites alone do not yet read.
- The scaffold should be compatible with existing telegraphs. Body pose should reinforce danger direction but never become the sole source of attack truth.
- Candidate files to inspect at spec time: `game/entities/enemies/small_enemy.tscn`, `game/entities/enemies/small_enemy.gd`, `game/entities/enemies/grid_enemy.gd`, `common/gameplay/view/enemy_status_bars.tscn`, and shared VFX helpers.
- The later spec should decide whether sprite resources live in the enemy scene directly, as a reusable enemy-visual child scene, or as data referenced by enemy identity. Keep the first pass narrow enough that it does not become a full asset pipeline.
- Avoid tying visuals to continuous animation time. Tick combat is action-counted, so clear pose changes and short tweens are a better first language than frame-heavy looping animation.

## Non-Goals

1. No final art pass or polished sprite-sheet pipeline.
2. No new enemy patterns, spawn ratios, or attack data changes.
3. No replacement of enemy AI, tick runtime, guard, health, or telegraph ownership.
4. No player class visuals in this child.

## Acceptance Criteria

1. SmallEnemy no longer reads as a pure prototype square body during normal combat.
2. Idle, movement, attack preparation, and attack resolution are distinguishable without reading debug text.
3. Facing and attack intent remain readable enough to support flank, guard, and back-hit decisions.
4. The scaffold is cheap enough to extend to later SmallEnemy pattern identities.
