# test_wave_reward_choice_generator.gd
# Tests WaveRewardChoiceGenerator's kind classification against the default artifact pool: the
# production catalog carries no curse artifacts (the pressure curses were retired), so the CURSE
# pool rolls empty while the generator's generic curse-exclusion support stays dormant; normal Minor
# offers exclude Legendary artifacts, and Major offers respect fixed class Mobility plus the
# run-wide legendary cap.
extends GutTest

const DEFAULT_REGISTRY_PATH := "res://data/rewards/default_artifact_registry.tres"

func test_production_registry_has_no_curse_artifacts() -> void:
    var generator := WaveRewardChoiceGenerator.new(_load_default_registry())
    var context := WaveRewardContext.new(null, RunBuild.new())

    var curses := generator.roll(WaveRewardChoiceGenerator.RewardKind.CURSE, 10, 5, context)

    assert_true(curses.is_empty(), "the production catalog must offer no curse artifacts")


func test_normal_minor_pool_excludes_legendary_artifacts() -> void:
    var generator := WaveRewardChoiceGenerator.new(_load_default_registry())
    var context := WaveRewardContext.new(null, RunBuild.new())

    var minors := generator.roll(WaveRewardChoiceGenerator.RewardKind.MINOR, 30, 5, context)
    assert_false(minors.is_empty(), "the Minor pool should still offer non-curse, non-Legendary artifacts")
    for choice in minors:
        var artifact := choice.artifacts()[0]
        assert_false(artifact.is_curse, "%s should not be offered as a Minor once it is a curse" % artifact.id)
        assert_ne(artifact.rarity, Artifact.Rarity.LEGENDARY, "%s should not be offered as a Minor" % artifact.id)


func test_ninja_major_pool_contains_only_dash_majors() -> void:
    var generator := WaveRewardChoiceGenerator.new(_load_default_registry())
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build, CharacterClassData.MOBILITY_DASH)

    var majors := generator.roll(WaveRewardChoiceGenerator.RewardKind.MAJOR, 10, 5, context)
    var ids: Array[StringName] = []
    for choice in majors:
        ids.append(choice.artifact().id)

    assert_eq(ids.size(), 3)
    assert_true(ids.has(&"guard_shredder"))
    assert_true(ids.has(&"execution"))
    assert_true(ids.has(&"chain_dash"))


func test_viking_major_pool_is_empty_until_smash_major_lands() -> void:
    var generator := WaveRewardChoiceGenerator.new(_load_default_registry())
    var context := WaveRewardContext.new(null, RunBuild.new(), CharacterClassData.MOBILITY_SMASH)

    var majors := generator.roll(WaveRewardChoiceGenerator.RewardKind.MAJOR, 10, 5, context)

    assert_true(majors.is_empty())


func test_major_pool_respects_legendary_cap() -> void:
    var generator := WaveRewardChoiceGenerator.new(_load_default_registry())
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build, CharacterClassData.MOBILITY_DASH)
    for i in RunBuild.LEGENDARY_CAP:
        var filler := Artifact.new()
        filler.id = StringName("filler_%d" % i)
        filler.rarity = Artifact.Rarity.LEGENDARY
        run_build.acquire_artifact(filler, 1)

    var majors_after_cap := generator.roll(WaveRewardChoiceGenerator.RewardKind.MAJOR, 10, 5, context)
    assert_true(majors_after_cap.is_empty(), "no further Major should be eligible once the legendary cap is full")


func _load_default_registry() -> ArtifactRegistry:
    return load(DEFAULT_REGISTRY_PATH) as ArtifactRegistry
