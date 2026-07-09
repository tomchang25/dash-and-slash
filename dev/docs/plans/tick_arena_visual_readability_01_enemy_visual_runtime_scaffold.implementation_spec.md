# Tick Arena Visual Readability 01: Enemy Visual Runtime Scaffold

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Add a narrow enemy visual runtime scaffold so SmallEnemy can display sprite-based facing and combat state while the existing tick enemy behavior remains the source of truth.

## Summary

SmallEnemy currently reads as a colored square Polygon2D with a separate facing arrow. This spec replaces that first visual read with a fixed scene child that displays Ninja Adventure-style 16x16 sprite frames at integer scale inside the 128px tick arena tile. The first implementation should use an existing 64x64 monster sheet as placeholder art, so the result proves the runtime contract before the baseline pose sheet is authored.

The change is presentation-only. GridEnemy keeps owning logical facing, grid cell, tick movement, guard/stagger/death, hit resolution, and attack lifecycle. Enemy states keep deciding behavior through the current StateMachine. The new presenter receives visual intent from those existing hooks, chooses Sprite2D frames through `frame_coords`, and plays cheap feedback such as damage flash or stagger tint.

This scaffold deliberately does not use AnimationTree, AnimationPlayer, AnimatedSprite2D, SpriteFrames, Timer-driven animation loops, or Tween-driven frame/state playback. Phase 1 should be a deterministic Sprite2D frame selector plus a small presenter API; tweens are allowed only for existing movement squash/slide and short feedback properties such as modulate flash.

The landed result should make SmallEnemy render through a sprite presenter instead of the prototype square during normal combat, while PuffEnemy, ChargeEnemy, and ModeEnemy continue to work through the existing Polygon2D fallback until they are deliberately migrated.

## Relational Context

- GridEnemy owns enemy-facing truth. The presenter reads facing through calls from GridEnemy; it never computes or stores authoritative combat facing.
- Enemy states remain behavior delegates. Do not add attack, recovery, or animation states to the StateMachine for this scaffold.
- EnemyTickRuntime remains the owner of pending attack countdown and recovery. Visual prepare/attack cues are notifications from `begin_attack_telegraph()`, `show_attack_charge()`, and cleanup hooks, not a new clock.
- SmallEnemy owns tile attack setup through EnemyAttackController. The presenter must not prepare, modify, or clear telegraph cells.
- Sprite state selection is a pure view mapping from `{visual_state, facing}` to `Sprite2D.frame_coords`. It is not an animation clock, transition graph, or asynchronous action sequence.
- GridEnemy feedback currently targets `_body`. After this change, feedback should prefer `_visual_presenter` when present and fall back to `_body` for enemy scenes not yet migrated.
- Persistent visual nodes belong in `.tscn`, not dynamic GDScript creation. SmallEnemy should pre-place the visual presenter and its Sprite2D child.
- The legacy facing arrow may remain visible during the scaffold. Its visibility is a readability aid, not a gameplay contract.

## Scope

### Included

- A thin sprite-frame animator/presenter path for enemy visual state and facing.
- SmallEnemy scene wiring that uses an existing Ninja Adventure 16x16 source sheet at integer scale.
- Optional GridEnemy hooks that notify the presenter about facing, movement, prepare attack, attack charge, damage, stagger, reset, and cleanup.
- Legacy Polygon2D fallback for enemy kinds without a presenter.

### Excluded

- Final SmallEnemy art, new authored pose sheets, or AI-generated assets.
- Comfy or prompt-config asset production.
- AnimationTree, AnimationPlayer, AnimatedSprite2D, SpriteFrames resources, or a separate animation FSM.
- Tween-driven animation state transitions, Timer-driven frame playback, or `_process()` loops for frame advancement.
- Pattern variants, spawn weighting, or attack data changes.
- Player visuals, player aim marker, or character classes.

## Files to Change

| File                                                     | Change Size | Purpose                                                                                                                                                                                         |
| -------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `game/entities/enemies/directional_sprite_frame_view.gd` | Medium      | Provide a small reusable frame selector for Sprite2D sheets with four directions and named visual states.                                                                                       |
| `game/entities/enemies/enemy_visual_presenter.gd`        | Medium      | Map enemy visual state and facing intent to the animator, plus expose feedback methods for damage flash, stagger tint, reset, and placeholder scaling.                                          |
| `game/entities/enemies/grid_enemy.gd`                    | Medium      | Add an optional exported presenter reference and send visual intent from existing facing, movement, attack, damage, stagger, death, reset, and cleanup hooks while preserving `_body` fallback. |
| `game/entities/enemies/small_enemy.gd`                   | Small       | Notify the presenter at SmallEnemy-specific telegraph/charge points if base hooks are not sufficient.                                                                                           |
| `game/entities/enemies/small_enemy.tscn`                 | Medium      | Add the presenter and Sprite2D child, wire the exported presenter path, assign placeholder Ninja Adventure texture, and hide or de-emphasize the prototype Body polygon.                        |

## Execution Outline

1. Add `directional_sprite_frame_view.gd` and `enemy_visual_presenter.gd` with GDScript headers, typed public APIs, and no gameplay dependencies beyond receiving state/facing values. The frame view must use a child Sprite2D and set `frame_coords`; it must not create or configure AnimationPlayer, AnimationTree, AnimatedSprite2D, SpriteFrames, Timer, or tween-based frame playback.
2. Wire `small_enemy.tscn` with a persistent `VisualPresenter` child and `Sprite` child. Use an existing 64x64 Ninja Adventure monster sheet such as `assets/Ninja Adventure - Asset Pack/Actor/Monster/KappaGreen/SpriteSheet.png`, `hframes = 4`, `vframes = 4`, and an integer Sprite2D scale, starting at 5x.
3. Add optional `_visual_presenter` export wiring to GridEnemy. Update `face_arrow()`, `tick_snap_to_cell()`, attack cleanup, reset, damage, stagger, and death-adjacent cleanup to notify it while keeping existing `_body` behavior as fallback.
4. Update SmallEnemy attack hooks only where the base class cannot infer the right cue: warning should show prepare attack, charge should show attack, and cancel/clear should return to idle unless stagger/death takes priority.
5. Run standards lint on changed files and a Godot parse/test command if available through the normal project workflow.

## Implementation Notes

- `EnemyVisualPresenter` should expose coarse methods such as `show_idle()`, `show_move()`, `show_prepare_attack()`, `show_attack()`, `set_facing(facing: Vector2)`, `flash_damage()`, `set_staggered(active: bool)`, and `reset_visuals()`. Keep frame-row details private.
- `DirectionalSpriteFrameView` should be data-light for this scaffold. A hard-coded placeholder mapping is acceptable if it is isolated behind named visual states and can be replaced by child 02's pose-sheet contract.
- Use explicit enums for `VisualState` and `Direction`. Do not pass raw animation names, node names, or StringName state labels from gameplay code into the frame view.
- Phase 1 frame selection is static per visual intent. Do not implement looping idle/walk animation, frame timers, elapsed-time counters, or tween callbacks that advance `frame_coords`.
- Avoid rotating the Sprite2D to express facing if the sheet already has directional frames. `face_arrow()` may still rotate the legacy arrow and body fallback.
- If `tick_snap_to_cell()` shows movement, restore idle when the move tween finishes only if no higher-priority state such as prepare attack, attack, stagger, or death is active.
- Tween use in `EnemyVisualPresenter` is limited to non-authoritative visual feedback such as `modulate` flash. Tweens must not sequence combat state, schedule attack state changes, or drive sprite frame/state transitions.
- Hide the SmallEnemy prototype Body polygon only after feedback fallback has a presenter target. Do not delete Body yet because GridEnemy still exposes `_body` and other enemy scenes depend on the legacy path.

## Edge Cases

| Case                                                          | Expected Handling                                                                                             |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Enemy scene has no presenter wired                            | GridEnemy uses the existing Polygon2D body and facing arrow behavior.                                         |
| Placeholder texture is missing or unassigned                  | Presenter should fail quietly to legacy visuals and report a dev-visible warning rather than crashing combat. |
| Enemy is damaged while staggered                              | Damage flash should finish back into stagger tint instead of resetting to normal white.                       |
| Enemy commits an attack and is guard-broken before detonation | Attack cue clears with the existing cancel path, then stagger visual takes priority.                          |
| Enemy moves and immediately commits an attack                 | Prepare/attack cue should override any move idle-restore callback.                                            |

## Acceptance Criteria

1. SmallEnemy renders through a sprite presenter in normal tick arena combat instead of reading primarily as a prototype square.
2. SmallEnemy facing updates through the existing capped-facing and movement hooks without adding a second facing authority.
3. Movement, attack warning, attack charge, damage, stagger, reset, and death cleanup keep working when the presenter is present.
4. Enemy scenes without the presenter keep their existing Polygon2D visuals and behavior.
5. The scaffold uses existing Ninja Adventure-style 16x16 source art at integer scale and does not introduce a final asset pipeline.
