# test_wave_reward_choice.gd
# Tests WaveRewardChoice's bundle apply semantics: a Minor x2 bundle applies its two distinct
# artifacts through the run build's owned-artifact registry at one stack each, not as one artifact
# duplicated into a two-stack pick.
extends GutTest

func test_single_choice_applies_one_artifact_at_one_stack() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_minor(&"speed_up", RunBuild.CH_SPEED, 1.0)

    var choice := WaveRewardChoice.single(artifact, 1)
    choice.apply(context)

    assert_true(run_build.has_artifact(&"speed_up"))
    assert_eq(run_build.total(RunBuild.CH_SPEED), 1.0)


func test_bundle_choice_applies_two_distinct_artifacts_at_one_stack_each() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var speed := _make_minor(&"speed_up", RunBuild.CH_SPEED, 1.0)
    var health := _make_minor(&"max_health_up", RunBuild.CH_MAX_HEALTH, 20.0)

    var choice := WaveRewardChoice.bundle([speed, health])
    choice.apply(context)

    assert_true(run_build.has_artifact(&"speed_up"))
    assert_true(run_build.has_artifact(&"max_health_up"))
    assert_eq(run_build.total(RunBuild.CH_SPEED), 1.0, "the bundle should apply speed_up at one stack, not two")
    assert_eq(run_build.total(RunBuild.CH_MAX_HEALTH), 20.0, "the bundle should apply max_health_up at one stack, not  two")

    var owned := run_build.get_owned_artifacts()
    assert_eq(owned.size(), 2, "the bundle should register two distinct owned artifacts, not one artifact at two stacks")


func test_bundle_choice_title_reports_minor_x2() -> void:
    var speed := _make_minor(&"speed_up", RunBuild.CH_SPEED, 1.0)
    var health := _make_minor(&"max_health_up", RunBuild.CH_MAX_HEALTH, 20.0)
    var choice := WaveRewardChoice.bundle([speed, health])

    assert_eq(choice.title(), "Minor x2")


func test_empty_choice_applies_nothing() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var choice := WaveRewardChoice.empty()

    choice.apply(context)

    assert_true(choice.is_empty())
    assert_eq(run_build.get_owned_artifacts().size(), 0, "an empty choice should register no artifacts")


func _make_minor(id: StringName, channel: StringName, magnitude: float) -> Artifact:
    return Artifact.new(
        id,
        "Minor Placeholder",
        "+%d test channel",
        Artifact.Rarity.COMMON,
        3,
        &"",
        false,
        1,
        magnitude,
        [ChannelArtifactEffect.new(channel, magnitude)],
    )
