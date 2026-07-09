# test_tick_player_speed_meter.gd
# Tests TickPlayer's Speed meter fill/spend rules directly: baseline fill, the per-action fill cap,
# the full-meter free-action signal, spend resetting the charge, and reset() zeroing the meter.
extends GutTest

func test_speed_meter_starts_empty_and_not_full() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())

    assert_eq(player.speed_meter, 0)
    assert_false(player.is_speed_meter_full())


func test_zero_speed_stacks_fill_the_baseline_amount() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())

    player.fill_speed_meter(0.0)

    assert_eq(player.speed_meter, TickPlayer.SPEED_BASE_FILL, "baseline fill should grant one free eligible action every four eligible actions")


func test_fill_gains_baseline_plus_ten_per_stack() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())

    player.fill_speed_meter(3.0)

    assert_eq(player.speed_meter, TickPlayer.SPEED_BASE_FILL + 30)


func test_fill_is_capped_at_fifty_per_action_regardless_of_stack_count() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())

    player.fill_speed_meter(10.0)

    assert_eq(player.speed_meter, TickPlayer.SPEED_FILL_CAP, "10 stacks * 10 would be 100, but a single action caps the gain at 50")


func test_meter_becomes_full_after_two_capped_fills() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())

    player.fill_speed_meter(10.0)
    assert_false(player.is_speed_meter_full())
    player.fill_speed_meter(10.0)

    assert_eq(player.speed_meter, TickPlayer.SPEED_METER_MAX)
    assert_true(player.is_speed_meter_full())


func test_fill_never_exceeds_the_meter_maximum() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())
    player.fill_speed_meter(10.0)
    player.fill_speed_meter(10.0)

    player.fill_speed_meter(10.0)

    assert_eq(player.speed_meter, TickPlayer.SPEED_METER_MAX)


func test_spend_resets_the_meter_to_zero() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())
    player.fill_speed_meter(10.0)
    player.fill_speed_meter(10.0)
    assert_true(player.is_speed_meter_full())

    player.spend_speed_meter()

    assert_eq(player.speed_meter, 0)
    assert_false(player.is_speed_meter_full())


func test_reset_zeroes_the_speed_meter() -> void:
    var grid: GridArena = autofree(GridArena.new())
    var player: TickPlayer = autofree(TickPlayer.new())
    player.setup(grid, Vector2i.ZERO)
    player.fill_speed_meter(10.0)
    player.fill_speed_meter(10.0)
    assert_true(player.is_speed_meter_full())

    player.reset(Vector2i.ZERO)

    assert_eq(player.speed_meter, 0)
