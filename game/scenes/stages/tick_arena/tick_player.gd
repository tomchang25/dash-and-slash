# tick_player.gd
# Tick-arena player actor: grid cell, hp, tick-based dash cooldown, smash windup state, and grey-box
# drawing. The player has no combat facing — mouse aim is a free verb parameter.
class_name TickPlayer
extends Node2D

# -- Constants --

const MAX_HP := 100.0
const MOVE_TWEEN_SEC := 0.09
const LEAP_TWEEN_SEC := 0.12
const BODY_RADIUS := 40.0
const DAMAGE_FLASH_SEC := 0.18

# -- State --

var cell := Vector2i.ZERO
var hp := MAX_HP
var dash_cooldown := 0
var smash_target := Vector2i.ZERO

var _smash_armed := false
var _grid: GridArena = null

# -- Timer / tween handles --

var _move_tween: Tween = null
var _flash_tween: Tween = null

# == Lifecycle ==


func _draw() -> void:
    draw_circle(Vector2.ZERO, BODY_RADIUS, Color(0.93, 0.96, 1.0))
    if _smash_armed:
        draw_arc(Vector2.ZERO, BODY_RADIUS + 10.0, 0.0, TAU, 32, Color(0.3, 0.9, 1.0), 4.0)

# == Common API ==


## Binds the player to the grid and snaps it onto its starting cell.
func setup(grid: GridArena, start_cell: Vector2i) -> void:
    _grid = grid
    cell = start_cell
    position = grid.cell_center(start_cell)


## Moves the logical cell immediately and tweens the visual position; leap uses the slower smash arc timing.
func move_to(target_cell: Vector2i, leap := false) -> void:
    cell = target_cell
    if _move_tween != null:
        _move_tween.kill()
    var duration := LEAP_TWEEN_SEC if leap else MOVE_TWEEN_SEC
    scale = Vector2(1.12, 0.88)
    _move_tween = create_tween()
    _move_tween.set_parallel(true)
    _move_tween.tween_property(self, "position", _grid.cell_center(target_cell), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _move_tween.tween_property(self, "scale", Vector2.ONE, duration * 1.5)


## Applies damage with a red flash; returns true when the player died.
func take_damage(amount: float) -> bool:
    hp = maxf(hp - amount, 0.0)
    if _flash_tween != null:
        _flash_tween.kill()
    modulate = Color(1.0, 0.35, 0.35)
    _flash_tween = create_tween()
    _flash_tween.tween_property(self, "modulate", Color.WHITE, DAMAGE_FLASH_SEC)
    return hp <= 0.0


## Restores spawn defaults and snaps back to the given cell.
func reset(start_cell: Vector2i) -> void:
    hp = MAX_HP
    dash_cooldown = 0
    disarm_smash()
    cell = start_cell
    if _move_tween != null:
        _move_tween.kill()
    position = _grid.cell_center(start_cell)
    scale = Vector2.ONE
    queue_redraw()


## Counts tick-based cooldowns down by one world tick.
func tick_cooldowns() -> void:
    dash_cooldown = maxi(dash_cooldown - 1, 0)


## Arms the smash windup on a locked landing cell.
func arm_smash(target_cell: Vector2i) -> void:
    _smash_armed = true
    smash_target = target_cell
    queue_redraw()


## Clears any armed smash windup.
func disarm_smash() -> void:
    _smash_armed = false
    queue_redraw()


func is_smash_armed() -> bool:
    return _smash_armed
