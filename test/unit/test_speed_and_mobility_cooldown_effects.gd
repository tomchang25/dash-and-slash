# test_speed_and_mobility_cooldown_effects.gd
# Tests the Speed and Mobility Cooldown Minor reward effects: both are always offerable (no
# player/grid dependency) and record their stacked contribution to RunBuild's dedicated channel,
# the same RunBuild-projection pattern the enemy-pressure Minors use.
extends GutTest

func test_speed_effect_is_always_applicable() -> void:
    var definition := _make_speed_effect()
    var context := WaveRewardContext.new(null, null, RunBuild.new())

    assert_true(definition.is_applicable(context))


func test_speed_effect_records_stacked_contribution_to_run_build_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var definition := _make_speed_effect()

    definition.apply(context, 3)

    assert_eq(run_build.total(RunBuild.CH_SPEED), 3.0)


func test_speed_effect_stacks_across_multiple_applications() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var definition := _make_speed_effect()

    definition.apply(context, 2)
    definition.apply(context, 1)

    assert_eq(run_build.total(RunBuild.CH_SPEED), 3.0)


func test_mobility_cooldown_effect_is_always_applicable() -> void:
    var definition := _make_mobility_cooldown_effect()
    var context := WaveRewardContext.new(null, null, RunBuild.new())

    assert_true(definition.is_applicable(context))


func test_mobility_cooldown_effect_records_stacked_contribution_to_run_build_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var definition := _make_mobility_cooldown_effect()

    definition.apply(context, 2)

    assert_eq(run_build.total(RunBuild.CH_MOBILITY_COOLDOWN), 2.0)


func _make_speed_effect() -> SpeedEffect:
    return SpeedEffect.new(
        "speed_up",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Fleet Step",
        "+%d Speed",
        -1,
        1.0,
        5,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )


func _make_mobility_cooldown_effect() -> MobilityCooldownEffect:
    return MobilityCooldownEffect.new(
        "mobility_cooldown_down",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Light Footwork",
        "-%d mobility cooldown (ticks)",
        -1,
        1.0,
        3,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )
