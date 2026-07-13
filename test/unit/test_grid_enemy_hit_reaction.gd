# test_grid_enemy_hit_reaction.gd
# Covers GridEnemy's hit-triggered facing response: a surviving non-breaking hit outside a committed
# telegraph clears stale Reposition intent and queues exactly one pending FaceTarget action, consumed
# only when a funded act_tick() actually executes it (never on mere entry, so a Speed free action — no
# act_tick() at all — leaves it visibly still pending). Also covers the response's priority table: a
# committed telegraph, a Guard Break/Stagger, and death all suppress it; repeat hits before any action
# add no extra turn or cost; a mid-recovery hit retains the response until the actor may act again
# and reset() clears a still-pending response.
extends GutTest

## Minimal tick-engine double exposing only what this test's paths read off _tick_engine:
## player_cell() for the shared facing math, and clear_energy() from a Guard Break. A world_advanced
## signal is declared so bind_tick_engine()'s debug-label connection has something to attach to.
class FakeTickEngine:
    extends RefCounted

    signal world_advanced(tick_count: int)

    var _target_cell: Vector2i


    func _init(target_cell: Vector2i) -> void:
        _target_cell = target_cell


    func player_cell() -> Vector2i:
        return _target_cell


    func clear_energy(_actor) -> void:
        pass


## Test double exposing the private tick-runtime seams under test (committing a fake telegraph,
## opening a recovery window) and the engine's own per-actor tick sequencing, so tests can drive one
## world tick without standing up a full TickEngine.
class TestGridEnemy:
    extends GridEnemy

    func wire_guard(guard: Guard) -> void:
        _guard = guard


    func wire_state_machine(machine: StateMachine) -> void:
        _state_machine = machine


    func commit_test_attack(ticks: int = 3) -> void:
        var cells: Array[Vector2i] = [Vector2i.ZERO]
        _tick_runtime.commit_attack(cells, ticks)


    func begin_test_recovery(ticks: int) -> void:
        _tick_runtime.begin_recovery(ticks)


    func has_pending_attack_test() -> bool:
        return _tick_runtime.has_pending_attack()


    func current_state_id() -> int:
        return _state_machine.current_state.state_id


    ## Mirrors TickEngine.advance_world()'s per-actor sequence for exactly one actor: detonation, then
    ## status (stagger/recovery gating), then a funded action only when status left it enabled this tick.
    func advance_one_world_tick() -> void:
        resolve_detonation()
        if advance_status():
            return
        act_tick()


func _make_grid(size: Vector2i) -> GridArena:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = size
    grid.starting_land_size = size
    grid.generate_grid()
    return grid


## Builds a fully wired GridEnemy test double: Health and Guard configured from a throwaway
## EnemyData/GuardProfile pair, and a real StateMachine with the production Idle/Reposition/FaceTarget/
## Staggered/Dead states as children, each owned by the enemy so their _ready() (which awaits
## owner.ready to resolve their typed entity reference) resolves the same way a packed scene's does.
func _make_enemy(grid: GridArena, start_cell: Vector2i, target_cell: Vector2i, base_guard: int, max_health: float) -> TestGridEnemy:
    var enemy: TestGridEnemy = TestGridEnemy.new()
    enemy.global_position = grid.cell_center(start_cell)

    var health := Health.new()
    enemy.add_child(health)
    health.owner = enemy
    enemy.health = health

    var guard := Guard.new()
    enemy.add_child(guard)
    guard.owner = enemy
    enemy.wire_guard(guard)

    var state_machine := StateMachine.new()
    state_machine.frame_driven = false
    enemy.add_child(state_machine)
    state_machine.owner = enemy

    var idle := EnemyIdleState.new()
    var reposition := EnemyRepositionState.new()
    var face := EnemyFaceOnceState.new()
    var staggered := EnemyStaggeredState.new()
    var dead := EnemyDeadState.new()
    for state: State in [idle, reposition, face, staggered, dead]:
        state_machine.add_child(state)
        state.owner = enemy
    state_machine.initial_state = idle
    enemy.wire_state_machine(state_machine)

    var guard_profile := GuardProfile.new()
    guard_profile.base_guard = base_guard
    var data := EnemyData.new()
    data.enemy_id = "test_hit_reaction"
    data.max_health = max_health
    data.guard_profile = guard_profile
    enemy.enemy_data = data

    var target: Node2D = autofree(Node2D.new())
    target.global_position = grid.cell_center(target_cell)

    add_child_autofree(enemy)

    enemy.bind_tick_engine(FakeTickEngine.new(target_cell))
    enemy.setup(grid, target)

    return enemy

# == Path cleanup ==


func test_non_breaking_hit_clears_a_reserved_path_before_queuing_the_response() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(0, 2), Vector2i(4, 2), 1000, 100.0)
    assert_true(enemy.plan_approach_action(), "the enemy should find a path toward a distant target")
    var reserved_cell := enemy.get_planned_path_first()
    assert_true(grid.is_reserved_by(reserved_cell, enemy), "planning should reserve the first step")

    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 5.0)

    assert_false(enemy.has_planned_path(), "a queued response must clear the stale planned path")
    assert_false(grid.is_reserved_by(reserved_cell, enemy), "the abandoned reservation must be released")
    assert_true(enemy.has_pending_hit_facing_response())
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.FACE_TARGET)


## A front-facing enemy has no capped turn to pay for. Its path and current decision state must survive
## the hit, otherwise FaceTarget consumes an empty action and leaves it parked in Idle.
func test_front_hit_preserves_the_existing_movement_intent() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(0, 2), Vector2i(4, 2), 1000, 100.0)
    assert_true(enemy.plan_approach_action())
    var reserved_cell := enemy.get_planned_path_first()
    enemy.tick_face_toward_target()
    assert_true(enemy.is_facing_target())

    enemy.take_hit(Vector2i(4, 2), 5.0)

    assert_false(enemy.has_pending_hit_facing_response())
    assert_true(enemy.has_planned_path(), "an already front-facing enemy must retain its current path")
    assert_true(grid.is_reserved_by(reserved_cell, enemy), "the existing reservation must remain claimed")
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.IDLE)

# == Priority: committed telegraph, Guard Break, death ==


func test_hit_during_a_committed_telegraph_never_queues_a_response() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(2, 2), Vector2i(4, 2), 1000, 100.0)
    enemy.commit_test_attack(3)

    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 5.0)

    assert_false(enemy.has_pending_hit_facing_response(), "a committed windup must stay immune to the response")
    assert_true(enemy.has_pending_attack_test(), "the telegraph itself must remain locked")
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.IDLE, "no transition should fire while a telegraph is committed")


func test_a_guard_breaking_hit_wins_priority_over_the_response() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(2, 2), Vector2i(4, 2), 1, 100.0)

    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 5.0)

    assert_true(enemy.is_staggered(), "a broken Guard must stagger the enemy")
    assert_false(enemy.has_pending_hit_facing_response(), "Stagger must suppress the facing response")
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.STAGGERED)


func test_a_killing_hit_never_queues_a_response() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(2, 2), Vector2i(4, 2), 1000, 1.0)

    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 50.0)

    assert_false(enemy.is_alive())
    assert_false(enemy.has_pending_hit_facing_response(), "a resolved death must never leave a response pending")
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.DEAD)

# == Repeat hits, free actions, and normal action order ==


func test_repeated_hits_before_any_action_cost_exactly_one_turn() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(2, 2), Vector2i(4, 2), 1000, 100.0)

    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 5.0)
    assert_true(enemy.has_pending_hit_facing_response())
    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 5.0)
    assert_true(enemy.has_pending_hit_facing_response(), "a second hit before any action must not clear the pending response")

    enemy.advance_one_world_tick()

    assert_eq(enemy.get_facing(), Vector2.RIGHT, "exactly one capped turn should have executed")
    assert_false(enemy.has_pending_hit_facing_response(), "the funded turn must consume the response")
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.IDLE)


func test_a_free_action_leaves_the_response_visibly_pending() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(2, 2), Vector2i(4, 2), 1000, 100.0)

    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 5.0)

    # A Speed-spent free action never reaches act_tick(), so simply not advancing the world here stands
    # in for it: the response must still be visibly pending and untouched afterward.
    assert_true(enemy.has_pending_hit_facing_response())
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.FACE_TARGET)
    assert_eq(enemy.get_facing(), Vector2.DOWN, "a free action must never itself execute the turn")

    enemy.advance_one_world_tick()

    assert_false(enemy.has_pending_hit_facing_response(), "the next funded action may finally execute it")
    assert_eq(enemy.get_facing(), Vector2.RIGHT)


func test_normal_action_order_turns_once_then_returns_to_idle() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(2, 2), Vector2i(4, 2), 1000, 100.0)
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.IDLE)

    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 5.0)
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.FACE_TARGET)

    enemy.advance_one_world_tick()

    assert_eq(enemy.get_facing(), Vector2.RIGHT)
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.IDLE, "FaceTarget hands back to Idle once its funded turn executes")

# == Recovery ==


func test_a_hit_during_recovery_retains_the_response_until_the_actor_may_act() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(2, 2), Vector2i(4, 2), 1000, 100.0)
    enemy.begin_test_recovery(1)

    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 5.0)
    assert_true(enemy.has_pending_hit_facing_response())
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.FACE_TARGET)

    enemy.advance_one_world_tick()
    assert_true(enemy.has_pending_hit_facing_response(), "the disabled recovery tick must not fund the turn")
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.FACE_TARGET, "no turn should have executed yet")

    enemy.advance_one_world_tick()
    assert_false(enemy.has_pending_hit_facing_response(), "the first tick the actor may act must execute the turn")
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.IDLE)

# == Reset ==


func test_reset_clears_a_still_pending_response() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var enemy := _make_enemy(grid, Vector2i(2, 2), Vector2i(4, 2), 1000, 100.0)
    enemy.take_hit(enemy.get_grid_pos() + Vector2i.UP, 5.0)
    assert_true(enemy.has_pending_hit_facing_response())

    enemy.reset()

    assert_false(enemy.has_pending_hit_facing_response(), "reset must never leave a stale response claimed as pending")
