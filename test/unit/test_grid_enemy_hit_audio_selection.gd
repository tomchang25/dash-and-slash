# test_grid_enemy_hit_audio_selection.gd
# Covers GridEnemy's single-result SFX selection (_select_result_sfx_event()): blocked-hit
# preservation (including the back-angle damaged substitution), Guard Shredder and Execution Major
# priority over their generic fallbacks, the mobility-kill and default-death fallback chain for KILL,
# and the shared damaged event for STAGGER_BURST/DAMAGED. Also covers the queued death-override
# lifecycle (_consume_queued_death_sfx_event()): consuming and clearing a queued override, falling
# back to the authored death event when nothing was queued, and never replaying a stale override after
# a prevented kill clears the queue. Exercised as pure selection/state so no AudioManager playback or
# scene tree is needed.
extends GutTest

class TestGridEnemy:
    extends GridEnemy

    func select_result_sfx_event(outcome: TickHitOutcome, sfx_context: TickHitSfxContext) -> SpatialAudioEvent:
        return _select_result_sfx_event(outcome, sfx_context)


    func queue_death_sfx_event(event: SpatialAudioEvent) -> void:
        _queued_death_sfx_event = event


    func consume_queued_death_sfx_event() -> SpatialAudioEvent:
        return _consume_queued_death_sfx_event()


func _make_enemy() -> TestGridEnemy:
    var enemy: TestGridEnemy = autofree(TestGridEnemy.new())
    enemy.death_sfx_event = SpatialAudioEvent.new()
    enemy.damaged_sfx_event = SpatialAudioEvent.new()
    enemy.blocked_sfx_event = SpatialAudioEvent.new()
    enemy.guard_break_sfx_event = SpatialAudioEvent.new()
    return enemy


func _make_outcome(
        feedback_kind: TickHitOutcome.FeedbackKind,
        major_trigger := TickHitOutcome.MajorTrigger.NONE,
        angle := TileDirectionResolver.HitAngle.NONE,
) -> TickHitOutcome:
    var outcome := TickHitOutcome.new()
    outcome.feedback_kind = feedback_kind
    outcome.major_trigger = major_trigger
    outcome.angle = angle
    return outcome

# == Selection: blocked ==


func test_blocked_hit_keeps_the_blocked_event_for_a_non_back_angle() -> void:
    var enemy := _make_enemy()
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.BLOCKED, TickHitOutcome.MajorTrigger.NONE, TileDirectionResolver.HitAngle.FRONT)

    var event := enemy.select_result_sfx_event(outcome, null)

    assert_eq(event, enemy.blocked_sfx_event)


func test_blocked_hit_from_the_back_substitutes_the_damaged_event() -> void:
    var enemy := _make_enemy()
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.BLOCKED, TickHitOutcome.MajorTrigger.NONE, TileDirectionResolver.HitAngle.BACK)

    var event := enemy.select_result_sfx_event(outcome, null)

    assert_eq(event, enemy.damaged_sfx_event)

# == Selection: guard break ==


func test_ordinary_guard_break_selects_the_generic_guard_break_event() -> void:
    var enemy := _make_enemy()
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.GUARD_BREAK)

    var event := enemy.select_result_sfx_event(outcome, null)

    assert_eq(event, enemy.guard_break_sfx_event)


func test_guard_shredder_break_selects_the_guard_shredder_event_over_the_generic_break_event() -> void:
    var enemy := _make_enemy()
    var guard_shredder_event := SpatialAudioEvent.new()
    var sfx_context := TickHitSfxContext.new(null, guard_shredder_event, null)
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.GUARD_BREAK, TickHitOutcome.MajorTrigger.GUARD_SHREDDER)

    var event := enemy.select_result_sfx_event(outcome, sfx_context)

    assert_eq(event, guard_shredder_event, "Guard Shredder must replace the generic Guard Break event")


func test_guard_shredder_break_without_a_context_event_falls_back_to_the_generic_break_event() -> void:
    var enemy := _make_enemy()
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.GUARD_BREAK, TickHitOutcome.MajorTrigger.GUARD_SHREDDER)

    var event := enemy.select_result_sfx_event(outcome, TickHitSfxContext.new())

    assert_eq(event, enemy.guard_break_sfx_event, "a missing Guard Shredder event must fall back to the generic Guard Break event")


func test_guard_break_without_a_dedicated_event_assigned_stays_silent() -> void:
    var enemy := _make_enemy()
    enemy.guard_break_sfx_event = null
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.GUARD_BREAK)

    var event := enemy.select_result_sfx_event(outcome, null)

    assert_null(event, "a missing generic event must remain silent rather than layering the damaged event")

# == Selection: stagger burst and ordinary damage ==


func test_stagger_burst_and_ordinary_damage_share_the_generic_damaged_event() -> void:
    var enemy := _make_enemy()

    var stagger_event := enemy.select_result_sfx_event(_make_outcome(TickHitOutcome.FeedbackKind.STAGGER_BURST), null)
    var damaged_event := enemy.select_result_sfx_event(_make_outcome(TickHitOutcome.FeedbackKind.DAMAGED), null)

    assert_eq(stagger_event, enemy.damaged_sfx_event)
    assert_eq(damaged_event, enemy.damaged_sfx_event)

# == Selection: kill ==


func test_execution_kill_selects_the_execution_event_over_the_mobility_kill_event() -> void:
    var enemy := _make_enemy()
    var execution_event := SpatialAudioEvent.new()
    var mobility_kill_event := SpatialAudioEvent.new()
    var sfx_context := TickHitSfxContext.new(mobility_kill_event, null, execution_event)
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.KILL, TickHitOutcome.MajorTrigger.EXECUTION)

    var event := enemy.select_result_sfx_event(outcome, sfx_context)

    assert_eq(event, execution_event, "Execution must take priority over the mobility-kill event")


func test_execution_kill_without_a_context_event_falls_back_to_the_mobility_kill_event() -> void:
    var enemy := _make_enemy()
    var mobility_kill_event := SpatialAudioEvent.new()
    var sfx_context := TickHitSfxContext.new(mobility_kill_event, null, null)
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.KILL, TickHitOutcome.MajorTrigger.EXECUTION)

    var event := enemy.select_result_sfx_event(outcome, sfx_context)

    assert_eq(event, mobility_kill_event, "a missing Execution event must fall through to the mobility-kill event")


func test_dash_or_smash_kill_selects_the_mobility_kill_event() -> void:
    var enemy := _make_enemy()
    var mobility_kill_event := SpatialAudioEvent.new()
    var sfx_context := TickHitSfxContext.new(mobility_kill_event, null, null)
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.KILL)

    var event := enemy.select_result_sfx_event(outcome, sfx_context)

    assert_eq(event, mobility_kill_event)


func test_normal_attack_kill_selects_no_event_so_the_default_death_event_plays_instead() -> void:
    var enemy := _make_enemy()
    var outcome := _make_outcome(TickHitOutcome.FeedbackKind.KILL)

    var event := enemy.select_result_sfx_event(outcome, null)

    assert_null(event, "a kill with no mobility sfx context must select nothing, deferring to the enemy's own death event")

# == Death-override queue lifecycle ==


func test_consuming_a_queued_death_event_returns_it_and_clears_the_queue() -> void:
    var enemy := _make_enemy()
    var queued_event := SpatialAudioEvent.new()
    enemy.queue_death_sfx_event(queued_event)

    var first := enemy.consume_queued_death_sfx_event()
    var second := enemy.consume_queued_death_sfx_event()

    assert_eq(first, queued_event, "the queued override must be returned once")
    assert_eq(second, enemy.death_sfx_event, "a second consume after the queue is cleared must fall back to the authored death event")


func test_consuming_an_empty_queue_falls_back_to_the_authored_death_event() -> void:
    var enemy := _make_enemy()

    var event := enemy.consume_queued_death_sfx_event()

    assert_eq(event, enemy.death_sfx_event)


func test_a_prevented_kill_never_replays_a_stale_queued_override() -> void:
    var enemy := _make_enemy()
    var stale_event := SpatialAudioEvent.new()
    enemy.queue_death_sfx_event(stale_event)

    # take_hit() clears the queue this same way (without consuming it) when a predicted-lethal hit did
    # not actually reduce health to zero (invulnerability, debug No-Damage/Undead).
    enemy.queue_death_sfx_event(null)
    var event := enemy.consume_queued_death_sfx_event()

    assert_eq(event, enemy.death_sfx_event, "force_death() after a prevented kill must play the default death event, never the stale override")
