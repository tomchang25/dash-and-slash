# tick_combat_feedback.gd
# Owns tick-arena result presentation: the HUD message text/timer and the major-trigger VFX/SFX for a
# resolved player hit outcome. TickActionController forwards set_message/current_message calls here
# through a thin facade so its own external callers (TickRunController, tick_arena.gd debug controls)
# keep working unchanged.
class_name TickCombatFeedback
extends Node

signal message_changed

const MESSAGE_SEC := 1.6

# -- Exports --

@export var player: TickPlayer

# -- State --

var _message := ""
var _message_time := 0.0

# == Lifecycle ==


func _process(delta: float) -> void:
    _update_message(delta)

# == Common API ==


## Sets the HUD message text and restarts its display timer; exposed publicly so debug controls and
## the run controller can post the same feedback real verb resolution uses instead of writing a second
## message path.
func set_message(text: String) -> void:
    _message = text
    _message_time = MESSAGE_SEC
    message_changed.emit()


func current_message() -> String:
    return _message


## Appends a short suffix to the current message instead of replacing it, so a Speed spend or Mobility
## Free Action refund note stays visible alongside whatever hit/whiff message the action already set.
func append_suffix(suffix: String) -> void:
    set_message("%s (%s)" % [_message, suffix] if _message != "" else suffix)


## Reports one committed player hit outcome: layers Major-trigger VFX/SFX over the fallback hit
## feedback, then sets the HUD message from the outcome. Callers with no meaningful hit position (a
## mobility strike with no victims) should call set_message(message_for_outcome(...)) directly instead,
## since an empty outcome carries no Major trigger and no VFX should fire.
func report_hit_outcome(result: TickHitOutcome, world_pos: Vector2) -> void:
    _play_major_trigger_feedback(result, world_pos)
    set_message(message_for_outcome(result))


## Renders one hit outcome as the HUD result text: whiff, kill/execution, guard break/shredder, stagger
## burst, blocked, or a plain angle-named hit. Pure so it can be unit-tested without a scene tree.
static func message_for_outcome(result: TickHitOutcome) -> String:
    match result.feedback_kind:
        TickHitOutcome.FeedbackKind.WHIFF:
            return "Whiff."
        TickHitOutcome.FeedbackKind.KILL:
            if result.major_trigger == TickHitOutcome.MajorTrigger.EXECUTION:
                return "EXECUTION!"
            return "Enemy destroyed!"
        TickHitOutcome.FeedbackKind.GUARD_BREAK:
            if result.major_trigger == TickHitOutcome.MajorTrigger.GUARD_SHREDDER:
                return "GUARD SHREDDER!"
            return "%s hit — GUARD BREAK!" % TickCombatRules.angle_name(result.angle)
        TickHitOutcome.FeedbackKind.STAGGER_BURST:
            return "%s burst hit." % TickCombatRules.angle_name(result.angle)
        TickHitOutcome.FeedbackKind.BLOCKED:
            return "%s blocked." % TickCombatRules.angle_name(result.angle)
        TickHitOutcome.FeedbackKind.DAMAGED:
            return "%s hit." % TickCombatRules.angle_name(result.angle)
        _:
            ToastManager.show_dev_error("TickCombatFeedback: unexpected feedback kind %s" % result.feedback_kind)
            return ""

# == Message timer ==


func _update_message(delta: float) -> void:
    if _message_time <= 0.0:
        return
    _message_time -= delta
    if _message_time <= 0.0:
        _message = ""
        message_changed.emit()

# == Major trigger VFX/SFX ==


## Layers distinct temporary VFX/SFX for a mobility-slot-triggered Major's upgraded result on top of the
## shared hit feedback GridEnemy already played, so Shredder and Execution read clearly without silencing
## the fallback guard-break/kill feedback every hit already has.
func _play_major_trigger_feedback(result: TickHitOutcome, world_pos: Vector2) -> void:
    if result.major_trigger == TickHitOutcome.MajorTrigger.GUARD_SHREDDER:
        MajorTriggerFeedbackVFX.play_guard_shredder(world_pos, self)
        AudioManager.play_event(player.guard_shredder_sfx_event, world_pos)
    elif result.major_trigger == TickHitOutcome.MajorTrigger.EXECUTION:
        MajorTriggerFeedbackVFX.play_execution(world_pos, self)
        AudioManager.play_event(player.execution_sfx_event, world_pos)
