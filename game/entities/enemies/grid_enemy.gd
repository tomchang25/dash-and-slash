# grid_enemy.gd
# Shared base for 1x1 grid enemies with target chasing, guard, stagger, and death handling.
# When bound to a TickEngine (bind_tick_engine), the enemy is clocked by discrete world ticks:
# the engine calls resolve_detonation() / advance_status() / act_tick() each world advance, movement
# snaps one cell per action, telegraph and recovery windows count in ticks, enemy-to-player damage
# resolves as a cell-membership check at detonation, and player-to-enemy damage arrives through
# take_hit() / predict_hit() instead of physics hurtbox overlap.
class_name GridEnemy
extends Enemy

const CARDINAL_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const NO_BLOCKED_CELL := Vector2i(-1, -1)
## Energy-skeleton default: 100 = one action per world tick. Slower kinds skip beats; see get_tick_speed().
const DEFAULT_TICK_SPEED := 100
const DEFAULT_WARNING_TICKS := 2
const DEFAULT_RECOVERY_TICKS := 1
## Visual-only slide time for a one-cell tick snap; the logical cell moves instantly.
const TICK_MOVE_TWEEN_SEC := 0.14
const STAGGER_VFX_COLOR := Color(0.3, 0.5, 1.0, 1.0)
const PATH_DEBUG_COLOR := Color(0.2, 0.8, 1.0, 0.8)
const PATH_DEBUG_WIDTH := 4.0

# -- Exports --

@export var death_sfx_event: SpatialAudioEvent
@export var damaged_sfx_event: SpatialAudioEvent
@export var blocked_sfx_event: SpatialAudioEvent
## Ordinary Guard Break's dedicated Result SFX, replacing the generic damaged event for a GUARD_BREAK
## outcome; see _select_result_sfx_event(). Generic across all base enemy kinds, not a Dash-only Major.
@export var guard_break_sfx_event: SpatialAudioEvent
@export var enemy_data: EnemyData

# -- State --

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
## Final level, recorded by apply_level_projection(). Read by the debug FSM label only.
var _level := 1
## Level projection recorded by apply_level_projection() (called pre-ready by the spawner) and
## applied from _ready() once _initialize_from_enemy_data() has set up Health/Guard from EnemyData.
var _pending_projection: EnemyLevelProjection = null
var _has_pending_projection := false
var _fsm_debug_label: Label
## One-shot Result SFX queued by a resolved KILL's take_hit(), consumed and cleared by
## play_death_sfx(). Cleared without consumption when the predicted kill did not actually reduce
## health to zero (invulnerability, debug No-Damage/Undead), so it can never leak into a later force
## or debug death.
var _queued_death_sfx_event: SpatialAudioEvent = null

# -- Tick state --

## Set by bind_tick_engine(); non-null means this enemy is clocked by the tick engine.
var _tick_engine = null
## Owns this enemy's clocked combat status: committed attack tiles, detonation countdown, recovery window.
var _tick_runtime := EnemyTickRuntime.new()

# -- Timer / tween handles --

var _stagger_tween: Tween
var _hurt_tween: Tween
var _tick_move_tween: Tween

# -- Node references --

@export var _state_machine: StateMachine
@export var _guard: Guard
@export var _status_bars: EnemyStatusBars
@export var _body: Polygon2D
@export var _facing_arrow: Polygon2D
## Optional sprite-based presenter; when wired, feedback prefers it over _body/_facing_arrow.
@export var _visual_presenter: EnemyVisualPresenter

# == Lifecycle ==


func _ready() -> void:
    _resolve_node_references()
    _initialize_from_enemy_data()
    _apply_pending_projection()
    super()
    if _grid != null:
        _grid_pos = _grid.world_to_grid(global_position)
        register_grid_occupant()
        _grid.register_enemy_entity(self)
        if not _grid.reservation_lost.is_connected(_on_reservation_lost):
            _grid.reservation_lost.connect(_on_reservation_lost)

    if health != null:
        health.damaged.connect(_on_damaged)
        _on_health_changed(health.current(), health.max_health)

    if _guard != null:
        _guard.guard_changed.connect(_on_guard_changed)
        _guard.guard_broken.connect(_on_guard_broken)
        _guard.stagger_started.connect(_on_stagger_started)
        _guard.stagger_ended.connect(_on_stagger_ended)
        _on_guard_changed(_guard.current(), _guard.max_guard)

    face_arrow()
    _init_debug_fsm_state()


func _draw() -> void:
    if _grid == null:
        return

    var next_move := _next_debug_move_cell()
    if next_move == NO_BLOCKED_CELL:
        return

    var start_point := to_local(_grid.cell_center(_grid_pos))
    var next_point := to_local(_grid.cell_center(next_move))
    draw_line(start_point, next_point, PATH_DEBUG_COLOR, PATH_DEBUG_WIDTH)
    draw_circle(next_point, PATH_DEBUG_WIDTH * 1.5, PATH_DEBUG_COLOR)

# == Overridden Custom Methods ==


func reset() -> void:
    super()
    _staggered = false
    stop_attack_windup_vfx()
    if _body != null:
        _body.modulate = Color.WHITE
    if _visual_presenter != null:
        _visual_presenter.reset_visuals()
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

# == Signal handlers ==


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
    _tick_engine.clear_energy(self)
    cancel_tick_attack()
    _tick_runtime.clear_recovery()
    _on_guard_broken_extra()
    var staggered_state_id := get_staggered_state_id()
    if _state_machine != null and staggered_state_id >= 0:
        _state_machine.request_transition(staggered_state_id, true)


func _on_guard_changed(current: int, maximum: int) -> void:
    if _status_bars != null:
        _status_bars.set_guard(current, maximum)


## Restores the idle visual after a tick-move slide finishes, unless a higher-priority
## state (a committed attack, stagger, or death) took over while the slide was playing.
func _on_tick_move_finished_visual() -> void:
    if _visual_presenter == null:
        return
    if _tick_runtime.has_pending_attack() or _staggered or not is_alive():
        return
    _visual_presenter.show_idle()


func _on_health_changed(current: float, maximum: float) -> void:
    super(current, maximum)
    if _status_bars != null:
        _status_bars.set_health(current, maximum)


func _on_damaged(_amount: float, _source: Node) -> void:
    if _visual_presenter != null:
        _visual_presenter.flash_damage()
        return
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


func _on_stagger_started() -> void:
    _staggered = true
    if _visual_presenter != null:
        _visual_presenter.set_staggered(true)
        return
    if _hurt_tween != null and _hurt_tween.is_valid():
        return
    _start_stagger_vfx()


func _on_stagger_ended() -> void:
    _staggered = false
    if _visual_presenter != null:
        _visual_presenter.set_staggered(false)
        return
    if _body != null:
        if _stagger_tween != null and is_instance_valid(_stagger_tween):
            _stagger_tween.kill()
        _stagger_tween = create_tween()
        _stagger_tween.tween_property(_body, "modulate", Color.WHITE, 0.3)

# == Common API ==


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

# == Tick actor contract ==

# Called by the TickEngine each world advance. The engine owns the resolution order
# (detonations first, then status, then energy-funded actions); the enemy owns its
# own behavior within those hooks.


## Binds this enemy to the scene tick engine, switching it from physics/frame clocking to tick clocking.
func bind_tick_engine(engine) -> void:
    _tick_engine = engine
    # Refresh the debug readout each world tick so the telegraph/recovery countdown updates while the
    # machine sits parked in its deciding state (those windows no longer drive state-change signals).
    if engine != null and not engine.world_advanced.is_connected(_on_world_advanced_debug):
        engine.world_advanced.connect(_on_world_advanced_debug)


func is_alive() -> bool:
    return health != null and health.is_alive()


## Per-kind energy-skeleton speed read by the engine; 100 = one action per world tick.
## Slower kinds skip beats so pursuit leaks distance and flanking windows open. Overridden per kind.
func get_tick_speed() -> int:
    return DEFAULT_TICK_SPEED


## Engine stage-2 hook: counts the committed telegraph down by one player action and detonates at zero.
func resolve_detonation() -> void:
    if not _tick_runtime.has_pending_attack():
        return
    var remaining := _tick_runtime.step_attack_countdown()
    if remaining == 1:
        # Last player action before impact: escalate the telegraph to the charge phase.
        show_attack_charge()
    if remaining > 0:
        return
    _tick_detonate()


## Engine stage-3a hook: counts the stagger and recovery windows down in world ticks. Returns true while the
## enemy is disabled this tick, so the engine neither funds an action nor lets it bank energy (no banked surprise).
func advance_status() -> bool:
    if _guard != null and _guard.is_staggered():
        _guard.advance_stagger()
        return true
    return _tick_runtime.advance_recovery()


## Engine stage-3b hook: spends one funded action. A committed telegraph freezes the enemy until it detonates.
func act_tick() -> void:
    if _tick_runtime.has_pending_attack():
        return
    if _state_machine != null:
        _state_machine.advance_tick()


## Returns the current danger display data ({cells, ticks}), or an empty dictionary when no attack is pending.
func get_danger() -> Dictionary:
    return _tick_runtime.danger()


## The committed attack's locked footprint tiles (live reference); kinds read this at detonation.
func get_attack_tiles() -> Array[Vector2i]:
    return _tick_runtime.attack_tiles()


## Predicts one player hit without mutating state, sharing math with take_hit() so a preview
## can never disagree with the resolved hit. Origin is the attacker's cell (player or dash origin).
## guard_shredder_trigger and execution_trigger are the mobility-slot-triggered Major hooks; callers
## pass true only for an actual mobility-slot strike (Dash or Smash) whose run build has that trigger active.
## Returns a TickHitOutcome with fields angle, was_guarded, stagger_burst, guard_broken, killed, hp_damage, guard_damage, feedback_kind, major_trigger.
func predict_hit(
        origin_cell: Vector2i,
        base_damage: float,
        guard_shredder_trigger := false,
        execution_trigger := false,
        stagger_burst_multiplier := TickCombatRules.STAGGER_ATTACK_MULTIPLIER,
) -> TickHitOutcome:
    return _resolve_tick_hit_outcome(origin_cell, base_damage, guard_shredder_trigger, execution_trigger, stagger_burst_multiplier)


## Applies one player hit from the given origin cell, reusing the established guard/health/feedback
## seams (single Result SFX selection, guard-break/shield/full-damage VFX), and returns the same
## outcome as predict_hit(). A guard break clears banked energy via _on_guard_broken().
## sfx_context carries the Dash/Smash mobility-kill, Guard Shredder, and Execution event overrides for
## this committed hit; a normal attack passes none, so every branch stays on its generic enemy-owned
## event. A resolved KILL never plays audio here — it queues the selected death event for the Dead
## state to consume instead; see _apply_hit_feedback() and play_death_sfx().
func take_hit(
        origin_cell: Vector2i,
        base_damage: float,
        guard_shredder_trigger := false,
        execution_trigger := false,
        stagger_burst_multiplier := TickCombatRules.STAGGER_ATTACK_MULTIPLIER,
        sfx_context: TickHitSfxContext = null,
) -> TickHitOutcome:
    var src_pos := _grid.cell_center(origin_cell) if _grid != null else Vector2.ZERO
    var outcome := _resolve_tick_hit_outcome(origin_cell, base_damage, guard_shredder_trigger, execution_trigger, stagger_burst_multiplier)
    if not is_alive():
        return outcome
    _apply_hit_feedback(outcome, src_pos, sfx_context)
    if health != null:
        health.take_damage(outcome.hp_damage, self)
    if health != null and not health.is_alive():
        return outcome
    # The predicted kill did not actually reduce health to zero (invulnerability, debug No-Damage or
    # Undead), so drop the queued override before it can leak into a later force or debug death.
    _queued_death_sfx_event = null
    if _guard != null and outcome.guard_damage > 0:
        _guard.take_guard_damage(outcome.guard_damage)
    return outcome


## Commits an attack telegraph clocked in ticks: locks the footprint tiles and starts the countdown.
## Returns false when the kind could not prepare the attack.
func begin_tick_telegraph() -> bool:
    if not begin_attack_telegraph():
        return false
    var cells := get_committed_attack_cells()
    if cells.is_empty():
        return false
    _tick_runtime.commit_attack(cells, get_warning_tick_count())
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
    _tick_move_tween.tween_property(self, "global_position", _grid.cell_center(target_cell), TICK_MOVE_TWEEN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _tick_move_tween.tween_property(self, "scale", Vector2.ONE, TICK_MOVE_TWEEN_SEC * 1.5)
    if _visual_presenter != null:
        _visual_presenter.show_move()
        _tick_move_tween.finished.connect(_on_tick_move_finished_visual, CONNECT_ONE_SHOT)


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
    if not _tick_engine.is_cell_open_for_enemy(next, self):
        # The player (not a grid occupant) or another actor moved onto the reserved cell since planning.
        clear_planned_path()
        return false
    _planned_path.remove_at(0)
    _has_active_path_cell = false
    _facing = cardinal_snap(Vector2(next - _grid_pos))
    face_arrow()
    tick_snap_to_cell(next)
    _refresh_planned_reservations()
    queue_redraw()
    return true


## Clears a committed but undetonated attack: drops the locked tiles, the countdown, and its telegraph.
func cancel_tick_attack() -> void:
    _tick_runtime.clear_attack()
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
## Kinds reuse this from _tick_detonate(). The machine is already parked in Idle (the deciding state
## returned there on commit), so no transition is needed here. The +1 absorbs the extra hand-off tick
## the former Recovery state spent transitioning back to Idle, keeping post-attack timing unchanged.
func finish_attack_into_recovery() -> void:
    _tick_runtime.clear_attack()
    _clear_attack_presentation()
    _tick_runtime.begin_recovery(get_recovery_tick_count() + 1)


## Records this enemy's final level and projected stats without touching Health/Guard yet. The wave
## controller calls this pre-ready (before EnemyData has initialized Health/Guard's authored bases
## via _initialize_from_enemy_data()), so it is applied later from _ready() instead; see
## _apply_pending_projection(). Leaves enemy_data and attack data untouched.
func apply_level_projection(level: int, projection: EnemyLevelProjection) -> void:
    _level = level
    _pending_projection = projection
    _has_pending_projection = true


## Returns this enemy's current outgoing-damage multiplier from its level projection.
func get_damage_multiplier() -> float:
    return _damage_multiplier


## Returns this enemy's current flat Defense value, from its level projection (or EnemyData's
## authored base when no projection was ever applied). Consumed by TickHitResolver.apply_defense().
func get_defense() -> float:
    return _defense


## Returns this enemy's final level, or 1 when no level projection was ever applied.
func get_level() -> int:
    return _level


func has_target() -> bool:
    return is_instance_valid(_target)


func get_target() -> Node2D:
    return _target


## Returns the target's current grid cell, or NO_BLOCKED_CELL when unavailable. Reads the engine's
## logical player cell so planning never lags the player's move tween by a frame.
func get_target_cell() -> Vector2i:
    if _grid == null or not has_target():
        return NO_BLOCKED_CELL
    return _tick_engine.player_cell()


func set_target(target: Node2D) -> void:
    _target = target


func is_staggered() -> bool:
    return _staggered


func set_staggered(value: bool) -> void:
    _staggered = value


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

    var path := EnemyPathPlanner.find_path_to_best_reachable_cell(
        _grid,
        self,
        _get_movement_directions(),
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


func cardinal_snap(v: Vector2) -> Vector2:
    if abs(v.x) > abs(v.y):
        return Vector2(sign(v.x), 0.0)
    return Vector2(0.0, sign(v.y))


func _next_debug_move_cell() -> Vector2i:
    if _has_active_path_cell:
        return _active_path_cell
    if _planned_path.is_empty():
        return NO_BLOCKED_CELL
    return _planned_path[0]


func face_arrow() -> void:
    if _facing_arrow != null:
        _facing_arrow.rotation = _facing.angle() - PI / 2.0
    if _body != null:
        _body.rotation = _facing.angle() + PI / 2.0
    if _visual_presenter != null:
        _visual_presenter.set_facing(_facing)


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


## Force-death entry point for boss wave resolution. Zeroes hp through Health,
## which fires the same Health.died path combat damage and debug instant-kill
## use, so death effects run through _on_death_effects() exactly once
## regardless of entry point.
func force_death() -> void:
    if health != null:
        health.kill()


## Plays this enemy's single death Result SFX: a queued override selected by a resolved KILL take_hit()
## (Execution's event, or Dash/Smash's mobility-kill event), falling back to this enemy's authored
## death_sfx_event when no override was queued. Always consumes and clears the queue first, including
## when it is empty, so force_death() and a later debug death never replay a stale override from an
## earlier prevented kill.
func play_death_sfx() -> void:
    var event := _consume_queued_death_sfx_event()
    if event != null:
        AudioManager.play_event(event, global_position)


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


## True when the enemy should commit an attack instead of planning movement this decision tick.
func should_commit_before_plan() -> bool:
    return false


## True when the enemy should commit an attack the moment it arrives at a stepped cell (current facing).
func should_commit_on_arrival() -> bool:
    return false


## True when the enemy should commit an attack right after turning one capped step toward the target.
func should_commit_after_face() -> bool:
    return false


## Commits this kind's attack telegraph and starts its tick countdown. Returns false when it could not
## be prepared. Kinds with a non-telegraph commit (the puff zone windup) override this.
func try_commit_attack() -> bool:
    return begin_tick_telegraph()


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
    var cells := get_unblocked_charge_cells(origin_cell, facing, attack_data)
    return target_cell in cells


## Returns the terrain-unblocked charge line. Occupied actors are pass-through for the path, but not legal landing cells.
func get_unblocked_charge_cells(origin_cell: Vector2i, facing: Vector2, attack_data: EnemyAttackData) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    if _grid == null or attack_data == null:
        return cells

    var raw_cells := EnemyAttackController.get_attack_cells(origin_cell, facing, attack_data, _grid)
    for cell: Vector2i in raw_cells:
        cells.append(cell)
    return cells


## Returns the farthest legal charge landing cell along the path. Player and enemies are pass-through blockers for landing only.
func get_charge_landing_cell(tiles: Array[Vector2i]) -> Vector2i:
    var dest := _grid_pos
    for line_cell: Vector2i in tiles:
        if _is_charge_landing_cell_open(line_cell):
            dest = line_cell
    return dest


## Performs shared setup when an enemy commits to a non-reposition action.
func begin_committed_action() -> bool:
    clear_planned_path()
    return true


## Default attack telegraph entry; enemies with telegraphs extend this setup.
func begin_attack_telegraph() -> bool:
    return begin_committed_action()


## Shows the charge telegraph phase. Enemies with telegraphs extend this.
func show_attack_charge() -> void:
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


## Ends the active charge-dash phase, used as defensive cleanup on guard break and reset.
## Enemies without a charge attack need not override this.
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

    var path := EnemyPathPlanner.find_path_to_cell(_grid, self, _get_movement_directions(), start, target_cell, charge_origins, false)
    if path.is_empty():
        return plan_approach_action()

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return plan_approach_action()
    queue_redraw()
    return true


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
        if origin_cell != start and not EnemyPathPlanner.can_plan_goal_cell(_grid, self, origin_cell, true):
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

    var path := EnemyPathPlanner.find_path_to_cell(_grid, self, _get_movement_directions(), start, target_cell, attack_origins, true)
    if path.is_empty():
        return false

    _planned_path = path
    if not _refresh_planned_reservations():
        clear_planned_path()
        return false
    queue_redraw()
    return true

# == Grid helpers ==


func _get_movement_directions() -> Array:
    return CARDINAL_DIRECTIONS


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
        if origin_cell != start and not EnemyPathPlanner.can_plan_goal_cell(_grid, self, origin_cell, false):
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


func _is_charge_landing_cell_open(cell: Vector2i) -> bool:
    if _grid == null or not _grid.is_land(cell):
        return false
    if _tick_engine.player_cell() == cell:
        return false
    var enemy: GridEnemy = _tick_engine.enemy_at(cell)
    return enemy == null or enemy == self


func _update_grid_pos() -> void:
    var new_cell := _grid.world_to_grid(global_position)
    if new_cell != _grid_pos:
        _grid_pos = new_cell
        register_grid_occupant()


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

# == Setup helpers ==


## Configures Health/Guard/Defense from this enemy's authored EnemyData. Runs once from _ready(),
## before Enemy._ready()'s health snapshot, so downstream signal listeners see the final authored
## bases rather than Health/Guard's own component defaults. Missing EnemyData reports a development
## error and leaves Health/Guard at those component defaults instead of silently trusting bad data.
func _initialize_from_enemy_data() -> void:
    if enemy_data == null:
        ToastManager.show_dev_error("GridEnemy: %s missing enemy_data; using component defaults" % name)
        return
    if health != null:
        health.initialize(enemy_data.max_health)
    if _guard != null:
        _guard.initialize(enemy_data.max_guard)
    _defense = enemy_data.defense


## Applies the level projection recorded by apply_level_projection(), once
## _initialize_from_enemy_data() has set up Health/Guard's authored bases. No-op when
## apply_level_projection() was never called pre-ready (e.g. direct instantiation in tests), which
## leaves Level 1 identity stats from the authored EnemyData in place.
func _apply_pending_projection() -> void:
    if not _has_pending_projection or _pending_projection == null:
        return
    _damage_multiplier = _pending_projection.damage_multiplier
    _defense = _pending_projection.defense
    if health != null:
        health.initialize(_pending_projection.max_health)
    if _guard != null:
        _guard.initialize(_pending_projection.max_guard)


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
    if _fsm_debug_label == null:
        return
    _fsm_debug_label.text = _fsm_status_text()


func _on_fsm_state_changed(_from: State, _to: State) -> void:
    if _fsm_debug_label != null:
        _fsm_debug_label.text = _fsm_status_text()


func _on_world_advanced_debug(_tick_count: int) -> void:
    if _fsm_debug_label != null and _fsm_debug_label.visible:
        _fsm_debug_label.text = _fsm_status_text()


## Debug readout text: prefixed with the enemy's final level, then the runtime's clocked status
## (telegraph countdown, then recovery), which takes priority over the parked state name since the
## machine now sits in its deciding state while those windows run.
func _fsm_status_text() -> String:
    return "Lv.%d %s" % [_level, _fsm_state_status_text()]


func _fsm_state_status_text() -> String:
    if _tick_runtime.has_pending_attack():
        return "Telegraph(%d)" % _tick_runtime.attack_ticks()
    if _tick_runtime.recovery_remaining() > 0:
        return "Recovery(%d)" % _tick_runtime.recovery_remaining()
    if _state_machine != null and _state_machine.current_state != null:
        return _state_machine.current_state.name
    return ""


## Falls back to a by-name lookup for any node reference left unassigned in the
## scene's @export slots, and warns so the scene can be rewired to set it directly.
func _resolve_node_references() -> void:
    _state_machine = _fallback_node(_state_machine, "StateMachine") as StateMachine
    _guard = _fallback_node(_guard, "Guard") as Guard
    _status_bars = _fallback_node(_status_bars, "StatusBars") as EnemyStatusBars
    _body = _fallback_node(_body, "Body") as Polygon2D
    _facing_arrow = _fallback_node(_facing_arrow, "FacingArrow") as Polygon2D
    _visual_presenter = _fallback_node(_visual_presenter, "VisualPresenter") as EnemyVisualPresenter
    if _visual_presenter != null and not _visual_presenter.has_valid_texture():
        # The presenter already reported the missing texture; degrade to the legacy body instead
        # of presenting a blank sprite.
        _visual_presenter = null
        if _body != null:
            _body.visible = true


func _fallback_node(assigned: Node, node_name: StringName) -> Node:
    if assigned != null:
        return assigned
    # node-ref: allow - fallback for enemy scenes not yet wired to the matching @export slot
    var found := find_child(str(node_name), false, false)
    if found != null:
        ToastManager.show_dev_error("%s: %s not wired to its @export slot; using name-based fallback." % [name, node_name])
    return found

# == Tick combat and detonation ==


## Per-kind detonation when the telegraph countdown reaches zero. The base resolves a single
## cell-membership check against the player and hands off to recovery. Charge/puff kinds override.
func _tick_detonate() -> void:
    _resolve_detonation_on_player(get_attack_tiles())
    finish_attack_into_recovery()


## Damages the player when their cell is inside the given locked tiles, then notifies presentation.
## This cell-membership check replaces enemy-side physics hitbox overlap for enemy-to-player damage.
func _resolve_detonation_on_player(tiles: Array[Vector2i]) -> void:
    if _tick_engine.player_cell() in tiles:
        _tick_engine.damage_player(get_attack_hit_damage(), self)
    _tick_engine.notify_detonation(tiles)


## Clears the kind's telegraph presentation for a resolved or cancelled attack. Kinds override.
func _clear_attack_presentation() -> void:
    pass


## Pure tick-grid hit resolution shared by predict_hit() and take_hit(); this is the authoritative path for previews and committed tick verbs.
func _resolve_tick_hit_outcome(
        origin_cell: Vector2i,
        base_damage: float,
        guard_shredder_trigger := false,
        execution_trigger := false,
        stagger_burst_multiplier := TickCombatRules.STAGGER_ATTACK_MULTIPLIER,
) -> TickHitOutcome:
    if not is_alive():
        return TickHitResolver.empty_outcome()

    return TickHitResolver.resolve_hit(
        origin_cell,
        _target_snapshot(),
        base_damage,
        -1,
        guard_shredder_trigger,
        execution_trigger,
        stagger_burst_multiplier,
    )


func _target_snapshot() -> Dictionary:
    return {
        "cell": _grid_pos,
        "facing": _facing_as_cell_dir(),
        "has_guard": _guard != null,
        "guard_current": _guard.current() if _guard != null else 0,
        "guard_max": _guard.max_guard if _guard != null else 0,
        "staggered": _guard.is_staggered() if _guard != null else false,
        "hp": health.current() if health != null else 0.0,
        "hp_max": health.max_health if health != null else 0.0,
        "defense": _defense,
        "alive": is_alive(),
    }


func _facing_as_cell_dir() -> Vector2i:
    if _facing == Vector2.ZERO:
        return Vector2i.ZERO
    return TickCombatRules.dominant_direction(Vector2i(roundi(_facing.x), roundi(_facing.y)))


## Plays the single selected Result SFX and the established guard-break/shield/full-damage VFX for a
## resolved hit. A KILL queues its selected death event instead of playing it immediately, since the
## Dead state fires synchronously inside health.take_damage() below and is the only caller allowed to
## play death audio; see _select_result_sfx_event() for the full priority table.
func _apply_hit_feedback(outcome: TickHitOutcome, src_pos: Vector2, sfx_context: TickHitSfxContext = null) -> void:
    if outcome.feedback_kind == TickHitOutcome.FeedbackKind.WHIFF:
        return
    var result_event := _select_result_sfx_event(outcome, sfx_context)
    if outcome.killed:
        _queued_death_sfx_event = result_event
    elif result_event != null:
        AudioManager.play_event(result_event, global_position)
    match outcome.feedback_kind:
        TickHitOutcome.FeedbackKind.BLOCKED:
            CombatFeedbackVFX.play_shielded_hit(global_position, src_pos.angle_to_point(global_position), self)
        TickHitOutcome.FeedbackKind.GUARD_BREAK:
            CombatFeedbackVFX.play_guard_break(global_position, self)
        TickHitOutcome.FeedbackKind.STAGGER_BURST, TickHitOutcome.FeedbackKind.KILL, TickHitOutcome.FeedbackKind.DAMAGED:
            CombatFeedbackVFX.play_full_damage(global_position, self)
        _:
            ToastManager.show_dev_error("GridEnemy: unexpected feedback kind %s" % outcome.feedback_kind)


## Selects the single Result SFX for a resolved (non-whiff) hit. KILL selects Execution's event when
## the outcome's Major trigger is EXECUTION, else the mobility-kill event from a Dash/Smash sfx_context,
## else null so play_death_sfx() falls back to this enemy's authored death event. GUARD_BREAK selects
## the Guard Shredder event when the Major trigger is GUARD_SHREDDER, else the generic Guard Break
## event. STAGGER_BURST and ordinary DAMAGED share the generic damaged event. BLOCKED keeps the
## existing angle-based blocked/damaged split. A missing special event falls through to the next
## applicable event; a missing generic event remains silent. Exposed as its own pure selection so tests
## can cover which event gets chosen without touching AudioManager playback.
func _select_result_sfx_event(outcome: TickHitOutcome, sfx_context: TickHitSfxContext) -> SpatialAudioEvent:
    match outcome.feedback_kind:
        TickHitOutcome.FeedbackKind.BLOCKED:
            return _get_blocked_hit_sfx(outcome.angle)
        TickHitOutcome.FeedbackKind.GUARD_BREAK:
            if outcome.major_trigger == TickHitOutcome.MajorTrigger.GUARD_SHREDDER and sfx_context != null and sfx_context.guard_shredder_event != null:
                return sfx_context.guard_shredder_event
            return guard_break_sfx_event
        TickHitOutcome.FeedbackKind.STAGGER_BURST, TickHitOutcome.FeedbackKind.DAMAGED:
            return damaged_sfx_event
        TickHitOutcome.FeedbackKind.KILL:
            if outcome.major_trigger == TickHitOutcome.MajorTrigger.EXECUTION and sfx_context != null and sfx_context.execution_event != null:
                return sfx_context.execution_event
            if sfx_context != null and sfx_context.mobility_kill_event != null:
                return sfx_context.mobility_kill_event
            return null
    return null


## Consumes and clears the queued death Result SFX, falling back to death_sfx_event when nothing was
## queued. Always clears the queue, including when it is already empty, so a later force_death() or
## debug death can never replay a stale override from an earlier prevented kill. Exposed as its own
## pure step so tests can cover the queue lifecycle without going through AudioManager playback.
func _consume_queued_death_sfx_event() -> SpatialAudioEvent:
    var event := _queued_death_sfx_event if _queued_death_sfx_event != null else death_sfx_event
    _queued_death_sfx_event = null
    return event


func _get_blocked_hit_sfx(angle: TileDirectionResolver.HitAngle) -> SpatialAudioEvent:
    return damaged_sfx_event if angle == TileDirectionResolver.HitAngle.BACK else blocked_sfx_event


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
