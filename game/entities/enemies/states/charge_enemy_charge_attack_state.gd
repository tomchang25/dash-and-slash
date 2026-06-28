# charge_enemy_charge_attack_state.gd
# Charge movement phase. Rushes through pre-computed cells at 4x speed.
# Clears telegraph per-cell as the enemy passes through. On reaching the
# last cell, transitions to RECOVERY.
extends ChargeEnemyState

var _charge_cells: Array[Vector2i] = []
var _current_target_index: int = 0


func _init() -> void:
    state_id = ChargeEnemyStateId.CHARGE_ATTACK


func _enter() -> void:
    _charge_cells = enemy.get_stored_charge_cells().duplicate()
    _current_target_index = 0
    if _charge_cells.is_empty():
        change_state(ChargeEnemyStateId.IDLE)
        return
    enemy.begin_charge_attack()
    _move_to_cell(_charge_cells[0])


func _exit() -> void:
    _charge_cells.clear()
    enemy.end_charge_attack()
    enemy.clear_stored_charge_cells()


func _physics_update(_delta: float) -> void:
    if _current_target_index >= _charge_cells.size():
        return

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
            change_state(ChargeEnemyStateId.RECOVERY)
        else:
            _move_to_cell(_charge_cells[_current_target_index])


func _move_to_cell(cell: Vector2i) -> void:
    var grid := enemy.get_grid()
    var target_world := grid.cell_center(cell)
    var dir := (target_world - enemy.global_position).normalized()
    enemy.velocity = dir * enemy.get_charge_speed()
