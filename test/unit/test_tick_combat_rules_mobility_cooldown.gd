# test_tick_combat_rules_mobility_cooldown.gd
# Tests TickCombatRules.mobility_cooldown_ticks(): the shared Dash/Smash cooldown projection that
# TickArena applies to whichever payload occupies the mobility slot, floored at 1 tick.
extends GutTest

func test_no_reduction_stacks_keeps_the_base_cooldown() -> void:
    assert_eq(TickCombatRules.mobility_cooldown_ticks(4, 0), 4)


func test_reduction_stacks_subtract_ticks() -> void:
    assert_eq(TickCombatRules.mobility_cooldown_ticks(6, 2), 4)


func test_reduction_floors_at_one_tick() -> void:
    assert_eq(TickCombatRules.mobility_cooldown_ticks(4, 10), 1, "reduction can never bring the mobility slot to a free cooldown")


func test_reduction_applies_independently_to_each_payloads_base() -> void:
    var reduction := 2
    assert_eq(TickCombatRules.mobility_cooldown_ticks(4, reduction), 2, "Dash's own base")
    assert_eq(TickCombatRules.mobility_cooldown_ticks(6, reduction), 4, "Smash's own base, same reduction")
