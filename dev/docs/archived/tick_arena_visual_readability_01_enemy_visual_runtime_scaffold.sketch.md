# Tick Arena Visual Readability 01: Enemy Visual Runtime Scaffold

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Explore the first implementation-facing visual slice: replacing prototype enemy body rendering with a small enemy visual presenter that can display direction and state from sprite frames without owning combat behavior.

## Summary

The favored first pass is runtime scaffolding, not asset production. SmallEnemy should keep its current AI, tick runtime, guard, health, telegraph, and attack ownership while gaining a child visual presenter that can read a simple visual intent such as idle, move, prepare attack, or attack plus facing direction and turn that into Sprite2D frame selection and cheap presentation effects.

Ninja Adventure is now the main visual reference. Its common character and monster frames are 16x16 source pixels, commonly arranged as 4-column or 4-by-4 sheets, and the sample project drives sprites with Sprite2D `hframes`, `vframes`, and `frame_coords` rather than AnimationTree. The first implementation spec should verify the live enemy hooks, but the direction should stay close to a thin reusable sprite-frame animator plus an enemy-specific presenter.

## Sketch

- Candidate shape: add a low-level directional sprite animator that only knows how to select frames from a Sprite2D atlas, then add an EnemyVisualPresenter that maps enemy-facing and enemy-visual-state intent onto that animator.
- SmallEnemy remains the first target because it is already the 1x1 pattern enemy and currently uses a prototype square Polygon2D body plus a facing arrow in its scene.
- The presenter should receive visual intent from existing gameplay flow rather than becoming another source of state truth. The current StateMachine and attack/tick flow remain responsible for behavior, while the presenter displays what those systems report.
- Avoid a full Animation FSM for the first child. The presenter can have a tiny priority resolver for one-shot cues, stagger/death overrides, or attack flashes, but it should not decide when an enemy acts, attacks, recovers, or dies.
- Avoid AnimationTree for this scaffold. AnimationPlayer can remain a later or optional helper for flash, offset bump, squash, or hit feedback, but sprite state selection should not depend on designer-authored animation graph wiring.
- Use 16x16 source sprites at integer render scale in Godot. In the 128px gameplay tile, 5x scale gives an 80px body and 6x gives a 96px body; the first spec should pick a default that leaves telegraphs, status bars, and facing aids readable.
- The facing arrow can remain during the scaffold if sprite direction alone does not yet read. The later pose-sheet child can decide whether the arrow becomes subtler or disappears.
- Candidate files to inspect at spec time: `game/entities/enemies/small_enemy.tscn`, `game/entities/enemies/small_enemy.gd`, `game/entities/enemies/grid_enemy.gd`, enemy state scripts, enemy attack/tick runtime hooks, `common/gameplay/view/enemy_status_bars.tscn`, Ninja Adventure actor sprite sheets, and project texture import/filter settings.

## Non-Goals

1. No final SmallEnemy art or polished pose sheet.
2. No AI image generation, Comfy pipeline, or prompt-config pipeline.
3. No new enemy patterns, spawn ratios, or attack data changes.
4. No player class visuals or player aim marker work in this child.
5. No replacement of enemy AI, tick runtime, guard, health, telegraph, attack resolution, or gameplay StateMachine ownership.

## Acceptance Criteria

1. SmallEnemy can display sprite-based direction and core visual state without replacing its gameplay state ownership.
2. The scaffold can use Ninja Adventure-style 16x16 source frames at integer scale inside the 128px tick arena tile.
3. Idle, movement, attack preparation, and attack resolution can be expressed through visual intent calls even if placeholder sprites are used.
4. The runtime contract is narrow enough to support the later baseline pose sheet and pattern identities without committing to a final art pipeline.
