# test_enemy_tick_runtime.gd
# Covers EnemyTickRuntime's shared committed-attack snapshot: footprint, countdown, and outgoing
# damage are locked together by commit_attack() and only clear_attack() drops them, so detonation,
# inspection, and cancellation always agree on one immutable combat-cycle snapshot.
extends GutTest

func test_commit_attack_stores_tiles_ticks_and_damage_together() -> void:
    var runtime := EnemyTickRuntime.new()
    var tiles: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]

    runtime.commit_attack(tiles, 2, 12.5)

    assert_eq(runtime.attack_tiles(), tiles)
    assert_eq(runtime.attack_ticks(), 2)
    assert_eq(runtime.attack_damage(), 12.5)
    assert_true(runtime.has_pending_attack())
    assert_true(runtime.has_committed_snapshot())


func test_attack_damage_defaults_to_zero_before_any_commit() -> void:
    var runtime := EnemyTickRuntime.new()

    assert_eq(runtime.attack_damage(), 0.0)
    assert_false(runtime.has_committed_snapshot())
    assert_false(runtime.has_pending_attack())


func test_snapshot_survives_the_countdown_reaching_zero() -> void:
    var runtime := EnemyTickRuntime.new()
    runtime.commit_attack([Vector2i.ZERO], 1, 20.0)

    runtime.step_attack_countdown()

    assert_false(runtime.has_pending_attack(), "the countdown itself should read as no longer pending")
    assert_true(runtime.has_committed_snapshot(), "the snapshot must survive until an explicit clear")
    assert_eq(runtime.attack_damage(), 20.0, "committed damage must remain readable at zero ticks")
    assert_eq(runtime.attack_tiles(), [Vector2i.ZERO])


func test_clear_attack_drops_tiles_ticks_and_damage_together() -> void:
    var runtime := EnemyTickRuntime.new()
    runtime.commit_attack([Vector2i.ZERO], 3, 9.0)

    runtime.clear_attack()

    assert_true(runtime.attack_tiles().is_empty())
    assert_eq(runtime.attack_ticks(), -1)
    assert_eq(runtime.attack_damage(), 0.0)
    assert_false(runtime.has_pending_attack())
    assert_false(runtime.has_committed_snapshot())


func test_danger_reads_committed_tiles_and_ticks_unaffected_by_damage() -> void:
    var runtime := EnemyTickRuntime.new()
    var tiles: Array[Vector2i] = [Vector2i.ZERO, Vector2i.UP]
    runtime.commit_attack(tiles, 3, 40.0)

    var danger := runtime.danger()

    assert_eq(danger["cells"], tiles)
    assert_eq(danger["ticks"], 3)
    assert_false(danger.has("damage"), "danger stays {cells, ticks} without a damage label")


func test_recommitting_before_a_clear_replaces_the_whole_snapshot() -> void:
    var runtime := EnemyTickRuntime.new()
    runtime.commit_attack([Vector2i.ZERO], 2, 10.0)

    runtime.commit_attack([Vector2i.RIGHT], 4, 25.0)

    assert_eq(runtime.attack_tiles(), [Vector2i.RIGHT])
    assert_eq(runtime.attack_ticks(), 4)
    assert_eq(runtime.attack_damage(), 25.0)
