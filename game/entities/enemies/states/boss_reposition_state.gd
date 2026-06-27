# boss_reposition_state.gd
# Moves the boss one cell at a time along a planned path toward a line-of-sight
# position. Checks player alignment on every frame via position-based detection,
# and snaps to a valid grid cell before transitioning to attack.
extends BossState

var _target_cell: Vector2i
var _has_step: bool = false
var _arriving: bool = false


func _init() -> void:
    state_id = BossStateId.REPOSITION


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    _arriving = false
    _has_step = enemy.has_planned_path()
    if _has_step:
        _target_cell = enemy.consume_next_planned_cell()
        enemy.face_toward_cell(_target_cell)


func _physics_update(_delta: float) -> void:
    if not _has_step:
        enemy.velocity = Vector2.ZERO
        _transition_to_face()
        return

    var grid := enemy.get_grid()
    if grid == null:
        _transition_to_face()
        return

    var target_world := grid.cell_center(_target_cell)
    var dir := (target_world - enemy.global_position).normalized()
    enemy.velocity = dir * enemy.get_move_speed()

    if enemy.is_player_in_same_line():
        _arriving = false
        enemy.snap_to_grid_cell(_target_cell)
        _transition_to_face()
        return

    var arrival_threshold := enemy.tile_size() * 0.1
    if enemy.global_position.distance_squared_to(target_world) < arrival_threshold * arrival_threshold:
        _arriving = false
        enemy.snap_to_grid_cell(_target_cell)

        if not enemy.has_planned_path():
            enemy.velocity = Vector2.ZERO
            _transition_to_face()
            return

        _target_cell = enemy.consume_next_planned_cell()
        enemy.face_toward_cell(_target_cell)


func _transition_to_face() -> void:
    enemy.choose_next_mode()
    change_state(BossStateId.FACE_TARGET)
