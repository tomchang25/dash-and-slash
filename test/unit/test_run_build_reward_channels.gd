# test_run_build_reward_channels.gd
# Tests the Phase 6c reward effects that moved off the legacy PlayerStatEffect gate: Normal Attack
# Damage, Mobility (Dash) Attack Damage, Mobility (Dash) Range, and Max Health. All four must offer
# and apply with no legacy Player in context, recording their stacked contribution to RunBuild's
# dedicated channel, the same pattern Speed and Mobility Cooldown already use. Max Health is the one
# exception that still branches on a legacy Player when present, per its own apply() contract.
extends GutTest

func test_normal_attack_damage_effect_is_always_applicable_without_player() -> void:
    var definition := _make_normal_attack_damage_effect()
    var context := WaveRewardContext.new(null, null, RunBuild.new())

    assert_true(definition.is_applicable(context))


func test_normal_attack_damage_effect_records_stacked_contribution_to_run_build_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var definition := _make_normal_attack_damage_effect()

    definition.apply(context, 2)

    assert_eq(run_build.total(RunBuild.CH_NORMAL_ATTACK_DAMAGE), 20.0)


func test_dash_attack_damage_effect_is_always_applicable_without_player() -> void:
    var definition := _make_dash_attack_damage_effect()
    var context := WaveRewardContext.new(null, null, RunBuild.new())

    assert_true(definition.is_applicable(context))


func test_dash_attack_damage_effect_records_to_mobility_attack_damage_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var definition := _make_dash_attack_damage_effect()

    definition.apply(context, 1)

    assert_eq(run_build.total(RunBuild.CH_MOBILITY_ATTACK_DAMAGE), 20.0)


func test_dash_range_effect_is_always_applicable_without_player() -> void:
    var definition := _make_dash_range_effect()
    var context := WaveRewardContext.new(null, null, RunBuild.new())

    assert_true(definition.is_applicable(context))


func test_dash_range_effect_records_to_mobility_range_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var definition := _make_dash_range_effect()

    definition.apply(context, 1)

    assert_eq(run_build.total(RunBuild.CH_MOBILITY_RANGE), 10.0)


func test_max_health_effect_is_always_applicable_without_player() -> void:
    var definition := _make_max_health_effect()
    var context := WaveRewardContext.new(null, null, RunBuild.new())

    assert_true(definition.is_applicable(context))


func test_max_health_effect_records_to_run_build_channel_without_player() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var definition := _make_max_health_effect()

    definition.apply(context, 2)

    assert_eq(run_build.total(RunBuild.CH_MAX_HEALTH), 40.0)


func test_max_health_effect_does_not_touch_run_build_when_a_legacy_player_is_present() -> void:
    var player: Player = autofree(Player.new())
    var run_build := RunBuild.new()
    player.set_run_build(run_build)
    var context := WaveRewardContext.new(null, player, run_build)
    var definition := _make_max_health_effect()

    definition.apply(context, 1)

    assert_eq(run_build.total(RunBuild.CH_MAX_HEALTH), 0.0, "a legacy player present applies the delta directly through Player instead")


func _make_normal_attack_damage_effect() -> NormalAttackDamageEffect:
    return NormalAttackDamageEffect.new(
        "attack_up",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Sharpened Edge",
        "+%d normal attack damage",
        -1,
        10.0,
        3,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )


func _make_dash_attack_damage_effect() -> DashAttackDamageEffect:
    return DashAttackDamageEffect.new(
        "dash_attack_up",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Impact Dash",
        "+%d dash attack damage",
        -1,
        20.0,
        3,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )


func _make_dash_range_effect() -> DashRangeEffect:
    return DashRangeEffect.new(
        "dash_range_up",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Longer Dash",
        "+%d%% dash range",
        -1,
        10.0,
        3,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )


func _make_max_health_effect() -> MaxHealthEffect:
    return MaxHealthEffect.new(
        "max_health_up",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Vital Spark",
        "+%d max health",
        -1,
        20.0,
        2,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )
