# charge_enemy_charge_attack_state.gd
# Charge movement phase. Rushes through pre-computed cells at 4x speed.
# Clears telegraph per-cell as the enemy passes through. On reaching the
# last cell, transitions to RECOVERY.
class_name ChargeEnemyChargeAttackState
extends EnemyState

var _charge_cells: Array[Vector2i] = []
var _current_target_index: int = 0


func _init() -> void:
    state_id = EnemyStateId.CHARGE_ATTACK


func _enter() -> void:
    var charge_enemy := enemy as ChargeEnemy
    _charge_cells = charge_enemy.get_stored_charge_cells().duplicate()
    _current_target_index = 0
    if _charge_cells.is_empty():
        change_state(EnemyStateId.IDLE)
        return
    charge_enemy.begin_charge_attack()
    _move_to_cell(_charge_cells[0], charge_enemy)


func _exit() -> void:
    var charge_enemy := enemy as ChargeEnemy
    _charge_cells.clear()
    charge_enemy.end_charge_attack()
    charge_enemy.clear_stored_charge_cells()


func _physics_update(_delta: float) -> void:
    if _current_target_index >= _charge_cells.size():
        return

    var charge_enemy := enemy as ChargeEnemy
    var grid := charge_enemy.get_grid()
    var target_cell := _charge_cells[_current_target_index]
    var target_world := grid.cell_center(target_cell)

    var arrival_threshold := charge_enemy.tile_size() * 0.1
    if charge_enemy.global_position.distance_squared_to(target_world) < arrival_threshold * arrival_threshold:
        charge_enemy.set_grid_pos(target_cell)
        charge_enemy.global_position = target_world
        charge_enemy.register_grid_occupant()

        var t := charge_enemy.get_telegraph()
        if t != null:
            t.clear_cell(target_cell)

        _current_target_index += 1

        if _current_target_index >= _charge_cells.size():
            charge_enemy.velocity = Vector2.ZERO
            if t != null:
                t.clear()
            change_state(EnemyStateId.RECOVERY)
        else:
            _move_to_cell(_charge_cells[_current_target_index], charge_enemy)


func _move_to_cell(cell: Vector2i, charge_enemy: ChargeEnemy) -> void:
    var grid := charge_enemy.get_grid()
    var target_world := grid.cell_center(cell)
    var dir := (target_world - charge_enemy.global_position).normalized()
    charge_enemy.velocity = dir * charge_enemy.get_charge_speed()
