# test_wave_controller.gd
# Tests WaveController progression, pressure modifiers, and spawn counts.
extends GutTest

func test_initial_state_has_no_wave() -> void:
    var wc := WaveController.new()
    assert_eq(wc.get_current_wave(), { }, "No wave before advance")


func test_advance_wave_moves_to_wave_one() -> void:
    var wc := WaveController.new()
    assert_true(wc.advance_wave(), "advance_wave should return true")
    assert_eq(wc.get_current_wave().get("index"), 1, "First wave should be index 1")


func test_advance_wave_progresses_through_all() -> void:
    var wc := WaveController.new()
    for i in 4:
        assert_true(wc.advance_wave(), "Should advance through normal waves")
    assert_true(wc.advance_wave(), "Should advance to boss wave")
    assert_eq(wc.get_current_wave().get("index"), 5, "Wave 5 should be boss")
    assert_true(wc.is_boss_wave(), "Wave 5 should be boss wave")


func test_normal_wave_base_support_count() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), 5, "Wave 1 spawns 5 enemies")


func test_wave_two_base_support_count() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), 6, "Wave 2 spawns 6 enemies")


func test_wave_three_base_support_count() -> void:
    var wc := WaveController.new()
    for i in 3:
        wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), 7, "Wave 3 spawns 7 enemies")


func test_wave_four_base_support_count() -> void:
    var wc := WaveController.new()
    for i in 4:
        wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), 8, "Wave 4 spawns 8 enemies")


func test_boss_wave_support_count() -> void:
    var wc := WaveController.new()
    for i in 5:
        wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), 8, "Boss wave support base is 8")


func test_future_pressure_increases_normal_support() -> void:
    var wc := WaveController.new()
    wc.add_future_enemy_count(3)
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), 8, "Wave 1 with +3 pressure is 8")


func test_future_pressure_increases_boss_support() -> void:
    var wc := WaveController.new()
    wc.add_future_enemy_count(3)
    for i in 5:
        wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), 11, "Boss wave with +3 pressure is 11")


func test_boss_count_is_one() -> void:
    var wc := WaveController.new()
    for i in 5:
        wc.advance_wave()
    assert_eq(wc.get_boss_spawn_count(), 1, "Boss wave spawns 1 boss")


func test_normal_wave_boss_count_is_zero() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    assert_eq(wc.get_boss_spawn_count(), 0, "Normal wave spawns 0 bosses")


func test_pressure_does_not_increase_boss_count() -> void:
    var wc := WaveController.new()
    wc.add_future_enemy_count(99)
    for i in 5:
        wc.advance_wave()
    assert_eq(wc.get_boss_spawn_count(), 1, "Pressure does not increase boss count")


func test_negative_pressure_is_clamped() -> void:
    var wc := WaveController.new()
    wc.add_future_enemy_count(-5)
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), 5, "Negative pressure is clamped to zero")


func test_get_wave_number() -> void:
    var wc := WaveController.new()
    wc.advance_wave()
    assert_eq(wc.get_wave_number(), 1, "Wave number 1 after first advance")
    wc.advance_wave()
    assert_eq(wc.get_wave_number(), 2, "Wave number 2 after second advance")


func test_reset_clears_state() -> void:
    var wc := WaveController.new()
    wc.add_future_enemy_count(5)
    wc.advance_wave()
    wc.reset()
    assert_eq(wc.get_current_wave(), { }, "No wave after reset")
    assert_eq(wc.get_wave_number(), 0, "Wave number 0 after reset")
    wc.advance_wave()
    assert_eq(wc.get_support_spawn_count(), 5, "Pressure reset to 0 after reset")


func test_not_a_boss_wave_before_advance() -> void:
    var wc := WaveController.new()
    assert_false(wc.is_boss_wave(), "Not boss before any wave")


func test_advance_past_last_wave_returns_false() -> void:
    var wc := WaveController.new()
    for i in 5:
        wc.advance_wave()
    assert_false(wc.advance_wave(), "No more waves after boss")
