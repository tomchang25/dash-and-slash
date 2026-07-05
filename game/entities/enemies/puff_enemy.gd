# puff_enemy.gd
# 1x1 grid enemy that chases the target and becomes a temporary area hazard, clocked in ticks.
# The puff windup counts down in player actions, then the zone stays active for several ticks,
# re-checking the player's cell each tick before shrinking and recovering.
class_name PuffEnemy
extends GridEnemy

## Zone lifecycle: WINDUP counts down the telegraph, ACTIVE damages each tick the player is inside.
enum PuffPhase {
    NONE,
    WINDUP,
    ACTIVE,
}

const PUFF_RANGE := 2
## Playtest tuning: slower pursuit leaks distance so the player can escape the zone footprint.
const TICK_SPEED := 75
const PUFF_ACTIVE_COLOR := Color(1.0, 0.5, 0.5, 1.0)
const PUFF_EXPAND_SCALE := 2.0
const PUFF_VFX_DURATION := 0.12

# -- State --------------------------------------------------------------------
var _attack_data: EnemyAttackData
var _puff_phase: int = PuffPhase.NONE
var _puff_base_scale := Vector2.ONE
var _puff_base_color := Color.WHITE
var _puff_vfx_tween: Tween

# -- Node references ----------------------------------------------------------
@onready var _puff_hitbox: Hitbox = %PuffHitbox
@onready var _point_executor: EnemyPointAttackExecutor = %PointAttackExecutor

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    _select_attack_data()
    _configure_point_executor()
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)

# == Common API ================================================================


func get_body() -> Polygon2D:
    return _body


func is_target_in_puff_range() -> bool:
    return is_target_within_grid_range(get_puff_range())


func enable_puff_hitbox(enable: bool) -> void:
    if _point_executor != null:
        _point_executor.set_hitbox_enabled(enable)


func get_tick_speed() -> int:
    return TICK_SPEED


## Commits the puff windup: locks the zone footprint and starts the telegraph countdown in player actions.
## Called by the puff-charge state. The zone activates when the countdown reaches zero (resolve_detonation).
func begin_puff_tick() -> bool:
    if not begin_committed_action() or not has_target():
        return false
    var cells := _compute_puff_cells()
    if cells.is_empty():
        return false
    _tick_runtime.commit_attack(cells, get_warning_tick_count())
    _puff_phase = PuffPhase.WINDUP
    start_attack_windup_vfx(CombatFeedbackVFX.WindupStyle.PUFF)
    return true


## Overrides the base single-shot detonation with a multi-tick zone: count down the windup, then keep the
## zone active for its lifetime, damaging the player each tick their cell is inside before shrinking.
func resolve_detonation() -> void:
    if not _tick_runtime.has_pending_attack():
        return
    var remaining := _tick_runtime.step_attack_countdown()
    if _puff_phase == PuffPhase.WINDUP:
        if remaining <= 0:
            _activate_puff_zone()
        return
    if _puff_phase == PuffPhase.ACTIVE:
        _resolve_detonation_on_player(get_attack_tiles())
        if remaining <= 0:
            _end_puff_zone()


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


## Commits the puff windup both before planning and on arrival, whenever the target is inside the zone
## range. The puff commits its zone windup rather than a tile telegraph, so it overrides try_commit_attack.
func should_commit_before_plan() -> bool:
    return is_target_in_puff_range()


func should_commit_on_arrival() -> bool:
    return is_target_in_puff_range()


func try_commit_attack() -> bool:
    return begin_puff_tick()

# == Tick puff zone ============================================================


## The square zone footprint centered on the enemy, sized to the puff radius.
func _compute_puff_cells() -> Array[Vector2i]:
    return AttackCellShapes.square(_grid_pos, get_puff_range(), _grid, true)


## Player actions the zone stays active (damaging) once the windup completes.
func _puff_active_ticks() -> int:
    var attack := get_current_attack_data()
    return maxi(int(attack.active_duration), 1) if attack != null else 2


## Windup finished: expand the body, damage the player once, and open the active window.
func _activate_puff_zone() -> void:
    _puff_phase = PuffPhase.ACTIVE
    _tick_runtime.set_attack_ticks(maxi(_puff_active_ticks() - 1, 0))
    stop_attack_windup_vfx()
    _play_puff_vfx(true)
    _resolve_detonation_on_player(get_attack_tiles())
    if _tick_runtime.attack_ticks() <= 0:
        _end_puff_zone()


## Active window finished: shrink the body, clear the zone, and open the recovery window before idle.
func _end_puff_zone() -> void:
    _puff_phase = PuffPhase.NONE
    _tick_runtime.clear_attack()
    _play_puff_vfx(false)
    # The machine is already parked in idle (the deciding state returned there on commit); the runtime's
    # freeze and this recovery window cover the whole windup/active span, so no transition is needed here.
    _tick_runtime.begin_recovery(get_recovery_tick_count())


func _play_puff_vfx(expand: bool) -> void:
    if _body == null:
        return
    if _puff_vfx_tween != null and _puff_vfx_tween.is_valid():
        _puff_vfx_tween.kill()
    if expand:
        _puff_base_scale = _body.scale
        _puff_base_color = _body.color
    var target_scale := _puff_base_scale * PUFF_EXPAND_SCALE if expand else _puff_base_scale
    var target_color := PUFF_ACTIVE_COLOR if expand else _puff_base_color
    _puff_vfx_tween = create_tween()
    _puff_vfx_tween.set_parallel()
    _puff_vfx_tween.tween_property(_body, "scale", target_scale, PUFF_VFX_DURATION)
    _puff_vfx_tween.tween_property(_body, "color", target_color, PUFF_VFX_DURATION)


## Tick hook: clears the puff windup/zone state and shrinks the body on a resolved or cancelled attack.
func _clear_attack_presentation() -> void:
    stop_attack_windup_vfx()
    if _puff_phase != PuffPhase.NONE:
        _puff_phase = PuffPhase.NONE
        _play_puff_vfx(false)
    enable_puff_hitbox(false)

# == Setup helpers =============================================================


func _after_setup_ready() -> void:
    _select_attack_data()
    _configure_point_executor()


func _on_begin_death_extra() -> void:
    enable_puff_hitbox(false)


func _reset_extra() -> void:
    enable_puff_hitbox(false)


func _select_attack_data() -> void:
    if enemy_data != null:
        for attack: EnemyAttackData in enemy_data.attacks:
            if attack != null and attack.attack_kind == EnemyAttackData.AttackKind.PUFF:
                _attack_data = attack
                return
    _attack_data = _create_fallback_attack_data()


func _configure_point_executor() -> void:
    if _point_executor == null:
        return
    _point_executor.setup(_grid, null, _puff_hitbox, false)
    _point_executor.configure(get_current_attack_data(), get_damage_multiplier())


func _create_fallback_attack_data() -> EnemyAttackData:
    var attack_data := EnemyAttackData.new()
    attack_data.attack_kind = EnemyAttackData.AttackKind.PUFF
    attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
    attack_data.damage = 12.0
    attack_data.damage_interval = 0.35
    attack_data.warning_duration = 3
    attack_data.active_duration = 2
    attack_data.recovery_duration = 2
    attack_data.recheck_interval = 1
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
    return _puff_phase == PuffPhase.ACTIVE
