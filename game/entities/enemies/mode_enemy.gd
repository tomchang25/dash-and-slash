# mode_enemy.gd
# 1x1 special enemy that selects one authored tile, puff, or charge attack per combat cycle.
class_name ModeEnemy
extends GridEnemy

signal guard_changed(current: int, maximum: int)
signal guard_stagger_started
signal guard_stagger_ended

const CHARGING_SPEED := 480.0
const FALLBACK_ATTACK_COUNT := 5

# -- Exports --

@export var attack_sfx_event: SpatialAudioEvent

# -- State --

var _current_attack_data: EnemyAttackData

# -- Node references --

@onready var _tile_executor: EnemyAttackController = %TileAttackExecutor
@onready var _telegraph: TileTelegraph = %TileTelegraph

# == Lifecycle ==


func _ready() -> void:
    super()
    _configure_executors()
    if _current_attack_data == null:
        _select_next_attack()

# == Signal handlers ==


func _on_guard_changed(current: int, maximum: int) -> void:
    super(current, maximum)
    guard_changed.emit(current, maximum)


func _on_stagger_started() -> void:
    super()
    guard_stagger_started.emit()


func _on_stagger_ended() -> void:
    super()
    _select_next_attack()
    guard_stagger_ended.emit()

# == Common API ==


func emit_guard_snapshot() -> void:
    if _guard != null:
        guard_changed.emit(_guard.current(), _guard.max_guard)


## Returns the single attack that governs ModeEnemy's current planning and combat cycle.
func get_current_attack_data() -> EnemyAttackData:
    return _current_attack_data


func get_telegraph() -> TileTelegraph:
    return _telegraph


## Commits whenever the selected attack's current footprint can cover the target.
func should_commit_before_plan() -> bool:
    return _can_attack_with_current_selection()


func should_commit_on_arrival() -> bool:
    return _can_attack_with_current_selection()


func should_commit_after_face() -> bool:
    return _can_attack_with_current_selection()


## Clears movement planning, prepares the selected attack's footprint, and starts its telegraph.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action() or not prepare_attack():
        return false
    show_attack_warning()
    start_attack_windup_vfx(_get_current_windup_style())
    if _visual_presenter != null:
        _visual_presenter.show_prepare_attack()
    return true


## Prepares the selected attack's cells through the shared tile executor.
func prepare_attack() -> bool:
    if _tile_executor == null or _current_attack_data == null:
        return false

    match _current_attack_data.attack_kind:
        EnemyAttackData.AttackKind.TILE:
            return _tile_executor.prepare(_grid_pos, _facing, _current_attack_data)
        EnemyAttackData.AttackKind.CHARGE:
            return _tile_executor.prepare_cells(get_unblocked_charge_cells(_grid_pos, _facing, _current_attack_data))
        EnemyAttackData.AttackKind.PUFF:
            return _tile_executor.prepare(_grid_pos, _facing, _current_attack_data)

    ToastManager.show_dev_error("ModeEnemy: unsupported selected attack kind")
    return false


func show_attack_warning() -> void:
    if _tile_executor != null:
        _tile_executor.show_warning()


func show_attack_charge() -> void:
    if _tile_executor != null:
        _tile_executor.show_charge()
    if _visual_presenter != null:
        _visual_presenter.show_attack_commit()


func cancel_attack() -> void:
    if _tile_executor != null:
        _tile_executor.cancel()
    stop_attack_windup_vfx()
    if _visual_presenter != null:
        _visual_presenter.show_idle()

# == Tick clocking ==


## Returns the selected attack's committed cells from the shared executor.
func get_committed_attack_cells() -> Array[Vector2i]:
    var empty: Array[Vector2i] = []
    return _tile_executor.get_cells() if _tile_executor != null else empty


## Resolves the selected attack, then chooses the next one before recovery freezes further decisions.
func _tick_detonate() -> void:
    if attack_sfx_event != null:
        AudioManager.play_event(attack_sfx_event, global_position)

    var tiles := get_attack_tiles()
    var is_charge := _current_attack_data != null and _current_attack_data.attack_kind == EnemyAttackData.AttackKind.CHARGE
    _resolve_detonation_on_player(tiles)
    var destination := get_charge_landing_cell(tiles) if is_charge else _grid_pos
    finish_attack_into_recovery()
    _select_next_attack()
    if is_charge and destination != _grid_pos:
        tick_snap_to_cell(destination)


## Clears only the active attack presentation; selection survives until its explicit reroll boundary.
func _clear_attack_presentation() -> void:
    cancel_attack()

# == Planning ==


func plan_next_action() -> bool:
    if _current_attack_data == null:
        _select_next_attack()
    if _current_attack_data == null:
        return plan_approach_action()

    match _current_attack_data.attack_kind:
        EnemyAttackData.AttackKind.TILE:
            var get_cells_for_origin := func(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
                return EnemyAttackController.get_attack_cells(origin_cell, facing, _current_attack_data, _grid)
            var get_origins_for_target := func(target_cell: Vector2i) -> Array[Vector2i]:
                return EnemyAttackController.get_attack_origin_cells(target_cell, _current_attack_data, _grid)
            return plan_cell_attack_action(get_cells_for_origin, get_origins_for_target)
        EnemyAttackData.AttackKind.CHARGE:
            return plan_charge_origin_action()
        EnemyAttackData.AttackKind.PUFF:
            return plan_approach_action()

    ToastManager.show_dev_error("ModeEnemy: unsupported selected attack kind")
    return false

# == Setup helpers ==


func _after_setup_ready() -> void:
    _configure_executors()
    if _current_attack_data == null:
        _select_next_attack()


func _on_begin_death_extra() -> void:
    cancel_attack()


func _reset_extra() -> void:
    _current_attack_data = null
    cancel_attack()
    _select_next_attack()


func _configure_executors() -> void:
    if _tile_executor != null:
        _tile_executor.setup(_grid, _telegraph)


func _select_next_attack() -> void:
    var authored_attacks := _get_authored_attacks()
    if authored_attacks.is_empty():
        _current_attack_data = _create_fallback_attack_data()
    else:
        _current_attack_data = authored_attacks[randi() % authored_attacks.size()]
    _sync_presenter_attack_kind()


func _get_authored_attacks() -> Array[EnemyAttackData]:
    var attacks: Array[EnemyAttackData] = []
    if enemy_data == null:
        return attacks
    for attack: EnemyAttackData in enemy_data.attacks:
        if attack != null:
            attacks.append(attack)
    return attacks


func _can_attack_with_current_selection() -> bool:
    if _grid == null or not has_target() or _current_attack_data == null:
        return false

    var target_cell := get_target_cell()
    match _current_attack_data.attack_kind:
        EnemyAttackData.AttackKind.TILE:
            if target_cell == _grid_pos or _facing == Vector2.ZERO:
                return false
            return target_cell in EnemyAttackController.get_attack_cells(_grid_pos, _facing, _current_attack_data, _grid)
        EnemyAttackData.AttackKind.CHARGE:
            if target_cell == _grid_pos or _facing == Vector2.ZERO:
                return false
            return target_cell in get_unblocked_charge_cells(_grid_pos, _facing, _current_attack_data)
        EnemyAttackData.AttackKind.PUFF:
            return is_target_within_grid_range(_current_attack_data.radius)

    ToastManager.show_dev_error("ModeEnemy: unsupported selected attack kind")
    return false


func _get_current_windup_style() -> int:
    if _current_attack_data != null and _current_attack_data.attack_kind == EnemyAttackData.AttackKind.CHARGE:
        return CombatFeedbackVFX.WindupStyle.CHARGE
    return CombatFeedbackVFX.WindupStyle.TILE


func _sync_presenter_attack_kind() -> void:
    var presenter := _visual_presenter as ModeEnemyVisualPresenter
    if presenter != null and _current_attack_data != null:
        presenter.set_attack_kind(_current_attack_data.attack_kind)


func _create_fallback_attack_data() -> EnemyAttackData:
    var attack_data := EnemyAttackData.new()
    attack_data.warning_duration = 2
    attack_data.charge_duration = 0
    attack_data.recovery_duration = 1

    match randi() % FALLBACK_ATTACK_COUNT:
        0:
            attack_data.attack_kind = EnemyAttackData.AttackKind.TILE
            attack_data.damage = 12.0
            attack_data.active_duration = 1
            attack_data.cell_shape = EnemyAttackData.CellShape.WIDE
            attack_data.width = 3
            attack_data.depth = 2
        1:
            attack_data.attack_kind = EnemyAttackData.AttackKind.TILE
            attack_data.damage = 12.0
            attack_data.active_duration = 1
            attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
            attack_data.radius = 1
        2:
            attack_data.attack_kind = EnemyAttackData.AttackKind.TILE
            attack_data.damage = 12.0
            attack_data.active_duration = 1
            attack_data.cell_shape = EnemyAttackData.CellShape.LINE
            attack_data.line_length = 4
        3:
            attack_data.attack_kind = EnemyAttackData.AttackKind.CHARGE
            attack_data.cell_shape = EnemyAttackData.CellShape.FULL_LINE
            attack_data.damage = 10.0
            attack_data.damage_interval = 0.45
            attack_data.charge_speed = CHARGING_SPEED
        4:
            attack_data.attack_kind = EnemyAttackData.AttackKind.PUFF
            attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
            attack_data.damage = 14.0
            attack_data.active_duration = 2
            attack_data.radius = 1
        _:
            ToastManager.show_dev_error("ModeEnemy: invalid fallback attack index")

    return attack_data
