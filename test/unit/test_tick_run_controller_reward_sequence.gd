# test_tick_run_controller_reward_sequence.gd
# Narrow coverage for TickRunController's milestone reward-offer assembly: the fixed Minor x2 first
# slot and the per-slot Major-or-Minor x2 fallback in the other two slots. Full wave-completion ->
# banner -> offer -> curse-confirmation -> next-wave sequencing needs the arena's full scene-node
# graph (grid, engine, player, overlays), so that sequence is covered by manual editor verification
# instead, per the cadence spec's documented escape hatch for scene-level coverage.
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


func test_normal_offer_is_three_single_minor_choices() -> void:
    var context := WaveRewardContext.new(null, RunBuild.new())
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    controller.inject_reward_flow(WaveRewardChoiceGenerator.new(), context)

    var offer := controller.build_normal_offer(1)

    assert_eq(offer.size(), 3, "a normal wave offers three choices")
    for choice in offer:
        assert_eq(choice.artifacts().size(), 1, "each normal choice is a single artifact")


func test_milestone_offer_first_slot_is_always_minor_x2() -> void:
    var context := WaveRewardContext.new(null, RunBuild.new())
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    controller.inject_reward_flow(WaveRewardChoiceGenerator.new(), context)

    var offer := controller.build_milestone_offer(5)

    assert_eq(offer.size(), 3, "a milestone wave offers exactly three choices")
    assert_eq(offer[0].title(), "Minor x2", "slot 1 is always the Minor x2 bundle")
    assert_eq(offer[0].artifacts().size(), 2, "slot 1 bundles two distinct Minors")
    assert_ne(offer[0].artifacts()[0].id, offer[0].artifacts()[1].id, "the Minor x2 bundle must hold two distinct artifacts")


func test_milestone_offer_uses_eligible_majors_when_available() -> void:
    var context := WaveRewardContext.new(null, RunBuild.new())
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    controller.inject_reward_flow(WaveRewardChoiceGenerator.new(), context)

    var offer := controller.build_milestone_offer(5)

    var major_count := 0
    for i in range(1, offer.size()):
        if offer[i].title() != "Minor x2":
            major_count += 1
    assert_eq(major_count, 2, "with an empty build, both fallback slots should fill with eligible Majors")


func test_milestone_offer_fills_missing_major_slots_with_minor_x2() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, run_build)
    var controller: TestTickRunController = autofree(TestTickRunController.new())
    controller.inject_reward_flow(WaveRewardChoiceGenerator.new(), context)

    # Fill the legendary cap so no Major can be eligible, forcing every slot's fallback path.
    for i in RunBuild.LEGENDARY_CAP:
        var filler := Artifact.new(
            "major_%d" % i,
            "Major Placeholder",
            "Major placeholder (%d)",
            Artifact.Rarity.LEGENDARY,
            1,
            "",
            false,
            2,
            1.0,
            [],
        )
        run_build.acquire_artifact(filler, 1)

    var offer := controller.build_milestone_offer(5)

    assert_eq(offer.size(), 3, "a milestone wave still offers exactly three enabled choices")
    for choice in offer:
        assert_eq(choice.title(), "Minor x2", "every slot falls back to Minor x2 when no Major is eligible")
        assert_false(choice.is_empty(), "the fallback bundle must still be an enabled choice")
