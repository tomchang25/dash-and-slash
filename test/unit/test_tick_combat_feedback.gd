# test_tick_combat_feedback.gd
# Tests TickCombatFeedback's message state (set/current/append/expiry) and its pure outcome-to-HUD-text
# mapping, extracted from TickActionController so a hit resolving is no longer the thing that owns HUD
# vocabulary. No exported scene dependency (player) is needed for these paths, so the node is exercised
# without a scene tree.
extends GutTest


func _make_outcome(
        feedback_kind: TickHitOutcome.FeedbackKind,
        angle := TileDirectionResolver.HitAngle.FRONT,
        major_trigger := TickHitOutcome.MajorTrigger.NONE,
) -> TickHitOutcome:
    var outcome := TickHitOutcome.new()
    outcome.feedback_kind = feedback_kind
    outcome.angle = angle
    outcome.major_trigger = major_trigger
    return outcome


func test_message_starts_empty_and_set_message_updates_it() -> void:
    var feedback: TickCombatFeedback = autofree(TickCombatFeedback.new())

    assert_eq(feedback.current_message(), "")

    feedback.set_message("Whiff.")

    assert_eq(feedback.current_message(), "Whiff.")


func test_set_message_emits_message_changed() -> void:
    var feedback: TickCombatFeedback = autofree(TickCombatFeedback.new())
    watch_signals(feedback)

    feedback.set_message("Whiff.")

    assert_signal_emitted(feedback, "message_changed")


func test_append_suffix_appends_to_an_existing_message() -> void:
    var feedback: TickCombatFeedback = autofree(TickCombatFeedback.new())
    feedback.set_message("Front hit.")

    feedback.append_suffix("Speed spent — free attack!")

    assert_eq(feedback.current_message(), "Front hit. (Speed spent — free attack!)")


func test_append_suffix_stands_alone_when_no_message_is_set() -> void:
    var feedback: TickCombatFeedback = autofree(TickCombatFeedback.new())

    feedback.append_suffix("Mobility refunded — free!")

    assert_eq(feedback.current_message(), "Mobility refunded — free!")


func test_message_clears_after_its_display_duration() -> void:
    var feedback: TickCombatFeedback = autofree(TickCombatFeedback.new())
    feedback.set_message("Front hit.")
    watch_signals(feedback)

    feedback._process(TickCombatFeedback.MESSAGE_SEC + 0.1)

    assert_eq(feedback.current_message(), "")
    assert_signal_emitted(feedback, "message_changed")


func test_message_survives_a_partial_tick() -> void:
    var feedback: TickCombatFeedback = autofree(TickCombatFeedback.new())
    feedback.set_message("Front hit.")

    feedback._process(TickCombatFeedback.MESSAGE_SEC - 0.1)

    assert_eq(feedback.current_message(), "Front hit.")


func test_message_for_outcome_whiff() -> void:
    assert_eq(TickCombatFeedback.message_for_outcome(_make_outcome(TickHitOutcome.FeedbackKind.WHIFF)), "Whiff.")


func test_message_for_outcome_kill() -> void:
    assert_eq(TickCombatFeedback.message_for_outcome(_make_outcome(TickHitOutcome.FeedbackKind.KILL)), "Enemy destroyed!")


func test_message_for_outcome_execution_kill() -> void:
    var text := TickCombatFeedback.message_for_outcome(_make_outcome(TickHitOutcome.FeedbackKind.KILL, TileDirectionResolver.HitAngle.BACK, TickHitOutcome.MajorTrigger.EXECUTION))
    assert_eq(text, "EXECUTION!")


func test_message_for_outcome_guard_break() -> void:
    var text := TickCombatFeedback.message_for_outcome(_make_outcome(TickHitOutcome.FeedbackKind.GUARD_BREAK, TileDirectionResolver.HitAngle.BACK))
    assert_eq(text, "BACK hit — GUARD BREAK!")


func test_message_for_outcome_guard_shredder() -> void:
    var text := TickCombatFeedback.message_for_outcome(_make_outcome(TickHitOutcome.FeedbackKind.GUARD_BREAK, TileDirectionResolver.HitAngle.BACK, TickHitOutcome.MajorTrigger.GUARD_SHREDDER))
    assert_eq(text, "GUARD SHREDDER!")


func test_message_for_outcome_stagger_burst() -> void:
    var text := TickCombatFeedback.message_for_outcome(_make_outcome(TickHitOutcome.FeedbackKind.STAGGER_BURST, TileDirectionResolver.HitAngle.SIDE))
    assert_eq(text, "Side burst hit.")


func test_message_for_outcome_blocked() -> void:
    var text := TickCombatFeedback.message_for_outcome(_make_outcome(TickHitOutcome.FeedbackKind.BLOCKED, TileDirectionResolver.HitAngle.FRONT))
    assert_eq(text, "Front blocked.")


func test_message_for_outcome_damaged() -> void:
    var text := TickCombatFeedback.message_for_outcome(_make_outcome(TickHitOutcome.FeedbackKind.DAMAGED, TileDirectionResolver.HitAngle.SIDE))
    assert_eq(text, "Side hit.")
