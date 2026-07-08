# test_wave_reward_choice.gd
# Tests WaveRewardChoice's single-entry apply semantics: a Minor x2 choice applies one artifact at
# two stacks through the run build's owned-artifact registry, not two distinct artifacts at one
# stack each.
extends GutTest

func test_single_choice_applies_one_artifact_at_one_stack() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_minor(&"speed_up", RunBuild.CH_SPEED, 1.0)

    var choice := WaveRewardChoice.single(artifact, 1)
    choice.apply(context)

    assert_true(run_build.has_artifact(&"speed_up"))
    assert_eq(run_build.total(RunBuild.CH_SPEED), 1.0)


func test_two_stack_choice_applies_one_artifact_at_two_stacks() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var speed := _make_minor(&"speed_up", RunBuild.CH_SPEED, 1.0)

    var choice := WaveRewardChoice.single(speed, 2)
    choice.apply(context)

    assert_true(run_build.has_artifact(&"speed_up"))
    assert_eq(run_build.total(RunBuild.CH_SPEED), 2.0, "a two-stack choice should apply speed_up at two stacks, not one")

    var owned := run_build.get_owned_artifacts()
    assert_eq(owned.size(), 1, "a two-stack choice should register one owned artifact, not two distinct artifacts")
    assert_eq(owned[0]["stacks"], 2)


func test_two_stack_choice_title_reports_the_single_artifact_name() -> void:
    var speed := _make_minor(&"speed_up", RunBuild.CH_SPEED, 1.0)
    var choice := WaveRewardChoice.single(speed, 2)

    assert_eq(choice.title(), "Minor Placeholder", "a Minor x2 choice keeps the same artifact title, not a bundled 'Minor x2' name")


func test_two_stack_choice_description_reports_doubled_effect() -> void:
    var speed := _make_minor(&"speed_up", RunBuild.CH_SPEED, 1.0)
    var choice := WaveRewardChoice.single(speed, 2)

    assert_eq(choice.description(), "+2 test channel", "a Minor x2 choice should report the doubled magnitude in one effect line")


func test_empty_choice_applies_nothing() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var choice := WaveRewardChoice.empty()

    choice.apply(context)

    assert_true(choice.is_empty())
    assert_eq(run_build.get_owned_artifacts().size(), 0, "an empty choice should register no artifacts")


func _make_minor(id: StringName, channel: StringName, magnitude: float) -> Artifact:
    var effect := ChannelArtifactEffect.new()
    effect.channel = channel
    effect.amount = magnitude

    var artifact := Artifact.new()
    artifact.id = id
    artifact.display_name = "Minor Placeholder"
    artifact.description_template = "+%d test channel"
    artifact.max_stacks = 3
    artifact.magnitude = magnitude
    artifact.effects = [effect]
    return artifact
