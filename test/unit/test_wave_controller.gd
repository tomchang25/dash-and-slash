# test_wave_controller.gd
# Tests WaveScaling formulas, EnemySpawnPlanner revalidation, and WaveController infinite
# progression, pressure modifiers, milestone detection, and tick-warning spawn queueing.
extends GutTest

## Spawn planner test double: always returns the origin cell so the test doesn't depend on real
## grid placement, only on queue/population bookkeeping. Revalidation is stubbed to always pass so
## these tests exercise queueing/warning timing, not cell geometry — see the dedicated
## "EnemySpawnPlanner revalidation" section below for that.
class FakeSpawnPlanner:
    extends EnemySpawnPlanner

    func choose_enemy_spawn_cell(_index: int, _spawn_count: int, _reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
        return Vector2i.ZERO


    func is_spawn_cell_still_valid(_cell: Vector2i, _reserved_spawn_cells: Array[Vector2i]) -> bool:
        return true


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


## Test-only subclass exposing WaveController's tick-warning spawn flow and queue state through
## public wrappers. Headless unit tests don't tick a live SceneTree or a real TickEngine, so the
## world-advanced countdown is driven directly instead of through a real engine signal.
class TestWaveController:
    extends WaveController

    func trigger_world_advanced() -> void:
        _on_world_advanced(0)


    func begin_wave_now() -> void:
        _begin_wave()


    func alive_count() -> int:
        return _alive_enemies.size()


    func first_alive() -> Node:
        return _alive_enemies[0] if not _alive_enemies.is_empty() else null


    func queue_count() -> int:
        return _spawn_queue.size()


    func pending_batch_count() -> int:
        return _pending_batch.size()

# == WaveScaling formulas ==


func test_support_count_formula() -> void:
    assert_eq(WaveScaling.get_support_count(1), 3, "wave 1 support count")
    assert_eq(WaveScaling.get_support_count(2), 4, "wave 2 support count")
    assert_eq(WaveScaling.get_support_count(5), 5, "wave 5 support count")
    assert_eq(WaveScaling.get_support_count(20), 13, "wave 20 support count")


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
    assert_eq(WaveScaling.get_population_cap(1), 3, "wave 1 population cap")
    assert_eq(WaveScaling.get_population_cap(5), 4, "wave 5 population cap")
    assert_eq(WaveScaling.get_population_cap(10), 5, "wave 10 population cap")
    assert_eq(WaveScaling.get_population_cap(15), 6, "wave 15 population cap")
    assert_eq(WaveScaling.get_population_cap(30), 6, "population cap never exceeds 6")


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

# == EnemySpawnPlanner revalidation ==


func test_is_spawn_cell_still_valid_rejects_occupied_cell() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()
    grid.register_occupant(autofree(Node.new()), [Vector2i(1, 1)])

    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return Vector2i(3, 3))
    assert_false(planner.is_spawn_cell_still_valid(Vector2i(1, 1), []), "an occupied cell is not a valid spawn target")
    assert_true(planner.is_spawn_cell_still_valid(Vector2i(2, 2), []), "an unoccupied land cell is valid")


func test_is_spawn_cell_still_valid_rejects_player_cell() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return Vector2i(2, 2))
    assert_false(planner.is_spawn_cell_still_valid(Vector2i(2, 2), []), "the player's own cell is never a valid spawn target")


func test_find_valid_spawn_replacement_returns_no_cell_when_grid_full() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(2, 2)
    grid.starting_land_size = Vector2i(2, 2)
    grid.generate_grid()
    grid.register_occupant(autofree(Node.new()), [Vector2i(0, 0)])
    grid.register_occupant(autofree(Node.new()), [Vector2i(1, 0)])
    grid.register_occupant(autofree(Node.new()), [Vector2i(0, 1)])

    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return Vector2i(1, 1))
    assert_eq(planner.find_valid_spawn_replacement(0, 1, []), EnemySpawnPlanner.NO_CELL, "no land cell remains open")


func test_find_valid_spawn_replacement_finds_open_cell() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(2, 2)
    grid.starting_land_size = Vector2i(2, 2)
    grid.generate_grid()
    grid.register_occupant(autofree(Node.new()), [Vector2i(0, 0)])
    grid.register_occupant(autofree(Node.new()), [Vector2i(1, 0)])

    var planner := EnemySpawnPlanner.new(grid, func() -> Vector2i: return Vector2i(1, 1))
    var replacement := planner.find_valid_spawn_replacement(0, 1, [])
    assert_eq(replacement, Vector2i(0, 1), "the only open, non-player cell should be chosen")

# == WaveController progression ==


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


## Regression for the Phase 6e death flow: TickRunController.handle_player_died() now calls
## end_run() on every death instead of leaving it unused, so is_run_over() must flip on end_run()
## and clear again on reset() for the next run.
func test_end_run_marks_run_over_and_reset_clears_it() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    assert_false(wc.is_run_over(), "a run is not over before end_run()")

    wc.end_run()
    assert_true(wc.is_run_over(), "end_run() should mark the run as over")

    wc.reset()
    assert_false(wc.is_run_over(), "reset() should clear the run-over flag for the next run")


func test_reset_clears_state() -> void:
    var wc := WaveController.new()
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)
    run_build.record(RunBuild.CH_FUTURE_ENEMY_COUNT, 5)
    wc.advance_wave()
    wc.end_run()
    wc.reset()
    run_build.clear()
    assert_eq(wc.get_wave_number(), 0, "wave number resets to 0")
    assert_true(wc.advance_wave(), "advance_wave should work again after reset")
    assert_eq(wc.get_support_spawn_count(), WaveScaling.get_support_count(1), "pressure should reset to 0")


## Regression for the Phase 6e restart flow: a restart hands WaveController a brand-new RunBuild
## instance (the arena root constructs it fresh) instead of clearing the old one in place, so any
## pressure recorded on the stale store must have zero effect the moment the swap happens.
func test_set_run_build_swaps_to_a_new_instance_not_just_clearing_the_old_one() -> void:
    var wc := WaveController.new()
    var stale_run_build := RunBuild.new()
    wc.set_run_build(stale_run_build)
    stale_run_build.record(RunBuild.CH_FUTURE_ENEMY_COUNT, 5)
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), WaveScaling.get_support_count(1) + 5, "the stale run build's pressure should apply before the swap")

    var fresh_run_build := RunBuild.new()
    wc.set_run_build(fresh_run_build)
    assert_eq(wc.get_support_spawn_count(), WaveScaling.get_support_count(1), "swapping to a fresh RunBuild must drop the previous run's pressure entirely")

# == Support / elite spawn counts ==


func test_support_count_matches_formula() -> void:
    var wc := WaveController.new()
    wc.set_run_build(RunBuild.new())
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), WaveScaling.get_support_count(1))


func test_future_pressure_adds_to_support_count() -> void:
    var wc := WaveController.new()
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)
    run_build.record(RunBuild.CH_FUTURE_ENEMY_COUNT, 3)
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), WaveScaling.get_support_count(1) + 3)


func test_negative_pressure_is_clamped() -> void:
    var wc := WaveController.new()
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)
    run_build.record(RunBuild.CH_FUTURE_ENEMY_COUNT, -5)
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
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)
    run_build.record(RunBuild.CH_FUTURE_ENEMY_COUNT, 99)
    for i in 5:
        wc.advance_wave()
    assert_eq(wc.get_elite_spawn_count(), 1, "pressure does not add extra elites")

# == Enemy-toughness pressure ==


func test_health_pressure_raises_hp_multiplier() -> void:
    var wc := WaveController.new()
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)
    run_build.record(RunBuild.CH_ENEMY_HEALTH_PRESSURE, 0.1)
    wc.advance_wave()
    assert_almost_eq(wc.get_hp_multiplier(), WaveScaling.get_hp_multiplier(1) + 0.1, 0.001)


func test_damage_pressure_raises_damage_multiplier() -> void:
    var wc := WaveController.new()
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)
    run_build.record(RunBuild.CH_ENEMY_DAMAGE_PRESSURE, 0.1)
    wc.advance_wave()
    assert_almost_eq(wc.get_damage_multiplier(), WaveScaling.get_damage_multiplier(1) + 0.1, 0.001)


func test_defense_pressure_raises_defense() -> void:
    var wc := WaveController.new()
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)
    run_build.record(RunBuild.CH_ENEMY_DEFENSE_PRESSURE, 3.0)
    wc.advance_wave()
    assert_almost_eq(wc.get_defense(), WaveScaling.get_defense(1) + 3.0, 0.001)


func test_negative_toughness_pressure_is_clamped() -> void:
    var wc := WaveController.new()
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)
    run_build.record(RunBuild.CH_ENEMY_HEALTH_PRESSURE, -0.5)
    run_build.record(RunBuild.CH_ENEMY_DAMAGE_PRESSURE, -0.5)
    run_build.record(RunBuild.CH_ENEMY_DEFENSE_PRESSURE, -5.0)
    wc.advance_wave()
    assert_almost_eq(wc.get_hp_multiplier(), WaveScaling.get_hp_multiplier(1), 0.001, "negative health pressure is clamped to zero")
    assert_almost_eq(wc.get_damage_multiplier(), WaveScaling.get_damage_multiplier(1), 0.001, "negative damage pressure is clamped to zero")
    assert_almost_eq(wc.get_defense(), WaveScaling.get_defense(1), 0.001, "negative defense pressure is clamped to zero")

# == Display text ==


func test_wave_display_text_for_normal_wave() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    assert_eq(wc.get_wave_display_text(), "Wave 1")


func test_wave_display_text_for_milestone_wave() -> void:
    var wc := WaveController.new()
    for i in 5:
        wc.advance_wave()
    assert_eq(wc.get_wave_display_text(), "Wave 5: ELITE")

# == Population cap + spawn-warning queueing ==
#
# These drive the world-advanced countdown directly through TestWaveController's wrapper instead
# of a live TickEngine, since headless unit tests don't tick a real engine and this test suite
# only needs the signal-driven countdown behavior, not engine scheduling itself.


func test_spawn_queue_drains_under_population_cap() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var fake_planner := FakeSpawnPlanner.new()
    var fake_spawner := FakeSpawner.new()
    var engine: TickEngine = autofree(TickEngine.new())

    var wc := TestWaveController.new()
    wc.setup(grid, fake_planner, fake_spawner, engine)
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)

    var completed_calls: Array = []
    wc.normal_wave_completed.connect(
        func(wave_number: int, is_milestone: bool) -> void:
            completed_calls.append([wave_number, is_milestone])
    )

    # Wave 1 support count formula is 3; +7 pressure asks for 10 against a
    # population cap of 3, so 7 should queue instead of spawning immediately.
    run_build.record(RunBuild.CH_FUTURE_ENEMY_COUNT, 7)
    wc.start_next_wave()
    wc.trigger_world_advanced()
    wc.trigger_world_advanced()

    assert_eq(fake_spawner.spawned.size(), 3, "only cap-worth of enemies should spawn immediately")
    assert_eq(wc.alive_count(), 3, "alive count should sit at the population cap")
    assert_eq(wc.queue_count(), 7, "the remaining 7 enemies should be queued, not force-spawned")
    assert_true(completed_calls.is_empty(), "wave should not complete while enemies remain queued or alive")

    # Kill one alive enemy at a time; each death schedules one more warning batch, which spawns
    # once its 2-tick countdown resolves.
    for i in 7:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)
        wc.trigger_world_advanced()
        wc.trigger_world_advanced()

    assert_eq(wc.queue_count(), 0, "queue should be fully drained")
    assert_eq(wc.alive_count(), 3, "population stays at cap while draining")
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


## Regression test: a spawn warning does not count down on world ticks it never receives, and
## resolves exactly on the tick its countdown reaches zero.
func test_spawn_warning_does_not_resolve_before_its_countdown_elapses() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var fake_planner := FakeSpawnPlanner.new()
    var fake_spawner := FakeSpawner.new()
    var engine: TickEngine = autofree(TickEngine.new())

    var wc := TestWaveController.new()
    wc.setup(grid, fake_planner, fake_spawner, engine)
    wc.set_run_build(RunBuild.new())

    wc.start_next_wave()
    assert_eq(fake_spawner.spawned.size(), 0, "the batch should only telegraph, not spawn, when scheduled")

    wc.trigger_world_advanced()
    assert_eq(fake_spawner.spawned.size(), 0, "one world advance is not enough to resolve a 2-tick warning")

    wc.trigger_world_advanced()
    assert_eq(fake_spawner.spawned.size(), WaveScaling.get_support_count(1), "the second world advance resolves the warning")

    for enemy in fake_spawner.spawned:
        if is_instance_valid(enemy):
            enemy.free()


## Regression test: two deaths landing within the same spawn-warning window (e.g. an AOE hit
## killing multiple enemies in one frame) must not lose a queued spawn. _resolve_pending_batch()
## replaces _pending_batch wholesale, so a naive re-entrant call while a batch is still warning
## would silently overwrite (and permanently drop) whichever entries the first call had already queued.
func test_spawn_queue_survives_overlapping_deaths_during_warning() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var fake_planner := FakeSpawnPlanner.new()
    var fake_spawner := FakeSpawner.new()
    var engine: TickEngine = autofree(TickEngine.new())

    var wc := TestWaveController.new()
    wc.setup(grid, fake_planner, fake_spawner, engine)
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)

    var completed_calls: Array = []
    wc.normal_wave_completed.connect(
        func(wave_number: int, is_milestone: bool) -> void:
            completed_calls.append([wave_number, is_milestone])
    )

    # Wave 1 support count formula is 3; +4 pressure asks for 7 against a
    # population cap of 3, so 4 should queue instead of spawning immediately.
    run_build.record(RunBuild.CH_FUTURE_ENEMY_COUNT, 4)
    wc.start_next_wave()
    wc.trigger_world_advanced()
    wc.trigger_world_advanced()

    assert_eq(fake_spawner.spawned.size(), 3, "only cap-worth of enemies should spawn immediately")
    assert_eq(wc.queue_count(), 4, "4 enemies should be queued")

    # Kill two alive enemies back-to-back WITHOUT resolving the pending warning batch in between.
    # Before the fix, the second _on_enemy_died call would call _schedule_next_warning_batch()
    # re-entrantly and overwrite _pending_batch, dropping whichever entry the first death had
    # already queued for warning.
    var first_dying: Node = wc.first_alive()
    first_dying.died.emit(first_dying)
    var second_dying: Node = wc.first_alive()
    second_dying.died.emit(second_dying)

    # Two batches now need to resolve in turn: the one death 1 queued, and the one death 2's
    # freed headroom queues immediately after.
    wc.trigger_world_advanced()
    wc.trigger_world_advanced()
    wc.trigger_world_advanced()
    wc.trigger_world_advanced()

    assert_eq(wc.alive_count(), 3, "population should be back at cap, not short an enemy")
    assert_eq(wc.queue_count(), 2, "2 of the 4 queued entries should remain")

    # Drain the rest the normal way.
    while wc.queue_count() > 0:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)
        wc.trigger_world_advanced()
        wc.trigger_world_advanced()

    assert_eq(wc.queue_count(), 0, "queue should be fully drained")
    assert_eq(fake_spawner.spawned.size(), 7, "all 7 requested enemies should eventually spawn, none dropped")

    while wc.alive_count() > 0:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)

    assert_eq(completed_calls.size(), 1, "wave should complete exactly once")
    assert_eq(completed_calls[0][0], 1, "completed wave number should be 1")

    for enemy in fake_spawner.spawned:
        if is_instance_valid(enemy):
            enemy.free()


func test_elite_cleared_signal_fires_without_ending_run() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var fake_planner := FakeSpawnPlanner.new()
    var fake_spawner := FakeSpawner.new()
    var engine: TickEngine = autofree(TickEngine.new())

    var wc := TestWaveController.new()
    wc.setup(grid, fake_planner, fake_spawner, engine)
    wc.set_run_build(RunBuild.new())

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

    # Wave 5's support count (5) plus its elite (1) total 6 requested against a population cap of
    # 4, so the elite queues behind two support enemies and only spawns once earlier kills drain
    # the queue down to it.
    wc.begin_wave_now()
    wc.trigger_world_advanced()
    wc.trigger_world_advanced()

    assert_eq(fake_spawner.spawned.size(), 4, "only cap-worth of enemies should spawn immediately")
    assert_eq(wc.queue_count(), 2, "the support overflow and the elite should still be queued")

    for i in 2:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)
        wc.trigger_world_advanced()
        wc.trigger_world_advanced()

    assert_eq(fake_spawner.spawned.size(), 6, "all 5 support enemies and the elite should have spawned")
    assert_eq(wc.queue_count(), 0, "queue should be fully drained")

    var elite: Node = fake_spawner.spawned.back()
    elite.died.emit(elite)

    assert_eq(elite_cleared_count[0], 1, "elite_cleared should fire when the elite dies")
    assert_eq(wc.alive_count(), 3, "remaining support enemies should stay alive, not be force-killed")

    while wc.alive_count() > 0:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)

    assert_eq(completed_calls.size(), 1, "wave should complete normally once support and elite are all dead")
    assert_true(completed_calls[0][1], "wave 5 completion should report as a milestone wave")

    for enemy in fake_spawner.spawned:
        if is_instance_valid(enemy):
            enemy.free()


## Regression for the Phase 6e death flow: TickRunController.handle_player_died() calls end_run()
## while a spawn-warning batch and queued overflow are both in flight, so end_run() must drop both —
## a stale queued/warning entry must never spawn once the run is over and the death overlay is up.
func test_end_run_clears_pending_spawn_queue_and_warning_batch() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var fake_planner := FakeSpawnPlanner.new()
    var fake_spawner := FakeSpawner.new()
    var engine: TickEngine = autofree(TickEngine.new())

    var wc := TestWaveController.new()
    wc.setup(grid, fake_planner, fake_spawner, engine)
    var run_build := RunBuild.new()
    wc.set_run_build(run_build)

    # Wave 1 support count formula is 3; +7 pressure asks for 10 against a population cap of 3, so
    # 3 telegraph as the pending warning batch and 7 sit queued behind the cap.
    run_build.record(RunBuild.CH_FUTURE_ENEMY_COUNT, 7)
    wc.start_next_wave()

    assert_eq(wc.pending_batch_count(), 3, "the first batch should be telegraphing before its countdown resolves")
    assert_eq(wc.queue_count(), 7, "the overflow should be queued, not force-spawned")

    wc.end_run()

    assert_eq(wc.pending_batch_count(), 0, "end_run should drop the in-flight warning batch")
    assert_eq(wc.queue_count(), 0, "end_run should drop the remaining spawn queue")

    # No further enemies should spawn even if the world keeps advancing after the run is over.
    wc.trigger_world_advanced()
    wc.trigger_world_advanced()
    assert_eq(fake_spawner.spawned.size(), 0, "nothing queued or warning should spawn once the run has ended")

    for enemy in fake_spawner.spawned:
        if is_instance_valid(enemy):
            enemy.free()
