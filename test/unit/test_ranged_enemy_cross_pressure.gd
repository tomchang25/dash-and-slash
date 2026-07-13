# test_ranged_enemy_cross_pressure.gd
# Verifies RangedEnemy's distance-band commitment and target-centered cross snapshot while relying on
# the shared GridEnemy tick runtime for countdown, detonation, recovery, and cleanup.
extends GutTest

## Minimal tick-engine double covering RangedEnemy's logical target and detonation seams.
class FakeTickEngine:
    extends RefCounted

    signal world_advanced(tick_count: int)

    var target_cell: Vector2i
    var damage_calls := 0
    var damage_dealt := 0.0
    var detonation_calls := 0
    var last_detonated_cells: Array[Vector2i] = []


    func _init(cell: Vector2i) -> void:
        target_cell = cell


    func player_cell() -> Vector2i:
        return target_cell


    func clear_energy(_actor) -> void:
        pass


    func damage_player(amount: float, _source: Node) -> void:
        damage_calls += 1
        damage_dealt += amount


    func notify_detonation(cells: Array[Vector2i]) -> void:
        detonation_calls += 1
        last_detonated_cells = cells.duplicate()


    func emit_world_advanced() -> void:
        world_advanced.emit(0)


## Exposes runtime state and suppresses purely visual windup effects from the logic-only fixture.
class TestRangedEnemy:
    extends RangedEnemy

    func has_pending_attack_test() -> bool:
        return _tick_runtime.has_pending_attack()


    func attack_ticks_test() -> int:
        return _tick_runtime.attack_ticks()


    func recovery_ticks_test() -> int:
        return _tick_runtime.recovery_remaining()


    func fake_tick_engine() -> FakeTickEngine:
        return _tick_engine


    func queue_hit_facing_response_for_test() -> void:
        _queue_hit_facing_response()


    func advance_one_world_tick() -> void:
        resolve_detonation()
        fake_tick_engine().emit_world_advanced()


    func start_attack_windup_vfx(_style: int = CombatFeedbackVFX.WindupStyle.TILE) -> void:
        pass


    func stop_attack_windup_vfx() -> void:
        pass


func _make_grid(size: Vector2i) -> GridArena:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = size
    grid.starting_land_size = size
    grid.generate_grid()
    return grid


func _make_ranged(grid: GridArena, start_cell: Vector2i, target_cell: Vector2i) -> TestRangedEnemy:
    var enemy := TestRangedEnemy.new()
    enemy.global_position = grid.cell_center(start_cell)

    var health := Health.new()
    enemy.add_child(health)
    health.owner = enemy
    enemy.health = health

    var telegraph := TileTelegraph.new()
    telegraph.name = "TileTelegraph"
    telegraph.unique_name_in_owner = true
    enemy.add_child(telegraph)
    telegraph.owner = enemy

    var controller := EnemyAttackController.new()
    controller.name = "AttackController"
    controller.unique_name_in_owner = true
    enemy.add_child(controller)
    controller.owner = enemy

    var attack := load("res://game/entities/enemies/data/ranged_enemy.tres") as EnemyData
    enemy.enemy_data = attack

    var target: Node2D = autofree(Node2D.new())
    target.global_position = grid.cell_center(target_cell)
    add_child_autofree(enemy)

    enemy.bind_tick_engine(FakeTickEngine.new(target_cell))
    enemy.setup(grid, target)
    return enemy

# == Ranged commitment ==


func test_commits_from_the_distance_band_without_facing_the_player() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_ranged(grid, Vector2i(1, 4), Vector2i(4, 4))

    assert_false(enemy.is_facing_target(), "the fixture begins facing down while the player is right")
    assert_true(enemy.can_attack())
    assert_true(enemy.try_commit_attack())
    assert_eq(enemy.get_facing(), Vector2.RIGHT, "telegraph start must face the target without a FaceOnce action")
    assert_true(enemy.has_pending_attack_test())


func test_diagonal_chebyshev_range_outside_the_manhattan_band_cannot_commit() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_ranged(grid, Vector2i(0, 0), Vector2i(4, 4))

    assert_false(enemy.can_attack(), "a diagonal offset of four by four has Manhattan distance eight")


func test_target_beyond_manhattan_distance_five_cannot_commit() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_ranged(grid, Vector2i(1, 4), Vector2i(7, 4))

    assert_false(enemy.can_attack(), "an axial offset of six exceeds Ranged's maximum Manhattan distance")


func test_commit_locks_a_target_centered_five_cell_cross() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_ranged(grid, Vector2i(1, 4), Vector2i(4, 4))

    assert_true(enemy.try_commit_attack())
    var actual := enemy.get_attack_tiles()
    var expected: Array[Vector2i] = [Vector2i(4, 4), Vector2i(5, 4), Vector2i(3, 4), Vector2i(4, 5), Vector2i(4, 3)]
    assert_eq(actual.size(), expected.size())
    for cell: Vector2i in expected:
        assert_true(cell in actual, "expected %s in the locked cross" % cell)


func test_target_movement_never_recenters_a_committed_cross() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_ranged(grid, Vector2i(1, 4), Vector2i(4, 4))
    assert_true(enemy.try_commit_attack())
    var original := enemy.get_attack_tiles().duplicate()

    var fake_engine := enemy.fake_tick_engine()
    fake_engine.target_cell = Vector2i(8, 8)
    enemy.advance_one_world_tick()

    assert_eq(enemy.attack_ticks_test(), 1)
    assert_eq(enemy.get_attack_tiles(), original)


func test_detonation_uses_the_post_action_player_cell_and_enters_recovery() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_ranged(grid, Vector2i(1, 4), Vector2i(4, 4))
    assert_true(enemy.try_commit_attack())
    var original := enemy.get_attack_tiles().duplicate()

    var fake_engine := enemy.fake_tick_engine()
    fake_engine.target_cell = Vector2i(8, 8)
    enemy.advance_one_world_tick()
    enemy.advance_one_world_tick()

    assert_eq(fake_engine.damage_calls, 0, "leaving the locked cross before detonation avoids damage")
    assert_eq(fake_engine.detonation_calls, 1)
    assert_eq(fake_engine.last_detonated_cells, original)
    assert_false(enemy.has_pending_attack_test())
    assert_eq(enemy.recovery_ticks_test(), 2)


func test_hit_facing_response_remains_available_but_pending_attacks_take_priority() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_ranged(grid, Vector2i(1, 4), Vector2i(4, 4))

    enemy.queue_hit_facing_response_for_test()
    assert_true(enemy.has_pending_hit_facing_response())

    assert_true(enemy.try_commit_attack())
    enemy.consume_pending_hit_facing_response()
    enemy.queue_hit_facing_response_for_test()
    assert_false(enemy.has_pending_hit_facing_response(), "a locked telegraph must keep the hit-facing response suppressed")


func test_reset_clears_the_cross_snapshot_and_countdown() -> void:
    var grid := _make_grid(Vector2i(9, 9))
    var enemy := _make_ranged(grid, Vector2i(1, 4), Vector2i(4, 4))
    assert_true(enemy.try_commit_attack())

    enemy.reset()

    assert_false(enemy.has_pending_attack_test())
    assert_true(enemy.get_attack_tiles().is_empty())
    assert_true(enemy.get_committed_attack_cells().is_empty())
