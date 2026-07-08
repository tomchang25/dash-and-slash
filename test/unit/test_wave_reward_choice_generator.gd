# test_wave_reward_choice_generator.gd
# Tests WaveRewardChoiceGenerator's kind classification against the default artifact pool: the four
# pressure artifacts roll as curses, normal Minor offers exclude pressure and Legendary artifacts,
# and Major offers respect the run-wide legendary cap.
extends GutTest

func test_pressure_artifacts_roll_as_curses() -> void:
    var generator := WaveRewardChoiceGenerator.new()
    var context := WaveRewardContext.new(null, RunBuild.new())

    var curses := generator.roll(WaveRewardChoiceGenerator.RewardKind.CURSE, 10, 5, context)
    var curse_ids: Array[StringName] = []
    for choice in curses:
        curse_ids.append(choice.artifacts()[0].id)

    assert_true(curse_ids.has(&"future_enemy"), "future_enemy should roll as a curse")
    assert_true(curse_ids.has(&"enemy_health_pressure"), "enemy_health_pressure should roll as a curse")
    assert_true(curse_ids.has(&"enemy_damage_pressure"), "enemy_damage_pressure should roll as a curse")
    assert_true(curse_ids.has(&"enemy_defense_pressure"), "enemy_defense_pressure should roll as a curse")
    assert_eq(curse_ids.size(), 4, "exactly the four pressure artifacts should classify as curses")


func test_normal_minor_pool_excludes_pressure_and_legendary_artifacts() -> void:
    var generator := WaveRewardChoiceGenerator.new()
    var context := WaveRewardContext.new(null, RunBuild.new())

    var minors := generator.roll(WaveRewardChoiceGenerator.RewardKind.MINOR, 30, 5, context)
    assert_false(minors.is_empty(), "the Minor pool should still offer non-curse, non-Legendary artifacts")
    for choice in minors:
        var artifact := choice.artifacts()[0]
        assert_false(artifact.is_curse, "%s should not be offered as a Minor once it is a curse" % artifact.id)
        assert_ne(artifact.rarity, Artifact.Rarity.LEGENDARY, "%s should not be offered as a Minor" % artifact.id)


func test_major_pool_respects_legendary_cap() -> void:
    var generator := WaveRewardChoiceGenerator.new()
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)

    var majors := generator.roll(WaveRewardChoiceGenerator.RewardKind.MAJOR, 10, 5, context)
    assert_eq(majors.size(), RunBuild.LEGENDARY_CAP, "every Legendary artifact should be eligible against an empty build")

    for choice in majors:
        run_build.acquire_artifact(choice.artifacts()[0], 1)

    var majors_after_cap := generator.roll(WaveRewardChoiceGenerator.RewardKind.MAJOR, 10, 5, context)
    assert_true(majors_after_cap.is_empty(), "no further Major should be eligible once the legendary cap is full")
