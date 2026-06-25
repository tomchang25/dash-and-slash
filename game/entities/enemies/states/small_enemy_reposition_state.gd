# small_enemy_reposition_state.gd
# Reposition state — grid-based movement toward the target using axis-prioritized
# pathfinding. Transitions to FACE_TARGET when in attack range, or IDLE when
# movement completes.
extends SmallEnemyState

func _init() -> void:
    state_id = SmallEnemyStateId.REPOSITION


func _physics_update(_delta: float) -> void:
    if enemy.can_attack():
        enemy.velocity = Vector2.ZERO
        change_state(SmallEnemyStateId.FACE_TARGET)
        return

    var grid: GridArena = enemy.get_grid()
    var current_cell := enemy.get_grid_pos()
    var target_cell := grid.world_to_grid(enemy.get_target().global_position)
    var diff := target_cell - current_cell

    var move := Vector2i(0, 0)
    if abs(diff.x) > abs(diff.y):
        move = Vector2i(signi(diff.x), 0)
    else:
        move = Vector2i(0, signi(diff.y))

    var next := current_cell + move
    if not grid.is_in_bounds(next) or grid.is_occupied(next):
        # try alternate axis
        if abs(diff.y) > 0:
            var alt := current_cell + Vector2i(0, signi(diff.y))
            if grid.is_in_bounds(alt) and not grid.is_occupied(alt):
                move = Vector2i(0, signi(diff.y))
            elif abs(diff.x) > 0:
                var alt2 := current_cell + Vector2i(signi(diff.x), 0)
                if grid.is_in_bounds(alt2) and not grid.is_occupied(alt2):
                    move = Vector2i(signi(diff.x), 0)
                else:
                    move = Vector2i.ZERO

    if move == Vector2i.ZERO:
        enemy.velocity = Vector2.ZERO
        return

    next = current_cell + move
    var target_world := grid.cell_center(next)
    var dir := (target_world - enemy.global_position).normalized()
    enemy.velocity = dir * enemy.MOVE_SPEED

    if enemy.global_position.distance_squared_to(target_world) < enemy.tile_size() * 0.25:
        enemy.set_grid_pos(next)
        enemy.global_position = target_world
        enemy.register_grid_occupant()
        enemy.velocity = Vector2.ZERO
        change_state(SmallEnemyStateId.IDLE)
