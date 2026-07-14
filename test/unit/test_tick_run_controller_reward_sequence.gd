# test_tick_run_controller_reward_sequence.gd
# Narrow coverage for TickRunController's every-third-wave Major reward cadence and milestone
# reward-offer assembly: the fixed Minor x2 first slot (one eligible Minor at two stacks) and the
# per-slot Major-or-Minor x2 fallback in the other two slots — milestone offers never open a curse
# confirmation. Full wave-completion -> banner -> offer -> next-wave sequencing needs the arena's
# full scene-node graph (grid, engine, player, overlays), so that sequence is covered by manual
# editor verification instead, per the cadence spec's documented escape hatch for scene-level
# coverage.
extends GutTest

## Test-only subclass exposing TickRunController's private offer-assembly helpers through public
## wrappers, and letting a test inject the reward generator/context directly instead of going
## through the full setup() scene-wiring path.
class TestTickRunController:
    extends TickRunController

    func inject_reward_flow(generator: WaveRewardChoiceGenerator, context: WaveRewardContext) -> void:
        _reward_generator = generator
        _reward_context = context


    func build_normal_offer(wave_number: int) -> Array[WaveRewardChoice]:
        return _build_normal_offer(wave_number)


    func build_milestone_offer(wave_number: int) -> Array[WaveRewardChoice]:
        return _build_milestone_offer(wave_number)


    func is_major_reward_wave(wave_number: int) -> bool:
        return _is_major_reward_wave(wave_number)

const DEFAULT_REGISTRY_PATH := "res://data/rewards/default_artifact_registry.tres"

# == Major reward cadence ==


func test_every_third_wave_is_a_major_reward_wave() -> void:
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    for wave_number in [3, 6, 9, 12]:
        assert_true(controller.is_major_reward_wave(wave_number), "wave %d is divisible by three and should open the Major offer" % wave_number)


## Boss wave 10 is not divisible by three, so continuing past it opens the normal Minor offer
## instead of a Major offer — Boss identity never decides reward cadence.
func test_non_cadence_waves_including_boss_wave_ten_are_not_major_reward_waves() -> void:
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    for wave_number in [1, 2, 4, 5, 7, 8, 10, 11]:
        assert_false(controller.is_major_reward_wave(wave_number), "wave %d is not divisible by three and should open the normal Minor offer" % wave_number)

# == Offer assembly ==


func test_normal_offer_is_three_single_minor_choices() -> void:
    var context := WaveRewardContext.new(null, RunBuild.new())
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    controller.inject_reward_flow(WaveRewardChoiceGenerator.new(_load_default_registry()), context)

    var offer := controller.build_normal_offer(1)

    assert_eq(offer.size(), 3, "a normal wave offers three choices")
    _assert_offer_artifacts_are_distinct(offer)
    for choice in offer:
        assert_eq(choice.artifacts().size(), 1, "each normal choice is a single artifact")
        assert_eq(choice.stack_count(), 1, "each normal choice is a single stack")


func test_milestone_offer_first_slot_is_one_eligible_minor_at_two_stacks() -> void:
    var context := WaveRewardContext.new(null, RunBuild.new())
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    controller.inject_reward_flow(WaveRewardChoiceGenerator.new(_load_default_registry()), context)

    var offer := controller.build_milestone_offer(5)

    assert_eq(offer.size(), 3, "a milestone wave offers exactly three choices")
    _assert_offer_artifacts_are_distinct(offer)
    assert_eq(offer[0].artifacts().size(), 1, "slot 1 holds exactly one Minor artifact, not a bundled pair")
    assert_eq(offer[0].artifact().rarity, Artifact.Rarity.COMMON, "slot 1 is always an eligible Minor")
    assert_eq(offer[0].stack_count(), 2, "slot 1 is always the same Minor at two stacks")
    assert_eq(offer[0].title(), offer[0].artifact().display_name, "slot 1's title is the real artifact name, not a bundled 'Minor x2' label")


func test_milestone_offer_uses_eligible_majors_when_available() -> void:
    var context := WaveRewardContext.new(null, RunBuild.new(), CharacterClassData.MOBILITY_DASH)
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    controller.inject_reward_flow(WaveRewardChoiceGenerator.new(_load_default_registry()), context)

    var offer := controller.build_milestone_offer(5)

    _assert_offer_artifacts_are_distinct(offer)
    var major_count := 0
    for i in range(1, offer.size()):
        if offer[i].artifact().rarity == Artifact.Rarity.LEGENDARY:
            major_count += 1
            assert_eq(offer[i].stack_count(), 1, "a Major fallback slot uses a single stack")
    assert_eq(major_count, 2, "with an empty build, both fallback slots should fill with eligible Majors")


func test_viking_milestone_offer_falls_back_to_minor_x2() -> void:
    var context := WaveRewardContext.new(null, RunBuild.new(), CharacterClassData.MOBILITY_SMASH)
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    controller.inject_reward_flow(WaveRewardChoiceGenerator.new(_load_default_registry()), context)

    var offer := controller.build_milestone_offer(5)

    assert_eq(offer.size(), 3)
    for choice in offer:
        assert_eq(choice.artifact().rarity, Artifact.Rarity.COMMON)
        assert_eq(choice.stack_count(), 2)


func test_milestone_offer_fills_missing_major_slots_with_minor_x2() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build, CharacterClassData.MOBILITY_DASH)
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    controller.inject_reward_flow(WaveRewardChoiceGenerator.new(_load_default_registry()), context)

    # Fill the legendary cap so no Major can be eligible, forcing every slot's fallback path.
    for i in RunBuild.LEGENDARY_CAP:
        run_build.acquire_artifact(_make_legendary_filler("major_%d" % i), 1)

    var offer := controller.build_milestone_offer(5)

    assert_eq(offer.size(), 3, "a milestone wave still offers exactly three enabled choices")
    _assert_offer_artifacts_are_distinct(offer)
    for choice in offer:
        assert_false(choice.is_empty(), "the fallback choice must still be an enabled choice")
        assert_eq(choice.artifact().rarity, Artifact.Rarity.COMMON, "every slot falls back to an eligible Minor when no Major is eligible")
        assert_eq(choice.stack_count(), 2, "every fallback slot is the same Minor at two stacks")


func _load_default_registry() -> ArtifactRegistry:
    return load(DEFAULT_REGISTRY_PATH) as ArtifactRegistry


func _make_legendary_filler(id: StringName) -> Artifact:
    var artifact := Artifact.new()
    artifact.id = id
    artifact.display_name = "Major Placeholder"
    artifact.description_template = "Major placeholder (%d)"
    artifact.rarity = Artifact.Rarity.LEGENDARY
    artifact.max_stacks = 1
    artifact.min_wave = 2
    artifact.magnitude = 1.0
    return artifact


func _assert_offer_artifacts_are_distinct(offer: Array[WaveRewardChoice]) -> void:
    var seen_ids: Dictionary = { }
    for choice in offer:
        if choice.is_empty():
            continue
        var artifact_id := choice.artifact().id
        assert_false(seen_ids.has(artifact_id), "artifact %s should not repeat within one offer" % artifact_id)
        seen_ids[artifact_id] = true
