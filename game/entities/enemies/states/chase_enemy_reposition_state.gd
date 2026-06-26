# chase_enemy_reposition_state.gd
# Reposition step state — moves one grid cell at a time. On each arrival,
# re-evaluates the plan using the player's current position so the enemy
# naturally chases the player.
extends ChaseEnemyState

var _target_cell: Vector2i
var _has_step: bool = false


func _init() -> void:
    state_id = ChaseEnemyStateId.REPOSITION_STEP


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    _has_step = enemy.has_planned_path()
    if _has_step:
        _target_cell = enemy.consume_next_planned_cell()
        enemy.face_toward_cell(_target_cell)


func _physics_update(_delta: float) -> void:
    if not _has_step:
        enemy.velocity = Vector2.ZERO
        change_state(ChaseEnemyStateId.FACE_ONCE)
        return

    var grid: GridArena = enemy.get_grid()
    var target_world := grid.cell_center(_target_cell)
    var dir := (target_world - enemy.global_position).normalized()
    enemy.velocity = dir * enemy.MOVE_SPEED

    var arrival_threshold := enemy.tile_size() * 0.1
    if enemy.global_position.distance_squared_to(target_world) < arrival_threshold * arrival_threshold:
        enemy.set_grid_pos(_target_cell)
        enemy.global_position = target_world
        enemy.register_grid_occupant()

        var planned := enemy.plan_next_action()

        if enemy.has_planned_path():
            _target_cell = enemy.consume_next_planned_cell()
            enemy.face_toward_cell(_target_cell)
            var next_world := grid.cell_center(_target_cell)
            var next_dir := (next_world - enemy.global_position).normalized()
            enemy.velocity = next_dir * enemy.MOVE_SPEED
        elif planned:
            change_state(ChaseEnemyStateId.FACE_ONCE)
        else:
            change_state(ChaseEnemyStateId.IDLE)
