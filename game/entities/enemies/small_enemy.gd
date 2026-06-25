# small_enemy.gd
# 1x1 grid actor enemy. Grid-based AI: reposition -> face target -> telegraph ->
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

@onready var _hitbox: Hitbox = $AttackHitbox
@onready var _state_machine: StateMachine = $StateMachine
@onready var _guard: Guard = $Guard
@onready var _telegraph: TileTelegraph = $TileTelegraph
@onready var hurtbox: Hurtbox = $Hurtbox

var _grid: GridArena
var _target: Node2D
var _grid_pos: Vector2i
var _facing: Vector2 = Vector2.DOWN
var _cooldown_timer: Timer
var _staggered: bool = false


func setup(grid: GridArena, target: Node2D) -> void:
    _grid = grid
    _target = target
    var t := $TileTelegraph as TileTelegraph
    if t != null:
        t.setup(grid)

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


func start_telegraph(tiles: Array) -> void:
    _telegraph.show_warning(tiles)


func clear_telegraph() -> void:
    _telegraph.clear()


func enable_attack_hitbox() -> void:
    _hitbox.set_enabled(true)


func disable_attack_hitbox() -> void:
    _hitbox.set_enabled(false)


func set_attack_hitbox_position(pos: Vector2) -> void:
    _hitbox.global_position = pos


func get_guard() -> Guard:
    return _guard

# -- Lifecycle --


func _ready() -> void:
    super()
    _hitbox.set_enabled(false)
    _grid_pos = _grid.world_to_grid(global_position)
    _grid.register_occupant(self, [_grid_pos])

    if hurtbox != null:
        hurtbox.got_hit.connect(_on_got_hit)

    _cooldown_timer = Timer.new()
    _cooldown_timer.one_shot = true
    add_child(_cooldown_timer)

    if _guard != null:
        _guard.guard_broken.connect(_on_guard_broken)


func _physics_process(_delta: float) -> void:
    if not is_instance_valid(_target):
        velocity = Vector2.ZERO
        move_and_slide()
        return

    _update_grid_pos()
    move_and_slide()


func _update_grid_pos() -> void:
    var new_cell := _grid.world_to_grid(global_position)
    if new_cell != _grid_pos:
        _grid_pos = new_cell
        _grid.register_occupant(self, [_grid_pos])

# -- Signal handlers --


func _on_guard_broken() -> void:
    _staggered = true
    _disable_telegraph_and_hitbox()
    _state_machine.request_transition(SmallEnemyState.SmallEnemyStateId.STAGGERED, true)


func _on_got_hit(_amount: float, source: Node2D) -> void:
    if _guard == null or source == null:
        return
    var src_pos := source.global_position
    var angle := DirectionResolver.resolve(src_pos, global_position, _facing)
    var gd := DirectionResolver.normal_guard_damage(angle)
    _guard.take_guard_damage(gd)


func _disable_telegraph_and_hitbox() -> void:
    if _telegraph != null:
        _telegraph.clear()
    if _hitbox != null:
        _hitbox.set_enabled(false)

# -- Pool lifecycle --


func reset() -> void:
    super()
    _staggered = false
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        _grid.register_occupant(self, [_grid_pos])
