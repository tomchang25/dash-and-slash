# test_tick_combat_rules_mobility_range.gd
# Tests TickCombatRules.mobility_range_cells(): the shared Dash/Smash range projection that the tick
# arena's action and preview controllers apply to whichever payload occupies the mobility slot,
# adding flat cell bonuses and flooring at 1 cell.
extends GutTest

func test_no_bonus_cells_keeps_the_base_range() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(5, 0.0), 5)


func test_bonus_cells_add_to_the_base_range() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(5, 1.0), 6)


func test_fractional_bonus_cells_round_before_applying() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(5, 1.6), 7)


func test_range_floors_at_one_cell() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(1, -9999.0), 1, "a reduction can never collapse the mobility slot's reach to nothing")


func test_negative_bonus_cells_reduce_the_range() -> void:
    assert_eq(TickCombatRules.mobility_range_cells(5, -2.0), 3, "a reduction still applies down to the floor")


func test_bonus_applies_independently_to_each_payloads_base() -> void:
    var bonus_cells := 1.0
    assert_eq(TickCombatRules.mobility_range_cells(5, bonus_cells), 6, "Dash's own base")
    assert_eq(TickCombatRules.mobility_range_cells(3, bonus_cells), 4, "Smash's own base, same bonus cells")
