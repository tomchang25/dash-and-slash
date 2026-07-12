# test_tick_player_speed_meter.gd
# Tests class-backed Speed fill, reward additions, caps, spending, and reset.
extends GutTest

func test_speed_meter_starts_empty_and_not_full() -> void:
    var player := _make_player(20)

    assert_eq(player.speed_meter, 0)
    assert_false(player.is_speed_meter_full())


func test_ninja_baseline_fills_twenty() -> void:
    var player := _make_player(20)

    player.fill_speed_meter(0.0)

    assert_eq(player.speed_meter, 20)


func test_viking_baseline_fills_ten() -> void:
    var player := _make_player(10)

    player.fill_speed_meter(0.0)

    assert_eq(player.speed_meter, 10)


func test_speed_stack_adds_ten_to_class_baseline() -> void:
    var player := _make_player(10)

    player.fill_speed_meter(1.0)

    assert_eq(player.speed_meter, 20)


func test_fill_is_capped_at_seventy_five_per_action() -> void:
    var player := _make_player(20)

    player.fill_speed_meter(10.0)

    assert_eq(player.speed_meter, TickPlayer.SPEED_FILL_CAP)


func test_meter_never_exceeds_maximum() -> void:
    var player := _make_player(20)
    player.fill_speed_meter(10.0)

    player.fill_speed_meter(10.0)

    assert_eq(player.speed_meter, TickPlayer.SPEED_METER_MAX)
    assert_true(player.is_speed_meter_full())


func test_prepare_speed_free_action_fills_the_meter_to_ready() -> void:
    var player := _make_player(20)

    player.prepare_speed_free_action()

    assert_true(player.is_speed_meter_full())
    assert_eq(player.speed_meter, TickPlayer.SPEED_METER_MAX)


func test_prepare_speed_free_action_is_idempotent_when_already_full() -> void:
    var player := _make_player(20)
    player.speed_meter = TickPlayer.SPEED_METER_MAX

    player.prepare_speed_free_action()

    assert_eq(player.speed_meter, TickPlayer.SPEED_METER_MAX)


func test_spend_resets_meter() -> void:
    var player := _make_player(20)
    player.speed_meter = TickPlayer.SPEED_METER_MAX

    player.spend_speed_meter()

    assert_eq(player.speed_meter, 0)
    assert_false(player.is_speed_meter_full())


func test_reset_zeroes_meter_and_preserves_class() -> void:
    var grid: GridArena = autofree(GridArena.new())
    var player: TickPlayer = autofree(TickPlayer.new())
    var character_class := _make_class(10)
    player.setup(grid, Vector2i.ZERO, character_class)
    player.speed_meter = TickPlayer.SPEED_METER_MAX

    player.reset(Vector2i.ZERO)

    assert_eq(player.speed_meter, 0)
    assert_eq(player.get_character_class(), character_class)


func _make_player(base_speed_fill: int) -> TickPlayer:
    var player: TickPlayer = autofree(TickPlayer.new())
    player.set_character_class(_make_class(base_speed_fill))
    return player


func _make_class(base_speed_fill: int) -> CharacterClassData:
    var character_class := CharacterClassData.new()
    character_class.id = &"test_class"
    character_class.display_name = "Test Class"
    character_class.base_speed_fill = base_speed_fill
    character_class.mobility_id = CharacterClassData.MOBILITY_DASH
    return character_class
