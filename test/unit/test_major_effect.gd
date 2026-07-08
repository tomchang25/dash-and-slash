# test_major_effect.gd
# Tests the legendary-cap and exclusivity-group rejection on RunBuild's owned-artifact registry,
# driven by synthetic legendary artifacts with empty effect lists and synthetic group ids.
extends GutTest

func test_legendary_artifact_is_eligible_and_registers() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var artifact := _make_legendary("major_placeholder", "")

    assert_true(artifact.is_eligible(context))
    run_build.acquire_artifact(artifact, 1)

    assert_eq(run_build.legendary_count(), 1)


func test_legendary_cap_rejects_beyond_four() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)

    for i in RunBuild.LEGENDARY_CAP:
        var artifact := _make_legendary("major_%d" % i, "")
        assert_true(artifact.is_eligible(context), "slot %d should still have capacity" % i)
        run_build.acquire_artifact(artifact, 1)

    var overflow := _make_legendary("major_overflow", "")

    assert_false(overflow.is_eligible(context), "cap reached should reject a new legendary regardless of group")
    assert_false(
        run_build.acquire_artifact(overflow, 1),
        "direct acquire_artifact should also reject once the cap is reached",
    )
    assert_eq(run_build.legendary_count(), RunBuild.LEGENDARY_CAP)


func test_same_artifact_id_cannot_be_offered_or_acquired_twice() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var first := _make_legendary("major_dup", "")
    var second := _make_legendary("major_dup", "")

    run_build.acquire_artifact(first, 1)

    assert_false(
        second.is_eligible(context),
        "the same artifact id must not be offerable again even with an empty exclusivity group",
    )
    assert_false(run_build.acquire_artifact(second, 1))
    assert_eq(run_build.legendary_count(), 1)


func test_empty_exclusivity_group_never_conflicts() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var first := _make_legendary("major_a", "")
    var second := _make_legendary("major_b", "")

    run_build.acquire_artifact(first, 1)

    assert_true(second.is_eligible(context), "an empty group should never conflict, only the cap can reject")
    run_build.acquire_artifact(second, 1)

    assert_eq(run_build.legendary_count(), 2)


func test_shared_exclusivity_group_rejects_second_member() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var first := _make_legendary("major_a", "synthetic_group")
    var second := _make_legendary("major_b", "synthetic_group")

    run_build.acquire_artifact(first, 1)

    assert_false(second.is_eligible(context), "a second legendary sharing an exclusivity group must be rejected")
    assert_false(run_build.acquire_artifact(second, 1))
    assert_eq(run_build.legendary_count(), 1)


func test_different_exclusivity_groups_can_both_be_active() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var first := _make_legendary("major_a", "group_a")
    var second := _make_legendary("major_b", "group_b")

    assert_true(first.is_eligible(context))
    run_build.acquire_artifact(first, 1)

    assert_true(second.is_eligible(context))
    run_build.acquire_artifact(second, 1)

    assert_eq(run_build.legendary_count(), 2)


func _make_legendary(id: StringName, exclusivity_group: StringName) -> Artifact:
    return Artifact.new(
        id,
        "Major Placeholder",
        "Major placeholder (%d)",
        Artifact.Rarity.LEGENDARY,
        1,
        exclusivity_group,
        false,
        2,
        -4,
        1.0,
        [WaveRewardChoiceGenerator.Profile.AGGRESSIVE],
        [],
    )
