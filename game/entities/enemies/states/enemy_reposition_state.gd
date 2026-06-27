# enemy_reposition_state.gd
# Shared one-cell grid reposition state for 1x1 enemies.
class_name EnemyRepositionState
extends EnemyState

var _target_cell: Vector2i
var _has_step: bool = false


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    _has_step = enemy.has_planned_path()
    if _has_step:
        _target_cell = enemy.consume_next_planned_cell()
        enemy.face_toward_cell(_target_cell)


func _physics_update(_delta: float) -> void:
    if not _has_step:
        enemy.velocity = Vector2.ZERO
        change_state(enemy.get_face_state_id())
        return

    var grid: GridArena = enemy.get_grid()
    var target_world := grid.cell_center(_target_cell)
    var dir := (target_world - enemy.global_position).normalized()
    enemy.velocity = dir * enemy.get_move_speed()

    var arrival_threshold := enemy.tile_size() * 0.1
    if enemy.global_position.distance_squared_to(target_world) < arrival_threshold * arrival_threshold:
        enemy.set_grid_pos(_target_cell)
        enemy.global_position = target_world
        enemy.register_grid_occupant()

        var override_state_id := enemy.get_arrival_override_state_id()
        if override_state_id >= 0:
            change_state(override_state_id)
            return

        var planned := enemy.plan_next_action()

        if enemy.has_planned_path():
            _target_cell = enemy.consume_next_planned_cell()
            enemy.face_toward_cell(_target_cell)
            var next_world := grid.cell_center(_target_cell)
            var next_dir := (next_world - enemy.global_position).normalized()
            enemy.velocity = next_dir * enemy.get_move_speed()
        elif planned:
            change_state(enemy.get_face_state_id())
        else:
            change_state(enemy.get_idle_state_id())
