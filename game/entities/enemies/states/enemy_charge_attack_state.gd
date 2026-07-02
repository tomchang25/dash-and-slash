# enemy_charge_attack_state.gd
# Charge movement phase shared by every enemy kind with a charge-style attack.
# Rushes through pre-computed cells at charge speed. Clears telegraph per-cell
# as the enemy passes through, with mid-charge streak VFX. On reaching the
# last cell, transitions to recovery.
class_name EnemyChargeAttackState
extends EnemyState

const CHARGE_STREAK_INTERVAL := 0.045

var _charge_cells: Array[Vector2i] = []
var _current_target_index: int = 0
var _streak_cooldown: float = 0.0
var _return_to_idle := false


func _init() -> void:
    state_id = EnemyStateId.CHARGE_ATTACK


func _enter() -> void:
    _charge_cells = enemy.get_stored_charge_cells().duplicate()
    _current_target_index = 0
    _streak_cooldown = 0.0
    _return_to_idle = false

    if _charge_cells.is_empty():
        ToastManager.show_warning("%s entered charge attack without stored charge cells." % enemy.name)
        _return_to_idle = true
        return

    enemy.begin_charge_attack()
    CombatFeedbackVFX.play_charge_start(enemy.global_position, enemy.get_facing(), enemy)
    _move_to_cell(_charge_cells[0])
    _play_charge_streak()


func _exit() -> void:
    _return_to_idle = false
    _charge_cells.clear()
    enemy.end_charge_attack()
    enemy.clear_stored_charge_cells()


func _physics_update(_delta: float) -> void:
    if _return_to_idle:
        change_state(EnemyStateId.IDLE)
        return

    _streak_cooldown -= _delta
    if _current_target_index >= _charge_cells.size():
        return

    if _streak_cooldown <= 0.0:
        _play_charge_streak()
        _streak_cooldown = CHARGE_STREAK_INTERVAL

    var grid := enemy.get_grid()
    var target_cell := _charge_cells[_current_target_index]
    var target_world := grid.cell_center(target_cell)

    var arrival_threshold := enemy.tile_size() * 0.1
    if enemy.global_position.distance_squared_to(target_world) < arrival_threshold * arrival_threshold:
        enemy.set_grid_pos(target_cell)
        enemy.global_position = target_world
        enemy.register_grid_occupant()

        var t := enemy.get_telegraph()
        if t != null:
            t.clear_cell(target_cell)

        _current_target_index += 1

        if _current_target_index >= _charge_cells.size():
            enemy.velocity = Vector2.ZERO
            if t != null:
                t.clear()
            change_state(enemy.get_recovery_state_id())
        else:
            _move_to_cell(_charge_cells[_current_target_index])


func _move_to_cell(cell: Vector2i) -> void:
    var grid := enemy.get_grid()
    var target_world := grid.cell_center(cell)
    var dir := (target_world - enemy.global_position).normalized()
    enemy.velocity = dir * enemy.get_charge_speed()


func _play_charge_streak() -> void:
    var direction := enemy.velocity.normalized()
    if direction == Vector2.ZERO:
        direction = enemy.get_facing()
    CombatFeedbackVFX.play_charge_streak(enemy.global_position, direction, enemy)
