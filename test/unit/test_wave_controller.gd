# test_wave_controller.gd
# Tests EnemySpawnPlanner revalidation and WaveController's catalog-driven ordered-group
# scheduling: eligibility latching, per-group warning batches, population-cap headroom, weighted
# expansion, level-projection wiring, boss-role signals, and wave completion.
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


## Spawn planner double for the no-cell requeue regression: every candidate and replacement is
## invalid, matching a temporarily full grid without depending on occupancy setup.
class NoCellSpawnPlanner:
    extends EnemySpawnPlanner

    func choose_enemy_spawn_cell(_index: int, _spawn_count: int, _reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
        return Vector2i.ZERO


    func is_spawn_cell_still_valid(_cell: Vector2i, _reserved_spawn_cells: Array[Vector2i]) -> bool:
        return false


    func find_valid_spawn_replacement(_index: int, _spawn_count: int, _reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
        return EnemySpawnPlanner.NO_CELL


## Spawner test double: creates a bare Enemy (has the "died" signal, no scene dependencies) instead
## of instantiating a real enemy PackedScene.
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


## Test-only subclass exposing WaveController's tick-warning spawn flow and group state through
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


    func pending_batch_count() -> int:
        return _pending_batch.size()


    func group_queue_count(index: int) -> int:
        return _group_queues[index].size()


    func total_queued() -> int:
        var total := 0
        for queue in _group_queues:
            total += queue.size()
        return total


    func group_eligible(index: int) -> bool:
        return _group_eligible[index]


    func group_living_count(index: int) -> int:
        return _group_living_count[index]


    ## Exposes queue-entry level construction without loading an enemy scene.
    func make_queue_entry_for_test(scene: PackedScene, group: WaveGroupDefinition) -> Dictionary:
        return _make_queue_entry(scene, group)


    ## Disconnects the test-only TickEngine signal and releases every fixture collaborator.
    func dispose_test_fixture() -> void:
        for enemy in _alive_enemies:
            if is_instance_valid(enemy):
                enemy.free()
        _alive_enemies.clear()
        _enemy_group_index.clear()
        if _engine != null and is_instance_valid(_engine) and _engine.world_advanced.is_connected(_on_world_advanced):
            _engine.world_advanced.disconnect(_on_world_advanced)
        _catalog = null
        _grid = null
        _spawn_planner = null
        _spawner = null
        _engine = null

# -- State --

var _test_controllers: Array[TestWaveController] = []

# == Test lifecycle ==


## Releases every RefCounted collaborator retained by the current test's wave-controller fixtures.
func after_each() -> void:
    for controller in _test_controllers:
        controller.dispose_test_fixture()
    _test_controllers.clear()

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


func test_advance_wave_blocked_before_catalog_is_set() -> void:
    var wc := WaveController.new()
    assert_false(wc.advance_wave(), "advance_wave should refuse to run before a catalog is set")


func test_set_catalog_null_reports_dev_error_and_blocks_advance() -> void:
    var wc := WaveController.new()
    wc.set_catalog(null)
    assert_push_error("missing or invalid WaveCatalog")
    assert_false(wc.advance_wave(), "advance_wave should refuse to run with an invalid catalog")


func test_advance_wave_moves_to_wave_one() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_group_wave()))
    assert_true(wc.advance_wave(), "advance_wave should return true")
    assert_eq(wc.get_wave_number(), 1, "first wave should be number 1")


func test_advance_wave_never_stops_without_end_run() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_group_wave()))
    for i in 50:
        assert_true(wc.advance_wave(), "the wave loop should never stop on its own")
    assert_eq(wc.get_wave_number(), 50, "wave number should keep climbing past the ten demo waves into the endless template")


func test_end_run_stops_advance_wave() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_group_wave()))
    wc.advance_wave()
    wc.end_run()
    assert_false(wc.advance_wave(), "advance_wave should stop once the run has ended")


func test_end_run_marks_run_over_and_reset_clears_it() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_group_wave()))
    wc.advance_wave()
    assert_false(wc.is_run_over(), "a run is not over before end_run()")

    wc.end_run()
    assert_true(wc.is_run_over(), "end_run() should mark the run as over")

    wc.reset()
    assert_false(wc.is_run_over(), "reset() should clear the run-over flag for the next run")


func test_reset_clears_wave_number() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_group_wave()))
    wc.advance_wave()
    wc.end_run()
    wc.reset()
    assert_eq(wc.get_wave_number(), 0, "wave number resets to 0")
    assert_true(wc.advance_wave(), "advance_wave should work again after reset")

# == Display text / boss role ==


func test_wave_display_text_for_normal_wave() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_group_wave()))
    wc.advance_wave()
    assert_false(wc.is_milestone_wave(), "a wave with no is_boss group is not a milestone wave")
    assert_eq(wc.get_wave_display_text(), "Wave 1")


func test_wave_display_text_for_boss_wave() -> void:
    var boss_wave := WaveDefinition.new()
    boss_wave.population_cap = 3
    boss_wave.groups = [_make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0, 0, 0, true)]
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(boss_wave))
    wc.advance_wave()
    assert_true(wc.is_milestone_wave(), "a wave with an is_boss group is a milestone wave")
    assert_eq(wc.get_wave_display_text(), "Wave 1: BOSS")

# == Population cap + spawn-warning queueing ==
#
# These drive the world-advanced countdown directly through TestWaveController's wrapper instead
# of a live TickEngine, since headless unit tests don't tick a real engine and this test suite
# only needs the signal-driven countdown behavior, not engine scheduling itself.


func test_group_drains_under_population_cap() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [_make_fixed_group(_make_placeholder_scene(), 10)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    var completed_calls: Array = []
    wc.normal_wave_completed.connect(
        func(wave_number: int, is_milestone: bool) -> void:
            completed_calls.append([wave_number, is_milestone])
    )

    wc.start_next_wave()
    wc.trigger_world_advanced()

    assert_eq(fake_spawner.spawned.size(), 3, "only cap-worth of enemies should spawn immediately")
    assert_eq(wc.alive_count(), 3, "alive count should sit at the population cap")
    assert_eq(wc.group_queue_count(0), 7, "the remaining 7 entries should be queued, not force-spawned")
    assert_true(completed_calls.is_empty(), "wave should not complete while entries remain queued or alive")

    for i in 7:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)
        wc.trigger_world_advanced()

    assert_eq(wc.group_queue_count(0), 0, "queue should be fully drained")
    assert_eq(wc.alive_count(), 3, "population stays at cap while draining")
    assert_true(completed_calls.is_empty(), "wave still should not complete while enemies remain alive")

    while wc.alive_count() > 0:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)

    assert_eq(completed_calls.size(), 1, "wave should complete exactly once, after queue and population are both empty")
    assert_eq(completed_calls[0][0], 1, "completed wave number should be 1")
    assert_false(completed_calls[0][1], "a single non-boss group is not a milestone wave")

    _free_spawned(fake_spawner)


func test_spawn_warning_does_not_resolve_before_its_countdown_elapses() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [_make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 2)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()
    assert_eq(fake_spawner.spawned.size(), 0, "the batch should only telegraph, not spawn, when scheduled")

    wc.trigger_world_advanced()
    assert_eq(fake_spawner.spawned.size(), 0, "one world advance should not resolve a two-tick warning")

    wc.trigger_world_advanced()
    assert_eq(fake_spawner.spawned.size(), 1, "the second world advance resolves the warning")

    _free_spawned(fake_spawner)


func test_zero_warning_ticks_group_spawns_immediately_without_telegraph() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [_make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_eq(fake_spawner.spawned.size(), 1, "a zero-tick group should resolve immediately without a telegraph pause")
    assert_eq(wc.pending_batch_count(), 0, "no batch should remain pending after an immediate resolve")

    _free_spawned(fake_spawner)


func test_zero_warning_ticks_group_with_no_valid_cell_requeues_without_recursing() -> void:
    var fixture := _make_test_controller_with_spawn_planner(NoCellSpawnPlanner.new())
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [_make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_eq(fake_spawner.spawned.size(), 0, "an invalid zero-warning batch must not spawn")
    assert_eq(wc.pending_batch_count(), 0, "the failed immediate batch must not remain pending")
    assert_eq(wc.group_queue_count(0), 1, "the failed entry must remain queued for a later retry")

    wc.trigger_world_advanced()
    assert_eq(wc.group_queue_count(0), 1, "a later retry must return without recursive scheduling")


func test_end_run_clears_pending_spawn_queue_and_warning_batch() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [_make_fixed_group(_make_placeholder_scene(), 10, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 1)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_eq(wc.pending_batch_count(), 3, "the first batch should be telegraphing before its countdown resolves")
    assert_eq(wc.total_queued(), 7, "the overflow should be queued, not force-spawned")

    wc.end_run()

    assert_eq(wc.pending_batch_count(), 0, "end_run should drop the in-flight warning batch")
    assert_eq(wc.total_queued(), 0, "end_run should drop every group's remaining queue")

    wc.trigger_world_advanced()
    assert_eq(fake_spawner.spawned.size(), 0, "nothing queued or warning should spawn once the run has ended")

    _free_spawned(fake_spawner)

# == Ordered group eligibility ==


func test_previous_group_cleared_gates_the_next_group() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var group_a := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0)
    var group_b := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.PREVIOUS_GROUP_CLEARED, 0)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [group_a, group_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()
    assert_eq(fake_spawner.spawned.size(), 1, "only group A's entry should have spawned so far")
    assert_false(wc.group_eligible(1), "group B should remain blocked while group A's member is alive")

    var dying: Node = wc.first_alive()
    dying.died.emit(dying)

    assert_true(wc.group_eligible(1), "group B becomes eligible once group A's living count hits zero")
    assert_eq(fake_spawner.spawned.size(), 2, "group B's zero-tick entry should spawn immediately once eligible")

    _free_spawned(fake_spawner)


func test_previous_group_survivors_at_most_gates_the_next_group() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var group_a := _make_fixed_group(_make_placeholder_scene(), 3, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0)
    var group_b := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.PREVIOUS_GROUP_SURVIVORS_AT_MOST, 0, 0, 1)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [group_a, group_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()
    assert_eq(fake_spawner.spawned.size(), 3, "group A's three entries should all spawn under the cap")
    assert_false(wc.group_eligible(1), "group B blocked while group A has more than 1 living member")

    var first: Node = wc.first_alive()
    first.died.emit(first)
    assert_false(wc.group_eligible(1), "group B still blocked at 2 living members against a threshold of 1")

    var second: Node = wc.first_alive()
    second.died.emit(second)
    assert_true(wc.group_eligible(1), "group B becomes eligible once group A's living count drops to the threshold")
    assert_eq(fake_spawner.spawned.size(), 4, "group B's entry spawns once eligible")

    _free_spawned(fake_spawner)


func test_immediate_overlap_groups_are_all_eligible_at_wave_start() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var group_a := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0)
    var group_b := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [group_a, group_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_true(wc.group_eligible(0), "the first group is always eligible by position")
    assert_true(wc.group_eligible(1), "a chained immediate-overlap group is eligible from wave start")
    assert_eq(fake_spawner.spawned.size(), 2, "both single-entry groups should drain under the cap in authored order")

    _free_spawned(fake_spawner)


## Regression: once a group latches eligible, it must never be revoked even if its predecessor's
## living count later climbs back above the threshold that first unlocked it.
func test_group_eligibility_is_never_revoked() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var group_a := _make_fixed_group(_make_placeholder_scene(), 4, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0)
    var group_b := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.PREVIOUS_GROUP_SURVIVORS_AT_MOST, 0, 0, 1)
    var wave := WaveDefinition.new()
    wave.population_cap = 2
    wave.groups = [group_a, group_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()
    assert_eq(fake_spawner.spawned.size(), 2, "only cap-worth of group A should spawn immediately")
    assert_eq(wc.group_living_count(0), 2)
    assert_false(wc.group_eligible(1))

    # Freeing one headroom slot drops group A's living count to 1 (<= threshold 1), latching group B
    # eligible; the scheduler then still fills that freed slot from group A first (earlier in authored
    # order), bringing group A's living count back to 2 — group B must stay eligible regardless.
    var dying: Node = wc.first_alive()
    dying.died.emit(dying)

    assert_true(wc.group_eligible(1), "once eligible, group B must stay eligible even as group A's living count rises again")
    assert_eq(wc.group_living_count(0), 2, "group A reclaimed the freed headroom before group B, per authored order")
    assert_eq(wc.group_queue_count(1), 1, "group B remains queued until it actually gets headroom")

    _free_spawned(fake_spawner)


func test_wave_completes_only_after_all_groups_and_warnings_are_exhausted() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var group_a := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0)
    var group_b := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.PREVIOUS_GROUP_CLEARED, 0)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [group_a, group_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    var completed_calls: Array = []
    wc.normal_wave_completed.connect(func(n: int, m: bool) -> void: completed_calls.append([n, m]))

    wc.start_next_wave()
    assert_true(completed_calls.is_empty())

    var a_enemy: Node = wc.first_alive()
    a_enemy.died.emit(a_enemy)
    assert_true(completed_calls.is_empty(), "wave should not complete while group B's member is alive")

    var b_enemy: Node = wc.first_alive()
    b_enemy.died.emit(b_enemy)
    assert_eq(completed_calls.size(), 1, "wave completes once every group's queue and living members are exhausted")

    _free_spawned(fake_spawner)

# == Boss role ==


func test_boss_spawned_and_boss_cleared_signals_fire_for_the_is_boss_group() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var boss_group := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0, 0, 0, true)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [boss_group]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    var spawned_count := [0]
    var cleared_count := [0]
    wc.boss_spawned.connect(func(_boss: Node) -> void: spawned_count[0] += 1)
    wc.boss_cleared.connect(func() -> void: cleared_count[0] += 1)

    wc.start_next_wave()
    assert_eq(spawned_count[0], 1, "boss_spawned should fire for the is_boss group's member")

    var boss: Node = wc.first_alive()
    boss.died.emit(boss)
    assert_eq(cleared_count[0], 1, "boss_cleared should fire when the boss dies")

    _free_spawned(fake_spawner)

# == Weighted expansion / level projection ==


func test_weighted_group_draws_exact_total_count() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var group := WaveGroupDefinition.new()
    group.composition_mode = WaveGroupDefinition.CompositionMode.WEIGHTED
    group.start_condition = WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP
    group.warning_ticks = 0
    group.weighted_total_count = 5
    group.entries = [_make_entry(_make_placeholder_scene(), 0, 1.0), _make_entry(_make_placeholder_scene(), 0, 1.0)]
    var wave := WaveDefinition.new()
    wave.population_cap = 10
    wave.groups = [group]

    wc.set_wave_rng_seed(1)
    wc.set_catalog(_make_catalog_for_wave_one(wave))
    wc.start_next_wave()

    assert_eq(fake_spawner.spawned.size(), 5, "weighted mode should draw exactly weighted_total_count entries")

    _free_spawned(fake_spawner)


## Ties the queued level to the wave-plus-offset formula and verifies Guard stays on the base wave.
func test_level_projection_uses_wave_number_plus_group_level_offset() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var group := _make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0, 3)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [group]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    var queue_entry := wc.make_queue_entry_for_test(_make_placeholder_scene(), group)
    var level: int = queue_entry["level"]
    var guard_profile := GuardProfile.new()
    guard_profile.base_guard = 32
    var enemy_data := EnemyData.new()
    enemy_data.guard_profile = guard_profile
    var projection := _make_profile().project(enemy_data, level, wc.get_wave_number())

    assert_eq(level, 4, "level should be wave_number (1) plus the group's level_offset (3)")
    assert_eq(projection.max_guard, 32, "group level_offset must not increase the Wave 1 Small Guard profile")

    _free_spawned(fake_spawner)

# == Test helpers ==


## Returns [TestWaveController, FakeSpawner] wired against a fresh headless grid/engine fixture.
func _make_test_controller() -> Array:
    return _make_test_controller_with_spawn_planner(FakeSpawnPlanner.new())


func _make_test_controller_with_spawn_planner(spawn_planner: EnemySpawnPlanner) -> Array:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(4, 4)
    grid.starting_land_size = Vector2i(4, 4)
    grid.generate_grid()

    var fake_spawner := FakeSpawner.new()
    var engine: TickEngine = autofree(TickEngine.new())

    var wc := TestWaveController.new()
    wc.setup(grid, spawn_planner, fake_spawner, engine)
    _test_controllers.append(wc)
    return [wc, fake_spawner]


func _free_spawned(fake_spawner: FakeSpawner) -> void:
    for enemy in fake_spawner.spawned:
        if is_instance_valid(enemy):
            enemy.free()


## Returns an inert scene because FakeSpawner records wave data but never instantiates it.
func _make_placeholder_scene() -> PackedScene:
    return PackedScene.new()


func _make_entry(scene: PackedScene, count: int = 0, weight: float = 0.0) -> WaveCompositionEntry:
    var entry := WaveCompositionEntry.new()
    entry.enemy_scene = scene
    entry.count = count
    entry.weight = weight
    return entry


func _make_fixed_group(
        scene: PackedScene,
        count: int,
        start_condition := WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP,
        warning_ticks := 1,
        level_offset := 0,
        survivor_threshold := 0,
        is_boss := false,
) -> WaveGroupDefinition:
    var group := WaveGroupDefinition.new()
    group.composition_mode = WaveGroupDefinition.CompositionMode.FIXED
    group.start_condition = start_condition
    group.survivor_threshold = survivor_threshold
    group.warning_ticks = warning_ticks
    group.level_offset = level_offset
    group.is_boss = is_boss
    group.entries = [_make_entry(scene, count)]
    return group


func _make_profile() -> EnemyLevelProgressionProfile:
    var curve := EnemyStatGrowthCurve.new()
    curve.standard_exponent = 1.0
    curve.lethal_exponent = 1.0
    var profile := EnemyLevelProgressionProfile.new()
    profile.hp_curve = curve
    profile.damage_curve = curve
    profile.defense_curve = curve
    return profile


func _make_single_group_wave() -> WaveDefinition:
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [_make_fixed_group(_make_placeholder_scene(), 1, WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP, 0)]
    return wave


## Builds a valid ten-demo-wave catalog whose wave 1 is the given wave; every other demo wave and
## the endless template reuse a trivial one-entry fixed group so the catalog stays valid without
## adding unrelated coverage noise.
func _make_catalog_for_wave_one(wave: WaveDefinition) -> WaveCatalog:
    var catalog := WaveCatalog.new()
    var demo_waves: Array[WaveDefinition] = [wave]
    for i in WaveCatalog.DEMO_WAVE_COUNT - 1:
        demo_waves.append(_make_single_group_wave())
    catalog.demo_waves = demo_waves
    catalog.endless_template = _make_single_group_wave()
    catalog.progression_profile = _make_profile()
    return catalog
