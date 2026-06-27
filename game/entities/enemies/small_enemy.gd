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
@onready var _hitbox: Hitbox = %AttackHitbox
@onready var _attack_controller: SmallEnemyAttackController = %AttackController
@onready var _telegraph: TileTelegraph = %TileTelegraph

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    _hitbox.set_enabled(false)
    _configure_attack_controller()
    if _attack_controller != null:
        _attack_controller.randomize_attack_pattern()

# == Common API ================================================================


func can_attack() -> bool:
    if _grid == null or _attack_controller == null or not has_target():
        return false
    var target_cell := _grid.world_to_grid(_target.global_position)
    return target_cell in _attack_controller.get_attack_cells(_grid_pos, _facing)


func get_attack_controller() -> SmallEnemyAttackController:
    return _attack_controller


func get_idle_state_id() -> int:
    return SmallEnemyState.SmallEnemyStateId.IDLE


func get_reposition_state_id() -> int:
    return SmallEnemyState.SmallEnemyStateId.REPOSITION_STEP


func get_face_state_id() -> int:
    return SmallEnemyState.SmallEnemyStateId.FACE_ONCE


func get_recovery_state_id() -> int:
    return SmallEnemyState.SmallEnemyStateId.RECOVERY


func get_staggered_state_id() -> int:
    return SmallEnemyState.SmallEnemyStateId.STAGGERED


func get_dead_state_id() -> int:
    return SmallEnemyState.SmallEnemyStateId.DEAD


func get_after_face_state_id() -> int:
    if can_attack():
        return SmallEnemyState.SmallEnemyStateId.TELEGRAPH
    return SmallEnemyState.SmallEnemyStateId.IDLE


func plan_next_action() -> bool:
    clear_planned_action()

    if _grid == null or _attack_controller == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := _grid.world_to_grid(_target.global_position)
    var attack_origins: Array[Vector2i] = []
    var blocked_cell := target_cell
    var uses_target_collision := false

    if _attack_controller.get_attack_pattern() == SmallEnemyAttackController.AttackPattern.SURROUND_3X3:
        if not _grid.is_in_bounds(target_cell):
            return false
        uses_target_collision = true
        attack_origins.append(target_cell)
        blocked_cell = NO_BLOCKED_CELL
    else:
        for facing_cell: Vector2i in CARDINAL_DIRECTIONS:
            var facing := Vector2(facing_cell.x, facing_cell.y)
            for x in range(GridArena.GRID_SIZE.x):
                for y in range(GridArena.GRID_SIZE.y):
                    var origin_cell := Vector2i(x, y)
                    if origin_cell != start and _grid.is_blocked(origin_cell):
                        continue
                    if target_cell not in _attack_controller.get_attack_cells(origin_cell, facing):
                        continue
                    if origin_cell not in attack_origins:
                        attack_origins.append(origin_cell)

    if attack_origins.is_empty():
        return false

    if start in attack_origins:
        queue_redraw()
        return true

    var path := _find_path_to_cell(start, blocked_cell, attack_origins)
    if path.is_empty() and uses_target_collision:
        attack_origins = _collect_adjacent_attack_origin_cells(target_cell, start)
        blocked_cell = target_cell
        if attack_origins.is_empty():
            return false
        if start in attack_origins:
            queue_redraw()
            return true
        path = _find_path_to_cell(start, blocked_cell, attack_origins)

    if path.is_empty():
        return false

    _planned_path = path
    _refresh_planned_reservations()
    queue_redraw()
    return true

# == Setup helpers =============================================================


func _after_setup_ready() -> void:
    _configure_attack_controller()


func _on_guard_broken_extra() -> void:
    _cancel_attack()


func _on_begin_death_extra() -> void:
    _cancel_attack()
    if _hitbox != null:
        _hitbox.set_enabled(false)


func _reset_extra() -> void:
    if _hitbox != null:
        _hitbox.set_enabled(false)


func _cancel_attack() -> void:
    if _attack_controller != null:
        _attack_controller.cancel()


func _configure_attack_controller() -> void:
    if _attack_controller == null:
        return
    _attack_controller.setup(_grid, _telegraph, _hitbox, self)


func _collect_adjacent_attack_origin_cells(target_cell: Vector2i, start: Vector2i) -> Array[Vector2i]:
    var origin_cells: Array[Vector2i] = []
    for direction: Vector2i in CARDINAL_DIRECTIONS:
        var neighbor := target_cell + direction
        if not _grid.is_in_bounds(neighbor):
            continue
        if neighbor == start or not _grid.is_blocked(neighbor):
            origin_cells.append(neighbor)
    return origin_cells
