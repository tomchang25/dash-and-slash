# Tick Arena Visual Readability 02: Enemy-Specific Visual Presenters

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Turn the Phase 1 enemy sprite scaffold into a shared semantic visual contract while letting each enemy kind own its movement, windup, commit cue, and VFX flavor.

## Summary

Phase 1 proved that the big readability win is not full animation volume; it is distinct facing and combat-state presentation at tick speed. This spec keeps one representative frame per visual state as the default, then lets enemy-specific presenter scripts add short tweens and accents that match each enemy's body language.

The visual state formerly named `ATTACK` is now `COMMIT_CUE`: a commit/release anticipation cue shown on the final warning beat before impact. It is not a full attack animation and not an attack scheduler. Gameplay timing remains owned by GridEnemy, EnemyTickRuntime, and each enemy kind's telegraph/detonation hooks.

Do not add an `EnemyVisualProfile` Resource for this slice. Numeric profiles would work for same-behavior variants, but SmallEnemy and ChargeEnemy need different motion language, not just different values. The right split for Phase 2 is a base `EnemyVisualPresenter` that owns the common API, facing/frame plumbing, damage flash, stagger tint, reset, and interruption rules, plus enemy-specific subclasses that implement action feedback.

## Relational Context

- GridEnemy remains the caller for shared lifecycle/facing/move/damage/stagger visual intent; it talks to `EnemyVisualPresenter` and does not know which subclass is wired.
- SmallEnemy and ChargeEnemy own their attack telegraph setup and detonation rules; they call or inherit presenter methods only to mirror warning, commit cue, cancel, and reset presentation.
- EnemyTickRuntime remains the authority for pending attack countdown and recovery; presenter tweens are non-authoritative feedback attached to existing hooks.
- `EnemyVisualPresenter` is the semantic base contract. It owns public methods such as `show_idle()`, `show_move()`, `show_prepare_attack()`, `show_attack_commit()`, `flash_damage()`, `set_staggered()`, and `reset_visuals()`.
- Enemy-specific presenter subclasses own action feedback methods for movement, prepare, and commit cues. They may use tweens and one-shot VFX, but they must not read target cells, schedule damage, start recovery, or clear telegraphs.
- DirectionalSpriteFrameView remains a frame-coordinate selector for `{direction, visual_state}`; it should not gain timers, loops, gameplay conditions, or transition ownership.
- Scene files own persistent visual nodes and script choice; SmallEnemy and ChargeEnemy should wire the appropriate presenter subclass in `.tscn`, not dynamically swap scripts from enemy gameplay code.
- Enemies without a valid presenter texture must continue through the legacy Polygon2D fallback.

## Scope

### Included

- Shared semantic base presenter behavior for frame state, facing, damage flash, stagger tint, reset, and action interruption cleanup.
- SmallEnemy-specific presenter tween flavor for movement, attack prepare, and commit cue.
- ChargeEnemy-specific presenter tween flavor for movement, charge prepare, and commit cue.
- ChargeEnemy scene wiring to use the sprite presenter path while keeping legacy fallback behavior available.
- Documentation of `COMMIT_CUE` as the last pre-impact visual cue rather than a full attack animation.

### Excluded

- `EnemyVisualProfile` or other data-driven visual tuning resources.
- Final authored enemy art, Comfy/GPT asset production, or broad pose-sheet pipeline work.
- Player visuals, boss-specific presenters, character classes, spawn weighting, or attack balance changes.
- AnimationPlayer, AnimationTree, AnimatedSprite2D, SpriteFrames resources, looping frame timers, or gameplay-state sequencing inside the presenter.

## Files to Change

| File | Change Size | Purpose |
| ---- | ----------- | ------- |
| `game/entities/enemies/enemy_visual_presenter.gd` | Medium | Keep the shared semantic API, common frame/facing plumbing, damage/stagger/reset behavior, and interruptible action-feedback hook points. |
| `game/entities/enemies/small_enemy_visual_presenter.gd` | Medium | Add SmallEnemy-specific move, prepare, and commit cue tweens while reusing the base presenter contract. |
| `game/entities/enemies/charge_enemy_visual_presenter.gd` | Medium | Add ChargeEnemy-specific directional movement, charge prepare, and commit cue tweens while reusing the base presenter contract. |
| `game/entities/enemies/directional_sprite_frame_view.gd` | Small | Keep static frame selection and `COMMIT_CUE` naming; only add minimal helper API if the base presenter needs it. |
| `game/entities/enemies/small_enemy.gd` | Small | Keep attack warning/charge hooks mapped to shared prepare and commit visual intent, with cleanup returning to idle through the presenter. |
| `game/entities/enemies/charge_enemy.gd` | Small | Mirror warning, charge-phase, cancel, reset, and charge-start presentation through the shared presenter without changing charge rules. |
| `game/entities/enemies/small_enemy.tscn` | Small | Use the SmallEnemy presenter subclass on the existing VisualPresenter node. |
| `game/entities/enemies/charge_enemy.tscn` | Medium | Add persistent VisualPresenter/Sprite nodes, use the ChargeEnemy presenter subclass, and keep the Body polygon available as fallback. |

## Execution Outline

1. Refactor `EnemyVisualPresenter` into the base semantic contract by adding action-feedback hook methods that default to no-op or minimal shared cleanup.
2. Add `SmallEnemyVisualPresenter` and move SmallEnemy's action feel into that subclass: light movement lean, compact prepare squash, and a short commit pop.
3. Add `ChargeEnemyVisualPresenter` with stronger facing-direction lean, lower charge prepare compression, and a sharper commit cue that complements the existing charge-start VFX.
4. Wire SmallEnemy's scene to the SmallEnemy presenter subclass without changing its attack hooks beyond the existing semantic calls.
5. Wire ChargeEnemy's scene and hooks into the presenter: warning shows prepare, final countdown beat shows commit, charge detonation keeps the existing charge-start VFX, and cleanup clears presentation.
6. Run standards lint on changed files and a Godot parse/test command if available through the normal project workflow.

## Implementation Notes

- Base presenter public methods should set the appropriate frame state first, update internal visual-state tracking, then call an underscore hook such as `_play_move_feedback()`, `_play_prepare_attack_feedback()`, or `_play_attack_commit_feedback()`. Subclasses override hooks, not the public semantic API, unless they have a strong reason.
- Base presenter should own killing/clearing action tweens so stale move feedback cannot restore idle over prepare, commit, stagger, or death visuals.
- Subclass tweens should target the presenter or sprite transform in a way that layers with GridEnemy's existing root position/scale movement tween instead of fighting it.
- Commit feedback should be short and forceful. Treat `DirectionalSpriteFrameView.VisualState.COMMIT_CUE` as the cue shown on the final warning beat before detonation.
- Damage flash and stagger tint stay in the base presenter so every enemy gets consistent combat feedback even when action flavor differs.

## Edge Cases

| Case | Expected Handling |
| ---- | ----------------- |
| Move tween finishes after an attack warning begins | The base presenter does not restore idle over prepare or commit visuals. |
| Enemy is staggered during prepare or commit | Action tweens stop, stagger tint/state takes priority, and attack cleanup can safely run afterward. |
| ChargeEnemy has no valid sprite texture | GridEnemy falls back to Body polygon behavior rather than showing a blank sprite. |
| Attack is canceled before the final countdown beat | Warning VFX and prepare visuals clear without showing the commit cue. |
| A future enemy needs radically custom presentation | It wires its own presenter subclass rather than adding conditional branches to the base presenter. |

## Acceptance Criteria

1. SmallEnemy and ChargeEnemy use the same presenter API for idle, move, prepare, commit, damage, stagger, and reset presentation.
2. SmallEnemy keeps the readable Phase 1 result while gaining its own movement lean, prepare squash, and clearer final commit cue.
3. ChargeEnemy gains sprite-facing presentation and charge-specific visual behavior without changing charge telegraph, damage, movement, or recovery rules.
4. The `COMMIT_CUE` visual state is clearly treated as the last pre-impact commit cue, not a full attack animation or gameplay timing source.
5. Enemies without a wired or valid presenter still render and receive feedback through the legacy Polygon2D fallback.
