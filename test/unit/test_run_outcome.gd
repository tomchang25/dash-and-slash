# test_run_outcome.gd
# Tests RunOutcome as an immutable terminal-run snapshot: it stores exactly the reason, selected
# character, highest completed wave, and demo-completion state it was constructed with.
extends GutTest


func test_death_outcome_stores_constructor_fields() -> void:
    var character_class := CharacterClassData.new()
    character_class.display_name = "Ninja"

    var outcome := RunOutcome.new(RunOutcome.Reason.DEATH, character_class, 7, false)

    assert_eq(outcome.reason, RunOutcome.Reason.DEATH)
    assert_eq(outcome.character_class, character_class)
    assert_eq(outcome.highest_completed_wave, 7)
    assert_false(outcome.demo_completed)


func test_end_run_outcome_stores_constructor_fields() -> void:
    var character_class := CharacterClassData.new()
    character_class.display_name = "Viking"

    var outcome := RunOutcome.new(RunOutcome.Reason.END_RUN, character_class, 10, true)

    assert_eq(outcome.reason, RunOutcome.Reason.END_RUN)
    assert_eq(outcome.character_class, character_class)
    assert_eq(outcome.highest_completed_wave, 10)
    assert_true(outcome.demo_completed)


func test_outcome_accepts_a_null_character_class() -> void:
    var outcome := RunOutcome.new(RunOutcome.Reason.DEATH, null, 0, false)

    assert_null(outcome.character_class)
    assert_eq(outcome.highest_completed_wave, 0)
