# test_bomb_enemy_self_destruct.gd
# Covers BombEnemy's guardless self-destruct lifecycle: adjacent-ring commitment, the locked
# Manhattan-distance-four footprint snapshot, the three-tick countdown, early-death disarm, hit/miss
# detonation, self-death ordering through Health, and reset/presentation cleanup.
extends GutTest

## Minimal tick-engine double exposing the seams BombEnemy reads and writes: player_cell() for the
## commit/detonation checks, damage_player()/notify_detonation() recorded for assertions, and
## clear_energy() so bind_tick_engine()'s debug-label connection has a target.
class FakeTickEngine:
    extends RefCounted

    signal world_advanced(tick_count: int)

    var target_cell: Vector2i
    var damage_dealt := 0.0
    var damage_calls := 0
    var detonation_calls := 0
    var last_detonated_cells: Array[Vector2i] = []


    func _init(cell: Vector2i) -> void:
        target_cell = cell


    func player_cell() -> Vector2i:
        return target_cell


    func clear_energy(_actor) -> void:
        pass


    func damage_player(amount: float, _source: Node) -> void:
        damage_dealt += amount
        damage_calls += 1


    func emit_world_advanced(tick_count: int) -> void:
        world_advanced.emit(tick_count)


    func notify_detonation(cells: Array[Vector2i]) -> void:
        last_detonated_cells = cells
        detonation_calls += 1


## Test double exposing BombEnemy's private tick-runtime seams and mirroring TickEngine's real
## per-actor world-tick sequence: detonation only while alive (the engine's own is_alive() gate),
## then status, then a funded action only when status left the actor enabled this tick.
class TestBombEnemy:
    extends BombEnemy

    func wire_state_machine(machine: StateMachine) -> void:
        _state_machine = machine


    func has_pending_attack_test() -> bool:
        return _tick_runtime.has_pending_attack()


    func attack_ticks_test() -> int:
        return _tick_runtime.attack_ticks()


    func recovery_ticks_test() -> int:
        return _tick_runtime.recovery_remaining()


    func current_state_id() -> int:
        return _state_machine.current_state.state_id


    func fake_tick_engine() -> FakeTickEngine:
        return _tick_engine


    func advance_one_world_tick() -> void:
        if is_alive():
            resolve_detonation()
        if is_alive() and not advance_status():
            act_tick()
        fake_tick_engine().emit_world_advanced(0)


func _make_grid(size: Vector2i) -> GridArena:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = size
    grid.starting_land_size = size
    grid.generate_grid()
    return grid


## Builds a fully wired guardless BombEnemy test double: Health from a throwaway EnemyData/attack
## pair (no Guard node, matching the production scene), and a real StateMachine with the production
## Idle/Reposition/FaceTarget/Dead states as children, each owned by the enemy so their _ready()
## (which awaits owner.ready) resolves the same way a packed scene's does.
func _make_bomb(grid: GridArena, start_cell: Vector2i, target_cell: Vector2i) -> TestBombEnemy:
    var enemy := TestBombEnemy.new()
    enemy.global_position = grid.cell_center(start_cell)

    var health := Health.new()
    enemy.add_child(health)
    health.owner = enemy
    enemy.health = health

    var state_machine := StateMachine.new()
    state_machine.frame_driven = false
    enemy.add_child(state_machine)
    state_machine.owner = enemy

    var idle := EnemyIdleState.new()
    var reposition := EnemyRepositionState.new()
    var face := EnemyFaceOnceState.new()
    var dead := EnemyDeadState.new()
    for state: State in [idle, reposition, face, dead]:
        state_machine.add_child(state)
        state.owner = enemy
    state_machine.initial_state = idle
    enemy.wire_state_machine(state_machine)

    var attack := EnemyAttackData.new()
    attack.attack_kind = EnemyAttackData.AttackKind.AREA
    attack.cell_shape = EnemyAttackData.CellShape.MANHATTAN
    attack.damage = 50.0
    attack.warning_duration = 3
    attack.radius = 4
    var attacks: Array[EnemyAttackData] = [attack]
    var data := EnemyData.new()
    data.enemy_id = "test_bomb"
    data.max_health = 50.0
    data.attacks = attacks
    enemy.enemy_data = data

    var target: Node2D = autofree(Node2D.new())
    target.global_position = grid.cell_center(target_cell)

    add_child_autofree(enemy)

    enemy.bind_tick_engine(FakeTickEngine.new(target_cell))
    enemy.setup(grid, target)

    return enemy

# == Commitment: adjacent ring only ==


func test_should_commit_when_target_is_diagonally_adjacent() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(4, 4))

    assert_true(enemy.should_commit_before_plan())
    assert_true(enemy.try_commit_attack())
    assert_true(enemy.has_pending_attack_test())


func test_should_not_commit_when_target_shares_the_same_cell() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(3, 3))

    assert_false(enemy.should_commit_before_plan(), "sharing Bomb's own cell is not an adjacent hit")
    assert_false(enemy.has_pending_attack_test())


func test_should_not_commit_when_target_is_two_cells_away() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(5, 3))

    assert_false(enemy.should_commit_before_plan())
    assert_false(enemy.has_pending_attack_test())


func test_tick_speed_is_75() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(4, 3))

    assert_eq(enemy.get_tick_speed(), 75)

# == Locked footprint ==


func test_commit_locks_the_centered_manhattan_distance_four_footprint() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_bomb(grid, Vector2i(4, 4), Vector2i(5, 4))

    enemy.try_commit_attack()

    var actual := enemy.get_attack_tiles()
    assert_eq(actual.size(), 41, "a radius-four Manhattan footprint contains 41 cells")
    for cell: Vector2i in [Vector2i(4, 4), Vector2i(8, 4), Vector2i(4, 8), Vector2i(5, 5)]:
        assert_true(cell in actual, "expected %s in the locked footprint" % cell)
    for cell: Vector2i in [Vector2i(7, 6), Vector2i(8, 5)]:
        assert_false(cell in actual, "%s exceeds Manhattan distance four" % cell)


func test_commit_near_an_edge_only_locks_in_bounds_cells() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(0, 0), Vector2i(1, 0))

    enemy.try_commit_attack()

    var actual := enemy.get_attack_tiles()
    assert_eq(actual.size(), 15, "a corner commit should only lock its fifteen in-bounds diamond cells")
    for cell: Vector2i in actual:
        assert_true(cell.x >= 0 and cell.y >= 0, "no locked cell should fall outside the grid")


func test_later_player_movement_never_recenters_the_locked_footprint() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_bomb(grid, Vector2i(4, 4), Vector2i(5, 4))
    enemy.try_commit_attack()
    var original := enemy.get_attack_tiles().duplicate()

    # The player moves well outside the footprint after commitment.
    var fake_engine: FakeTickEngine = enemy.fake_tick_engine()
    fake_engine.target_cell = Vector2i(8, 8)
    enemy.advance_one_world_tick()

    assert_eq(enemy.get_attack_tiles(), original, "the footprint snapshot must never recenter on later movement")

# == Countdown: three normal world advances ==


func test_detonates_on_the_third_world_advance_not_before() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(4, 3))
    enemy.try_commit_attack()
    assert_eq(enemy.attack_ticks_test(), 3)

    enemy.advance_one_world_tick()
    assert_eq(enemy.attack_ticks_test(), 2)
    assert_true(enemy.is_alive())

    enemy.advance_one_world_tick()
    assert_eq(enemy.attack_ticks_test(), 1)
    assert_true(enemy.is_alive())

    enemy.advance_one_world_tick()
    assert_false(enemy.is_alive(), "the third normal world advance must resolve the detonation")

# == Disarm: killing Bomb before detonation ==


func test_killing_bomb_before_detonation_disarms_it_and_deals_no_explosion_damage() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(4, 3))
    enemy.try_commit_attack()
    enemy.advance_one_world_tick()

    enemy.health.take_damage(1000.0, null)
    assert_false(enemy.is_alive())
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.DEAD)

    var fake_engine: FakeTickEngine = enemy.fake_tick_engine()
    # Mirrors the world advance that would otherwise have detonated Bomb on its final tick.
    enemy.advance_one_world_tick()

    assert_eq(fake_engine.damage_calls, 0, "a Bomb killed mid-fuse must never deal explosion damage")
    assert_eq(fake_engine.detonation_calls, 0, "a Bomb killed mid-fuse must never flash its footprint")


func test_killing_bomb_before_any_commitment_leaves_it_dead_and_harmless() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(4, 3))

    enemy.health.take_damage(1000.0, null)

    assert_false(enemy.is_alive())
    assert_false(enemy.has_pending_attack_test())

# == Detonation: hit and miss ==


func test_detonation_damages_the_player_inside_the_footprint_then_self_kills() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(4, 3))
    enemy.try_commit_attack()

    enemy.advance_one_world_tick()
    enemy.advance_one_world_tick()
    enemy.advance_one_world_tick()

    var fake_engine: FakeTickEngine = enemy.fake_tick_engine()
    assert_eq(fake_engine.damage_calls, 1)
    assert_almost_eq(fake_engine.damage_dealt, 50.0, 0.001)
    assert_eq(fake_engine.detonation_calls, 1)
    assert_false(enemy.is_alive())
    assert_eq(enemy.current_state_id(), EnemyState.EnemyStateId.DEAD)
    assert_false(enemy.has_pending_attack_test(), "detonation must clear the runtime countdown")


func test_detonation_still_self_kills_when_the_player_left_the_footprint() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(4, 3))
    enemy.try_commit_attack()

    var fake_engine: FakeTickEngine = enemy.fake_tick_engine()
    fake_engine.target_cell = Vector2i(6, 6)

    enemy.advance_one_world_tick()
    enemy.advance_one_world_tick()
    enemy.advance_one_world_tick()

    assert_eq(fake_engine.damage_calls, 0, "a miss must never deal explosion damage")
    assert_eq(fake_engine.detonation_calls, 1, "the footprint must still flash on a miss")
    assert_false(enemy.is_alive(), "Bomb must self-kill even when its detonation misses")


func test_detonation_never_enters_a_recovery_window() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(4, 3))
    enemy.try_commit_attack()

    enemy.advance_one_world_tick()
    enemy.advance_one_world_tick()
    enemy.advance_one_world_tick()

    assert_eq(enemy.recovery_ticks_test(), 0, "a self-destructed Bomb must never bank a recovery window")

# == Reset ==


func test_reset_clears_a_pending_fuse_without_a_later_detonation() -> void:
    var grid := _make_grid(Vector2i(7, 7))
    var enemy := _make_bomb(grid, Vector2i(3, 3), Vector2i(4, 3))
    enemy.try_commit_attack()
    assert_true(enemy.has_pending_attack_test())

    enemy.reset()

    assert_false(enemy.has_pending_attack_test(), "reset must drop the locked fuse")
    assert_true(enemy.is_alive())

    var fake_engine: FakeTickEngine = enemy.fake_tick_engine()
    # Isolates the stale-countdown concern from Idle's normal re-commit decision: a reset Bomb still
    # adjacent to its target will legitimately recommit on its next funded action, so this checks
    # resolve_detonation() alone treats the cleared runtime as having nothing pending.
    enemy.resolve_detonation()
    assert_eq(fake_engine.detonation_calls, 0, "a reset Bomb must never detonate from a stale countdown")

# == Scene wiring ==


func test_scene_is_guardless_with_no_staggered_state() -> void:
    var scene := load("res://game/entities/enemies/bomb_enemy.tscn") as PackedScene
    assert_not_null(scene, "BombEnemy scene should load")

    var enemy := scene.instantiate()
    # node-ref: allow - validates Bomb's guardless scene wiring
    assert_null(enemy.get_node_or_null("Guard"), "Bomb must not own a Guard node")
    # node-ref: allow - validates Bomb has no Staggered state
    assert_null(enemy.get_node_or_null("StateMachine/Staggered"), "Bomb must not retain a Staggered state")
    # node-ref: allow - validates Bomb's required presenter scene wiring
    assert_not_null(enemy.get_node_or_null("VisualPresenter"), "Bomb should own a visual presenter")
    enemy.free()
