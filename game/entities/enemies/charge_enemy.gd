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


func can_charge_target_from_cell(origin_cell: Vector2i) -> bool:
    if _grid == null or not has_target():
        return false
    if not _grid.is_in_bounds(origin_cell) or not _grid.is_walkable(origin_cell):
        return false

    var target_cell := get_target_cell()
    if origin_cell == target_cell:
        return false
    if origin_cell.x != target_cell.x and origin_cell.y != target_cell.y:
        return false

    var facing := cardinal_snap(Vector2(target_cell - origin_cell))
    var cells := get_charge_cells_from_pos(origin_cell, facing)
    return target_cell in cells


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
    return EnemyState.EnemyStateId.IDLE


func get_reposition_state_id() -> int:
    return EnemyState.EnemyStateId.REPOSITION


func get_face_state_id() -> int:
    return EnemyState.EnemyStateId.FACE_TARGET


func get_recovery_state_id() -> int:
    return EnemyState.EnemyStateId.RECOVERY


func get_staggered_state_id() -> int:
    return EnemyState.EnemyStateId.STAGGERED


func get_dead_state_id() -> int:
    return EnemyState.EnemyStateId.DEAD


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
    _configure_contact_hitbox()
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
    clear_planned_path()
    _reservation_is_attack = false

    if _grid == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := get_target_cell()
    if not _grid.is_in_bounds(target_cell):
        return false
    if start == target_cell:
        queue_redraw()
        return true

    var line_goals := _collect_viable_charge_origin_cells(target_cell, start)
    if line_goals.is_empty():
        return plan_approach_action()
    if start in line_goals:
        queue_redraw()
        return true

    var path := _find_path_to_cell(start, NO_BLOCKED_CELL, line_goals, false)
    if path.is_empty():
        return plan_approach_action()

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return plan_approach_action()
    queue_redraw()
    return true


func begin_charge_attack() -> void:
    stop_attack_windup_vfx()
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(true)


func end_charge_attack() -> void:
    stop_attack_windup_vfx()
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


func _collect_viable_charge_origin_cells(target_cell: Vector2i, start: Vector2i) -> Array[Vector2i]:
    var goals: Array[Vector2i] = []
    for x in range(_grid.grid_size.x):
        var cell := Vector2i(x, target_cell.y)
        if _can_use_charge_origin(cell, target_cell, start):
            goals.append(cell)
    for y in range(_grid.grid_size.y):
        var cell := Vector2i(target_cell.x, y)
        if cell in goals:
            continue
        if _can_use_charge_origin(cell, target_cell, start):
            goals.append(cell)
    return goals


func _can_use_charge_origin(cell: Vector2i, target_cell: Vector2i, start: Vector2i) -> bool:
    if cell == target_cell:
        return false
    if cell != start and not _can_plan_goal_cell(cell, false):
        return false
    return can_charge_target_from_cell(cell)


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
