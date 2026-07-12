# test_tick_player_max_health.gd
# Tests TickPlayer's Max Health reward projection: max_hp() projects the base plus the recorded
# RunBuild bonus total, floored at the base; reset() heals to that projected ceiling so a run's
# earned max health survives a death/reset instead of reverting to the flat base constant.
# apply_max_health_gain() covers the immediate current-hp gain a positive contribution grants,
# clamped at the newly projected maximum.
extends GutTest

func test_max_hp_with_no_bonus_is_the_base_constant() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())

    assert_eq(player.max_hp(0.0), TickPlayer.MAX_HP)


func test_max_hp_adds_the_recorded_bonus_total() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())

    assert_eq(player.max_hp(40.0), TickPlayer.MAX_HP + 40.0)


func test_max_hp_floors_a_negative_bonus_total_at_the_base() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())

    assert_eq(player.max_hp(-40.0), TickPlayer.MAX_HP, "a reduction effect could never collapse survivability below the base")


func test_reset_heals_to_the_projected_max_hp_bonus() -> void:
    var grid: GridArena = autofree(GridArena.new())
    var player: TickPlayer = autofree(TickPlayer.new())
    player.setup(grid, Vector2i.ZERO, CharacterClassData.new())
    player.take_damage(90.0)

    player.reset(Vector2i.ZERO, 40.0)

    assert_eq(player.hp, TickPlayer.MAX_HP + 40.0)


func test_reset_with_no_bonus_argument_heals_to_the_base() -> void:
    var grid: GridArena = autofree(GridArena.new())
    var player: TickPlayer = autofree(TickPlayer.new())
    player.setup(grid, Vector2i.ZERO, CharacterClassData.new())
    player.take_damage(50.0)

    player.reset(Vector2i.ZERO)

    assert_eq(player.hp, TickPlayer.MAX_HP)


func test_apply_max_health_gain_adds_exactly_the_gain_while_damaged() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())
    player.hp = 50.0

    player.apply_max_health_gain(20.0, 20.0)

    assert_eq(player.hp, 70.0, "a +20 pick grants +20 current hp rather than healing to full")


func test_apply_max_health_gain_clamps_at_the_newly_projected_maximum() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())
    player.hp = 118.0

    player.apply_max_health_gain(5.0, 20.0)

    assert_eq(player.hp, TickPlayer.MAX_HP + 20.0, "hp clamps to the maximum this contribution just raised")


func test_apply_max_health_gain_ignores_non_positive_gain() -> void:
    var player: TickPlayer = autofree(TickPlayer.new())
    player.hp = 50.0

    player.apply_max_health_gain(0.0, 0.0)
    player.apply_max_health_gain(-10.0, 0.0)

    assert_eq(player.hp, 50.0, "non-positive gains must never change current hp")
