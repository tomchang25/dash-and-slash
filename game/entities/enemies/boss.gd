# boss.gd
# 2x2 grid actor boss with mode-swapping attacks managed by BossAttackController.
class_name Boss
extends Enemy

signal guard_changed(current: int, maximum: int)
signal guard_stagger_started
signal guard_stagger_ended

const TELEGRAPH_DURATION := 0.9
const CHARGE_DURATION := 0.25
const ATTACK_DURATION := 0.55
const RECOVERY_DURATION := 0.8
const CYCLE_COOLDOWN := 1.5
const CHARGING_SPEED := 520.0
const GUARDED_DAMAGE_MULTIPLIER := 0.25
const STAGGER_VFX_COLOR := Color(0.4, 0.6, 1.0, 1.0)
const BOSS_FOOTPRINT := Vector2i(2, 2)

# -- Exports ------------------------------------------------------------------
@export var death_sfx_event: SpatialAudioEvent
@export var damaged_sfx_event: SpatialAudioEvent
@export var blocked_sfx_event: SpatialAudioEvent
@export var attack_sfx_event: SpatialAudioEvent

# -- State --------------------------------------------------------------------
var _grid: GridArena
var _target: Node2D
var _grid_pos: Vector2i ## top-left cell of 2x2 footprint
var _facing: Vector2 = Vector2.DOWN
var _mode_index := 0
var _staggered := false
var _charge_cells: Array[Vector2i] = []
var _charge_index := 0

# -- Timer / tween handles ----------------------------------------------------
var _cooldown_timer: Timer
var _hurt_tween: Tween
var _stagger_tween: Tween

# -- Node references ----------------------------------------------------------
@onready var _state_machine: StateMachine = %StateMachine
@onready var _guard: Guard = %Guard
@onready var _attack_controller: BossAttackController = %AttackController
@onready var _telegraph: TileTelegraph = %TileTelegraph
@onready var _body: Polygon2D = %Body
@onready var hurtbox: Hurtbox = %Hurtbox
@onready var _facing_arrow: Polygon2D = %FacingArrow
@onready var _tile_hitbox: Hitbox = %TileAttackHitbox
@onready var _contact_hitbox: Hitbox = %ContactHitbox
@onready var _puff_hitbox: Hitbox = %PuffHitbox

# == Lifecycle ================================================================


func _ready() -> void:
    super()

    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        _refresh_occupied()

    _cooldown_timer = Timer.new()
    _cooldown_timer.one_shot = true
    # node-src: timer
    add_child(_cooldown_timer)

    if _guard != null:
        _guard.guard_changed.connect(_on_guard_changed)
        _guard.guard_broken.connect(_on_guard_broken)
        _guard.stagger_started.connect(_on_stagger_started)
        _guard.stagger_ended.connect(_on_stagger_ended)
        emit_guard_snapshot()

    if hurtbox != null:
        hurtbox.hit_received.connect(_on_hit_received)

    if health != null:
        health.damaged.connect(_on_damaged)

    _configure_attack_controller()
    _face_arrow()


func _physics_process(_delta: float) -> void:
    if not is_instance_valid(_target):
        velocity = Vector2.ZERO
    move_and_slide()

# == Signal handlers ==========================================================


func _on_guard_broken() -> void:
    _staggered = true
    cancel_attack()
    _state_machine.request_transition(BossState.BossStateId.STAGGERED, true)


func _on_guard_changed(current: int, maximum: int) -> void:
    guard_changed.emit(current, maximum)


func _on_stagger_started() -> void:
    _staggered = true
    guard_stagger_started.emit()
    if _hurt_tween != null and _hurt_tween.is_valid():
        return
    _start_stagger_vfx()


func _on_stagger_ended() -> void:
    _staggered = false
    guard_stagger_ended.emit()
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    if _body != null:
        _body.modulate = Color.WHITE


func _on_hit_received(amount: float, source: Node, guard_damage_profile: int) -> void:
    if not (source is Node2D):
        return

    var src_pos := (source as Node2D).global_position
    var angle := DirectionResolver.resolve(src_pos, global_position, _facing)
    var guard_damage: int
    if guard_damage_profile == Hitbox.GuardDamageProfile.DASH:
        guard_damage = DirectionResolver.dash_guard_damage(angle)
    else:
        guard_damage = DirectionResolver.normal_guard_damage(angle)

    var will_break_guard := _guard != null and not _guard.is_staggered() and _guard.current() > 0 and guard_damage >= _guard.current()
    var full_damage := _guard == null or _guard.is_staggered() or will_break_guard
    var hp_damage := amount if full_damage else amount * GUARDED_DAMAGE_MULTIPLIER

    if full_damage:
        if damaged_sfx_event != null:
            AudioManager.play_event(damaged_sfx_event, global_position)
    else:
        var sfx_event := damaged_sfx_event if angle == DirectionResolver.HitAngle.BACK else blocked_sfx_event
        if sfx_event != null:
            AudioManager.play_event(sfx_event, global_position)

    if health != null:
        health.take_damage(hp_damage, source)

    if health != null and not health.is_alive():
        _state_machine.request_transition(BossState.BossStateId.DEAD, true)
        return

    if _guard != null:
        _guard.take_guard_damage(guard_damage)


func _on_damaged(_amount: float, _source: Node) -> void:
    if _body == null:
        return
    if _hurt_tween != null and _hurt_tween.is_valid():
        _hurt_tween.kill()
    _hurt_tween = create_tween()
    _hurt_tween.tween_property(_body, "modulate", Color.WHITE, 0.03)
    _hurt_tween.tween_property(_body, "modulate", Color(0.8, 0.2, 0.2, 1.0), 0.06)
    _hurt_tween.tween_property(_body, "modulate", Color.WHITE, 0.08)
    _hurt_tween.finished.connect(
        func():
            if _body != null:
                if _staggered:
                    _start_stagger_vfx()
                else:
                    _body.modulate = Color.WHITE,
        CONNECT_ONE_SHOT,
    )

# == Common API ================================================================


func setup(grid: GridArena, target: Node2D) -> void:
    _grid = grid
    _target = target
    if is_node_ready():
        _grid_pos = _grid.world_to_grid(global_position)
        _refresh_occupied()
        _configure_attack_controller()


func has_target() -> bool:
    return is_instance_valid(_target)


func set_target(target: Node2D) -> void:
    _target = target


func is_staggered() -> bool:
    return _staggered


func cooldown_active() -> bool:
    return _cooldown_timer != null and _cooldown_timer.time_left > 0.0


func start_cooldown() -> void:
    if _cooldown_timer != null:
        _cooldown_timer.start(CYCLE_COOLDOWN)


func get_guard() -> Guard:
    return _guard


func emit_guard_snapshot() -> void:
    if _guard != null:
        guard_changed.emit(_guard.current(), _guard.max_guard)


func choose_next_mode() -> void:
    if _attack_controller == null:
        return
    _attack_controller.set_mode(_mode_index % BossAttackController.MODE_COUNT)
    _mode_index += 1


func face_target_position() -> void:
    if not has_target():
        return
    var direction := _target.global_position - global_position
    if direction == Vector2.ZERO:
        return
    _facing = _cardinal_snap(direction)
    _face_arrow()


func prepare_attack() -> bool:
    if _attack_controller == null:
        return false
    return _attack_controller.prepare(_grid_pos, _facing)


func show_attack_warning() -> void:
    if _attack_controller != null:
        _attack_controller.show_warning()


func show_attack_charge() -> void:
    if _attack_controller != null:
        _attack_controller.show_charge()


func begin_attack() -> void:
    velocity = Vector2.ZERO
    _charge_cells.clear()
    _charge_index = 0
    if _attack_controller == null:
        return

    if attack_sfx_event != null:
        AudioManager.play_event(attack_sfx_event, global_position)

    _attack_controller.begin_attack()
    if _attack_controller.get_mode() == BossAttackController.BossMode.CONTACT_CHARGE:
        _charge_cells = _attack_controller.get_cells()
        if not _charge_cells.is_empty():
            _move_to_charge_cell(_charge_cells[0])


func update_attack_motion(_delta: float) -> bool:
    if _attack_controller == null or _attack_controller.get_mode() != BossAttackController.BossMode.CONTACT_CHARGE:
        return false
    if _charge_index >= _charge_cells.size():
        return true

    var target_cell := _charge_cells[_charge_index]
    var target_world := _grid.cell_center(target_cell)
    var arrival_threshold := _tile_size() * 0.1
    if global_position.distance_squared_to(target_world) >= arrival_threshold * arrival_threshold:
        return false

    _grid_pos = target_cell
    global_position = target_world
    _refresh_occupied()
    _attack_controller.clear_cell(target_cell)
    _charge_index += 1
    if _charge_index >= _charge_cells.size():
        velocity = Vector2.ZERO
        return true

    _move_to_charge_cell(_charge_cells[_charge_index])
    return false


func end_attack() -> void:
    velocity = Vector2.ZERO
    _charge_cells.clear()
    _charge_index = 0
    if _attack_controller != null:
        _attack_controller.end_attack()


func cancel_attack() -> void:
    velocity = Vector2.ZERO
    _charge_cells.clear()
    _charge_index = 0
    if _attack_controller != null:
        _attack_controller.cancel()


func begin_death() -> void:
    velocity = Vector2.ZERO
    cancel_attack()
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    if health != null:
        health.set_enabled(false)
    if hurtbox != null:
        hurtbox.set_enabled(false)


func play_death_sfx() -> void:
    if death_sfx_event != null:
        AudioManager.play_event(death_sfx_event, global_position)

# == Grid helpers ==============================================================


func _refresh_occupied() -> void:
    if _grid != null:
        _grid.register_occupant(self, _occupied_tiles())


func _occupied_tiles() -> Array[Vector2i]:
    return [
        _grid_pos,
        _grid_pos + Vector2i(1, 0),
        _grid_pos + Vector2i(0, 1),
        _grid_pos + Vector2i(1, 1),
    ]


func _cardinal_snap(v: Vector2) -> Vector2:
    if abs(v.x) > abs(v.y):
        return Vector2(sign(v.x), 0.0)
    return Vector2(0.0, sign(v.y))


func _face_arrow() -> void:
    if _facing_arrow != null:
        _facing_arrow.rotation = _facing.angle() - PI / 2.0


func _tile_size() -> float:
    return _grid.tile_size if _grid else 64.0


func _move_to_charge_cell(cell: Vector2i) -> void:
    if _grid == null:
        velocity = Vector2.ZERO
        return
    var target_world := _grid.cell_center(cell)
    var direction := (target_world - global_position).normalized()
    velocity = direction * CHARGING_SPEED

# == Setup helpers =============================================================


func _configure_attack_controller() -> void:
    if _attack_controller == null:
        return
    _attack_controller.setup(_grid, _telegraph, _tile_hitbox, _contact_hitbox, _puff_hitbox)


func _start_stagger_vfx() -> void:
    if _body != null:
        if _stagger_tween != null and is_instance_valid(_stagger_tween):
            _stagger_tween.kill()
        _stagger_tween = create_tween()
        _stagger_tween.tween_property(_body, "modulate", STAGGER_VFX_COLOR, 0.2)

# == Overridden Custom Methods ================================================


func reset() -> void:
    super()
    _staggered = false
    _charge_cells.clear()
    _charge_index = 0
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    if _body != null:
        _body.modulate = Color.WHITE
    cancel_attack()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        _refresh_occupied()
