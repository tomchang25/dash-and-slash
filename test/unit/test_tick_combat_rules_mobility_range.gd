# test_tick_combat_rules_mobility_range.gd
# Tests TickCombatRules.mobility_range_cells(): the shared Dash/Smash range projection that the tick
# arena's action and preview controllers apply to whichever payload occupies the mobility slot,
# clamped to a max bonus percent and floored at 1 cell.
extends GutTest

func test_no_bonus_percent_keeps_the_base_range() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(5, 0.0, 200.0), 5)


func test_bonus_percent_scales_the_base_range_and_rounds() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(5, 10.0, 200.0), 6, "5 * 1.1 = 5.5, rounds up to 6")


func test_bonus_percent_clamps_to_the_max_bonus_percent() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(5, 9999.0, 200.0), 15, "clamped to 200%, so 5 * 3.0 = 15")


func test_range_floors_at_one_cell() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(1, -9999.0, 200.0), 1, "a reduction can never collapse the mobility slot's reach to nothing")


func test_negative_bonus_percent_reduces_the_range() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(5, -20.0, 200.0), 4, "5 * 0.8 = 4, a reduction still applies down to the floor")


func test_bonus_applies_independently_to_each_payloads_base() -> void:
    var bonus_percent := 20.0
    assert_eq(TickCombatRules.mobility_range_cells(5, bonus_percent, 200.0), 6, "Dash's own base")
    assert_eq(TickCombatRules.mobility_range_cells(3, bonus_percent, 200.0), 4, "Smash's own base, same bonus percent")
