# grid_enemy.gd
# Shared base for 1x1 grid enemies with target chasing, guard, stagger, and death handling.
# When bound to a TickEngine (bind_tick_engine), the enemy is clocked by discrete world ticks:
# the engine calls resolve_detonation() / advance_status() / act_tick() each world advance, movement
# snaps one cell per action, telegraph and recovery windows count in ticks, enemy-to-player damage
# resolves as a cell-membership check at detonation, and player-to-enemy damage arrives through
# take_hit() / predict_hit() instead of physics hurtbox overlap.
class_name GridEnemy
extends Enemy

const MOVE_SPEED := 120.0
const CYCLE_COOLDOWN := 1.0
const CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const EIGHT_DIRECTIONS := [
    Vector2i.RIGHT,
    Vector2i.LEFT,
    Vector2i.DOWN,
    Vector2i.UP,
    Vector2i(1, 1),
    Vector2i(1, -1),
    Vector2i(-1, 1),
    Vector2i(-1, -1),
]
const NO_BLOCKED_CELL := Vector2i(-1, -1)
const GUARDED_DAMAGE_MULTIPLIER := 0.2
## Energy-skeleton default: 100 = one action per world tick. Slower kinds skip beats; see get_tick_speed().
const DEFAULT_TICK_SPEED := 100
const DEFAULT_WARNING_TICKS := 2
const DEFAULT_RECOVERY_TICKS := 1
## Visual-only slide time for a one-cell tick snap; the logical cell moves instantly.
const TICK_MOVE_TWEEN_SEC := 0.09
const STAGGER_VFX_COLOR := Color(0.3, 0.5, 1.0, 1.0)
const PATH_DEBUG_COLOR := Color(0.2, 0.8, 1.0, 0.8)
const PATH_DEBUG_WIDTH := 4.0

# -- Movement -----------------------------------------------------------------
var _allow_diagonal_movement: bool = false


func _get_movement_directions() -> Array:
    return EIGHT_DIRECTIONS if _allow_diagonal_movement else CARDINAL_DIRECTIONS

# -- Exports ------------------------------------------------------------------
@export var death_sfx_event: SpatialAudioEvent
@export var damaged_sfx_event: SpatialAudioEvent
@export var blocked_sfx_event: SpatialAudioEvent
@export var enemy_data: EnemyData

# -- State --------------------------------------------------------------------
var _grid: GridArena
var _target: Node2D
var _grid_pos: Vector2i
var _facing: Vector2 = Vector2.DOWN
var _staggered: bool = false
var _planned_path: Array[Vector2i] = []
var _active_path_cell: Vector2i
var _has_active_path_cell: bool = false
var _reservation_is_attack: bool = false
var _attack_windup_vfx: Node2D
var _damage_multiplier := 1.0
var _defense := 0.0

# -- Tick state ---------------------------------------------------------------
## Set by bind_tick_engine(); non-null means this enemy is clocked by the tick engine.
var _tick_engine = null
## The committed attack's locked tiles, checked against the player's cell at detonation.
var _attack_tiles: Array[Vector2i] = []
## Player-actions remaining until the committed attack detonates; -1 when no attack is pending.
var _attack_ticks := -1
## World ticks the enemy stays in its post-attack recovery window (disabled, like stagger).
var _recovery_ticks := 0

# -- Timer / tween handles ----------------------------------------------------
var _cooldown_timer: Timer
var _stagger_tween: Tween
var _hurt_tween: Tween
var _tick_move_tween: Tween

# -- Node references ----------------------------------------------------------
@export var _state_machine: StateMachine
@export var _guard: Guard
@export var _status_bars: EnemyStatusBars
@export var hurtbox: Hurtbox
@export var _body: Polygon2D
@export var _facing_arrow: Polygon2D

# == Lifecycle ================================================================


func _ready() -> void:
    _resolve_node_references()
    super()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        register_grid_occupant()
        _grid.register_enemy_entity(self)
        if not _grid.reservation_lost.is_connected(_on_reservation_lost):
            _grid.reservation_lost.connect(_on_reservation_lost)

    if hurtbox != null:
        hurtbox.hit_received.connect(_on_hit_received)

    if health != null:
        health.damaged.connect(_on_damaged)
        _on_health_changed(health.current(), health.max_health)

    _cooldown_timer = Timer.new()
    _cooldown_timer.one_shot = true
    # node-src: timer
    add_child(_cooldown_timer)

    if _guard != null:
        _guard.guard_changed.connect(_on_guard_changed)
        _guard.guard_broken.connect(_on_guard_broken)
        _guard.stagger_started.connect(_on_stagger_started)
        _guard.stagger_ended.connect(_on_stagger_ended)
        _on_guard_changed(_guard.current(), _guard.max_guard)

    face_arrow()
    _init_debug_fsm_state()


func _physics_process(_delta: float) -> void:
    # Tick-clocked enemies never move on physics frames; the engine drives position via snap-steps.
    if _tick_engine != null:
        return

    if not is_instance_valid(_target):
        velocity = Vector2.ZERO
        move_and_slide()
        return

    if _grid == null:
        velocity = global_position.direction_to(_target.global_position) * get_move_speed()

    move_and_slide()
    queue_redraw()


func _draw() -> void:
    if _grid == null or (not _has_active_path_cell and _planned_path.is_empty()):
        return

    var previous := Vector2.ZERO
    if _has_active_path_cell:
        var active_point := to_local(_grid.cell_center(_active_path_cell))
        draw_line(previous, active_point, PATH_DEBUG_COLOR, PATH_DEBUG_WIDTH)
        draw_circle(active_point, PATH_DEBUG_WIDTH * 1.5, PATH_DEBUG_COLOR)
        previous = active_point
    else:
        previous = to_local(_grid.cell_center(_grid_pos))

    for cell in _planned_path:
        var point := to_local(_grid.cell_center(cell))
        draw_line(previous, point, PATH_DEBUG_COLOR, PATH_DEBUG_WIDTH)
        draw_circle(point, PATH_DEBUG_WIDTH * 1.5, PATH_DEBUG_COLOR)
        previous = point

# == Overridden Custom Methods ================================================


func reset() -> void:
    super()
    _staggered = false
    stop_attack_windup_vfx()
    if _body != null:
        _body.modulate = Color.WHITE
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    clear_planned_path()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        register_grid_occupant()
    if health != null:
        _on_health_changed(health.current(), health.max_health)
    if _guard != null:
        _on_guard_changed(_guard.current(), _guard.max_guard)
    _reset_extra()

# == Signal handlers ==========================================================


## Clears planned movement when a higher-priority claim takes our reservation.
func _on_reservation_lost(_entity: Object) -> void:
    if _entity != self:
        return

    if _has_active_path_cell:
        _planned_path.clear()
        if not _grid.reserve_cells_with_active_steps(self, [_active_path_cell], _reservation_is_attack, [_active_path_cell]):
            _has_active_path_cell = false
            _grid.clear_reservation(self)
        queue_redraw()
    else:
        clear_planned_path()


func _on_guard_broken() -> void:
    _staggered = true
    stop_attack_windup_vfx()
    clear_planned_path()
    # A guard break clears any banked action energy and cancels the pending attack, so a
    # just-recovered enemy can never surprise the player with saved-up movement or a stale telegraph.
    if _tick_engine != null:
        _tick_engine.clear_energy(self)
        cancel_tick_attack()
        _recovery_ticks = 0
    _on_guard_broken_extra()
    var staggered_state_id := get_staggered_state_id()
    if _state_machine != null and staggered_state_id >= 0:
        _state_machine.request_transition(staggered_state_id, true)


func _on_guard_changed(current: int, maximum: int) -> void:
    if _status_bars != null:
        _status_bars.set_guard(current, maximum)


func _on_health_changed(current: float, maximum: float) -> void:
    super(current, maximum)
    if _status_bars != null:
        _status_bars.set_health(current, maximum)


func _on_damaged(_amount: float, _source: Node) -> void:
    if _body == null:
        return
    if _hurt_tween != null and _hurt_tween.is_valid():
        _hurt_tween.kill()

    _hurt_tween = create_tween()
    _hurt_tween.tween_property(_body, "modulate", Color.WHITE, 0.03)
    _hurt_tween.tween_property(_body, "modulate", Color(0.8, 0.2, 0.2, 1.0), 0.06)
    _hurt_tween.tween_property(_body, "modulate", Color.WHITE, 0.08)
    _hurt_tween.finished.connect(
        func():
            if _body != null:
                if _staggered:
                    _start_stagger_vfx()
                else:
                    _body.modulate = Color.WHITE,
        CONNECT_ONE_SHOT,
    )


func _on_hit_received(amount: float, source: Node, guard_damage_profile: int) -> void:
    if not (source is Node2D):
        return

    var src_pos := (source as Node2D).global_position
    var is_dash := guard_damage_profile == Hitbox.GuardDamageProfile.DASH
    var outcome := _resolve_hit_outcome(src_pos, amount, is_dash)
    if not is_alive():
        return

    _apply_hit_feedback(outcome, src_pos)

    if health != null:
        health.take_damage(float(outcome["hp_damage"]), source)
    if health != null and not health.is_alive():
        return
    if _guard != null:
        _guard.take_guard_damage(int(outcome["guard_damage"]))


func _on_stagger_started() -> void:
    _staggered = true
    if _hurt_tween != null and _hurt_tween.is_valid():
        return
    _start_stagger_vfx()


func _on_stagger_ended() -> void:
    _staggered = false
    if _body != null:
        if _stagger_tween != null and is_instance_valid(_stagger_tween):
            _stagger_tween.kill()
        _stagger_tween = create_tween()
        _stagger_tween.tween_property(_body, "modulate", Color.WHITE, 0.3)

# == Common API ================================================================


func setup(grid: GridArena, target: Node2D) -> void:
    _grid = grid
    _target = target
    if is_node_ready() and _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        register_grid_occupant()
        _grid.register_enemy_entity(self)
        if not _grid.reservation_lost.is_connected(_on_reservation_lost):
            _grid.reservation_lost.connect(_on_reservation_lost)
        _after_setup_ready()

# == Tick actor contract =======================================================
# Called by the TickEngine each world advance. The engine owns the resolution order
# (detonations first, then status, then energy-funded actions); the enemy owns its
# own behavior within those hooks.


## Binds this enemy to the scene tick engine, switching it from physics/frame clocking to tick clocking.
func bind_tick_engine(engine) -> void:
    _tick_engine = engine


func is_alive() -> bool:
    return health != null and health.is_alive()


## Per-kind energy-skeleton speed read by the engine; 100 = one action per world tick.
## Slower kinds skip beats so pursuit leaks distance and flanking windows open. Overridden per kind.
func get_tick_speed() -> int:
    return DEFAULT_TICK_SPEED


## Engine stage-2 hook: counts the committed telegraph down by one player action and detonates at zero.
func resolve_detonation() -> void:
    if _attack_ticks <= 0:
        return
    _attack_ticks -= 1
    if _attack_ticks == 1:
        # Last player action before impact: escalate the telegraph to the charge phase.
        show_attack_charge()
    if _attack_ticks > 0:
        return
    _tick_detonate()


## Engine stage-3a hook: counts the stagger and recovery windows down in world ticks. Returns true while the
## enemy is disabled this tick, so the engine neither funds an action nor lets it bank energy (no banked surprise).
func advance_status() -> bool:
    if _guard != null and _guard.is_staggered():
        _guard.advance_stagger()
        return true
    if _recovery_ticks > 0:
        _recovery_ticks -= 1
        return true
    return false


## Engine stage-3b hook: spends one funded action. A committed telegraph freezes the enemy until it detonates.
func act_tick() -> void:
    if _attack_ticks > 0:
        return
    if _state_machine != null:
        _state_machine.advance_tick()


## Returns the current danger display data ({cells, ticks}), or an empty dictionary when no attack is pending.
func get_danger() -> Dictionary:
    if _attack_ticks <= 0 or _attack_tiles.is_empty():
        return { }
    return {
        "cells": _attack_tiles.duplicate(),
        "ticks": _attack_ticks,
    }


## Predicts one player hit without mutating state, sharing math with take_hit() so a preview
## can never disagree with the resolved hit. Origin is the attacker's cell (player or dash origin).
## Returns keys angle, staggered, guard_broken, killed, hp_damage, guard_damage.
func predict_hit(origin_cell: Vector2i, base_damage: float, is_dash: bool) -> Dictionary:
    var src_pos := _grid.cell_center(origin_cell) if _grid != null else Vector2.ZERO
    return _resolve_hit_outcome(src_pos, base_damage, is_dash)


## Applies one player hit from the given origin cell, reusing the established guard/health/feedback
## seams (damaged/blocked SFX, guard-break/shield/full-damage VFX), and returns the same dictionary
## as predict_hit(). A guard break clears banked energy via _on_guard_broken().
func take_hit(origin_cell: Vector2i, base_damage: float, is_dash: bool) -> Dictionary:
    var src_pos := _grid.cell_center(origin_cell) if _grid != null else Vector2.ZERO
    var outcome := _resolve_hit_outcome(src_pos, base_damage, is_dash)
    if not is_alive():
        return outcome
    _apply_hit_feedback(outcome, src_pos)
    if health != null:
        health.take_damage(float(outcome["hp_damage"]), self)
    if health != null and not health.is_alive():
        return outcome
    if _guard != null and int(outcome["guard_damage"]) > 0:
        _guard.take_guard_damage(int(outcome["guard_damage"]))
    return outcome


## Commits an attack telegraph clocked in ticks: locks the footprint tiles and starts the countdown.
## Returns false when the kind could not prepare the attack.
func begin_tick_telegraph() -> bool:
    if not begin_attack_telegraph():
        return false
    var cells := get_committed_attack_cells()
    if cells.is_empty():
        return false
    _attack_tiles = cells
    _attack_ticks = get_warning_tick_count()
    return true


## Number of player actions the telegraph is displayed before detonation.
func get_warning_tick_count() -> int:
    var attack := get_current_attack_data()
    return maxi(int(attack.warning_duration), 1) if attack != null else DEFAULT_WARNING_TICKS


## Number of world ticks the enemy recovers (cannot act) after an attack resolves.
func get_recovery_tick_count() -> int:
    var attack := get_current_attack_data()
    return maxi(int(attack.recovery_duration), 0) if attack != null else DEFAULT_RECOVERY_TICKS


## Snaps the logical cell immediately and slides the visual there; the flank turn cap is applied
## separately by tick_turn_toward_cell(). Registers the new occupancy and refreshes reservations.
func tick_snap_to_cell(target_cell: Vector2i) -> void:
    _grid_pos = target_cell
    register_grid_occupant()
    if _tick_move_tween != null and _tick_move_tween.is_valid():
        _tick_move_tween.kill()
    scale = Vector2(1.1, 0.9)
    _tick_move_tween = create_tween()
    _tick_move_tween.set_parallel(true)
    _tick_move_tween.tween_property(self, "global_position", _grid.cell_center(target_cell), TICK_MOVE_TWEEN_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tick_move_tween.tween_property(self, "scale", Vector2.ONE, TICK_MOVE_TWEEN_SEC * 1.5)


## Turns capped toward the current target cell. Returns true once aligned (or when there is no target).
func tick_face_toward_target() -> bool:
    if not has_target():
        return true
    return tick_turn_toward_cell(get_target_cell())


## Rotates facing at most 90 degrees toward the target's cardinal direction. Returns true once aligned.
## The per-tick cap is the flank-depth knob: turning to face a flanker costs actions, opening back hits.
func tick_turn_toward_cell(target_cell: Vector2i) -> bool:
    var desired := cardinal_snap(Vector2(target_cell - _grid_pos))
    if desired == Vector2.ZERO or _facing == desired:
        return true
    if _facing == -desired:
        # A 180-degree reversal takes two actions: step 90 degrees this tick.
        _facing = Vector2(-_facing.y, _facing.x)
    else:
        _facing = desired
    face_arrow()
    return _facing == desired


## Consumes one reserved cell from the planned path as a tick snap-step. Returns true when a step was taken.
func tick_step_along_path() -> bool:
    if _grid == null or _planned_path.is_empty():
        return false
    var next := _planned_path[0]
    if not _grid.is_reserved_by(next, self):
        # Lost the reservation to a higher-priority claim before stepping; abandon the path this tick.
        clear_planned_path()
        return false
    if _tick_engine != null and not _tick_engine.is_cell_open_for_enemy(next, self):
        # The player (not a grid occupant) or another actor moved onto the reserved cell since planning.
        clear_planned_path()
        return false
    _planned_path.remove_at(0)
    _has_active_path_cell = false
    _facing = Vector2(signi(next.x - _grid_pos.x), signi(next.y - _grid_pos.y))
    face_arrow()
    tick_snap_to_cell(next)
    _refresh_planned_reservations()
    queue_redraw()
    return true


## Clears a committed but undetonated attack: drops the locked tiles, the countdown, and its telegraph.
func cancel_tick_attack() -> void:
    _attack_tiles.clear()
    _attack_ticks = -1
    _clear_attack_presentation()


## The footprint tiles just prepared by begin_attack_telegraph(), stored for detonation and danger display.
## Kinds override to return their executor/telegraph cells; the base has no footprint.
func get_committed_attack_cells() -> Array[Vector2i]:
    var empty: Array[Vector2i] = []
    return empty


## Outgoing per-hit damage this enemy deals to the player at detonation, after wave-scaling.
func get_attack_hit_damage() -> float:
    var attack := get_current_attack_data()
    var base := attack.damage if attack != null else 10.0
    return base * _damage_multiplier


## Ends a resolved attack and opens its recovery window (a disabled status counted in advance_status()).
## Kinds reuse this from _tick_detonate().
func finish_attack_into_recovery() -> void:
    _attack_tiles.clear()
    _attack_ticks = -1
    _clear_attack_presentation()
    _recovery_ticks = get_recovery_tick_count()
    if _state_machine != null:
        _state_machine.request_transition(get_recovery_state_id(), true)


## Applies per-wave milestone scaling to this enemy instance: bumps max_health in
## place (Health is a per-instance node, safe to mutate), stores a damage
## multiplier consumed when attacks stamp their hitbox damage, and stores a flat
## defense value consumed by _apply_defense(). Guard never scales.
func apply_wave_scaling(hp_multiplier: float, damage_multiplier: float, defense: float) -> void:
    _damage_multiplier = max(damage_multiplier, 0.0)
    _defense = max(defense, 0.0)
    if health != null and hp_multiplier > 1.0:
        health.add_max_health(health.max_health * (hp_multiplier - 1.0), true)


## Returns this enemy's current outgoing-damage multiplier from wave scaling.
func get_damage_multiplier() -> float:
    return _damage_multiplier


func has_target() -> bool:
    return is_instance_valid(_target)


func get_target() -> Node2D:
    return _target


## Returns the target's current grid cell, or NO_BLOCKED_CELL when unavailable. Tick-clocked enemies
## read the engine's logical player cell so planning never lags the player's move tween by a frame.
func get_target_cell() -> Vector2i:
    if _grid == null or not has_target():
        return NO_BLOCKED_CELL
    if _tick_engine != null:
        return _tick_engine.player_cell()
    return _grid.world_to_grid(_target.global_position)


func set_target(target: Node2D) -> void:
    _target = target


func is_staggered() -> bool:
    return _staggered


func set_staggered(value: bool) -> void:
    _staggered = value


func cooldown_active() -> bool:
    return _cooldown_timer != null and _cooldown_timer.time_left > 0.0


func get_cycle_cooldown() -> float:
    return enemy_data.cycle_cooldown if enemy_data != null else CYCLE_COOLDOWN


func start_cooldown() -> void:
    if _cooldown_timer != null:
        _cooldown_timer.start(get_cycle_cooldown())


func tile_size() -> float:
    return _grid.tile_size if _grid else 64.0


func get_grid() -> GridArena:
    return _grid


func get_grid_pos() -> Vector2i:
    return _grid_pos


func set_grid_pos(pos: Vector2i) -> void:
    _grid_pos = pos


func get_facing() -> Vector2:
    return _facing


func set_facing(v: Vector2) -> void:
    _facing = v


func plan_next_action() -> bool:
    return plan_approach_action()


## Plans ordinary movement toward the target, preferring adjacent cells when reachable.
func plan_approach_action() -> bool:
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

    var path := _find_path_to_best_reachable_cell(
        start,
        target_cell,
        false,
        func(cell: Vector2i) -> bool: return _is_approach_candidate(cell, target_cell),
        func(cell: Vector2i, path_length: int) -> int: return _score_approach_candidate(cell, target_cell, path_length)
    )
    if path.is_empty():
        if _is_approach_candidate(start, target_cell):
            queue_redraw()
            return true
        return false

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return false
    queue_redraw()
    return true


## Clears pending grid movement, active path debug state, and path reservations.
func clear_planned_path() -> void:
    if _grid != null:
        _grid.clear_reservation(self)
    _planned_path.clear()
    _has_active_path_cell = false
    queue_redraw()


func has_planned_path() -> bool:
    return not _planned_path.is_empty()


## Returns the first cell of the planned path without consuming it, or NO_BLOCKED_CELL.
func get_planned_path_first() -> Vector2i:
    return _planned_path[0] if not _planned_path.is_empty() else NO_BLOCKED_CELL


func consume_next_planned_cell() -> Vector2i:
    var next := _planned_path[0]
    _planned_path.remove_at(0)
    _active_path_cell = next
    _has_active_path_cell = true
    if not _refresh_planned_reservations():
        _planned_path.clear()
        _grid.clear_reservation(self)
    queue_redraw()
    return next


func face_toward_cell(target_cell: Vector2i) -> void:
    var step := target_cell - _grid_pos
    if step == Vector2i.ZERO:
        return
    _facing = Vector2(signi(step.x), signi(step.y))
    face_arrow()


func face_target_position() -> void:
    if not has_target():
        return
    var direction := _target.global_position - global_position
    if direction == Vector2.ZERO:
        return
    _facing = cardinal_snap(direction)
    face_arrow()


func cardinal_snap(v: Vector2) -> Vector2:
    if abs(v.x) > abs(v.y):
        return Vector2(sign(v.x), 0.0)
    return Vector2(0.0, sign(v.y))


func face_arrow() -> void:
    if _facing_arrow != null:
        _facing_arrow.rotation = _facing.angle() - PI / 2.0
    if _body != null:
        _body.rotation = _facing.angle() + PI / 2.0
    if hurtbox != null:
        hurtbox.rotation = _facing.angle() + PI / 2.0


func register_grid_occupant() -> void:
    if _grid != null:
        _grid.register_occupant(self, [_grid_pos])


## Returns true when the target is within Chebyshev grid range.
func is_target_within_grid_range(cell_range: int) -> bool:
    if _grid == null or not has_target():
        return false
    var target_cell := get_target_cell()
    var diff := target_cell - _grid_pos
    return absi(diff.x) <= cell_range and absi(diff.y) <= cell_range


func get_guard() -> Guard:
    return _guard


func begin_death() -> void:
    velocity = Vector2.ZERO
    stop_attack_windup_vfx()
    clear_planned_path()
    # Vacate the grid cell immediately so other actors and the player can enter during the death tween.
    if _grid != null:
        _grid.unregister_occupant(self)
    _on_begin_death_extra()
    if _stagger_tween != null and is_instance_valid(_stagger_tween):
        _stagger_tween.kill()
    if health != null:
        health.set_enabled(false)
    if hurtbox != null:
        hurtbox.set_enabled(false)


## Force-death entry point for boss wave resolution. Zeroes hp through Health,
## which fires the same Health.died path combat damage and debug instant-kill
## use, so death effects run through _on_death_effects() exactly once
## regardless of entry point.
func force_death() -> void:
    if health != null:
        health.kill()


func play_death_sfx() -> void:
    if death_sfx_event != null:
        AudioManager.play_event(death_sfx_event, global_position)


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


func get_after_face_state_id() -> int:
    return get_idle_state_id()


func get_pre_plan_state_id() -> int:
    return -1


func get_arrival_override_state_id() -> int:
    return -1


func get_current_attack_data() -> EnemyAttackData:
    return null


func can_charge_target_from_cell(origin_cell: Vector2i) -> bool:
    if _grid == null or not has_target():
        return false
    if not _grid.is_in_bounds(origin_cell) or not _grid.is_walkable(origin_cell):
        return false

    var attack_data := get_current_attack_data()
    if attack_data == null or attack_data.attack_kind != EnemyAttackData.AttackKind.CHARGE:
        return false

    var target_cell := get_target_cell()
    if origin_cell == target_cell:
        return false

    var facing := cardinal_snap(Vector2(target_cell - origin_cell))
    var cells := EnemyAttackController.get_attack_cells(origin_cell, facing, attack_data, _grid)
    return target_cell in cells


func get_warning_duration() -> float:
    var attack := get_current_attack_data()
    return float(attack.warning_duration) if attack != null else 0.6


func get_charge_duration() -> float:
    var attack := get_current_attack_data()
    return float(attack.charge_duration) if attack != null else 0.2


func get_attack_duration() -> float:
    var attack := get_current_attack_data()
    return float(attack.active_duration) if attack != null else 0.2


## Performs shared setup when an enemy commits to a non-reposition action.
func begin_committed_action() -> bool:
    velocity = Vector2.ZERO
    clear_planned_path()
    return true


## Default attack telegraph entry; enemies with telegraphs extend this setup.
func begin_attack_telegraph() -> bool:
    return begin_committed_action()


func get_attack_state_id() -> int:
    return EnemyState.EnemyStateId.ATTACK


## Shows the charge telegraph phase. Enemies with telegraphs extend this.
func show_attack_charge() -> void:
    pass


## Starts the active attack phase. Returns false if attack cannot begin.
func begin_attack() -> bool:
    return false


## Ends the active attack phase and disables hitboxes.
func end_attack() -> void:
    pass


## Returns the enemy's charge-mode telegraph. Enemies without a charge attack
## leave this null.
func get_telegraph() -> TileTelegraph:
    return null


## Returns the pre-computed cell sequence for the enemy's active charge attack.
## Enemies without a charge attack leave this empty.
func get_stored_charge_cells() -> Array[Vector2i]:
    return []


## Clears the pre-computed charge cell sequence. Enemies without a charge
## attack need not override this.
func clear_stored_charge_cells() -> void:
    pass


## Returns the enemy's charge-mode traversal speed.
func get_charge_speed() -> float:
    return 0.0


## Starts the active charge-dash phase (hitbox enable). Enemies without a
## charge attack need not override this.
func begin_charge_attack() -> void:
    pass


## Ends the active charge-dash phase (hitbox disable). Enemies without a
## charge attack need not override this.
func end_charge_attack() -> void:
    pass


## Starts a reusable attack windup loop for telegraphed actions.
func start_attack_windup_vfx(style: int = CombatFeedbackVFX.WindupStyle.TILE) -> void:
    stop_attack_windup_vfx()
    _attack_windup_vfx = CombatFeedbackVFX.start_attack_windup_loop(global_position, _facing, self, style)


## Stops the active attack windup loop, if one exists.
func stop_attack_windup_vfx() -> void:
    CombatFeedbackVFX.stop_loop(_attack_windup_vfx)
    _attack_windup_vfx = null


## Plans movement to a charge origin whose attack-data footprint can hit the target.
func plan_charge_origin_action() -> bool:
    clear_planned_path()
    _reservation_is_attack = false

    if _grid == null or not has_target():
        return false

    var attack_data := get_current_attack_data()
    if attack_data == null or attack_data.attack_kind != EnemyAttackData.AttackKind.CHARGE:
        return plan_approach_action()

    var start := _grid_pos
    var target_cell := get_target_cell()
    if not _grid.is_in_bounds(target_cell):
        return false
    if start == target_cell:
        queue_redraw()
        return true

    var charge_origins := _collect_charge_origin_cells(target_cell, start, attack_data)
    if charge_origins.is_empty():
        return plan_approach_action()

    if start in charge_origins:
        queue_redraw()
        return true

    var path := _find_path_to_cell(start, target_cell, charge_origins, false)
    if path.is_empty():
        return plan_approach_action()

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return plan_approach_action()
    queue_redraw()
    return true


func get_move_speed() -> float:
    return enemy_data.move_speed if enemy_data != null else MOVE_SPEED


func get_recovery_duration() -> float:
    return enemy_data.default_recovery_duration if enemy_data != null else 3.0


## Shared cell-origin planning for tile attacks. Computes target-derived origin
## candidates, verifies the committed facing can hit the target, and paths to one.
func plan_cell_attack_action(get_cells_for_origin: Callable, get_origins_for_target: Callable = Callable()) -> bool:
    clear_planned_path()
    _reservation_is_attack = true

    if _grid == null or not has_target():
        return false

    var start := _grid_pos
    var target_cell := get_target_cell()
    if not _grid.is_in_bounds(target_cell):
        return false

    var candidate_origins := _collect_attack_origin_candidates(target_cell, get_origins_for_target)
    var attack_origins: Array[Vector2i] = []
    for origin_cell: Vector2i in candidate_origins:
        if origin_cell == target_cell:
            continue
        if origin_cell != start and not _can_plan_goal_cell(origin_cell, true):
            continue
        var facing := cardinal_snap(Vector2(target_cell - origin_cell))
        var cells: Array[Vector2i] = get_cells_for_origin.call(origin_cell, facing)
        if target_cell not in cells:
            continue
        if origin_cell not in attack_origins:
            attack_origins.append(origin_cell)

    if attack_origins.is_empty():
        return false

    if start in attack_origins:
        queue_redraw()
        return true

    var path := _find_path_to_cell(start, target_cell, attack_origins, true)
    if path.is_empty():
        return false

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return false
    queue_redraw()
    return true

# == Grid helpers ==============================================================


func _collect_attack_origin_candidates(target_cell: Vector2i, get_origins_for_target: Callable) -> Array[Vector2i]:
    if get_origins_for_target.is_valid():
        var origins: Array[Vector2i] = get_origins_for_target.call(target_cell)
        return origins
    return _collect_all_grid_origin_cells()


func _collect_charge_origin_cells(target_cell: Vector2i, start: Vector2i, attack_data: EnemyAttackData) -> Array[Vector2i]:
    var origins: Array[Vector2i] = []
    for origin_cell: Vector2i in EnemyAttackController.get_attack_origin_cells(target_cell, attack_data, _grid):
        if origin_cell == target_cell:
            continue
        if origin_cell != start and not _can_plan_goal_cell(origin_cell, false):
            continue
        if not can_charge_target_from_cell(origin_cell):
            continue
        if origin_cell not in origins:
            origins.append(origin_cell)
    return origins


func _collect_all_grid_origin_cells() -> Array[Vector2i]:
    var origins: Array[Vector2i] = []
    for x in range(_grid.grid_size.x):
        for y in range(_grid.grid_size.y):
            origins.append(Vector2i(x, y))
    return origins


func _update_grid_pos() -> void:
    var new_cell := _grid.world_to_grid(global_position)
    if new_cell != _grid_pos:
        _grid_pos = new_cell
        register_grid_occupant()


func _find_path_to_cell(start: Vector2i, blocked_cell: Vector2i, goal_cells: Array[Vector2i], is_attack: bool) -> Array[Vector2i]:
    var queue: Array[Vector2i] = [start]
    var came_from: Dictionary = { }
    var queue_index := 0
    var goal := Vector2i(-1, -1)
    came_from[start] = start

    while queue_index < queue.size():
        var current := queue[queue_index]
        queue_index += 1

        if current in goal_cells:
            goal = current
            break

        for direction: Vector2i in _get_movement_directions():
            var next := current + direction
            if came_from.has(next):
                continue
            if not _can_path_through(current, next, start, blocked_cell, goal_cells, is_attack):
                continue
            came_from[next] = current
            queue.append(next)

    if goal == Vector2i(-1, -1):
        var empty_path: Array[Vector2i] = []
        return empty_path

    var path: Array[Vector2i] = []
    var path_cell := goal
    while came_from[path_cell] != path_cell:
        path.push_front(path_cell)
        path_cell = came_from[path_cell]
    return path


func _find_path_to_best_reachable_cell(
        start: Vector2i,
        blocked_cell: Vector2i,
        is_attack: bool,
        is_candidate: Callable,
        score_candidate: Callable,
) -> Array[Vector2i]:
    var queue: Array[Vector2i] = [start]
    var came_from: Dictionary = { }
    var distances: Dictionary = { }
    var queue_index := 0
    var best_cell := NO_BLOCKED_CELL
    var best_score := 999999
    var best_path_length := 999999
    var endpoint_goals: Array[Vector2i] = []
    came_from[start] = start
    distances[start] = 0

    while queue_index < queue.size():
        var current := queue[queue_index]
        queue_index += 1

        var path_length: int = distances[current]
        if _can_end_ranked_path_at(current, start, is_attack) and is_candidate.call(current):
            var score: int = score_candidate.call(current, path_length)
            if _is_better_ranked_endpoint(score, path_length, current, best_score, best_path_length, best_cell):
                best_cell = current
                best_score = score
                best_path_length = path_length

        for direction: Vector2i in _get_movement_directions():
            var next := current + direction
            if came_from.has(next):
                continue
            if not _can_path_through(current, next, start, blocked_cell, endpoint_goals, is_attack):
                continue
            came_from[next] = current
            distances[next] = path_length + 1
            queue.append(next)

    if best_cell == NO_BLOCKED_CELL or best_cell == start:
        var empty_path: Array[Vector2i] = []
        return empty_path

    return _reconstruct_path(came_from, best_cell)


func _reconstruct_path(came_from: Dictionary, goal: Vector2i) -> Array[Vector2i]:
    var path: Array[Vector2i] = []
    var path_cell := goal
    while came_from[path_cell] != path_cell:
        path.push_front(path_cell)
        path_cell = came_from[path_cell]
    return path


func _can_end_ranked_path_at(cell: Vector2i, start: Vector2i, is_attack: bool) -> bool:
    return cell == start or _can_plan_goal_cell(cell, is_attack)


func _is_better_ranked_endpoint(
        score: int,
        path_length: int,
        cell: Vector2i,
        best_score: int,
        best_path_length: int,
        best_cell: Vector2i,
) -> bool:
    if best_cell == NO_BLOCKED_CELL:
        return true
    if score != best_score:
        return score < best_score
    if path_length != best_path_length:
        return path_length < best_path_length
    if cell.y != best_cell.y:
        return cell.y < best_cell.y
    return cell.x < best_cell.x


func _can_path_through(
        current: Vector2i,
        next: Vector2i,
        start: Vector2i,
        blocked_cell: Vector2i,
        goal_cells: Array[Vector2i],
        is_attack: bool,
) -> bool:
    if not _grid.can_move_between(current, next):
        return false
    if next == blocked_cell:
        return false
    if _needs_committed_path_cell(current, next, start, goal_cells):
        return _can_claim_committed_path_cell(next, is_attack)
    return true


func _needs_committed_path_cell(
        current: Vector2i,
        next: Vector2i,
        start: Vector2i,
        goal_cells: Array[Vector2i],
) -> bool:
    return current == start or next in goal_cells


func _can_claim_committed_path_cell(cell: Vector2i, is_attack: bool) -> bool:
    if _grid.is_occupied(cell):
        return false
    if not _grid.is_reserved(cell):
        return true
    return _grid.can_reserve_cell(self, cell, is_attack)


func _can_plan_goal_cell(cell: Vector2i, is_attack: bool) -> bool:
    if not _grid.is_walkable(cell):
        return false
    return _can_claim_committed_path_cell(cell, is_attack)


func _is_approach_candidate(cell: Vector2i, target_cell: Vector2i) -> bool:
    return cell != target_cell and _grid.is_walkable(cell)


func _score_approach_candidate(cell: Vector2i, target_cell: Vector2i, path_length: int) -> int:
    var distance := absi(cell.x - target_cell.x) + absi(cell.y - target_cell.y)
    var chebyshev_distance := maxi(absi(cell.x - target_cell.x), absi(cell.y - target_cell.y))
    var adjacent_penalty := 0 if distance == 1 else 100000
    var sea_corner_penalty := _get_sea_corner_approach_penalty(cell, target_cell)
    return adjacent_penalty + sea_corner_penalty + chebyshev_distance * 1000 + distance * 100 + path_length


func _get_sea_corner_approach_penalty(cell: Vector2i, target_cell: Vector2i) -> int:
    if cell.x == target_cell.x or cell.y == target_cell.y:
        return 0

    var x_step := signi(target_cell.x - cell.x)
    var y_step := signi(target_cell.y - cell.y)
    var horizontal_bridge := Vector2i(cell.x + x_step, cell.y)
    var vertical_bridge := Vector2i(cell.x, cell.y + y_step)
    if not _grid.is_walkable(horizontal_bridge) or not _grid.is_walkable(vertical_bridge):
        return 10000
    return 0


func _refresh_planned_reservations() -> bool:
    if _grid == null:
        return true

    var reserved_cells: Array[Vector2i] = []
    var active_cells: Array[Vector2i] = []
    if _has_active_path_cell:
        reserved_cells.append(_active_path_cell)
        active_cells.append(_active_path_cell)
    if not _planned_path.is_empty():
        var final_cell := _planned_path[_planned_path.size() - 1]
        if final_cell not in reserved_cells:
            reserved_cells.append(final_cell)
        if not _has_active_path_cell:
            var first_cell := _planned_path[0]
            if first_cell not in reserved_cells:
                reserved_cells.append(first_cell)

    if reserved_cells.is_empty():
        _grid.clear_reservation(self)
        return true

    return _grid.reserve_cells_with_active_steps(self, reserved_cells, _reservation_is_attack, active_cells)

# == Setup helpers =============================================================

var _fsm_debug_label: Label


func _init_debug_fsm_state() -> void:
    if _state_machine == null:
        return
    if not _state_machine.state_changed.is_connected(_on_fsm_state_changed):
        _state_machine.state_changed.connect(_on_fsm_state_changed)
    if not Debug.toggled.is_connected(_on_debug_mode_toggled):
        Debug.toggled.connect(_on_debug_mode_toggled)
    if Debug.enabled:
        _ensure_fsm_label()
        _sync_fsm_label.call_deferred()


func _on_debug_mode_toggled(enabled: bool) -> void:
    if enabled:
        _ensure_fsm_label()
        _sync_fsm_label.call_deferred()
    elif _fsm_debug_label != null:
        _fsm_debug_label.visible = false


func _ensure_fsm_label() -> void:
    if _fsm_debug_label != null:
        _fsm_debug_label.visible = true
        return
    _fsm_debug_label = Label.new()
    _fsm_debug_label.name = "FsmStateDebugLabel"
    _fsm_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _fsm_debug_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
    _fsm_debug_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
    _fsm_debug_label.add_theme_constant_override("shadow_outline_size", 1)
    _fsm_debug_label.position = Vector2(0.0, 0.0)
    # node-src: debug
    add_child(_fsm_debug_label)


func _sync_fsm_label() -> void:
    if _fsm_debug_label == null or _state_machine == null:
        return
    if _state_machine.current_state != null:
        _fsm_debug_label.text = _state_machine.current_state.name


func _on_fsm_state_changed(_from: State, to: State) -> void:
    if _fsm_debug_label != null:
        _fsm_debug_label.text = to.name


## Falls back to a by-name lookup for any node reference left unassigned in the
## scene's @export slots, and warns so the scene can be rewired to set it directly.
func _resolve_node_references() -> void:
    _state_machine = _fallback_node(_state_machine, "StateMachine") as StateMachine
    _guard = _fallback_node(_guard, "Guard") as Guard
    _status_bars = _fallback_node(_status_bars, "StatusBars") as EnemyStatusBars
    hurtbox = _fallback_node(hurtbox, "Hurtbox") as Hurtbox
    _body = _fallback_node(_body, "Body") as Polygon2D
    _facing_arrow = _fallback_node(_facing_arrow, "FacingArrow") as Polygon2D


func _fallback_node(assigned: Node, node_name: StringName) -> Node:
    if assigned != null:
        return assigned
    # node-ref: allow - fallback for enemy scenes not yet wired to the matching @export slot
    var found := find_child(str(node_name), false, false)
    if found != null:
        ToastManager.show_dev_error("%s: %s not wired to its @export slot; using name-based fallback." % [name, node_name])
    return found

# == Tick combat and detonation ================================================


## Per-kind detonation when the telegraph countdown reaches zero. The base resolves a single
## cell-membership check against the player and hands off to recovery. Charge/puff kinds override.
func _tick_detonate() -> void:
    _resolve_detonation_on_player(_attack_tiles)
    finish_attack_into_recovery()


## Damages the player when their cell is inside the given locked tiles, then notifies presentation.
## This cell-membership check replaces enemy-side physics hitbox overlap for enemy-to-player damage.
func _resolve_detonation_on_player(tiles: Array[Vector2i]) -> void:
    if _tick_engine == null:
        return
    if _tick_engine.player_cell() in tiles:
        _tick_engine.damage_player(get_attack_hit_damage(), self)
    _tick_engine.notify_detonation(tiles)


## Clears the kind's telegraph presentation for a resolved or cancelled attack. Kinds override.
func _clear_attack_presentation() -> void:
    pass


## Pure hit resolution shared by predict_hit(), take_hit(), and the physics _on_hit_received() path,
## so a preview, a tick commit, and a real-time overlap all agree on angle, guard, and lethality.
func _resolve_hit_outcome(src_pos: Vector2, base_damage: float, is_dash: bool) -> Dictionary:
    var outcome := {
        "angle": DirectionResolver.HitAngle.NONE,
        "staggered": false,
        "guard_broken": false,
        "killed": false,
        "hp_damage": 0.0,
        "guard_damage": 0,
    }
    if not is_alive():
        return outcome

    var angle := DirectionResolver.resolve(src_pos, global_position, _facing)
    var profile := Hitbox.GuardDamageProfile.DASH if is_dash else Hitbox.GuardDamageProfile.NORMAL
    var guard_damage := _resolve_guard_damage(angle, profile)
    var already_staggered := _guard != null and _guard.is_staggered()
    var will_break_guard := _guard != null and not already_staggered and _guard.current() > 0 and guard_damage >= _guard.current()
    var full_damage := _guard == null or already_staggered or will_break_guard
    var hp_damage := base_damage if full_damage else base_damage * GUARDED_DAMAGE_MULTIPLIER
    hp_damage = _apply_defense(hp_damage)

    outcome["angle"] = angle
    outcome["staggered"] = already_staggered
    outcome["guard_broken"] = will_break_guard
    outcome["hp_damage"] = hp_damage
    outcome["guard_damage"] = guard_damage
    var remaining := (health.current() - hp_damage) if health != null else 0.0
    outcome["killed"] = remaining <= 0.0
    return outcome


## Plays the established damaged/blocked SFX and guard-break/shield/full-damage VFX for a resolved hit.
func _apply_hit_feedback(outcome: Dictionary, src_pos: Vector2) -> void:
    var angle := int(outcome["angle"])
    var full_damage := _guard == null or bool(outcome["staggered"]) or bool(outcome["guard_broken"])
    var sfx_event := damaged_sfx_event if full_damage else _get_blocked_hit_sfx(angle)
    if sfx_event != null:
        AudioManager.play_event(sfx_event, global_position)

    if bool(outcome["guard_broken"]):
        CombatFeedbackVFX.play_guard_break(global_position, self)
    elif full_damage:
        CombatFeedbackVFX.play_full_damage(global_position, self)
    else:
        CombatFeedbackVFX.play_shielded_hit(global_position, src_pos.angle_to_point(global_position), self)


func _resolve_guard_damage(angle: int, guard_damage_profile: int) -> int:
    if guard_damage_profile == Hitbox.GuardDamageProfile.DASH:
        return DirectionResolver.dash_guard_damage(angle)
    return DirectionResolver.normal_guard_damage(angle)


## Reduces incoming hp damage by this enemy's flat wave-scaling defense using
## effective = amount * (amount / (amount + defense)). No-op at defense 0.
func _apply_defense(amount: float) -> float:
    if _defense <= 0.0:
        return amount
    return amount * (amount / (amount + _defense))


func _get_blocked_hit_sfx(angle: int) -> SpatialAudioEvent:
    return damaged_sfx_event if angle == DirectionResolver.HitAngle.BACK else blocked_sfx_event


func _start_stagger_vfx() -> void:
    if _body != null:
        if _stagger_tween != null and is_instance_valid(_stagger_tween):
            _stagger_tween.kill()
        _stagger_tween = create_tween()
        _stagger_tween.tween_property(_body, "modulate", STAGGER_VFX_COLOR, 0.2)


func _after_setup_ready() -> void:
    pass


func _on_guard_broken_extra() -> void:
    pass


func _on_begin_death_extra() -> void:
    pass


func _reset_extra() -> void:
    pass


## Enemy.gd override point, fired once from Health.died via _on_health_died().
## Requests the dead-state transition; begin_death(), the death sfx, and the
## death tween all live in EnemyDeadState._enter(), not here.
func _on_death_effects() -> void:
    var dead_state_id := get_dead_state_id()
    if _state_machine != null and dead_state_id >= 0:
        _state_machine.request_transition(dead_state_id, true)
