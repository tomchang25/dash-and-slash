# test_run_build_reward_channels.gd
# Tests channel artifacts covering Normal Attack Damage, Mobility (Dash) Attack Damage, Mobility
# (Dash) Range, and Max Health. All four must be eligible and apply with no grid in context,
# recording their stacked contribution to RunBuild's dedicated channel, the same pattern Speed and
# Mobility Cooldown already use.
extends GutTest

func test_normal_attack_damage_artifact_is_eligible_without_grid() -> void:
    var artifact := _make_normal_attack_damage_artifact()
    var context := WaveRewardContext.new(null, RunBuild.new())

    assert_true(artifact.is_eligible(context))


func test_normal_attack_damage_artifact_records_stacked_contribution_to_run_build_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_normal_attack_damage_artifact()

    artifact.apply(context, 2)

    assert_eq(run_build.total(RunBuild.CH_NORMAL_ATTACK_DAMAGE), 20.0)


func test_dash_attack_damage_artifact_is_eligible_without_grid() -> void:
    var artifact := _make_dash_attack_damage_artifact()
    var context := WaveRewardContext.new(null, RunBuild.new())

    assert_true(artifact.is_eligible(context))


func test_dash_attack_damage_artifact_records_to_mobility_attack_damage_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_dash_attack_damage_artifact()

    artifact.apply(context, 1)

    assert_eq(run_build.total(RunBuild.CH_MOBILITY_ATTACK_DAMAGE), 20.0)


func test_dash_range_artifact_is_eligible_without_grid() -> void:
    var artifact := _make_dash_range_artifact()
    var context := WaveRewardContext.new(null, RunBuild.new())

    assert_true(artifact.is_eligible(context))


func test_dash_range_artifact_records_to_mobility_range_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_dash_range_artifact()

    artifact.apply(context, 1)

    assert_eq(run_build.total(RunBuild.CH_MOBILITY_RANGE), 10.0)


func test_max_health_artifact_is_eligible_without_grid() -> void:
    var artifact := _make_max_health_artifact()
    var context := WaveRewardContext.new(null, RunBuild.new())

    assert_true(artifact.is_eligible(context))


func test_max_health_artifact_records_to_run_build_channel_without_grid() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_max_health_artifact()

    artifact.apply(context, 2)

    assert_eq(run_build.total(RunBuild.CH_MAX_HEALTH), 40.0)


func _make_normal_attack_damage_artifact() -> Artifact:
    return Artifact.new(
        &"attack_up",
        "Sharpened Edge",
        "+%d normal attack damage",
        Artifact.Rarity.COMMON,
        3,
        &"",
        false,
        1,
        -1,
        10.0,
        [WaveRewardChoiceGenerator.Profile.CONSERVATIVE],
        [ChannelArtifactEffect.new(RunBuild.CH_NORMAL_ATTACK_DAMAGE, 10.0)],
    )


func _make_dash_attack_damage_artifact() -> Artifact:
    return Artifact.new(
        &"dash_attack_up",
        "Impact Dash",
        "+%d dash attack damage",
        Artifact.Rarity.COMMON,
        3,
        &"",
        false,
        1,
        -1,
        20.0,
        [WaveRewardChoiceGenerator.Profile.CONSERVATIVE],
        [ChannelArtifactEffect.new(RunBuild.CH_MOBILITY_ATTACK_DAMAGE, 20.0)],
    )


func _make_dash_range_artifact() -> Artifact:
    return Artifact.new(
        &"dash_range_up",
        "Longer Dash",
        "+%d%% dash range",
        Artifact.Rarity.COMMON,
        3,
        &"",
        false,
        1,
        -1,
        10.0,
        [WaveRewardChoiceGenerator.Profile.CONSERVATIVE],
        [ChannelArtifactEffect.new(RunBuild.CH_MOBILITY_RANGE, 10.0)],
    )


func _make_max_health_artifact() -> Artifact:
    return Artifact.new(
        &"max_health_up",
        "Vital Spark",
        "+%d max health",
        Artifact.Rarity.COMMON,
        2,
        &"",
        false,
        1,
        -1,
        20.0,
        [WaveRewardChoiceGenerator.Profile.CONSERVATIVE],
        [ChannelArtifactEffect.new(RunBuild.CH_MAX_HEALTH, 20.0)],
    )
