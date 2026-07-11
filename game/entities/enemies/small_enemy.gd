# small_enemy.gd
# 1x1 grid actor enemy with pattern-based telegraphed tile attacks, clocked by the tick engine.
class_name SmallEnemy
extends GridEnemy

## Playtest tuning: 75 = three actions per four world ticks, so flat running leaks pursuit distance
## and flanking windows open naturally instead of the chase locking on forever.
const TICK_SPEED := 75

# -- State --

var _attack_data: EnemyAttackData

# -- Node references --

@onready var _attack_controller: EnemyAttackController = %AttackController
@onready var _telegraph: TileTelegraph = %TileTelegraph

# == Lifecycle ==


func _ready() -> void:
    super()
    _configure_attack_controller()
    _select_attack_data()

# == Common API ==


## Reports an attack only when the enemy already faces the direction whose footprint covers the target.
## Turning to face a flanker is capped per tick (see tick_turn_toward_cell), so a back attacker gets a window.
func can_attack() -> bool:
    if _grid == null or _attack_controller == null or not has_target() or _attack_data == null:
        return false
    var target_cell := get_target_cell()
    if target_cell == _grid_pos or _facing == Vector2.ZERO:
        return false
    return target_cell in EnemyAttackController.get_attack_cells(_grid_pos, _facing, _attack_data, _grid)


func get_tick_speed() -> int:
    return TICK_SPEED


func get_current_attack_data() -> EnemyAttackData:
    return _attack_data


## Tick footprint committed by begin_attack_telegraph(): the tile cells the controller just prepared.
func get_committed_attack_cells() -> Array[Vector2i]:
    if _attack_controller == null:
        var empty: Array[Vector2i] = []
        return empty
    return _attack_controller.get_cells()


func get_attack_controller() -> EnemyAttackController:
    return _attack_controller


## Commits before planning when already facing a footprint that covers the target, and after a capped
## turn brings that footprint onto the target — the two decision points a tile attack can open from.
func should_commit_before_plan() -> bool:
    return can_attack()


func should_commit_after_face() -> bool:
    return can_attack()


## Clears movement planning and prepares the attack telegraph for the enemy's current (capped) facing.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action():
        return false
    var attack := get_attack_controller()
    if attack == null or _attack_data == null:
        return false
    if not attack.prepare(get_grid_pos(), get_facing(), _attack_data):
        return false
    attack.show_warning()
    start_attack_windup_vfx(CombatFeedbackVFX.WindupStyle.TILE)
    if _visual_presenter != null:
        _visual_presenter.show_prepare_attack()
    return true


## Shows the committed attack's charge telegraph phase.
func show_attack_charge() -> void:
    var attack := get_attack_controller()
    if attack != null:
        attack.show_charge()
    if _visual_presenter != null:
        _visual_presenter.show_attack_commit()


func plan_next_action() -> bool:
    if _attack_controller == null or _attack_data == null:
        return plan_approach_action()

    var get_cells_for_origin := func(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
        return EnemyAttackController.get_attack_cells(origin_cell, facing, _attack_data, _grid)
    var get_origins_for_target := func(target_cell: Vector2i) -> Array[Vector2i]:
        return EnemyAttackController.get_attack_origin_cells(target_cell, _attack_data, _grid)

    if plan_cell_attack_action(get_cells_for_origin, get_origins_for_target):
        return true

    return plan_approach_action()

# == Setup helpers ==


func _after_setup_ready() -> void:
    _configure_attack_controller()
    _select_attack_data()


func _on_guard_broken_extra() -> void:
    _cancel_attack()


func _on_begin_death_extra() -> void:
    _cancel_attack()


func _reset_extra() -> void:
    _cancel_attack()


func _cancel_attack() -> void:
    stop_attack_windup_vfx()
    if _attack_controller != null:
        _attack_controller.cancel()
    if _visual_presenter != null:
        _visual_presenter.show_idle()


## Tick hook: clears the tile telegraph and windup when an attack resolves or is cancelled.
func _clear_attack_presentation() -> void:
    _cancel_attack()


func _configure_attack_controller() -> void:
    if _attack_controller == null:
        return
    _attack_controller.setup(_grid, _telegraph)


## Picks a random attack from enemy data. Falls back to a LINE attack when data
## is unavailable, preserving pre-migration behavior.
func _select_attack_data() -> void:
    if enemy_data != null and not enemy_data.attacks.is_empty():
        _attack_data = enemy_data.attacks[randi() % enemy_data.attacks.size()]
        return

    var fallback := EnemyAttackData.new()
    fallback.attack_kind = EnemyAttackData.AttackKind.TILE
    fallback.cell_shape = EnemyAttackData.CellShape.LINE if randi() % 2 == 0 else EnemyAttackData.CellShape.WIDE
    fallback.damage = 10.0
    fallback.line_length = 3
    fallback.width = 3
    fallback.depth = 2
    _attack_data = fallback
