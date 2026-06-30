# small_enemy.gd
# 1x1 grid actor enemy with pattern-based telegraphed tile attacks.
class_name SmallEnemy
extends GridEnemy

const ATTACK_RANGE := 1.5
const WARNING_DURATION := 0.6
const CHARGE_DURATION := 0.2
const ATTACK_DURATION := 0.2
const RECOVERY_DURATION := 0.4

# -- Node references ----------------------------------------------------------
@onready var _attack_controller: EnemyAttackController = %AttackController
@onready var _telegraph: TileTelegraph = %TileTelegraph

# -- State --------------------------------------------------------------------
var _attack_data: EnemyAttackData

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    _allow_diagonal_movement = true
    _configure_attack_controller()
    _select_attack_data()

# == Common API ================================================================


func can_attack() -> bool:
    if _grid == null or _attack_controller == null or not has_target() or _attack_data == null:
        return false
    var target_cell := get_target_cell()
    var dir_to_target := Vector2(target_cell - _grid_pos)
    if dir_to_target == Vector2.ZERO:
        return false
    return target_cell in EnemyAttackController.get_attack_cells(_grid_pos, cardinal_snap(dir_to_target), _attack_data, _grid)


func get_current_attack_data() -> EnemyAttackData:
    return _attack_data


func get_attack_controller() -> EnemyAttackController:
    return _attack_controller


func get_idle_state_id() -> int:
    return EnemyState.EnemyStateId.IDLE


func get_reposition_state_id() -> int:
    return EnemyState.EnemyStateId.REPOSITION


func get_face_state_id() -> int:
    return EnemyState.EnemyStateId.FACE_TARGET


func get_recovery_state_id() -> int:
    return EnemyState.EnemyStateId.RECOVERY


func get_staggered_state_id() -> int:
    return EnemyState.EnemyStateId.STAGGERED


func get_pre_plan_state_id() -> int:
    if can_attack():
        return EnemyState.EnemyStateId.TELEGRAPH
    return -1


func get_dead_state_id() -> int:
    return EnemyState.EnemyStateId.DEAD


func get_after_face_state_id() -> int:
    if can_attack():
        return EnemyState.EnemyStateId.TELEGRAPH
    return EnemyState.EnemyStateId.IDLE


## Clears movement planning and prepares the attack telegraph.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action():
        return false
    face_target_position()
    var attack := get_attack_controller()
    if attack == null or _attack_data == null:
        return false
    if not attack.prepare(get_grid_pos(), get_facing(), _attack_data):
        return false
    attack.show_warning()
    start_attack_windup_vfx(CombatFeedbackVFX.WindupStyle.TILE)
    return true


## Shows the committed attack's charge telegraph phase.
func show_attack_charge() -> void:
    var attack := get_attack_controller()
    if attack != null:
        attack.show_charge()


func begin_attack() -> bool:
    var attack := get_attack_controller()
    if attack == null:
        return false
    stop_attack_windup_vfx()
    attack.begin_attack()
    return true


func end_attack() -> void:
    stop_attack_windup_vfx()
    var attack := get_attack_controller()
    if attack != null:
        attack.end_attack()


func plan_next_action() -> bool:
    if _attack_controller == null or _attack_data == null:
        return plan_approach_action()

    if plan_cell_attack_action(
        func(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
            return EnemyAttackController.get_attack_cells(origin_cell, facing, _attack_data, _grid)
    ):
        return true

    return plan_approach_action()

# == Setup helpers =============================================================


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


func _configure_attack_controller() -> void:
    if _attack_controller == null:
        return
    _attack_controller.setup(_grid, _telegraph, self)


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
