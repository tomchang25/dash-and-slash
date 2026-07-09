# Tick Arena Visual Readability 02: SmallEnemy Baseline Pose Sheet

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Explore the first SmallEnemy visual asset slice: establishing a readable baseline pose sheet for idle, movement, attack preparation, and attack once the runtime presenter can display direction and state.

## Summary

This child owns the first real SmallEnemy pose language. It should adapt or extend Ninja Adventure-style 16x16 pixel art rather than inventing a separate high-resolution sprite style. The expected source is either a selected asset-pack monster/character sheet, a small hand-edited derivative, or a GPT-assisted first draft that is cleaned back into the same 16x16 pixel grammar.

The baseline pose sheet is a readability proof, not a final art bible. The important result is that the same small enemy body can read as idle, moving, preparing an attack, and resolving an attack in four directions at gameplay size.

## Sketch

- Candidate asset contract: 16x16 source frames, four directions, and four visual states: idle, move, prepare attack, and attack. The runtime scaffold can decide whether these live in one combined sheet, several state sheets, or a resource map.
- The first readable sheet should favor silhouette and pose over detail. Prepare attack needs the strongest distinction because it must agree with danger tiles and make the attack feel authored rather than arbitrary.
- Godot should scale the 16x16 frames at an integer factor, likely 5x or 6x inside 128px gameplay tiles. Upscaling should not be a first-line production step unless the project deliberately moves away from pixel-art readability.
- GPT image generation can be used for a first draft only if the output can be brought back to the Ninja Adventure pixel grammar. A Comfy batch pipeline should wait until pattern variants need repeatable production.
- The first pose sheet should be tested in-combat, not judged only as a sprite sheet. Facing, attack intent, status bars, telegraphs, and player readability all share the same tile space.
- Candidate files to inspect at spec time: Ninja Adventure actor and monster sprite sheets under `assets/Ninja Adventure - Asset Pack/Actor/`, any imported texture settings for the chosen placeholder sheets, the enemy visual presenter from child 01 once it exists, and `game/entities/enemies/small_enemy.tscn`.

## Non-Goals

1. No reusable runtime presenter work beyond whatever child 01 already shipped.
2. No SmallEnemy pattern variants or spawn weighting.
3. No final asset pipeline, Comfy workflow, or batch prompt configuration.
4. No character class or player aim marker visuals.

## Acceptance Criteria

1. The baseline SmallEnemy body reads as the same enemy across all four directions.
2. Idle, movement, attack preparation, and attack resolution are visually distinguishable at gameplay scale.
3. The pose sheet remains compatible with Ninja Adventure-style 16x16 source art and integer Godot scaling.
4. The pose language is clear enough to become the base for later SmallEnemy pattern identities.
