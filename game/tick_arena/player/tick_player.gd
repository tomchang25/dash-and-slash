# tick_player.gd
# Tick-arena player actor: grid cell, hp, tick-based dash cooldown, smash windup state, the shared
# Speed meter, and grey-box drawing. The player has no combat facing — mouse aim is a free verb parameter.
class_name TickPlayer
extends Node2D

# -- Constants --

const MAX_HP := 100.0
const MOVE_TWEEN_SEC := 0.09
const LEAP_TWEEN_SEC := 0.12
const BODY_RADIUS := 40.0
const DAMAGE_FLASH_SEC := 0.18

## Full meter: the next eligible move or normal attack skips world advancement and spends the charge.
const SPEED_METER_MAX := 100
## Meter gained by one eligible action before Speed stacks, so baseline play earns one free action every four eligible actions.
const SPEED_BASE_FILL := 25
## Meter gained per Speed stack for one eligible action.
const SPEED_FILL_PER_STACK := 10
## Overall per-action fill ceiling (baseline plus stack bonus), so no stack count can more than
## triple the baseline gain in a single action.
const SPEED_FILL_CAP := 75

# -- Exports --

@export var smash_windup_sfx_event: SpatialAudioEvent
@export var smash_impact_sfx_event: SpatialAudioEvent
@export var guard_shredder_sfx_event: SpatialAudioEvent
@export var execution_sfx_event: SpatialAudioEvent

# -- State --

var cell := Vector2i.ZERO
var hp := MAX_HP
var dash_cooldown := 0
var smash_cooldown := 0
var smash_target := Vector2i.ZERO
var speed_meter := 0

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


## Returns the effective max hp: the base value plus every recorded Max Health reward bonus, floored
## at the base so a reduction effect could never collapse survivability below it. Callers project this
## from the run's RunBuild total themselves, since TickPlayer holds no RunBuild reference of its own.
func max_hp(bonus_total: float) -> float:
    return MAX_HP + maxf(bonus_total, 0.0)


## Restores spawn defaults and snaps back to the given cell, healing to the max hp projected from the
## given Max Health reward bonus total so a run's earned max health survives a death/reset.
func reset(start_cell: Vector2i, max_health_bonus := 0.0) -> void:
    hp = max_hp(max_health_bonus)
    dash_cooldown = 0
    smash_cooldown = 0
    speed_meter = 0
    disarm_smash()
    cell = start_cell
    if _move_tween != null:
        _move_tween.kill()
    position = _grid.cell_center(start_cell)
    scale = Vector2.ONE
    queue_redraw()


## Counts tick-based cooldowns down by one consumed player action.
func tick_cooldowns() -> void:
    dash_cooldown = maxi(dash_cooldown - 1, 0)
    smash_cooldown = maxi(smash_cooldown - 1, 0)


## Whether the Speed meter is full: the next eligible move or normal attack skips world advancement.
func is_speed_meter_full() -> bool:
    return speed_meter >= SPEED_METER_MAX


## Spends the full Speed charge for the eligible action now resolving as a free action.
func spend_speed_meter() -> void:
    speed_meter = 0


## Fills the Speed meter after an eligible move or normal attack resolves, including a free one, from
## the run's current Speed stack total. Gain is capped per action so stacking Speed cannot skip more
## than every other eligible action.
func fill_speed_meter(speed_stacks: float) -> void:
    var gain := speed_meter_fill_for(speed_stacks)
    speed_meter = mini(speed_meter + gain, SPEED_METER_MAX)


## Returns the meter energy gained by one eligible move or normal attack at the given Speed stack total.
func speed_meter_fill_for(speed_stacks: float) -> int:
    return mini(SPEED_BASE_FILL + int(speed_stacks) * SPEED_FILL_PER_STACK, SPEED_FILL_CAP)


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
