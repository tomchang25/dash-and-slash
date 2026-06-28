# puff_enemy.gd
# 1x1 grid enemy that chases the target and becomes a temporary area hazard.
class_name PuffEnemy
extends GridEnemy

const PUFF_ACTIVE_DURATION := 0.35
const PUFF_RANGE := 1

# -- Node references ----------------------------------------------------------
@onready var _puff_hitbox: Hitbox = _find_child_node("PuffHitbox") as Hitbox

# == Common API ================================================================


func get_body() -> Polygon2D:
    return _body


func is_target_in_puff_range() -> bool:
    if _grid == null or not has_target():
        return false
    var player_cell := _grid.world_to_grid(_target.global_position)
    var diff := player_cell - _grid_pos
    return absi(diff.x) <= PUFF_RANGE and absi(diff.y) <= PUFF_RANGE


func enable_puff_hitbox(enable: bool) -> void:
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(enable)


func get_idle_state_id() -> int:
    return PuffEnemyState.PuffEnemyStateId.IDLE


func get_reposition_state_id() -> int:
    return PuffEnemyState.PuffEnemyStateId.REPOSITION_STEP


func get_face_state_id() -> int:
    return PuffEnemyState.PuffEnemyStateId.FACE_ONCE


func get_staggered_state_id() -> int:
    return PuffEnemyState.PuffEnemyStateId.STAGGERED


func get_dead_state_id() -> int:
    return PuffEnemyState.PuffEnemyStateId.DEAD


func get_pre_plan_state_id() -> int:
    if is_target_in_puff_range():
        return PuffEnemyState.PuffEnemyStateId.PUFF
    return -1


func get_arrival_override_state_id() -> int:
    if is_target_in_puff_range():
        return PuffEnemyState.PuffEnemyStateId.PUFF
    return -1

# == Setup helpers =============================================================


func _on_begin_death_extra() -> void:
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)


func _reset_extra() -> void:
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)


func _resolve_guard_damage(angle: int, guard_damage_profile: int) -> int:
    if _is_puffing():
        return DirectionResolver.normal_guard_damage(DirectionResolver.HitAngle.FRONT)
    return super(angle, guard_damage_profile)


func _get_blocked_hit_sfx(angle: int) -> SpatialAudioEvent:
    if not _is_puffing() and angle == DirectionResolver.HitAngle.BACK:
        return damaged_sfx_event
    return blocked_sfx_event


func _is_puffing() -> bool:
    return _state_machine != null and _state_machine.current_state != null and _state_machine.current_state.state_id == PuffEnemyState.PuffEnemyStateId.PUFF
