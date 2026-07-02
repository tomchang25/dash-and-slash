# charge_enemy.gd
# 1x1 grid enemy that lines up with the target, telegraphs, then rushes forward.
class_name ChargeEnemy
extends GridEnemy

const CHARGING_SPEED := 480.0
const WARNING_DURATION := 1.0
const RECOVERY_DURATION := 3.0

# -- State --------------------------------------------------------------------
var _attack_data: EnemyAttackData
var _charge_cells: Array[Vector2i] = []

# -- Node references ----------------------------------------------------------
@onready var _contact_hitbox: Hitbox = %ContactHitbox
@onready var _telegraph: TileTelegraph = %TileTelegraph
@onready var _point_executor: EnemyPointAttackExecutor = %PointAttackExecutor

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    _select_attack_data()
    _configure_point_executor()
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)
    if _telegraph != null:
        _telegraph.setup(_grid)

# == Common API ================================================================


func get_charge_cells_from_pos(from: Vector2i, facing: Vector2) -> Array[Vector2i]:
    var attack_data := get_current_attack_data()
    if attack_data != null:
        return EnemyAttackController.get_attack_cells(from, facing, attack_data, _grid)
    return EnemyAttackController.get_attack_cells(from, facing, _create_fallback_attack_data(), _grid)


func get_charge_cells() -> Array[Vector2i]:
    return get_charge_cells_from_pos(_grid_pos, _facing)


func get_telegraph() -> TileTelegraph:
    return _telegraph


func get_stored_charge_cells() -> Array[Vector2i]:
    return _charge_cells


func set_stored_charge_cells(cells: Array[Vector2i]) -> void:
    _charge_cells = cells


func clear_stored_charge_cells() -> void:
    _charge_cells.clear()


func face_arrow() -> void:
    super()
    if _contact_hitbox != null:
        _contact_hitbox.rotation = _facing.angle() + PI / 2.0


func get_pre_plan_state_id() -> int:
    if can_charge_target_from_cell(_grid_pos):
        return EnemyState.EnemyStateId.TELEGRAPH
    return -1


func get_recovery_duration() -> float:
    return _attack_data.recovery_duration if _attack_data != null else RECOVERY_DURATION


func get_current_attack_data() -> EnemyAttackData:
    return _attack_data


func get_charge_speed() -> float:
    return _attack_data.charge_speed if _attack_data != null else CHARGING_SPEED


func get_attack_state_id() -> int:
    return EnemyState.EnemyStateId.CHARGE_ATTACK


func show_attack_charge() -> void:
    var telegraph := get_telegraph()
    if telegraph != null:
        telegraph.show_charge(get_stored_charge_cells())


func get_arrival_override_state_id() -> int:
    if can_charge_target_from_cell(_grid_pos):
        return EnemyState.EnemyStateId.TELEGRAPH
    return -1


## Clears movement planning and prepares the charge telegraph.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action():
        return false
    if not has_target():
        return false

    face_target_position()
    var cells := get_charge_cells()
    if cells.is_empty() or get_target_cell() not in cells:
        return false

    set_stored_charge_cells(cells)
    var telegraph := get_telegraph()
    if telegraph != null:
        telegraph.show_warning(cells)

    start_attack_windup_vfx(CombatFeedbackVFX.WindupStyle.CHARGE)
    return true


func plan_next_action() -> bool:
    return plan_charge_origin_action()


func begin_charge_attack() -> void:
    stop_attack_windup_vfx()
    if _point_executor != null:
        _point_executor.set_hitbox_enabled(true)


func end_charge_attack() -> void:
    stop_attack_windup_vfx()
    if _point_executor != null:
        _point_executor.set_hitbox_enabled(false)

# == Setup helpers =============================================================


func _after_setup_ready() -> void:
    _select_attack_data()
    _configure_point_executor()
    if _telegraph != null:
        _telegraph.setup(_grid)


func _on_guard_broken_extra() -> void:
    if _telegraph != null:
        _telegraph.clear()
    end_charge_attack()


func _on_begin_death_extra() -> void:
    if _telegraph != null:
        _telegraph.clear()
    if _point_executor != null:
        _point_executor.set_hitbox_enabled(false)


func _reset_extra() -> void:
    _charge_cells.clear()
    end_charge_attack()


func _select_attack_data() -> void:
    if enemy_data != null:
        for attack: EnemyAttackData in enemy_data.attacks:
            if attack != null and attack.attack_kind == EnemyAttackData.AttackKind.CHARGE:
                _attack_data = attack
                return
    _attack_data = _create_fallback_attack_data()


func _configure_point_executor() -> void:
    if _point_executor == null:
        return
    _point_executor.setup(_grid, _telegraph, _contact_hitbox, true)
    _point_executor.configure(get_current_attack_data(), get_damage_multiplier())


func _create_fallback_attack_data() -> EnemyAttackData:
    var attack_data := EnemyAttackData.new()
    attack_data.attack_kind = EnemyAttackData.AttackKind.CHARGE
    attack_data.cell_shape = EnemyAttackData.CellShape.FULL_LINE
    attack_data.damage = 8.0
    attack_data.damage_interval = 0.6
    attack_data.warning_duration = WARNING_DURATION
    attack_data.charge_duration = 0.0
    attack_data.recovery_duration = RECOVERY_DURATION
    attack_data.charge_speed = CHARGING_SPEED
    return attack_data
