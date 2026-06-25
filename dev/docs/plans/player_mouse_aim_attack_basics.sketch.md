# Player Mouse-Aim Attack Basics

## Goal

Add a first-pass player attack feel layer: the player faces the mouse, normal attack uses a fixed player-attached capsule hitbox, and attack startup triggers SFX plus a matching visual slash. This closes the current gap where attack range exists but is not aimed or visually readable.

## Requirements

1. The player continuously aims toward the mouse position so facing is readable even while idle or moving.
2. Normal attack uses one fixed capsule-shaped hitbox attached to the player. This is intentionally hard-coded for now because the immediate goal is validating basic feel, not data-driven weapon shapes.
3. The attack hitbox is positioned and rotated by aim direction when the attack starts, not by movement direction, so standing attacks and moving attacks behave consistently.
4. Attack SFX plays exactly when a normal attack is triggered, so audio confirms the action at startup.
5. Hit SFX and hurt SFX are excluded for now because the current scope is attack startup feedback, not impact feedback.
6. Attack VFX uses animation or tweening and should overlap the active hitbox shape, position, and size closely enough that players can trust what the visual represents.
7. The existing player FSM ownership stays intact: attack behavior remains in the attack state, while the player entity exposes query and command APIs for aim, hitbox, audio, and VFX.

## Design

The first version treats normal attack as a short forward capsule slash anchored to the player. The capsule should sit in front of the player center along the current mouse aim direction, with its long axis aligned to that direction. The visual can be slightly larger or brighter than the hitbox for readability, but it should not imply a much wider or longer damaging region.

The attack startup sequence is: consume attack input, enter attack state, capture the current aim direction, place and enable the capsule hitbox, play the attack SFX, show the matching VFX, allow slight drift during the active window, then disable hitbox and hide/reset the VFX on exit.

## Sketch (non-normative)

Proposed touched files:

1. `game/entities/player/player.tscn`
2. `game/entities/player/player.gd`
3. `game/entities/player/states/player_attack_state.gd`
4. Optional asset path for attack SFX, such as `assets/audio/sfx/player_attack.wav`, if an audio asset exists or is added later.

Suggested scene shape:

```text
Player
├── FacingArrow
├── AttackHitbox
│   └── CollisionShape2D      # CapsuleShape2D, disabled by Hitbox.set_enabled(false)
└── AttackVfx
    └── Polygon2D or Line2D   # pre-placed, hidden by default, roughly same capsule footprint
```

Suggested constants and exports in `player.gd`:

```gdscript
const ATTACK_RANGE := 38.0
const ATTACK_CAPSULE_RADIUS := 16.0
const ATTACK_CAPSULE_HEIGHT := 52.0

@export var attack_sfx: AudioStream

@onready var _facing_arrow: Polygon2D = %FacingArrow
@onready var _attack_hitbox: Hitbox = %AttackHitbox
@onready var _attack_hitbox_shape: CollisionShape2D = %AttackHitboxShape
@onready var _attack_vfx: CanvasItem = %AttackVfx
```

Suggested player-facing API:

```gdscript
func get_aim_direction() -> Vector2:
    var dir := get_global_mouse_position() - global_position
    if dir.length_squared() <= 0.001:
        return _last_move_dir
    return dir.normalized()


func update_aim_visual() -> void:
    var aim_dir := get_aim_direction()
    _facing_arrow.rotation = aim_dir.angle() + PI / 2.0


func begin_normal_attack(aim_dir: Vector2) -> void:
    _position_attack_shape(aim_dir)
    _attack_hitbox.set_enabled(true)
    AudioManager.play_sfx_2d(attack_sfx, global_position)
    _play_attack_vfx(aim_dir)


func end_normal_attack() -> void:
    _attack_hitbox.set_enabled(false)
    _reset_attack_vfx()
```

Suggested private helpers:

```gdscript
func _position_attack_shape(aim_dir: Vector2) -> void:
    _attack_hitbox.position = aim_dir * ATTACK_RANGE
    _attack_hitbox.rotation = aim_dir.angle() + PI / 2.0


func _play_attack_vfx(aim_dir: Vector2) -> void:
    _attack_vfx.position = aim_dir * ATTACK_RANGE
    _attack_vfx.rotation = aim_dir.angle() + PI / 2.0
    _attack_vfx.visible = true
    _attack_vfx.modulate = Color(1.0, 1.0, 1.0, 0.85)
    _attack_vfx.scale = Vector2(0.75, 0.75)

    var tween := create_tween()
    tween.tween_property(_attack_vfx, "scale", Vector2.ONE, 0.06)
    tween.parallel().tween_property(_attack_vfx, "modulate:a", 0.0, ATTACK_DURATION)
```

Suggested attack state change:

```gdscript
func _enter() -> void:
    var aim_dir := player.get_aim_direction()
    player.begin_normal_attack(aim_dir)
    _start_attack_timer()


func _exit() -> void:
    player.end_normal_attack()
    _clear_attack_timer()
```

Suggested implementation steps:

1. Replace the normal attack rectangle shape with a capsule shape in the player scene, keeping it as a persistent child node.
2. Add a persistent attack VFX node in the player scene, hidden by default, sized and oriented to approximately match the capsule hitbox.
3. Add mouse-aim query and facing visual update API to the player entity.
4. Update the player physics loop to refresh the facing visual every frame without adding state dispatch logic.
5. Replace direct `enable_attack_hitbox()` / `disable_attack_hitbox()` usage with `begin_normal_attack()` / `end_normal_attack()` so attack state owns the timing while the entity owns hitbox/audio/VFX commands.
6. Play attack SFX from the attack startup command using the existing audio manager and a nullable exported stream.
7. Keep timers in the attack state as runtime-created timer nodes, with the existing timer exception pattern preserved.

## Non-Goals

1. No hit SFX or hurt SFX.
2. No data-driven weapon shapes or card-driven attack shape changes.
3. No new combo chain, cancel window, or attack buffering behavior.
4. No right-stick aiming or auto-aim fallback beyond the existing movement direction fallback.
5. No animation-tree integration; tween or simple animation nodes are enough for this pass.

## Acceptance Criteria

1. Moving the mouse around the player visibly rotates the player facing indicator.
2. Pressing attack while idle or moving creates one short forward attack in the mouse direction.
3. The damaging area is a capsule attached to the player and appears in front of the player instead of staying at a fixed world or local offset.
4. Attack SFX plays once per accepted normal attack input.
5. The attack visual appears at attack startup and fades or resets by the end of the attack.
6. The visible attack effect and damaging hitbox substantially overlap in direction, position, and footprint.
7. The player FSM still delegates attack timing to the attack state rather than adding state dispatch logic to the player entity.
