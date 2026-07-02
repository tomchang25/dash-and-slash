# test_wave_controller.gd
# Tests WaveScaling formulas and WaveController infinite progression, pressure
# modifiers, milestone detection, and population-cap spawn queueing.
extends GutTest

## Spawn planner test double: always returns the origin cell so the test doesn't
## depend on real grid placement, only on queue/population bookkeeping.
class FakeSpawnPlanner:
    extends EnemySpawnPlanner

    func choose_enemy_spawn_cell(_index: int, _spawn_count: int, _reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
        return Vector2i.ZERO


## Spawner test double: creates a bare Enemy (has the "died" signal, no scene
## dependencies) instead of instantiating a real enemy PackedScene.
class FakeSpawner:
    extends EnemySpawner

    var spawned: Array[Node] = []


    func spawn_enemy(_picked: PackedScene, _spawn_cell: Vector2i, died_callback: Callable, pre_ready_setup: Callable = Callable()) -> Node:
        var enemy := Enemy.new()
        enemy.connect(&"died", died_callback)
        if pre_ready_setup.is_valid():
            pre_ready_setup.call(enemy)
        spawned.append(enemy)
        return enemy


## Test-only subclass exposing WaveController's timer-driven spawn flow and queue
## state through public wrappers. Headless unit tests don't tick a live SceneTree,
## so timer callbacks must be triggered directly instead of waited on; going
## through a subclass keeps that private-method access inside the class family
## instead of reaching into WaveController from unrelated test code.
class TestWaveController:
    extends WaveController

    func trigger_wave_gap_timeout() -> void:
        _on_wave_gap_timeout()


    func trigger_spawn_telegraph_timeout() -> void:
        _on_spawn_telegraph_timeout()


    func begin_wave_now() -> void:
        _begin_wave()


    func alive_count() -> int:
        return _alive_enemies.size()


    func first_alive() -> Node:
        return _alive_enemies[0] if not _alive_enemies.is_empty() else null


    func queue_count() -> int:
        return _spawn_queue.size()

# == WaveScaling formulas ========================================================


func test_support_count_formula() -> void:
    assert_eq(WaveScaling.get_support_count(1), 5, "wave 1 support count")
    assert_eq(WaveScaling.get_support_count(2), 6, "wave 2 support count")
    assert_eq(WaveScaling.get_support_count(5), 9, "wave 5 support count")
    assert_eq(WaveScaling.get_support_count(20), 24, "wave 20 support count")


func test_tier_boundaries() -> void:
    assert_eq(WaveScaling.get_tier(1), 0, "wave 1 is tier 0")
    assert_eq(WaveScaling.get_tier(4), 0, "wave 4 is still tier 0")
    assert_eq(WaveScaling.get_tier(5), 1, "wave 5 is tier 1")
    assert_eq(WaveScaling.get_tier(9), 1, "wave 9 is still tier 1")
    assert_eq(WaveScaling.get_tier(10), 2, "wave 10 is tier 2")


func test_is_milestone_wave() -> void:
    assert_false(WaveScaling.is_milestone_wave(0), "wave 0 is not a milestone")
    assert_false(WaveScaling.is_milestone_wave(4), "wave 4 is not a milestone")
    assert_true(WaveScaling.is_milestone_wave(5), "wave 5 is a milestone")
    assert_false(WaveScaling.is_milestone_wave(6), "wave 6 is not a milestone")
    assert_true(WaveScaling.is_milestone_wave(10), "wave 10 is a milestone")


func test_population_cap_formula() -> void:
    assert_eq(WaveScaling.get_population_cap(1), 12, "wave 1 population cap")
    assert_eq(WaveScaling.get_population_cap(5), 16, "wave 5 population cap")
    assert_eq(WaveScaling.get_population_cap(10), 20, "wave 10 population cap")


func test_hp_multiplier_per_tier() -> void:
    assert_eq(WaveScaling.get_hp_multiplier(1), 1.0, "tier 0 has no hp bonus")
    assert_almost_eq(WaveScaling.get_hp_multiplier(5), 1.35, 0.001)
    assert_almost_eq(WaveScaling.get_hp_multiplier(10), 1.70, 0.001)


func test_damage_multiplier_per_tier() -> void:
    assert_eq(WaveScaling.get_damage_multiplier(1), 1.0, "tier 0 has no damage bonus")
    assert_almost_eq(WaveScaling.get_damage_multiplier(5), 1.20, 0.001)


func test_defense_per_tier() -> void:
    assert_eq(WaveScaling.get_defense(1), 0.0, "tier 0 has no defense")
    assert_almost_eq(WaveScaling.get_defense(5), 6.0, 0.001)
    assert_almost_eq(WaveScaling.get_defense(10), 12.0, 0.001)

# == WaveController progression ==================================================


func test_initial_state_has_no_wave() -> void:
    var wc := WaveController.new()
    assert_eq(wc.get_wave_number(), 0, "no wave before advance")


func test_advance_wave_moves_to_wave_one() -> void:
    var wc := WaveController.new()
    assert_true(wc.advance_wave(), "advance_wave should return true")
    assert_eq(wc.get_wave_number(), 1, "first wave should be number 1")


func test_advance_wave_never_stops_without_end_run() -> void:
    var wc := WaveController.new()
    for i in 50:
        assert_true(wc.advance_wave(), "the wave loop should never stop on its own")
    assert_eq(wc.get_wave_number(), 50, "wave number should keep climbing")


func test_end_run_stops_advance_wave() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    wc.end_run()
    assert_false(wc.advance_wave(), "advance_wave should stop once the run has ended")


func test_reset_clears_state() -> void:
    var wc := WaveController.new()
    wc.add_future_enemy_count(5)
    wc.advance_wave()
    wc.end_run()
    wc.reset()
    assert_eq(wc.get_wave_number(), 0, "wave number resets to 0")
    assert_true(wc.advance_wave(), "advance_wave should work again after reset")
    assert_eq(wc.get_support_spawn_count(), WaveScaling.get_support_count(1), "pressure should reset to 0")

# == Support / elite spawn counts =================================================


func test_support_count_matches_formula() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), WaveScaling.get_support_count(1))


func test_future_pressure_adds_to_support_count() -> void:
    var wc := WaveController.new()
    wc.add_future_enemy_count(3)
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), WaveScaling.get_support_count(1) + 3)


func test_negative_pressure_is_clamped() -> void:
    var wc := WaveController.new()
    wc.add_future_enemy_count(-5)
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), WaveScaling.get_support_count(1), "negative pressure is clamped to zero")


func test_elite_spawn_count_on_milestone_wave() -> void:
    var wc := WaveController.new()
    for i in 5:
        wc.advance_wave()
    assert_true(wc.is_milestone_wave(), "wave 5 is a milestone")
    assert_eq(wc.get_elite_spawn_count(), 1, "milestone wave spawns 1 elite")


func test_elite_spawn_count_off_milestone_wave() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    assert_false(wc.is_milestone_wave(), "wave 1 is not a milestone")
    assert_eq(wc.get_elite_spawn_count(), 0, "non-milestone wave spawns 0 elites")


func test_pressure_does_not_affect_elite_count() -> void:
    var wc := WaveController.new()
    wc.add_future_enemy_count(99)
    for i in 5:
        wc.advance_wave()
    assert_eq(wc.get_elite_spawn_count(), 1, "pressure does not add extra elites")

# == Display text =================================================================


func test_wave_display_text_for_normal_wave() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    assert_eq(wc.get_wave_display_text(), "Wave 1")


func test_wave_display_text_for_milestone_wave() -> void:
    var wc := WaveController.new()
    for i in 5:
        wc.advance_wave()
    assert_eq(wc.get_wave_display_text(), "Wave 5: ELITE")

# == Population cap + spawn queueing =============================================
#
# These drive the wave-gap and spawn-telegraph timer callbacks directly instead of
# waiting on real Timer nodes, since headless unit tests don't tick a live
# SceneTree. This is whitebox by necessity: there is no public API for "wait for
# the next spawn batch," only for driving wave flow end-to-end in a running game.


func test_spawn_queue_drains_under_population_cap() -> void:
    var timer_parent: Node = add_child_autofree(Node.new())
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var fake_planner := FakeSpawnPlanner.new()
    var fake_spawner := FakeSpawner.new()

    var wc := TestWaveController.new()
    wc.setup(timer_parent, grid, fake_planner, fake_spawner)

    var completed_calls: Array = []
    wc.normal_wave_completed.connect(
        func(wave_number: int, is_milestone: bool) -> void:
            completed_calls.append([wave_number, is_milestone])
    )

    # Wave 1 support count formula is 5; +10 pressure asks for 15 against a
    # population cap of 12, so 3 should queue instead of spawning immediately.
    wc.add_future_enemy_count(10)
    wc.start_next_wave()
    wc.trigger_wave_gap_timeout()
    wc.trigger_spawn_telegraph_timeout()

    assert_eq(fake_spawner.spawned.size(), 12, "only cap-worth of enemies should spawn immediately")
    assert_eq(wc.alive_count(), 12, "alive count should sit at the population cap")
    assert_eq(wc.queue_count(), 3, "the remaining 3 enemies should be queued, not force-spawned")
    assert_true(completed_calls.is_empty(), "wave should not complete while enemies remain queued or alive")

    # Kill one alive enemy at a time; each death should drain exactly one more
    # from the queue until it's empty.
    for i in 3:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)
        wc.trigger_spawn_telegraph_timeout()

    assert_eq(wc.queue_count(), 0, "queue should be fully drained")
    assert_eq(wc.alive_count(), 12, "population stays at cap while draining")
    assert_true(completed_calls.is_empty(), "wave still should not complete while enemies remain alive")

    # Kill everyone remaining; the queue is empty so no further batches spawn.
    while wc.alive_count() > 0:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)

    assert_eq(completed_calls.size(), 1, "wave should complete exactly once, after queue and population are both empty")
    assert_eq(completed_calls[0][0], 1, "completed wave number should be 1")
    assert_false(completed_calls[0][1], "wave 1 is not a milestone wave")

    for enemy in fake_spawner.spawned:
        if is_instance_valid(enemy):
            enemy.free()


## Regression test: two deaths landing within the same spawn-telegraph window
## (e.g. an AOE hit killing multiple enemies in one frame) must not lose a
## queued spawn. _spawn_next_batch() replaces _current_batch wholesale, so a
## naive re-entrant call while a batch is still telegraphing would silently
## overwrite (and permanently drop) whichever entries the first call had
## already queued.
func test_spawn_queue_survives_overlapping_deaths_during_telegraph() -> void:
    var timer_parent: Node = add_child_autofree(Node.new())
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var fake_planner := FakeSpawnPlanner.new()
    var fake_spawner := FakeSpawner.new()

    var wc := TestWaveController.new()
    wc.setup(timer_parent, grid, fake_planner, fake_spawner)

    var completed_calls: Array = []
    wc.normal_wave_completed.connect(
        func(wave_number: int, is_milestone: bool) -> void:
            completed_calls.append([wave_number, is_milestone])
    )

    # Wave 1 support count formula is 5; +10 pressure asks for 15 against a
    # population cap of 12, so 3 should queue instead of spawning immediately.
    wc.add_future_enemy_count(10)
    wc.start_next_wave()
    wc.trigger_wave_gap_timeout()
    wc.trigger_spawn_telegraph_timeout()

    assert_eq(fake_spawner.spawned.size(), 12, "only cap-worth of enemies should spawn immediately")
    assert_eq(wc.queue_count(), 3, "3 enemies should be queued")

    # Kill two alive enemies back-to-back WITHOUT resolving the spawn
    # telegraph in between. Before the fix, the second _on_enemy_died call
    # would call _spawn_next_batch() re-entrantly and overwrite
    # _current_batch, dropping whichever entry the first death had already
    # queued for spawning.
    var first_dying: Node = wc.first_alive()
    first_dying.died.emit(first_dying)
    var second_dying: Node = wc.first_alive()
    second_dying.died.emit(second_dying)

    # Two batches now need to resolve in turn: the one death 1 queued, and
    # the one death 2's freed headroom queues immediately after.
    wc.trigger_spawn_telegraph_timeout()
    wc.trigger_spawn_telegraph_timeout()

    assert_eq(wc.alive_count(), 12, "population should be back at cap, not short an enemy")
    assert_eq(wc.queue_count(), 1, "exactly 1 of the 3 queued entries should remain")

    # Drain the last queued entry the normal way.
    var last_dying: Node = wc.first_alive()
    last_dying.died.emit(last_dying)
    wc.trigger_spawn_telegraph_timeout()

    assert_eq(wc.queue_count(), 0, "queue should be fully drained")
    assert_eq(fake_spawner.spawned.size(), 15, "all 15 requested enemies should eventually spawn, none dropped")

    while wc.alive_count() > 0:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)

    assert_eq(completed_calls.size(), 1, "wave should complete exactly once")
    assert_eq(completed_calls[0][0], 1, "completed wave number should be 1")

    for enemy in fake_spawner.spawned:
        if is_instance_valid(enemy):
            enemy.free()


func test_elite_cleared_signal_fires_without_ending_run() -> void:
    var timer_parent: Node = add_child_autofree(Node.new())
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var fake_planner := FakeSpawnPlanner.new()
    var fake_spawner := FakeSpawner.new()

    var wc := TestWaveController.new()
    wc.setup(timer_parent, grid, fake_planner, fake_spawner)

    # Boxed in an Array, not a plain int: GDScript lambdas capture outer locals by
    # value for primitives, so a plain int would only mutate the lambda's own copy.
    var elite_cleared_count := [0]
    wc.elite_cleared.connect(func() -> void: elite_cleared_count[0] += 1)
    var completed_calls: Array = []
    wc.normal_wave_completed.connect(
        func(wave_number: int, is_milestone: bool) -> void:
            completed_calls.append([wave_number, is_milestone])
    )

    for i in 5:
        wc.advance_wave()
    assert_true(wc.is_milestone_wave(), "wave 5 should be a milestone wave")

    # Wave 5's support+elite count (10) fits under the wave-5 population cap (16),
    # so the whole batch spawns in one shot; drive the flow directly rather than
    # through the wave-gap timer, which this test isn't exercising.
    wc.begin_wave_now()
    wc.trigger_spawn_telegraph_timeout()

    var elite: Node = fake_spawner.spawned.back()
    elite.died.emit(elite)

    assert_eq(elite_cleared_count[0], 1, "elite_cleared should fire when the elite dies")
    assert_eq(wc.alive_count(), WaveScaling.get_support_count(5), "remaining support enemies should stay alive, not be force-killed")

    while wc.alive_count() > 0:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)

    assert_eq(completed_calls.size(), 1, "wave should complete normally once support and elite are all dead")
    assert_true(completed_calls[0][1], "wave 5 completion should report as a milestone wave")

    for enemy in fake_spawner.spawned:
        if is_instance_valid(enemy):
            enemy.free()
