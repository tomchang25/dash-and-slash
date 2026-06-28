# puff_enemy.gd
# 1x1 grid enemy that chases the target and becomes a temporary area hazard.
class_name PuffEnemy
extends GridEnemy

const PUFF_RANGE := 2

# -- State --------------------------------------------------------------------
var _attack_data: EnemyAttackData

# -- Node references ----------------------------------------------------------
@onready var _puff_hitbox: Hitbox = _find_child_node("PuffHitbox") as Hitbox

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    _select_attack_data()
    _configure_puff_hitbox()
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)

# == Common API ================================================================


func get_body() -> Polygon2D:
    return _body


func is_target_in_puff_range() -> bool:
    return is_target_within_grid_range(get_puff_range())


## Commits the enemy to the puff action and clears any planned movement.
func begin_puff_action() -> bool:
    _configure_puff_hitbox()
    return begin_committed_action()


func enable_puff_hitbox(enable: bool) -> void:
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(enable)


## Returns the actual circular puff hitbox radius used by the scene.
func get_puff_hitbox_radius() -> float:
    if _puff_hitbox == null:
        return tile_size() * float(PUFF_RANGE)
    var collision_shape := _puff_hitbox.collision_shape as CollisionShape2D
    if collision_shape == null:
        return tile_size() * float(PUFF_RANGE)
    var circle := collision_shape.shape as CircleShape2D
    if circle == null:
        return tile_size() * float(PUFF_RANGE)
    return circle.radius


func get_current_attack_data() -> EnemyAttackData:
    return _attack_data


func get_puff_range() -> int:
    return _attack_data.radius if _attack_data != null else PUFF_RANGE


func get_puff_minimum_duration() -> float:
    return _attack_data.active_duration if _attack_data != null else 3.0


func get_puff_recheck_interval() -> float:
    return _attack_data.recheck_interval if _attack_data != null else 1.0


func get_idle_state_id() -> int:
    return EnemyState.EnemyStateId.IDLE


func get_reposition_state_id() -> int:
    return EnemyState.EnemyStateId.REPOSITION


func get_face_state_id() -> int:
    return EnemyState.EnemyStateId.FACE_TARGET


func get_staggered_state_id() -> int:
    return EnemyState.EnemyStateId.STAGGERED


func get_dead_state_id() -> int:
    return EnemyState.EnemyStateId.DEAD


func get_pre_plan_state_id() -> int:
    if is_target_in_puff_range():
        return EnemyState.EnemyStateId.PUFF
    return -1


func get_arrival_override_state_id() -> int:
    if is_target_in_puff_range():
        return EnemyState.EnemyStateId.PUFF
    return -1

# == Setup helpers =============================================================


func _after_setup_ready() -> void:
    _select_attack_data()
    _configure_puff_hitbox()


func _on_begin_death_extra() -> void:
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)


func _reset_extra() -> void:
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)


func _select_attack_data() -> void:
    if enemy_data != null:
        for attack: EnemyAttackData in enemy_data.attacks:
            if attack != null and attack.attack_kind == EnemyAttackData.AttackKind.PUFF:
                _attack_data = attack
                return
    _attack_data = _create_fallback_attack_data()


func _configure_puff_hitbox() -> void:
    if _puff_hitbox == null:
        return
    var attack_data := get_current_attack_data()
    _puff_hitbox.damage = attack_data.damage if attack_data != null else 12.0
    _puff_hitbox.damage_interval = attack_data.damage_interval if attack_data != null else 0.35
    _puff_hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL


func _create_fallback_attack_data() -> EnemyAttackData:
    var attack_data := EnemyAttackData.new()
    attack_data.attack_kind = EnemyAttackData.AttackKind.PUFF
    attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
    attack_data.damage = 12.0
    attack_data.damage_interval = 0.35
    attack_data.active_duration = 3.0
    attack_data.recheck_interval = 1.0
    attack_data.radius = PUFF_RANGE
    return attack_data


func _resolve_guard_damage(angle: int, guard_damage_profile: int) -> int:
    if _is_puffing():
        return DirectionResolver.normal_guard_damage(DirectionResolver.HitAngle.FRONT)
    return super(angle, guard_damage_profile)


func _get_blocked_hit_sfx(angle: int) -> SpatialAudioEvent:
    if not _is_puffing() and angle == DirectionResolver.HitAngle.BACK:
        return damaged_sfx_event
    return blocked_sfx_event


func _is_puffing() -> bool:
    return _state_machine != null and _state_machine.current_state != null and _state_machine.current_state.state_id == EnemyState.EnemyStateId.PUFF
