# mode_enemy.gd
# 1x1 special enemy that randomly changes between tile, puff, and charge modes.
class_name ModeEnemy
extends GridEnemy

signal guard_changed(current: int, maximum: int)
signal guard_stagger_started
signal guard_stagger_ended

enum Mode { TILE = 0, PUFF = 1, CHARGE = 2 }

const MODE_COUNT := 3
const CHARGING_SPEED := 480.0
const TILE_MODE_COLOR := Color(0.9, 0.35, 0.25, 1.0)
const PUFF_MODE_COLOR := Color(0.95, 0.8, 0.2, 1.0)
const CHARGE_MODE_COLOR := Color(0.35, 0.6, 1.0, 1.0)

# -- Exports ------------------------------------------------------------------
@export var attack_sfx_event: SpatialAudioEvent

# -- State --------------------------------------------------------------------
var _mode: int = Mode.TILE
var _mode_ready := false
var _current_attack_data: EnemyAttackData

# -- Node references ----------------------------------------------------------
@onready var _tile_executor: EnemyAttackController = %TileAttackExecutor
@onready var _point_executor: EnemyPointAttackExecutor = %PointAttackExecutor
@onready var _telegraph: TileTelegraph = %TileTelegraph
@onready var _contact_hitbox: Hitbox = %ContactHitbox
@onready var _puff_hitbox: Hitbox = %PuffHitbox

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    _configure_executors()
    _disable_mode_hitboxes()
    _apply_current_mode_color()

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


## Rolls a fresh mode before planning whenever the current one is spent; once a mode is ready it commits
## its attack at any of the three decision points the mode's footprint can cover the target.
func get_pre_decision_state_id() -> int:
    if not _mode_ready:
        return EnemyState.EnemyStateId.MODE_CHANGE
    return -1


func should_commit_before_plan() -> bool:
    return can_attack_current_mode()


func should_commit_on_arrival() -> bool:
    return can_attack_current_mode()


func should_commit_after_face() -> bool:
    return can_attack_current_mode()


## Commits the enemy to mode selection and clears any planned movement.
func begin_mode_change() -> bool:
    return begin_committed_action()


## Clears movement planning and prepares the current mode telegraph.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action():
        return false
    if not prepare_attack():
        return false
    show_attack_warning()
    return true


func get_current_attack_data() -> EnemyAttackData:
    return _current_attack_data


func get_telegraph() -> TileTelegraph:
    return _telegraph


func choose_random_mode() -> void:
    _mode = randi() % MODE_COUNT
    _mode_ready = true
    _current_attack_data = _select_attack_data_for_mode(_mode)
    _rewire_point_executor()
    _apply_current_mode_color()


func set_preview_mode(mode: int) -> void:
    if _body != null:
        _body.color = get_mode_color(mode)


func get_mode_color(mode: int) -> Color:
    if enemy_data != null and mode >= 0 and mode < enemy_data.mode_colors.size():
        return enemy_data.mode_colors[mode]
    match mode:
        Mode.PUFF:
            return PUFF_MODE_COLOR
        Mode.CHARGE:
            return CHARGE_MODE_COLOR
    return TILE_MODE_COLOR


func can_attack_current_mode() -> bool:
    if _grid == null or not has_target() or not _mode_ready:
        return false
    var target_cell := get_target_cell()
    match _mode:
        Mode.CHARGE:
            if target_cell == _grid_pos or _facing == Vector2.ZERO or _current_attack_data == null:
                return false
            return target_cell in get_unblocked_charge_cells(_grid_pos, _facing, _current_attack_data)
        Mode.PUFF:
            return is_target_within_grid_range(_get_current_puff_range())
        Mode.TILE:
            if target_cell == _grid_pos or _facing == Vector2.ZERO:
                return false
            return target_cell in EnemyAttackController.get_attack_cells(_grid_pos, _facing, _tile_attack_data(), _grid)
    return false


func plan_next_action() -> bool:
    match _mode:
        Mode.CHARGE:
            return plan_charge_origin_action()
        Mode.TILE:
            var get_cells_for_origin := func(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
                return EnemyAttackController.get_attack_cells(origin_cell, facing, _tile_attack_data(), _grid)
            var get_origins_for_target := func(target_cell: Vector2i) -> Array[Vector2i]:
                return EnemyAttackController.get_attack_origin_cells(target_cell, _tile_attack_data(), _grid)
            return plan_cell_attack_action(get_cells_for_origin, get_origins_for_target)
    return super()


func prepare_attack() -> bool:
    match _mode:
        Mode.TILE:
            if _tile_executor == null:
                return false
            return _tile_executor.prepare(_grid_pos, _facing, _tile_attack_data(), get_damage_multiplier())
        Mode.CHARGE, Mode.PUFF:
            if _point_executor == null:
                return false
            if _mode == Mode.CHARGE:
                return _point_executor.prepare_cells(get_unblocked_charge_cells(_grid_pos, _facing, _current_attack_data), _current_attack_data, get_damage_multiplier())
            return _point_executor.prepare(_grid_pos, _facing, _current_attack_data, get_damage_multiplier())
    return false


func show_attack_warning() -> void:
    match _mode:
        Mode.TILE:
            if _tile_executor != null:
                _tile_executor.show_warning()
        Mode.CHARGE, Mode.PUFF:
            if _point_executor != null:
                _point_executor.show_warning()


func show_attack_charge() -> void:
    match _mode:
        Mode.TILE:
            if _tile_executor != null:
                _tile_executor.show_charge()
        Mode.CHARGE, Mode.PUFF:
            if _point_executor != null:
                _point_executor.show_charge()


func cancel_attack() -> void:
    velocity = Vector2.ZERO
    match _mode:
        Mode.TILE:
            if _tile_executor != null:
                _tile_executor.cancel()
        Mode.CHARGE, Mode.PUFF:
            if _point_executor != null:
                _point_executor.cancel()

# == Tick clocking =============================================================


## Tick footprint committed by begin_attack_telegraph(): the current mode's executor cells.
func get_committed_attack_cells() -> Array[Vector2i]:
    var empty: Array[Vector2i] = []
    if _mode == Mode.TILE:
        return _tile_executor.get_cells() if _tile_executor != null else empty
    return _point_executor.get_cells() if _point_executor != null else empty


## Tick detonation. CHARGE mode rushes along its line like the charger; TILE/PUFF resolve a single
## cell-membership check. Every mode plays the attack cue and re-arms mode selection for the next cycle.
func _tick_detonate() -> void:
    if attack_sfx_event != null:
        AudioManager.play_event(attack_sfx_event, global_position)
    var tiles := get_attack_tiles()
    if _mode == Mode.CHARGE:
        _resolve_detonation_on_player(tiles)
        var dest := get_charge_landing_cell(tiles)
        if dest != _grid_pos:
            tick_snap_to_cell(dest)
    else:
        _resolve_detonation_on_player(tiles)
    finish_attack_into_recovery()


## Tick hook: clears the current mode's telegraph and forces a fresh mode roll after the attack resolves.
func _clear_attack_presentation() -> void:
    cancel_attack()
    stop_attack_windup_vfx()
    _mode_ready = false

# == Setup helpers =============================================================


func _after_setup_ready() -> void:
    _configure_executors()


func _on_guard_broken_extra() -> void:
    cancel_attack()


func _on_begin_death_extra() -> void:
    cancel_attack()
    _disable_mode_hitboxes()


func _reset_extra() -> void:
    _mode_ready = false
    _current_attack_data = null
    cancel_attack()
    _apply_current_mode_color()


func _configure_executors() -> void:
    if _tile_executor != null:
        _tile_executor.setup(_grid, _telegraph, self)
    _rewire_point_executor()


func _rewire_point_executor() -> void:
    if _point_executor == null:
        return
    var hitbox := _puff_hitbox if _mode == Mode.PUFF else _contact_hitbox
    _point_executor.setup(_grid, _telegraph, hitbox, true)


## Returns the attack data driving TILE-mode cell computation, falling back to the
## WIDE_2X3 shape ModeEnemy always used before per-mode attack data existed.
func _tile_attack_data() -> EnemyAttackData:
    if _current_attack_data != null:
        return _current_attack_data
    var fallback := EnemyAttackData.new()
    fallback.cell_shape = EnemyAttackData.CellShape.WIDE
    fallback.width = 3
    fallback.depth = 2
    return fallback


func _disable_mode_hitboxes() -> void:
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)


func _apply_current_mode_color() -> void:
    if _body != null:
        _body.color = get_mode_color(_mode)


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
        Mode.CHARGE:
            return EnemyAttackData.AttackKind.CHARGE
        Mode.PUFF:
            return EnemyAttackData.AttackKind.PUFF
    return EnemyAttackData.AttackKind.TILE


func _get_current_puff_range() -> int:
    return _current_attack_data.radius if _current_attack_data != null else 1


func _create_fallback_attack_data(mode: int) -> EnemyAttackData:
    var attack_data := EnemyAttackData.new()
    attack_data.warning_duration = 2
    attack_data.charge_duration = 0
    attack_data.recovery_duration = 1
    match mode:
        Mode.CHARGE:
            attack_data.attack_kind = EnemyAttackData.AttackKind.CHARGE
            attack_data.cell_shape = EnemyAttackData.CellShape.FULL_LINE
            attack_data.damage = 10.0
            attack_data.damage_interval = 0.45
            attack_data.charge_speed = CHARGING_SPEED
        Mode.PUFF:
            attack_data.attack_kind = EnemyAttackData.AttackKind.PUFF
            attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
            attack_data.damage = 14.0
            attack_data.active_duration = 2
            attack_data.radius = 1
        _:
            attack_data.attack_kind = EnemyAttackData.AttackKind.TILE
            attack_data.damage = 12.0
            attack_data.active_duration = 1
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
