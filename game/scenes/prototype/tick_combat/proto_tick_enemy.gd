# proto_tick_enemy.gd
# Base class for tick-prototype enemies: tick-count attack scheduling, guard/stagger/recovery state,
# capped-turn facing, an energy skeleton locked to baseline speed, and grey-box drawing.
class_name ProtoTickEnemy
extends Node2D

# -- Constants --

const STAGGER_TICKS := 3
const ENERGY_PER_ACTION := 100
const MOVE_TWEEN_SEC := 0.09
const BODY_SIZE := 88.0
const BAR_WIDTH := 96.0
const BAR_HEIGHT := 8.0

# -- State --

var cell := Vector2i.ZERO
var facing := Vector2i.LEFT
## Energy skeleton field; the prototype locks every actor to baseline so speed never varies (plan non-goal).
var speed := 100
var max_guard := 32
var max_hp := 60.0
var attack_damage := 10.0
var body_color := Color(0.75, 0.75, 0.78)

var _ctx = null
var _grid: GridArena = null
var _guard := 0
var _hp := 0.0
var _energy := 0
var _stagger_ticks := 0
var _recovery_ticks := 0
var _attack_tiles: Array[Vector2i] = []
var _attack_ticks := -1

# -- Timer / tween handles --

var _move_tween: Tween = null


# == Lifecycle ==


func _ready() -> void:
    _guard = max_guard
    _hp = max_hp
    queue_redraw()


func _draw() -> void:
    _draw_body()
    _draw_bars()
    _draw_status_rings()


# == Common API ==


## Binds the enemy to its tick context and grid, and snaps it onto its starting cell.
func setup(ctx, grid: GridArena, start_cell: Vector2i) -> void:
    _ctx = ctx
    _grid = grid
    cell = start_cell
    position = grid.cell_center(start_cell)


## Advances this enemy by one world tick (resolution stage 3): stagger/recovery countdowns, then behavior.
func advance_tick() -> void:
    _energy += speed
    while _energy >= ENERGY_PER_ACTION:
        _energy -= ENERGY_PER_ACTION
        _step_tick()
    queue_redraw()


## Counts down and detonates this enemy's telegraphed attack (resolution stage 2).
func resolve_detonation() -> void:
    if _attack_ticks <= 0:
        return
    _attack_ticks -= 1
    if _attack_ticks > 0:
        queue_redraw()
        return
    _detonate()
    _attack_tiles.clear()
    _attack_ticks = -1
    queue_redraw()


## Predicts one player hit without mutating any state; the preview layer and take_hit() share this
## math so the displayed outcome can never disagree with the resolved one.
## Returns keys angle, staggered, guard_damage, guard_broken, killed, and hp_damage.
func predict_hit(attacker_cell: Vector2i, base_damage: float, is_dash: bool) -> Dictionary:
    var result := {
        "angle": ProtoCombatRules.HitAngle.SIDE,
        "staggered": false,
        "guard_damage": 0,
        "guard_broken": false,
        "killed": false,
        "hp_damage": 0.0,
    }
    if not is_alive():
        return result

    if _stagger_ticks > 0 or _guard <= 0:
        var multiplier := ProtoCombatRules.STAGGER_DASH_MULTIPLIER if is_dash else ProtoCombatRules.STAGGER_ATTACK_MULTIPLIER
        result["staggered"] = true
        result["hp_damage"] = base_damage * multiplier
    else:
        var angle := ProtoCombatRules.resolve_angle(attacker_cell, cell, facing)
        result["angle"] = angle
        result["guard_damage"] = ProtoCombatRules.guard_damage_for(angle, max_guard)
        result["guard_broken"] = _guard - int(result["guard_damage"]) <= 0
        result["hp_damage"] = base_damage * ProtoCombatRules.hp_bypass_for(angle)

    result["killed"] = _hp - float(result["hp_damage"]) <= 0.0
    return result


## Applies one player hit from the given origin cell and returns the same result dictionary as predict_hit().
func take_hit(attacker_cell: Vector2i, base_damage: float, is_dash: bool) -> Dictionary:
    var result := predict_hit(attacker_cell, base_damage, is_dash)
    if not is_alive():
        return result

    if not bool(result["staggered"]):
        _guard = maxi(_guard - int(result["guard_damage"]), 0)
        if bool(result["guard_broken"]):
            _stagger_ticks = STAGGER_TICKS
            _cancel_pending_attack()

    _hp = maxf(_hp - float(result["hp_damage"]), 0.0)
    queue_redraw()
    return result


## Returns the current danger display data ({cells, ticks}), or an empty dictionary when no attack is pending.
func get_danger() -> Dictionary:
    if _attack_ticks <= 0 or _attack_tiles.is_empty():
        return { }
    return {
        "cells": _attack_tiles.duplicate(),
        "ticks": _attack_ticks,
    }


func is_alive() -> bool:
    return _hp > 0.0


func is_staggered() -> bool:
    return _stagger_ticks > 0


# == Behavior (virtual) ==


## Per-kind behavior for one tick when free to act; subclasses override.
func _think() -> void:
    pass


## Per-kind attack resolution when the telegraph countdown reaches zero; subclasses override.
func _detonate() -> void:
    pass


## Runs one tick step: stagger and recovery countdowns gate behavior, and a committed telegraph freezes movement.
func _step_tick() -> void:
    if _stagger_ticks > 0:
        _stagger_ticks -= 1
        if _stagger_ticks == 0:
            _guard = max_guard
        return
    if _recovery_ticks > 0:
        _recovery_ticks -= 1
        return
    if _attack_ticks > 0:
        return
    _think()


func _cancel_pending_attack() -> void:
    _attack_tiles.clear()
    _attack_ticks = -1


# == Movement ==


## Rotates facing at most 90 degrees toward the desired direction, so a 180-degree turn costs two ticks.
func _turn_step_toward(desired: Vector2i) -> void:
    if desired == Vector2i.ZERO or desired == facing:
        return
    if desired == -facing:
        facing = Vector2i(-facing.y, facing.x)
    else:
        facing = desired
    queue_redraw()


## Steps one cell toward the player, preferring the dominant axis; facing follows the movement direction.
func _step_toward_player() -> void:
    var delta: Vector2i = _ctx.player_cell() - cell
    var step_x := Vector2i(signi(delta.x), 0)
    var step_y := Vector2i(0, signi(delta.y))
    var ordered: Array[Vector2i] = []
    if absi(delta.x) >= absi(delta.y):
        ordered = [step_x, step_y]
    else:
        ordered = [step_y, step_x]
    for dir in ordered:
        if dir == Vector2i.ZERO:
            continue
        if _try_step(dir):
            return


## Attempts a one-cell step in the given direction; returns false when the target cell is closed.
func _try_step(dir: Vector2i) -> bool:
    var target := cell + dir
    if not _ctx.is_cell_open_for_enemy(target, self):
        return false
    facing = dir
    _move_to(target, MOVE_TWEEN_SEC)
    return true


## Snaps the logical cell immediately and tweens the visual position with a small landing squash.
func _move_to(target_cell: Vector2i, duration: float) -> void:
    cell = target_cell
    if _move_tween != null:
        _move_tween.kill()
    scale = Vector2(1.1, 0.9)
    _move_tween = create_tween()
    _move_tween.set_parallel(true)
    _move_tween.tween_property(self, "position", _grid.cell_center(target_cell), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _move_tween.tween_property(self, "scale", Vector2.ONE, duration * 1.5)


# == Drawing ==


func _draw_body() -> void:
    var half := BODY_SIZE * 0.5
    draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), body_color)
    if _attack_ticks > 0:
        draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), Color.WHITE, false, 3.0)

    var forward := Vector2(facing)
    var side := forward.orthogonal()
    var tip := forward * (half + 16.0)
    var base_a := forward * half + side * 14.0
    var base_b := forward * half - side * 14.0
    draw_colored_polygon(PackedVector2Array([tip, base_a, base_b]), body_color.darkened(0.35))


func _draw_bars() -> void:
    var top := -BODY_SIZE * 0.5 - 26.0
    var left := -BAR_WIDTH * 0.5
    draw_rect(Rect2(left, top, BAR_WIDTH, BAR_HEIGHT), Color(0.1, 0.1, 0.12, 0.8))
    var guard_ratio := float(_guard) / float(max_guard)
    draw_rect(Rect2(left, top, BAR_WIDTH * guard_ratio, BAR_HEIGHT), Color(0.35, 0.6, 0.95))

    var hp_top := top + BAR_HEIGHT + 3.0
    draw_rect(Rect2(left, hp_top, BAR_WIDTH, BAR_HEIGHT), Color(0.1, 0.1, 0.12, 0.8))
    var hp_ratio := _hp / max_hp
    draw_rect(Rect2(left, hp_top, BAR_WIDTH * hp_ratio, BAR_HEIGHT), Color(0.85, 0.25, 0.25))


func _draw_status_rings() -> void:
    if _stagger_ticks > 0:
        draw_arc(Vector2.ZERO, BODY_SIZE * 0.5 + 10.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.2), 4.0)
    elif _recovery_ticks > 0:
        draw_arc(Vector2.ZERO, BODY_SIZE * 0.5 + 10.0, 0.0, TAU, 32, Color(0.6, 0.6, 0.65, 0.6), 2.0)
