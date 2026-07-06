# test_major_effect.gd
# Tests the Major-effect cap and exclusivity-group rejection on RunBuild,
# driven entirely by the placeholder Major effect and synthetic group ids.
extends GutTest

func test_major_placeholder_is_applicable_and_registers() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var definition := _make_major("major_placeholder", "")

    assert_true(definition.is_applicable(context))
    definition.apply(context, 1)

    assert_eq(run_build.major_count(), 1)


func test_major_cap_rejects_beyond_four() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)

    for i in RunBuild.MAJOR_CAP:
        var definition := _make_major("major_%d" % i, "")
        assert_true(definition.is_applicable(context), "slot %d should still have capacity" % i)
        definition.apply(context, 1)

    var overflow := _make_major("major_overflow", "")

    assert_false(overflow.is_applicable(context), "cap reached should reject a new Major regardless of group")
    assert_false(
        run_build.add_major(overflow.effect_id, overflow.exclusivity_group),
        "direct add_major should also reject once the cap is reached",
    )
    assert_eq(run_build.major_count(), RunBuild.MAJOR_CAP)


func test_same_effect_id_cannot_be_offered_or_added_twice() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var first := _make_major("major_dup", "")
    var second := _make_major("major_dup", "")

    first.apply(context, 1)

    assert_false(
        second.is_applicable(context),
        "the same effect id must not be offerable again even with an empty exclusivity group",
    )
    assert_false(run_build.add_major(second.effect_id, second.exclusivity_group))
    assert_eq(run_build.major_count(), 1)


func test_empty_exclusivity_group_never_conflicts() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var first := _make_major("major_a", "")
    var second := _make_major("major_b", "")

    first.apply(context, 1)

    assert_true(second.is_applicable(context), "an empty group should never conflict, only the cap can reject")
    second.apply(context, 1)

    assert_eq(run_build.major_count(), 2)


func test_shared_exclusivity_group_rejects_second_member() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var first := _make_major("major_a", "synthetic_group")
    var second := _make_major("major_b", "synthetic_group")

    first.apply(context, 1)

    assert_false(second.is_applicable(context), "a second Major sharing an exclusivity group must be rejected")
    assert_false(run_build.add_major(second.effect_id, second.exclusivity_group))
    assert_eq(run_build.major_count(), 1)


func test_different_exclusivity_groups_can_both_be_active() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var first := _make_major("major_a", "group_a")
    var second := _make_major("major_b", "group_b")

    assert_true(first.is_applicable(context))
    first.apply(context, 1)

    assert_true(second.is_applicable(context))
    second.apply(context, 1)

    assert_eq(run_build.major_count(), 2)


func _make_major(effect_id: String, exclusivity_group: String) -> MajorPlaceholderEffect:
    return MajorPlaceholderEffect.new(
        effect_id,
        "Major Placeholder",
        "Major placeholder (%d)",
        -4,
        1.0,
        1,
        2,
        [WaveRewardEffectDefinition.Profile.AGGRESSIVE],
        exclusivity_group,
    )
