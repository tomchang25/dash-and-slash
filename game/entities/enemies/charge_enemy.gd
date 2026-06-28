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
@onready var _contact_hitbox: Hitbox = _find_child_node("ContactHitbox") as Hitbox
@onready var _telegraph: TileTelegraph = _find_child_node("TileTelegraph") as TileTelegraph

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    _select_attack_data()
    _configure_contact_hitbox()
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


func get_body() -> Polygon2D:
    return _body


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


func get_idle_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.IDLE


func get_reposition_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.REPOSITION_STEP


func get_face_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.FACE_ONCE


func get_recovery_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.RECOVERY


func get_staggered_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.STAGGERED


func get_dead_state_id() -> int:
    return ChargeEnemyState.ChargeEnemyStateId.DEAD


func get_pre_plan_state_id() -> int:
    if is_target_cardinally_aligned():
        return ChargeEnemyState.ChargeEnemyStateId.CHARGE_TELEGRAPH
    return -1


func get_recovery_duration() -> float:
    return _attack_data.recovery_duration if _attack_data != null else RECOVERY_DURATION


func get_current_attack_data() -> EnemyAttackData:
    return _attack_data


func get_charge_speed() -> float:
    return _attack_data.charge_speed if _attack_data != null else CHARGING_SPEED


func get_arrival_override_state_id() -> int:
    if is_target_cardinally_aligned():
        return ChargeEnemyState.ChargeEnemyStateId.CHARGE_TELEGRAPH
    return -1


## Clears movement planning and prepares the charge telegraph.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action():
        return false
    if not has_target():
        return false

    face_target_position()
    _configure_contact_hitbox()
    var cells := get_charge_cells()
    if cells.is_empty():
        return false

    set_stored_charge_cells(cells)
    var telegraph := get_telegraph()
    if telegraph != null:
        telegraph.show_warning(cells)
    return true


func plan_next_action() -> bool:
    return plan_charge_line_action()


func begin_charge_attack() -> void:
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(true)


func end_charge_attack() -> void:
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)

# == Setup helpers =============================================================


func _after_setup_ready() -> void:
    _select_attack_data()
    _configure_contact_hitbox()
    if _telegraph != null:
        _telegraph.setup(_grid)


func _on_guard_broken_extra() -> void:
    if _telegraph != null:
        _telegraph.clear()
    end_charge_attack()


func _on_begin_death_extra() -> void:
    if _telegraph != null:
        _telegraph.clear()
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)


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


func _configure_contact_hitbox() -> void:
    if _contact_hitbox == null:
        return
    var attack_data := get_current_attack_data()
    _contact_hitbox.damage = attack_data.damage if attack_data != null else 8.0
    _contact_hitbox.damage_interval = attack_data.damage_interval if attack_data != null else 0.6
    _contact_hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL


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
