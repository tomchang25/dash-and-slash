# charge_enemy.gd
# 1x1 grid enemy that lines up with the target, telegraphs, then rushes forward.
class_name ChargeEnemy
extends GridEnemy

const CHARGING_SPEED := 480.0
const CHARGE_RANGE := 5
## Baseline tick speed: the charger's threat is bursty and self-paces via align/turn/telegraph/recovery.
const TICK_SPEED := 100

# -- State --
var _attack_data: EnemyAttackData
var _charge_cells: Array[Vector2i] = []

# -- Node references --
@onready var _telegraph: TileTelegraph = %TileTelegraph


# == Lifecycle ==
func _ready() -> void:
    super()
    _select_attack_data()
    if _telegraph != null:
        _telegraph.setup(_grid)


# == Common API ==
func get_charge_cells_from_pos(from: Vector2i, facing: Vector2) -> Array[Vector2i]:
    var attack_data := get_current_attack_data()
    if attack_data != null:
        return get_unblocked_charge_cells(from, facing, attack_data)
    return get_unblocked_charge_cells(from, facing, _create_fallback_attack_data())


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


## Commits the charge both before planning and on arrival, whenever the enemy is aligned and already
## facing the charge direction so its line footprint covers the target.
func should_commit_before_plan() -> bool:
    return _can_charge_now()


func should_commit_on_arrival() -> bool:
    return _can_charge_now()


func get_tick_speed() -> int:
    return TICK_SPEED


## True only when the enemy is aligned with the target, already facing the charge direction, and no
## other enemy blocks the line before the target. The turn cap is the flank knob.
func _can_charge_now() -> bool:
    if _grid == null or not has_target() or _attack_data == null or _facing == Vector2.ZERO:
        return false
    var cells := get_charge_cells()
    return not cells.is_empty() and get_target_cell() in cells


## Tick footprint committed by begin_attack_telegraph(): the pre-computed charge line.
func get_committed_attack_cells() -> Array[Vector2i]:
    return get_stored_charge_cells()


## Adds the charge destination marker to the shared danger display.
func get_danger() -> Dictionary:
    var danger := super()
    var tiles := get_attack_tiles()
    if not danger.is_empty() and not tiles.is_empty():
        danger["dest"] = tiles.back()
    return danger


func get_current_attack_data() -> EnemyAttackData:
    return _attack_data


func show_attack_charge() -> void:
    var telegraph := get_telegraph()
    if telegraph != null:
        telegraph.show_charge(get_stored_charge_cells())


## Clears movement planning and prepares the charge telegraph along the enemy's current (capped) facing.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action():
        return false
    if not has_target():
        return false

    var cells := get_charge_cells()
    if cells.is_empty() or get_target_cell() not in cells:
        return false

    set_stored_charge_cells(cells)
    var telegraph := get_telegraph()
    if telegraph != null:
        telegraph.show_warning(cells)

    start_attack_windup_vfx(CombatFeedbackVFX.WindupStyle.CHARGE)
    return true


## Tick detonation: damages the player if their cell is on the charge line, then rushes to the farthest open landing cell along it.
func _tick_detonate() -> void:
    var tiles := get_attack_tiles()
    _resolve_detonation_on_player(tiles)
    var dest := get_charge_landing_cell(tiles)
    if dest != _grid_pos:
        CombatFeedbackVFX.play_charge_start(global_position, _facing, self)
        tick_snap_to_cell(dest)
    finish_attack_into_recovery()


## Tick hook: clears the charge telegraph, windup, and stored line when the charge resolves or cancels.
func _clear_attack_presentation() -> void:
    if _telegraph != null:
        _telegraph.clear()
    stop_attack_windup_vfx()
    clear_stored_charge_cells()


func plan_next_action() -> bool:
    return plan_charge_origin_action()


## Defensive cleanup on guard break and reset: stops the windup.
func end_charge_attack() -> void:
    stop_attack_windup_vfx()


# == Setup helpers ==
func _after_setup_ready() -> void:
    _select_attack_data()
    if _telegraph != null:
        _telegraph.setup(_grid)


func _on_guard_broken_extra() -> void:
    if _telegraph != null:
        _telegraph.clear()
    end_charge_attack()


func _on_begin_death_extra() -> void:
    if _telegraph != null:
        _telegraph.clear()


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


func _create_fallback_attack_data() -> EnemyAttackData:
    var attack_data := EnemyAttackData.new()
    attack_data.attack_kind = EnemyAttackData.AttackKind.CHARGE
    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
    attack_data.damage = 8.0
    attack_data.damage_interval = 0.6
    attack_data.warning_duration = 2
    attack_data.charge_duration = 0
    attack_data.recovery_duration = 2
    attack_data.line_length = CHARGE_RANGE
    attack_data.charge_speed = CHARGING_SPEED
    return attack_data
