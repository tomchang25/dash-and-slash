# test_wave_controller.gd
# Tests WaveController's catalog-driven ordered-slot atomic scheduling: eligibility latching,
# whole-remaining-group admission gated on headroom and a complete EnemySpawnPlanner plan, per-slot
# warning batches, weighted expansion, level-projection wiring, boss-role signals, wave completion,
# and the shape of the production demo/endless catalog. EnemySpawnPlanner's own placement strategies
# and replacement logic are covered directly in test_enemy_spawn_planner.gd; here it is stubbed so
# these tests exercise queueing/scheduling bookkeeping, not cell geometry.
extends GutTest

const DefaultWaveCatalog := preload("res://data/waves/default_wave_catalog.tres")
const ThrustEnemyScene := preload("res://game/entities/enemies/thrust_enemy.tscn")
const SlashEnemyScene := preload("res://game/entities/enemies/slash_enemy.tscn")
const BombEnemyScene := preload("res://game/entities/enemies/bomb_enemy.tscn")
const ModeBossScene := preload("res://game/entities/enemies/mode_boss.tscn")


## Spawn planner test double: always returns a complete plan of distinct cells for the requested
## count and always revalidates true, so these tests exercise queueing/warning timing and atomic
## admission bookkeeping, not real cell geometry.
class FakeSpawnPlanner:
    extends EnemySpawnPlanner

    func plan_group_cells(_strategy: SpawnGroupDefinition.PlacementStrategy, count: int) -> Dictionary:
        var cells: Array[Vector2i] = []
        for i in count:
            cells.append(Vector2i(i, 0))
        return { "cells": cells, "anchor": Vector2i.ZERO }


    func is_spawn_cell_still_valid(_cell: Vector2i, _excluded_cells: Array[Vector2i]) -> bool:
        return true


## Spawn planner double for the no-cell requeue regression: admission always succeeds (so a batch
## can become pending), but every cell fails revalidation and no replacement exists either, matching
## a grid that went fully invalid between admission and resolution.
class NoCellSpawnPlanner:
    extends EnemySpawnPlanner

    func plan_group_cells(_strategy: SpawnGroupDefinition.PlacementStrategy, count: int) -> Dictionary:
        var cells: Array[Vector2i] = []
        for i in count:
            cells.append(Vector2i(i, 0))
        return { "cells": cells, "anchor": Vector2i.ZERO }


    func is_spawn_cell_still_valid(_cell: Vector2i, _excluded_cells: Array[Vector2i]) -> bool:
        return false


    func find_replacement_cell(_strategy: SpawnGroupDefinition.PlacementStrategy, _anchor: Vector2i, _excluded_cells: Array[Vector2i]) -> Vector2i:
        return EnemySpawnPlanner.NO_CELL


## Spawn planner double for the headroom-fits-but-no-plan-exists edge case: admission always fails to
## produce a complete plan, matching a grid with no legal placement at all.
class NoPlanSpawnPlanner:
    extends EnemySpawnPlanner

    func plan_group_cells(_strategy: SpawnGroupDefinition.PlacementStrategy, _count: int) -> Dictionary:
        var empty_cells: Array[Vector2i] = []
        return { "cells": empty_cells, "anchor": EnemySpawnPlanner.NO_CELL }


## Spawner test double: creates a bare Enemy (has the "died" signal, no scene dependencies) instead
## of instantiating a real enemy PackedScene.
class FakeSpawner:
    extends EnemySpawner

    var spawned: Array[Node] = []
    var picked_scenes: Array[PackedScene] = []


    func spawn_enemy(_picked: PackedScene, _spawn_cell: Vector2i, died_callback: Callable, pre_ready_setup: Callable = Callable()) -> Node:
        var enemy := Enemy.new()
        enemy.connect(&"died", died_callback)
        if pre_ready_setup.is_valid():
            pre_ready_setup.call(enemy)
        spawned.append(enemy)
        picked_scenes.append(_picked)
        return enemy


## Test-only subclass exposing WaveController's tick-warning spawn flow and slot state through
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


    func slot_queue_count(index: int) -> int:
        return _slot_queues[index].size()


    func total_queued() -> int:
        var total := 0
        for queue in _slot_queues:
            total += queue.size()
        return total


    func slot_eligible(index: int) -> bool:
        return _slot_eligible[index]


    func slot_living_count(index: int) -> int:
        return _slot_living_count[index]


    ## Exposes queue-entry level construction without loading an enemy scene.
    func make_queue_entry_for_test(scene: PackedScene, slot: WaveGroupSlot) -> Dictionary:
        return _make_queue_entry(scene, slot)


    ## Disconnects the test-only TickEngine signal and releases every fixture collaborator.
    func dispose_test_fixture() -> void:
        for enemy in _alive_enemies:
            if is_instance_valid(enemy):
                enemy.free()
        _alive_enemies.clear()
        _enemy_slot_index.clear()
        if _engine != null and is_instance_valid(_engine) and _engine.world_advanced.is_connected(_on_world_advanced):
            _engine.world_advanced.disconnect(_on_world_advanced)
        _catalog = null
        _grid = null
        _spawn_planner = null
        _spawner = null
        _engine = null

# -- State --

var _test_controllers: Array[TestWaveController] = []
var _debug_enabled_before_test := false

# == Test lifecycle ==


func before_each() -> void:
    _debug_enabled_before_test = Debug.enabled


## Releases every RefCounted collaborator retained by the current test's wave-controller fixtures.
func after_each() -> void:
    for controller in _test_controllers:
        controller.dispose_test_fixture()
    _test_controllers.clear()
    Debug.enabled = _debug_enabled_before_test

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
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_slot_wave()))
    assert_true(wc.advance_wave(), "advance_wave should return true")
    assert_eq(wc.get_wave_number(), 1, "first wave should be number 1")


func test_advance_wave_never_stops_without_end_run() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_slot_wave()))
    for i in 50:
        assert_true(wc.advance_wave(), "the wave loop should never stop on its own")
    assert_eq(wc.get_wave_number(), 50, "wave number should keep climbing past the ten demo waves into the endless template")


func test_end_run_stops_advance_wave() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_slot_wave()))
    wc.advance_wave()
    wc.end_run()
    assert_false(wc.advance_wave(), "advance_wave should stop once the run has ended")


func test_end_run_marks_run_over_and_reset_clears_it() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_slot_wave()))
    wc.advance_wave()
    assert_false(wc.is_run_over(), "a run is not over before end_run()")

    wc.end_run()
    assert_true(wc.is_run_over(), "end_run() should mark the run as over")

    wc.reset()
    assert_false(wc.is_run_over(), "reset() should clear the run-over flag for the next run")


func test_reset_clears_wave_number() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_slot_wave()))
    wc.advance_wave()
    wc.end_run()
    wc.reset()
    assert_eq(wc.get_wave_number(), 0, "wave number resets to 0")
    assert_true(wc.advance_wave(), "advance_wave should work again after reset")

# == Display text / boss role ==


func test_wave_display_text_for_normal_wave() -> void:
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(_make_single_slot_wave()))
    wc.advance_wave()
    assert_false(wc.is_boss_wave(), "a wave with no is_boss slot is not a boss wave")
    assert_eq(wc.get_wave_display_text(), "Wave 1")


func test_wave_display_text_for_boss_wave() -> void:
    var boss_wave := WaveDefinition.new()
    boss_wave.population_cap = 3
    boss_wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0, 0, 0, true)]
    var wc := WaveController.new()
    wc.set_catalog(_make_catalog_for_wave_one(boss_wave))
    wc.advance_wave()
    assert_true(wc.is_boss_wave(), "a wave with an is_boss slot is a boss wave")
    assert_eq(wc.get_wave_display_text(), "Wave 1: BOSS")

# == Population cap + spawn-warning queueing ==
#
# These drive the world-advanced countdown directly through TestWaveController's wrapper instead
# of a live TickEngine, since headless unit tests don't tick a real engine and this test suite
# only needs the signal-driven countdown behavior, not engine scheduling itself.


func test_full_group_spawns_atomically_and_wave_completes_after_all_die() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 3)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    var completed_calls: Array = []
    wc.normal_wave_completed.connect(
        func(wave_number: int) -> void:
            completed_calls.append(wave_number)
    )

    wc.start_next_wave()
    wc.trigger_world_advanced()

    assert_eq(fake_spawner.spawned.size(), 3, "the whole 3-member group should spawn together, not in slices")
    assert_eq(wc.alive_count(), 3)
    assert_eq(wc.slot_queue_count(0), 0, "the queue should be fully drained by the one atomic batch")
    assert_true(completed_calls.is_empty(), "wave should not complete while enemies remain alive")

    while wc.alive_count() > 0:
        var dying: Node = wc.first_alive()
        dying.died.emit(dying)

    assert_eq(completed_calls.size(), 1, "wave should complete exactly once, after the batch and its population are gone")
    assert_eq(completed_calls[0], 1, "completed wave number should be 1")

    _free_spawned(fake_spawner)


func test_spawn_warning_does_not_resolve_before_its_countdown_elapses() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 2)]
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
    wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_eq(fake_spawner.spawned.size(), 1, "a zero-tick slot should resolve immediately without a telegraph pause")
    assert_eq(wc.pending_batch_count(), 0, "no batch should remain pending after an immediate resolve")

    _free_spawned(fake_spawner)


func test_zero_warning_ticks_group_with_no_valid_cell_requeues_without_recursing() -> void:
    var fixture := _make_test_controller_with_spawn_planner(NoCellSpawnPlanner.new())
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_eq(fake_spawner.spawned.size(), 0, "an invalid zero-warning batch must not spawn")
    assert_eq(wc.pending_batch_count(), 0, "the failed immediate batch must not remain pending")
    assert_eq(wc.slot_queue_count(0), 1, "the failed entry must remain queued for a later retry")

    wc.trigger_world_advanced()
    assert_eq(wc.slot_queue_count(0), 1, "a later retry must return without recursive scheduling")


func test_end_run_clears_pending_spawn_queue_and_warning_batch() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 3, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 1)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_eq(wc.pending_batch_count(), 3, "the whole 3-member batch should be telegraphing before its countdown resolves")

    wc.end_run()

    assert_eq(wc.pending_batch_count(), 0, "end_run should drop the in-flight warning batch")
    assert_eq(wc.total_queued(), 0, "end_run should drop every slot's remaining queue")

    wc.trigger_world_advanced()
    assert_eq(fake_spawner.spawned.size(), 0, "nothing queued or warning should spawn once the run has ended")

    _free_spawned(fake_spawner)

# == Atomic group admission ==


func test_group_that_exceeds_current_headroom_waits_without_partial_spawn() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var slot_a := _make_fixed_slot(_make_placeholder_scene(), 2, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)
    var slot_b := _make_fixed_slot(_make_placeholder_scene(), 2, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [slot_a, slot_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_eq(fake_spawner.spawned.size(), 2, "only slot A's two-member batch fits the cap of 3")
    assert_eq(wc.slot_queue_count(1), 2, "slot B must wait entirely; a headroom of 1 can never fit its 2-member batch")

    var dying: Node = wc.first_alive()
    dying.died.emit(dying)

    assert_eq(fake_spawner.spawned.size(), 4, "freeing enough headroom lets slot B's whole batch admit at once")
    assert_eq(wc.slot_queue_count(1), 0)

    _free_spawned(fake_spawner)


func test_group_with_no_complete_plan_waits_without_telegraph_or_partial_spawn() -> void:
    var fixture := _make_test_controller_with_spawn_planner(NoPlanSpawnPlanner.new())
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var wave := WaveDefinition.new()
    wave.population_cap = 5
    wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 2, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 1)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_eq(fake_spawner.spawned.size(), 0, "no complete plan means the group must not spawn at all")
    assert_eq(wc.pending_batch_count(), 0, "a plan failure must not create a pending telegraph batch")
    assert_eq(wc.slot_queue_count(0), 2, "the whole group remains queued for a later retry")

# == Ordered slot eligibility ==


func test_previous_group_cleared_gates_the_next_group() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var slot_a := _make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)
    var slot_b := _make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.PREVIOUS_GROUP_CLEARED, 0)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [slot_a, slot_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()
    assert_eq(fake_spawner.spawned.size(), 1, "only slot A's entry should have spawned so far")
    assert_false(wc.slot_eligible(1), "slot B should remain blocked while slot A's member is alive")

    var dying: Node = wc.first_alive()
    dying.died.emit(dying)

    assert_true(wc.slot_eligible(1), "slot B becomes eligible once slot A's living count hits zero")
    assert_eq(fake_spawner.spawned.size(), 2, "slot B's zero-tick entry should spawn immediately once eligible")

    _free_spawned(fake_spawner)


func test_previous_group_survivors_at_most_gates_the_next_group() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var slot_a := _make_fixed_slot(_make_placeholder_scene(), 3, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)
    var slot_b := _make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.PREVIOUS_GROUP_SURVIVORS_AT_MOST, 0, 0, 1)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [slot_a, slot_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()
    assert_eq(fake_spawner.spawned.size(), 3, "slot A's three entries should all spawn under the cap")
    assert_false(wc.slot_eligible(1), "slot B blocked while slot A has more than 1 living member")

    var first: Node = wc.first_alive()
    first.died.emit(first)
    assert_false(wc.slot_eligible(1), "slot B still blocked at 2 living members against a threshold of 1")

    var second: Node = wc.first_alive()
    second.died.emit(second)
    assert_true(wc.slot_eligible(1), "slot B becomes eligible once slot A's living count drops to the threshold")
    assert_eq(fake_spawner.spawned.size(), 4, "slot B's entry spawns once eligible")

    _free_spawned(fake_spawner)


func test_immediate_overlap_groups_are_all_eligible_at_wave_start() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var slot_a := _make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)
    var slot_b := _make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [slot_a, slot_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    assert_true(wc.slot_eligible(0), "the first slot is always eligible by position")
    assert_true(wc.slot_eligible(1), "a chained immediate-overlap slot is eligible from wave start")
    assert_eq(fake_spawner.spawned.size(), 2, "both single-entry slots should drain under the cap in authored order")

    _free_spawned(fake_spawner)


## Regression: once a slot latches eligible, it must never be revoked even as its predecessor's
## living count keeps changing afterward. Atomic admission means a slot's whole queue is consumed in
## one shot, so a predecessor can never gain new living members once its queue is spent; the latch
## must hold through that ongoing decline regardless.
func test_group_eligibility_is_never_revoked() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var slot_a := _make_fixed_slot(_make_placeholder_scene(), 3, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)
    var slot_b := _make_fixed_slot(_make_placeholder_scene(), 2, WaveGroupSlot.StartCondition.PREVIOUS_GROUP_SURVIVORS_AT_MOST, 0, 0, 2)
    var wave := WaveDefinition.new()
    wave.population_cap = 5
    wave.slots = [slot_a, slot_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()
    assert_eq(fake_spawner.spawned.size(), 3, "slot A's whole 3-member group admits atomically")
    assert_eq(wc.slot_living_count(0), 3)
    assert_false(wc.slot_eligible(1), "slot B blocked while slot A has more than the threshold of 2 living")

    var dying: Node = wc.first_alive()
    dying.died.emit(dying)

    assert_true(wc.slot_eligible(1), "slot B latches eligible once slot A's living count drops to the threshold")
    assert_eq(fake_spawner.spawned.size(), 5, "slot B's whole group admits once eligible and within headroom")

    var another_dying: Node = wc.first_alive()
    another_dying.died.emit(another_dying)

    assert_true(wc.slot_eligible(1), "the latch must hold even as slot A's living count keeps falling")

    _free_spawned(fake_spawner)


func test_wave_completes_only_after_all_groups_and_warnings_are_exhausted() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var slot_a := _make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)
    var slot_b := _make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.PREVIOUS_GROUP_CLEARED, 0)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [slot_a, slot_b]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    var completed_calls: Array = []
    wc.normal_wave_completed.connect(func(n: int) -> void: completed_calls.append(n))

    wc.start_next_wave()
    assert_true(completed_calls.is_empty())

    var a_enemy: Node = wc.first_alive()
    a_enemy.died.emit(a_enemy)
    assert_true(completed_calls.is_empty(), "wave should not complete while slot B's member is alive")

    var b_enemy: Node = wc.first_alive()
    b_enemy.died.emit(b_enemy)
    assert_eq(completed_calls.size(), 1, "wave completes once every slot's queue and living members are exhausted")

    _free_spawned(fake_spawner)

# == Wave 1 debug Boss ==


func test_debug_wave_one_boss_spawns_after_authored_enemies_and_delays_completion() -> void:
    Debug.enabled = true
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 1)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))
    wc.set_debug_wave_one_boss_scene(ModeBossScene)

    var completed_calls: Array = []
    var boss_spawned_count := [0]
    var boss_cleared_count := [0]
    wc.normal_wave_completed.connect(func(n: int) -> void: completed_calls.append(n))
    wc.boss_spawned.connect(func(_boss: Node) -> void: boss_spawned_count[0] += 1)
    wc.boss_cleared.connect(func() -> void: boss_cleared_count[0] += 1)

    wc.start_next_wave()
    wc.trigger_world_advanced()
    var authored_enemy := wc.first_alive()
    authored_enemy.died.emit(authored_enemy)

    assert_eq(fake_spawner.spawned.size(), 2, "clearing authored Wave 1 enemies should append one debug Boss")
    assert_eq(fake_spawner.picked_scenes[1], ModeBossScene)
    assert_eq(wc.alive_count(), 1)
    assert_eq(boss_spawned_count[0], 1)
    assert_true(completed_calls.is_empty(), "Wave 1 must stay active until the debug Boss dies")

    var debug_boss := wc.first_alive()
    debug_boss.died.emit(debug_boss)

    assert_eq(boss_cleared_count[0], 1)
    assert_eq(completed_calls, [1], "killing the debug Boss should complete Wave 1 normally")
    _free_spawned(fake_spawner)


func test_wave_one_debug_boss_never_spawns_while_debug_is_disabled() -> void:
    Debug.enabled = false
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 1)]
    wc.set_catalog(_make_catalog_for_wave_one(wave))
    wc.set_debug_wave_one_boss_scene(ModeBossScene)

    var completed_calls: Array = []
    wc.normal_wave_completed.connect(func(n: int) -> void: completed_calls.append(n))

    wc.start_next_wave()
    wc.trigger_world_advanced()
    var authored_enemy := wc.first_alive()
    authored_enemy.died.emit(authored_enemy)

    assert_eq(fake_spawner.spawned.size(), 1)
    assert_eq(completed_calls, [1], "release-safe flow should complete without injecting the debug Boss")
    _free_spawned(fake_spawner)

# == Boss role ==


func test_boss_spawned_and_boss_cleared_signals_fire_for_the_is_boss_group() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var boss_slot := _make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0, 0, 0, true)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [boss_slot]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    var spawned_count := [0]
    var cleared_count := [0]
    wc.boss_spawned.connect(func(_boss: Node) -> void: spawned_count[0] += 1)
    wc.boss_cleared.connect(func() -> void: cleared_count[0] += 1)

    wc.start_next_wave()
    assert_eq(spawned_count[0], 1, "boss_spawned should fire for the is_boss slot's member")

    var boss: Node = wc.first_alive()
    boss.died.emit(boss)
    assert_eq(cleared_count[0], 1, "boss_cleared should fire when the boss dies")

    _free_spawned(fake_spawner)

# == Weighted expansion / level projection ==


## The authored Small group is the roster's only weighted composition; every other group is fixed.
func test_default_catalog_weighted_groups_use_only_active_small_roles() -> void:
    for wave_index in DefaultWaveCatalog.demo_waves.size():
        var wave := DefaultWaveCatalog.demo_waves[wave_index]
        _assert_weighted_groups_use_active_small_roles(wave)
    _assert_weighted_groups_use_active_small_roles(DefaultWaveCatalog.endless_template)


func test_weighted_group_draws_exact_total_count() -> void:
    var fixture := _make_test_controller()
    var wc: TestWaveController = fixture[0]
    var fake_spawner: FakeSpawner = fixture[1]

    var group := SpawnGroupDefinition.new()
    group.composition_mode = SpawnGroupDefinition.CompositionMode.WEIGHTED
    group.weighted_total_count = 5
    group.entries = [_make_entry(_make_placeholder_scene(), 0, 1.0), _make_entry(_make_placeholder_scene(), 0, 1.0)]
    var slot := WaveGroupSlot.new()
    slot.spawn_group = group
    slot.start_condition = WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP
    slot.warning_ticks = 0
    var wave := WaveDefinition.new()
    wave.population_cap = 10
    wave.slots = [slot]

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

    var slot := _make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0, 3)
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [slot]
    wc.set_catalog(_make_catalog_for_wave_one(wave))

    wc.start_next_wave()

    var queue_entry := wc.make_queue_entry_for_test(_make_placeholder_scene(), slot)
    var level: int = queue_entry["level"]
    var guard_profile := GuardProfile.new()
    guard_profile.base_guard = 32
    var enemy_data := EnemyData.new()
    enemy_data.guard_profile = guard_profile
    var projection := _make_profile().project(enemy_data, level, wc.get_wave_number())

    assert_eq(level, 4, "level should be wave_number (1) plus the slot's level_offset (3)")
    assert_eq(projection.max_guard, 32, "slot level_offset must not increase the Wave 1 Small Guard profile")

    _free_spawned(fake_spawner)

# == Production catalog shape ==


## Wave-by-wave structural shape check against the authored demo schedule: population cap, ordered
## slot count, and each slot's placement strategy, matching the design's explicit wave table.
func test_default_catalog_demo_waves_match_the_authored_schedule() -> void:
    var ring := SpawnGroupDefinition.PlacementStrategy.PLAYER_RING
    var cluster := SpawnGroupDefinition.PlacementStrategy.ANCHOR_CLUSTER
    var scatter := SpawnGroupDefinition.PlacementStrategy.SCATTER
    var expectations := [
        [3, [ring]],
        [2, [cluster]],
        [5, [cluster]],
        [2, [scatter]],
        [5, [cluster]],
        [6, [ring, cluster, scatter]],
        [7, [cluster, ring, scatter]],
        [8, [ring, cluster, scatter, scatter]],
        [9, [scatter, cluster, ring, scatter]],
        [1, [scatter]],
    ]
    for i in expectations.size():
        var wave: WaveDefinition = DefaultWaveCatalog.demo_waves[i]
        var expected: Array = expectations[i]
        assert_eq(wave.population_cap, expected[0], "wave %d population_cap" % (i + 1))
        var expected_strategies: Array = expected[1]
        assert_eq(wave.slots.size(), expected_strategies.size(), "wave %d slot count" % (i + 1))
        for j in expected_strategies.size():
            assert_eq(wave.slots[j].spawn_group.placement_strategy, expected_strategies[j], "wave %d slot %d placement_strategy" % [i + 1, j])


func test_default_catalog_bomb_group_first_appears_at_wave_eight() -> void:
    for i in 7:
        var wave: WaveDefinition = DefaultWaveCatalog.demo_waves[i]
        for slot in wave.slots:
            for entry in slot.spawn_group.entries:
                assert_ne(entry.enemy_scene, BombEnemyScene, "Bomb must not appear before wave 8 (wave %d)" % (i + 1))
    var wave8: WaveDefinition = DefaultWaveCatalog.demo_waves[7]
    var bomb_slot: WaveGroupSlot = wave8.slots[3]
    assert_eq(bomb_slot.spawn_group.entries[0].enemy_scene, BombEnemyScene)


func test_default_catalog_wave_ten_is_boss_only() -> void:
    var wave: WaveDefinition = DefaultWaveCatalog.demo_waves[9]
    assert_eq(wave.population_cap, 1)
    assert_eq(wave.slots.size(), 1)
    var boss_slot: WaveGroupSlot = wave.slots[0]
    assert_true(boss_slot.is_boss)
    assert_eq(boss_slot.level_offset, 3)
    assert_eq(boss_slot.warning_ticks, 2)
    assert_eq(boss_slot.spawn_group.entries[0].enemy_scene, ModeBossScene)


func test_default_catalog_endless_template_uses_fixed_cap_of_ten_and_wave_nine_grammar() -> void:
    var endless: WaveDefinition = DefaultWaveCatalog.endless_template
    var wave9: WaveDefinition = DefaultWaveCatalog.demo_waves[8]
    assert_eq(endless.population_cap, 10)
    assert_eq(endless.slots.size(), wave9.slots.size())
    for i in endless.slots.size():
        assert_eq(endless.slots[i].spawn_group, wave9.slots[i].spawn_group, "endless slot %d must reuse the same group resource as wave 9" % i)
        assert_eq(endless.slots[i].start_condition, wave9.slots[i].start_condition)
        assert_eq(endless.slots[i].warning_ticks, wave9.slots[i].warning_ticks)

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


## Returns a production scene because FakeSpawner records wave data but never instantiates it.
func _make_placeholder_scene() -> PackedScene:
    return ThrustEnemyScene


func _assert_weighted_groups_use_active_small_roles(wave: WaveDefinition) -> void:
    for slot in wave.slots:
        var group := slot.spawn_group
        if group.composition_mode != SpawnGroupDefinition.CompositionMode.WEIGHTED:
            continue
        for entry in group.entries:
            assert_true(entry.enemy_scene in [ThrustEnemyScene, SlashEnemyScene])


func _make_entry(scene: PackedScene, count: int = 0, weight: float = 0.0) -> WaveCompositionEntry:
    var entry := WaveCompositionEntry.new()
    entry.enemy_scene = scene
    entry.count = count
    entry.weight = weight
    return entry


func _make_fixed_slot(
        scene: PackedScene,
        count: int,
        start_condition := WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP,
        warning_ticks := 1,
        level_offset := 0,
        survivor_threshold := 0,
        is_boss := false,
) -> WaveGroupSlot:
    var group := SpawnGroupDefinition.new()
    group.composition_mode = SpawnGroupDefinition.CompositionMode.FIXED
    group.placement_strategy = SpawnGroupDefinition.PlacementStrategy.SCATTER
    group.entries = [_make_entry(scene, count)]

    var slot := WaveGroupSlot.new()
    slot.spawn_group = group
    slot.start_condition = start_condition
    slot.survivor_threshold = survivor_threshold
    slot.warning_ticks = warning_ticks
    slot.level_offset = level_offset
    slot.is_boss = is_boss
    return slot


func _make_profile() -> EnemyLevelProgressionProfile:
    var curve := EnemyStatGrowthCurve.new()
    curve.standard_exponent = 1.0
    curve.lethal_exponent = 1.0
    var profile := EnemyLevelProgressionProfile.new()
    profile.hp_curve = curve
    profile.damage_curve = curve
    profile.defense_curve = curve
    return profile


func _make_single_slot_wave() -> WaveDefinition:
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.slots = [_make_fixed_slot(_make_placeholder_scene(), 1, WaveGroupSlot.StartCondition.IMMEDIATE_OVERLAP, 0)]
    return wave


## Builds a valid ten-demo-wave catalog whose wave 1 is the given wave; every other demo wave and
## the endless template reuse a trivial one-entry fixed slot so the catalog stays valid without
## adding unrelated coverage noise.
func _make_catalog_for_wave_one(wave: WaveDefinition) -> WaveCatalog:
    var catalog := WaveCatalog.new()
    var demo_waves: Array[WaveDefinition] = [wave]
    for i in WaveCatalog.DEMO_WAVE_COUNT - 1:
        demo_waves.append(_make_single_slot_wave())
    catalog.demo_waves = demo_waves
    catalog.endless_template = _make_single_slot_wave()
    catalog.progression_profile = _make_profile()
    return catalog
