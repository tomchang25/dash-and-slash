# enemy_reposition_state.gd
# Shared one-cell grid reposition state for 1x1 enemies.
class_name EnemyRepositionState
extends EnemyState

func _init() -> void:
    state_id = EnemyStateId.REPOSITION


var _target_cell: Vector2i
var _has_step: bool = false
var _arrival_handled := false
var _replan_requested := false
var _reservation_lost_warned := false


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    _has_step = enemy.has_planned_path()
    _arrival_handled = false
    _replan_requested = false
    _reservation_lost_warned = false
    if _has_step:
        var grid: GridArena = enemy.get_grid()
        var path_first := enemy.get_planned_path_first()
        if path_first != enemy.NO_BLOCKED_CELL and not grid.is_reserved_by(path_first, enemy):
            enemy.clear_planned_path()
            _has_step = false
            _replan_requested = true
            return
        _target_cell = enemy.consume_next_planned_cell()
        enemy.face_toward_cell(_target_cell)


func _physics_update(delta: float) -> void:
    if _replan_requested:
        _replan_requested = false
        _replan_or_transition()
        return

    if not _has_step:
        enemy.velocity = Vector2.ZERO
        change_state(enemy.get_face_state_id())
        return

    var grid: GridArena = enemy.get_grid()

    # Active step reservations should not be preempted; warn once and finish the step if it still happens.
    if not grid.is_reserved_by(_target_cell, enemy) and not _reservation_lost_warned:
        ToastManager.show_warning("%s lost active step reservation for %s while repositioning." % [enemy.name, str(_target_cell)])
        _reservation_lost_warned = true

    var target_world := grid.cell_center(_target_cell)
    var dir := (target_world - enemy.global_position).normalized()
    enemy.velocity = dir * enemy.get_move_speed()

    var arrival_threshold := maxf(1.0, enemy.get_move_speed() * delta)
    if not _arrival_handled and enemy.global_position.distance_squared_to(target_world) < arrival_threshold * arrival_threshold:
        _arrival_handled = true
        enemy.set_grid_pos(_target_cell)
        enemy.global_position = target_world
        enemy.register_grid_occupant()

        var override_state_id := enemy.get_arrival_override_state_id()
        if override_state_id >= 0:
            change_state(override_state_id)
            return

        _replan_or_transition()


func _replan_or_transition() -> void:
    var planned := enemy.plan_next_action()

    if enemy.has_planned_path():
        var grid := enemy.get_grid()
        _target_cell = enemy.consume_next_planned_cell()
        _has_step = true
        _arrival_handled = false
        _reservation_lost_warned = false
        enemy.face_toward_cell(_target_cell)
        var next_world := grid.cell_center(_target_cell)
        var next_dir := (next_world - enemy.global_position).normalized()
        enemy.velocity = next_dir * enemy.get_move_speed()
    elif planned:
        _has_step = false
        enemy.velocity = Vector2.ZERO
        change_state(enemy.get_face_state_id())
    else:
        _has_step = false
        enemy.velocity = Vector2.ZERO
        change_state(enemy.get_idle_state_id())
