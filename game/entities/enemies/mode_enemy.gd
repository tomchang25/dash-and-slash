# mode_enemy.gd
# 1x1 special enemy that randomly changes between tile, puff, and charge modes.
class_name ModeEnemy
extends GridEnemy

signal guard_changed(current: int, maximum: int)
signal guard_stagger_started
signal guard_stagger_ended

const MODE_CHANGE_DURATION := 3.0
const MODE_PREVIEW_INTERVAL := 0.25
const TELEGRAPH_DURATION := 0.8
const CHARGE_DURATION := 0.2
const TILE_ATTACK_DURATION := 0.25
const PUFF_ATTACK_DURATION := 1.0
const CHARGE_ATTACK_TIMEOUT := 1.2
const RECOVERY_DURATION := 0.8
const CHARGING_SPEED := 480.0
const TILE_MODE_COLOR := Color(0.9, 0.35, 0.25, 1.0)
const PUFF_MODE_COLOR := Color(0.95, 0.8, 0.2, 1.0)
const CHARGE_MODE_COLOR := Color(0.35, 0.6, 1.0, 1.0)

# -- Exports ------------------------------------------------------------------
@export var attack_sfx_event: SpatialAudioEvent

# -- State --------------------------------------------------------------------
var _mode: int = ModeEnemyAttackController.Mode.TILE
var _mode_ready := false
var _current_attack_data: EnemyAttackData
var _charge_cells: Array[Vector2i] = []
var _charge_index := 0

# -- Node references ----------------------------------------------------------
@onready var _attack_controller: ModeEnemyAttackController = %AttackController
@onready var _telegraph: TileTelegraph = %TileTelegraph
@onready var _tile_hitbox: Hitbox = %TileAttackHitbox
@onready var _contact_hitbox: Hitbox = %ContactHitbox
@onready var _puff_hitbox: Hitbox = %PuffHitbox

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    _allow_diagonal_movement = true
    _configure_attack_controller()
    _disable_mode_hitboxes()
    _apply_current_mode_color()

# == Overridden Custom Methods ================================================


func start_cooldown() -> void:
    super()
    _mode_ready = false

# == Signal handlers ==========================================================


func _on_guard_changed(current: int, maximum: int) -> void:
    super(current, maximum)
    guard_changed.emit(current, maximum)


func _on_stagger_started() -> void:
    super()
    guard_stagger_started.emit()


func _on_stagger_ended() -> void:
    super()
    guard_stagger_ended.emit()

# == Common API ================================================================


func emit_guard_snapshot() -> void:
    if _guard != null:
        guard_changed.emit(_guard.current(), _guard.max_guard)


func get_pre_plan_state_id() -> int:
    if not _mode_ready:
        return EnemyState.EnemyStateId.MODE_CHANGE
    if can_attack_current_mode():
        return EnemyState.EnemyStateId.TELEGRAPH
    return -1


func get_arrival_override_state_id() -> int:
    if can_attack_current_mode():
        return EnemyState.EnemyStateId.TELEGRAPH
    return -1


func get_after_face_state_id() -> int:
    if can_attack_current_mode():
        return EnemyState.EnemyStateId.TELEGRAPH
    return EnemyState.EnemyStateId.IDLE


## Commits the enemy to mode selection and clears any planned movement.
func begin_mode_change() -> bool:
    return begin_committed_action()


## Clears movement planning and prepares the current mode telegraph.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action():
        return false
    face_target_position()
    if not prepare_attack():
        return false
    show_attack_warning()
    return true


func get_recovery_duration() -> float:
    return _current_attack_data.recovery_duration if _current_attack_data != null else RECOVERY_DURATION


func get_current_attack_data() -> EnemyAttackData:
    return _current_attack_data


func get_attack_duration() -> float:
    if _current_attack_data != null:
        return _current_attack_data.active_duration
    match _mode:
        ModeEnemyAttackController.Mode.PUFF:
            return PUFF_ATTACK_DURATION
        ModeEnemyAttackController.Mode.CHARGE:
            return CHARGE_ATTACK_TIMEOUT
    return TILE_ATTACK_DURATION


func get_mode_preview_interval() -> float:
    return MODE_PREVIEW_INTERVAL


func choose_random_mode() -> void:
    _mode = randi() % ModeEnemyAttackController.MODE_COUNT
    _mode_ready = true
    _current_attack_data = _select_attack_data_for_mode(_mode)
    if _attack_controller != null:
        _attack_controller.set_mode(_mode)
        _attack_controller.set_attack_data(_current_attack_data)
    _apply_current_mode_color()


func set_preview_mode(mode: int) -> void:
    if _body != null:
        _body.color = get_mode_color(mode)


func get_mode_color(mode: int) -> Color:
    if enemy_data != null and mode >= 0 and mode < enemy_data.mode_colors.size():
        return enemy_data.mode_colors[mode]
    match mode:
        ModeEnemyAttackController.Mode.PUFF:
            return PUFF_MODE_COLOR
        ModeEnemyAttackController.Mode.CHARGE:
            return CHARGE_MODE_COLOR
    return TILE_MODE_COLOR


func can_attack_current_mode() -> bool:
    if _grid == null or _attack_controller == null or not has_target() or not _mode_ready:
        return false
    match _mode:
        ModeEnemyAttackController.Mode.CHARGE:
            return can_charge_target_from_cell(_grid_pos)
        ModeEnemyAttackController.Mode.PUFF:
            return is_target_within_grid_range(_get_current_puff_range())
        ModeEnemyAttackController.Mode.TILE:
            var target_cell := get_target_cell()
            var dir_to_target := Vector2(target_cell - _grid_pos)
            if dir_to_target == Vector2.ZERO:
                return false
            return target_cell in _attack_controller.get_attack_cells(_grid_pos, cardinal_snap(dir_to_target))
    return false


func plan_next_action() -> bool:
    match _mode:
        ModeEnemyAttackController.Mode.CHARGE:
            return plan_charge_origin_action()
        ModeEnemyAttackController.Mode.TILE:
            if _attack_controller == null:
                return false
            var get_cells_for_origin := func(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
                return _attack_controller.get_attack_cells(origin_cell, facing)
            var get_origins_for_target := func(target_cell: Vector2i) -> Array[Vector2i]:
                return _attack_controller.get_attack_origin_cells(target_cell)
            return plan_cell_attack_action(get_cells_for_origin, get_origins_for_target)
    return super()


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


func begin_attack() -> bool:
    velocity = Vector2.ZERO
    _charge_cells.clear()
    _charge_index = 0
    if _attack_controller == null:
        return false
    if attack_sfx_event != null:
        AudioManager.play_event(attack_sfx_event, global_position)

    _attack_controller.begin_attack()
    if _mode == ModeEnemyAttackController.Mode.CHARGE:
        _charge_cells = _attack_controller.get_cells()
        if not _charge_cells.is_empty():
            _move_to_charge_cell(_charge_cells[0])

    return true


func update_attack_motion(_delta: float) -> bool:
    if _mode != ModeEnemyAttackController.Mode.CHARGE:
        return false
    if _charge_index >= _charge_cells.size():
        return true

    var target_cell := _charge_cells[_charge_index]
    var target_world := _grid.cell_center(target_cell)
    var arrival_threshold := tile_size() * 0.1
    if global_position.distance_squared_to(target_world) >= arrival_threshold * arrival_threshold:
        return false

    _grid_pos = target_cell
    global_position = target_world
    register_grid_occupant()
    if _attack_controller != null:
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

# == Setup helpers =============================================================


func _after_setup_ready() -> void:
    _configure_attack_controller()


func _on_guard_broken_extra() -> void:
    cancel_attack()


func _on_begin_death_extra() -> void:
    cancel_attack()
    _disable_mode_hitboxes()


func _reset_extra() -> void:
    _mode_ready = false
    _current_attack_data = null
    _charge_cells.clear()
    _charge_index = 0
    cancel_attack()
    _apply_current_mode_color()


func _configure_attack_controller() -> void:
    if _attack_controller == null:
        return
    _attack_controller.setup(_grid, _telegraph, _tile_hitbox, _contact_hitbox, _puff_hitbox)


func _disable_mode_hitboxes() -> void:
    if _tile_hitbox != null:
        _tile_hitbox.set_enabled(false)
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)


func _apply_current_mode_color() -> void:
    if _body != null:
        _body.color = get_mode_color(_mode)


func _move_to_charge_cell(cell: Vector2i) -> void:
    if _grid == null:
        velocity = Vector2.ZERO
        return
    var target_world := _grid.cell_center(cell)
    var direction := (target_world - global_position).normalized()
    var charge_speed := _current_attack_data.charge_speed if _current_attack_data != null else CHARGING_SPEED
    velocity = direction * charge_speed


func _select_attack_data_for_mode(mode: int) -> EnemyAttackData:
    var kind := _attack_kind_for_mode(mode)
    var attacks := _get_attacks_for_kind(kind)
    if attacks.is_empty():
        return _create_fallback_attack_data(mode)
    return attacks[randi() % attacks.size()] if kind == EnemyAttackData.AttackKind.TILE else attacks[0]


func _get_attacks_for_kind(kind: int) -> Array[EnemyAttackData]:
    var attacks: Array[EnemyAttackData] = []
    if enemy_data == null:
        return attacks
    for attack: EnemyAttackData in enemy_data.attacks:
        if attack != null and attack.attack_kind == kind:
            attacks.append(attack)
    return attacks


func _attack_kind_for_mode(mode: int) -> int:
    match mode:
        ModeEnemyAttackController.Mode.CHARGE:
            return EnemyAttackData.AttackKind.CHARGE
        ModeEnemyAttackController.Mode.PUFF:
            return EnemyAttackData.AttackKind.PUFF
    return EnemyAttackData.AttackKind.TILE


func _get_current_puff_range() -> int:
    return _current_attack_data.radius if _current_attack_data != null else 1


func _create_fallback_attack_data(mode: int) -> EnemyAttackData:
    var attack_data := EnemyAttackData.new()
    attack_data.warning_duration = TELEGRAPH_DURATION
    attack_data.charge_duration = CHARGE_DURATION
    attack_data.recovery_duration = RECOVERY_DURATION
    match mode:
        ModeEnemyAttackController.Mode.CHARGE:
            attack_data.attack_kind = EnemyAttackData.AttackKind.CHARGE
            attack_data.cell_shape = EnemyAttackData.CellShape.FULL_LINE
            attack_data.damage = 10.0
            attack_data.damage_interval = 0.45
            attack_data.active_duration = CHARGE_ATTACK_TIMEOUT
            attack_data.charge_speed = CHARGING_SPEED
        ModeEnemyAttackController.Mode.PUFF:
            attack_data.attack_kind = EnemyAttackData.AttackKind.PUFF
            attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
            attack_data.damage = 14.0
            attack_data.active_duration = PUFF_ATTACK_DURATION
            attack_data.radius = 1
        _:
            attack_data.attack_kind = EnemyAttackData.AttackKind.TILE
            attack_data.damage = 12.0
            attack_data.active_duration = TILE_ATTACK_DURATION
            var shape := randi() % 3
            if shape == 0:
                attack_data.cell_shape = EnemyAttackData.CellShape.WIDE
                attack_data.width = 3
                attack_data.depth = 2
            elif shape == 1:
                attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
                attack_data.radius = 1
            else:
                attack_data.cell_shape = EnemyAttackData.CellShape.LINE
                attack_data.line_length = 4
    return attack_data
