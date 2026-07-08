# test_tick_combat_projection.gd
# Tests RunBuild-to-combat projection helpers shared by tick action commits and previews.
extends GutTest

func test_projects_normal_attack_damage_from_run_build() -> void:
    var run_build := RunBuild.new()
    run_build.record(RunBuild.CH_NORMAL_ATTACK_DAMAGE, 10.0)

    assert_eq(TickCombatProjection.normal_attack_damage(run_build), TickCombatRules.PLAYER_ATTACK_DAMAGE + 10.0)


func test_projects_mobility_attack_damage_from_run_build() -> void:
    var run_build := RunBuild.new()
    run_build.record(RunBuild.CH_MOBILITY_ATTACK_DAMAGE, 20.0)

    assert_eq(TickCombatProjection.mobility_attack_damage(run_build, TickCombatRules.PLAYER_DASH_DAMAGE), TickCombatRules.PLAYER_DASH_DAMAGE + 20.0)


func test_projects_mobility_range_with_cap() -> void:
    var run_build := RunBuild.new()
    run_build.record(RunBuild.CH_MOBILITY_RANGE, 999.0)

    assert_eq(TickCombatProjection.mobility_range_cells(run_build, 3), 9)


func test_projects_mobility_cooldown_floor() -> void:
    var run_build := RunBuild.new()
    run_build.record(RunBuild.CH_MOBILITY_COOLDOWN, 99.0)

    assert_eq(TickCombatProjection.mobility_cooldown_ticks(run_build, 4), 1)


func test_projects_mobility_triggers() -> void:
    var run_build := RunBuild.new()
    run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, true)
    run_build.set_mobility_trigger(RunBuild.TRIGGER_EXECUTION, true)
    run_build.set_mobility_trigger(RunBuild.TRIGGER_MOBILITY_FREE_ACTION, true)

    assert_true(TickCombatProjection.has_mobility_guard_shredder(run_build))
    assert_true(TickCombatProjection.has_mobility_execution(run_build))
    assert_true(TickCombatProjection.has_mobility_free_action(run_build))


func test_projects_mobility_stagger_burst_multiplier() -> void:
    assert_eq(TickCombatProjection.mobility_stagger_burst_multiplier(), TickCombatRules.STAGGER_MOBILITY_MULTIPLIER)
