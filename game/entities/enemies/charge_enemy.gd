# charge_enemy.gd
# 1x1 grid enemy that lines up with the target, telegraphs, then rushes forward.
class_name ChargeEnemy
extends GridEnemy

const CHARGING_SPEED := 480.0
const WARNING_DURATION := 1.0
const RECOVERY_DURATION := 3.0

# -- State --------------------------------------------------------------------
var _charge_cells: Array[Vector2i] = []

# -- Node references ----------------------------------------------------------
@onready var _contact_hitbox: Hitbox = _find_child_node("ContactHitbox") as Hitbox
@onready var _telegraph: TileTelegraph = _find_child_node("TileTelegraph") as TileTelegraph

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    if _telegraph != null:
        _telegraph.setup(_grid)

# == Common API ================================================================


func is_player_in_same_line() -> bool:
    if _grid == null or not has_target():
        return false
    var player_cell := _grid.world_to_grid(_target.global_position)
    return _grid_pos.x == player_cell.x or _grid_pos.y == player_cell.y


func get_charge_cells_from_pos(from: Vector2i, facing: Vector2) -> Array[Vector2i]:
    var f := Vector2i(int(facing.x), int(facing.y))
    var cells: Array[Vector2i] = []
    var cell := from + f
    while _grid.is_in_bounds(cell):
        cells.append(cell)
        cell += f
    return cells


func get_charge_cells() -> Array[Vector2i]:
    return get_charge_cells_from_pos(_grid_pos, _facing)


func get_body() -> Polygon2D:
    return _body


func get_telegraph() -> TileTelegraph:
    return _telegraph


func get_stored_charge_cells() -> Array[Vector2i]:
    return _charge_cells


func set_stored_charge_cells(cells: Array[Vector2i]) -> void:
    _charge_cells = cells


func clear_stored_charge_cells() -> void:
    _charge_cells.clear()


func get_idle_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.IDLE


func get_reposition_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.REPOSITION_STEP


func get_face_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.FACE_ONCE


func get_recovery_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.RECOVERY


func get_staggered_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.STAGGERED


func get_dead_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.DEAD


func get_pre_plan_state_id() -> int:
    if is_player_in_same_line():
        return ChargeEnemyState.ChargeEnemyStateId.CHARGE_TELEGRAPH
    return -1


func get_recovery_duration() -> float:
    return RECOVERY_DURATION


func get_arrival_override_state_id() -> int:
    if is_player_in_same_line():
        return ChargeEnemyState.ChargeEnemyStateId.CHARGE_TELEGRAPH
    return -1


func plan_next_action() -> bool:
    clear_planned_action()

    if _grid == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := _grid.world_to_grid(_target.global_position)

    if not _grid.is_in_bounds(target_cell):
        return false

    if start == target_cell:
        queue_redraw()
        return true

    var path: Array[Vector2i] = []
    var line_goals := _collect_charge_line_goal_cells(target_cell, start)
    if not line_goals.is_empty():
        if start in line_goals:
            queue_redraw()
            return true
        path = _find_path_to_cell(start, NO_BLOCKED_CELL, line_goals)

    if path.is_empty() and not _grid.is_blocked(target_cell):
        path = _find_path_to_cell(start, NO_BLOCKED_CELL, [target_cell])

    if path.is_empty():
        var fallback_goals := _collect_adjacent_goal_cells(target_cell, start)
        if fallback_goals.is_empty():
            return false
        if start in fallback_goals:
            queue_redraw()
            return true
        path = _find_path_to_cell(start, target_cell, fallback_goals)

    if path.is_empty():
        return false

    _planned_path = path
    _refresh_planned_reservations()
    queue_redraw()
    return true

# == Setup helpers =============================================================


func _after_setup_ready() -> void:
    if _telegraph != null:
        _telegraph.setup(_grid)


func _on_guard_broken_extra() -> void:
    if _telegraph != null:
        _telegraph.clear()


func _on_begin_death_extra() -> void:
    if _telegraph != null:
        _telegraph.clear()
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)


func _reset_extra() -> void:
    _charge_cells.clear()


func _collect_charge_line_goal_cells(target_cell: Vector2i, start: Vector2i) -> Array[Vector2i]:
    var goals: Array[Vector2i] = []
    for x in range(_grid.GRID_SIZE.x):
        var cell := Vector2i(x, target_cell.y)
        if cell == target_cell:
            continue
        if cell == start or not _grid.is_blocked(cell):
            goals.append(cell)
    for y in range(_grid.GRID_SIZE.y):
        var cell := Vector2i(target_cell.x, y)
        if cell == target_cell:
            continue
        if cell in goals:
            continue
        if cell == start or not _grid.is_blocked(cell):
            goals.append(cell)
    return goals
