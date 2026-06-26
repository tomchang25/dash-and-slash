# small_enemy.gd
# 1x1 grid actor enemy. Grid-based AI: reposition step -> face once -> telegraph ->
# attack -> recovery cycle. Attacks are simple 1-tile forward hitboxes.
# Guard 4 (1 shield), uses Hitbox/Hurtbox/Health components from template.
# Uses the template's StateMachine with behaviour-delegation: states own logic,
# the entity provides a public query/command API.
class_name SmallEnemy
extends Entity

const MOVE_SPEED := 120.0
const ATTACK_RANGE := 1.5
const TELEGRAPH_DURATION := 0.6
const ATTACK_DURATION := 0.25
const RECOVERY_DURATION := 0.4
const CYCLE_COOLDOWN := 1.0
const CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const PATH_DEBUG_COLOR := Color(0.2, 0.8, 1.0, 0.8)
const PATH_DEBUG_WIDTH := 4.0

@onready var _hitbox: Hitbox = $AttackHitbox
@onready var _state_machine: StateMachine = $StateMachine
@onready var _guard: Guard = $Guard
@onready var _attack_controller: SmallEnemyAttackController = $AttackController
@onready var hurtbox: Hurtbox = $Hurtbox

var _grid: GridArena
var _target: Node2D
var _grid_pos: Vector2i
var _facing: Vector2 = Vector2.DOWN
var _cooldown_timer: Timer
var _staggered: bool = false
var _planned_path: Array[Vector2i] = []
var _active_path_cell: Vector2i
var _has_active_path_cell: bool = false
var _planned_facing: Vector2 = Vector2.DOWN
var _has_planned_action: bool = false


func setup(grid: GridArena, target: Node2D) -> void:
    _grid = grid
    _target = target
    _configure_attack_controller()

# -- Public API (called BY states, not the other way around) --


func has_target() -> bool:
    return is_instance_valid(_target)


func get_target() -> Node2D:
    return _target


func set_target(target: Node2D) -> void:
    _target = target


func can_attack() -> bool:
    return global_position.distance_to(_target.global_position) <= _grid.tile_size * ATTACK_RANGE


func is_staggered() -> bool:
    return _staggered


func set_staggered(value: bool) -> void:
    _staggered = value


func cooldown_active() -> bool:
    return _cooldown_timer != null and _cooldown_timer.time_left > 0.0


func start_cooldown() -> void:
    if _cooldown_timer != null:
        _cooldown_timer.start(CYCLE_COOLDOWN)


func tile_size() -> float:
    return _grid.tile_size if _grid else 64.0


func get_grid() -> GridArena:
    return _grid


func get_grid_pos() -> Vector2i:
    return _grid_pos


func set_grid_pos(pos: Vector2i) -> void:
    _grid_pos = pos


func get_facing() -> Vector2:
    return _facing


func set_facing(v: Vector2) -> void:
    _facing = v


func plan_next_action() -> bool:
    clear_planned_action()

    if _grid == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := _grid.world_to_grid(_target.global_position)
    var attack_cells: Array[Vector2i] = []
    var facing_by_cell: Dictionary = { }

    for facing_cell: Vector2i in CARDINAL_DIRECTIONS:
        var attack_cell := target_cell - facing_cell
        if not _grid.is_in_bounds(attack_cell):
            continue
        if attack_cell != start and _grid.is_blocked(attack_cell):
            continue
        attack_cells.append(attack_cell)
        facing_by_cell[attack_cell] = Vector2(facing_cell.x, facing_cell.y)

    if attack_cells.is_empty():
        return false

    if start in attack_cells:
        _planned_facing = facing_by_cell[start]
        _has_planned_action = true
        queue_redraw()
        return true

    var path := _find_path_to_attack_cell(start, target_cell, attack_cells)
    if path.is_empty():
        return false

    _planned_path = path
    _planned_facing = facing_by_cell[path[path.size() - 1]]
    _has_planned_action = true
    _grid.reserve_cell(self, path[path.size() - 1])
    queue_redraw()
    return true


func clear_planned_action() -> void:
    if _grid != null:
        _grid.clear_reservation(self)
    _planned_path.clear()
    _has_active_path_cell = false
    _has_planned_action = false
    queue_redraw()


func has_planned_action() -> bool:
    return _has_planned_action


func has_planned_path() -> bool:
    return not _planned_path.is_empty()


func consume_next_planned_cell() -> Vector2i:
    var next := _planned_path[0]
    _planned_path.remove_at(0)
    _active_path_cell = next
    _has_active_path_cell = true
    queue_redraw()
    return next


func face_toward_cell(target_cell: Vector2i) -> void:
    var step := target_cell - _grid_pos
    if step == Vector2i.ZERO:
        return
    _facing = Vector2(signi(step.x), signi(step.y))
    face_arrow()


func apply_planned_facing() -> void:
    _facing = _planned_facing
    face_arrow()


func face_target_position() -> void:
    if not has_target():
        return
    var direction := _target.global_position - global_position
    if direction == Vector2.ZERO:
        return
    _facing = cardinal_snap(direction)
    face_arrow()


func cardinal_snap(v: Vector2) -> Vector2:
    if abs(v.x) > abs(v.y):
        return Vector2(sign(v.x), 0.0)
    return Vector2(0.0, sign(v.y))


func face_arrow() -> void:
    var arr: Polygon2D = get_node_or_null("FacingArrow") as Polygon2D
    if arr != null:
        arr.rotation = _facing.angle() - PI / 2.0


func register_grid_occupant() -> void:
    _grid.register_occupant(self, [_grid_pos])


func get_attack_controller() -> SmallEnemyAttackController:
    return _attack_controller


func get_guard() -> Guard:
    return _guard

# -- Lifecycle --


func _ready() -> void:
    super()
    _hitbox.set_enabled(false)
    _configure_attack_controller()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        _grid.register_occupant(self, [_grid_pos])

    if hurtbox != null:
        hurtbox.got_hit.connect(_on_got_hit)

    _cooldown_timer = Timer.new()
    _cooldown_timer.one_shot = true
    # node-src: timer
    add_child(_cooldown_timer)

    if _guard != null:
        _guard.guard_broken.connect(_on_guard_broken)


func _physics_process(_delta: float) -> void:
    if not is_instance_valid(_target):
        velocity = Vector2.ZERO
        move_and_slide()
        return

    move_and_slide()
    if _has_planned_action:
        queue_redraw()


func _draw() -> void:
    if _grid == null or (not _has_active_path_cell and _planned_path.is_empty()):
        return

    var previous := Vector2.ZERO
    if _has_active_path_cell:
        var active_point := to_local(_grid.cell_center(_active_path_cell))
        draw_line(previous, active_point, PATH_DEBUG_COLOR, PATH_DEBUG_WIDTH)
        draw_circle(active_point, PATH_DEBUG_WIDTH * 1.5, PATH_DEBUG_COLOR)
        previous = active_point
    else:
        previous = to_local(_grid.cell_center(_grid_pos))

    for cell in _planned_path:
        var point := to_local(_grid.cell_center(cell))
        draw_line(previous, point, PATH_DEBUG_COLOR, PATH_DEBUG_WIDTH)
        draw_circle(point, PATH_DEBUG_WIDTH * 1.5, PATH_DEBUG_COLOR)
        previous = point


func _update_grid_pos() -> void:
    var new_cell := _grid.world_to_grid(global_position)
    if new_cell != _grid_pos:
        _grid_pos = new_cell
        _grid.register_occupant(self, [_grid_pos])

# -- Signal handlers --


func _on_guard_broken() -> void:
    _staggered = true
    clear_planned_action()
    _cancel_attack()
    _state_machine.request_transition(SmallEnemyState.SmallEnemyStateId.STAGGERED, true)


func _on_got_hit(_amount: float, source: Node2D) -> void:
    if _guard == null or source == null:
        return
    var src_pos := source.global_position
    var angle := DirectionResolver.resolve(src_pos, global_position, _facing)
    var gd := DirectionResolver.normal_guard_damage(angle)
    _guard.take_guard_damage(gd)


func _cancel_attack() -> void:
    if _attack_controller != null:
        _attack_controller.cancel()


func _configure_attack_controller() -> void:
    var controller := get_node_or_null("AttackController") as SmallEnemyAttackController
    if controller == null:
        return
    var telegraph := get_node_or_null("TileTelegraph") as TileTelegraph
    var hitbox := get_node_or_null("AttackHitbox") as Hitbox
    controller.setup(_grid, telegraph, hitbox)
    _attack_controller = controller


func _find_path_to_attack_cell(start: Vector2i, blocked_cell: Vector2i, attack_cells: Array[Vector2i]) -> Array[Vector2i]:
    var queue: Array[Vector2i] = [start]
    var came_from: Dictionary = { }
    var queue_index := 0
    var goal := Vector2i(-1, -1)
    came_from[start] = start

    while queue_index < queue.size():
        var current := queue[queue_index]
        queue_index += 1

        if current in attack_cells:
            goal = current
            break

        for direction: Vector2i in CARDINAL_DIRECTIONS:
            var next := current + direction
            if came_from.has(next):
                continue
            if not _can_path_through(next, blocked_cell):
                continue
            came_from[next] = current
            queue.append(next)

    if goal == Vector2i(-1, -1):
        var empty_path: Array[Vector2i] = []
        return empty_path

    var path: Array[Vector2i] = []
    var path_cell := goal
    while came_from[path_cell] != path_cell:
        path.push_front(path_cell)
        path_cell = came_from[path_cell]
    return path


func _can_path_through(cell: Vector2i, blocked_cell: Vector2i) -> bool:
    if not _grid.is_in_bounds(cell):
        return false
    if cell == blocked_cell:
        return false
    return true

# -- Pool lifecycle --


func reset() -> void:
    super()
    _staggered = false
    clear_planned_action()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        _grid.register_occupant(self, [_grid_pos])
