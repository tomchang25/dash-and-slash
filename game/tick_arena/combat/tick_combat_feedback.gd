# tick_combat_feedback.gd
# Owns tick-arena result presentation: the major-trigger VFX/SFX for a resolved player hit outcome.
class_name TickCombatFeedback
extends Node

# -- Exports --

@export var player: TickPlayer

# == Common API ==


## Reports one committed player hit outcome: layers Major-trigger VFX/SFX over the fallback hit
## feedback. Callers with no meaningful hit position (a mobility strike with no victims) should skip
## this call entirely, since an empty outcome carries no Major trigger and no VFX should fire.
func report_hit_outcome(result: TickHitOutcome, world_pos: Vector2) -> void:
    _play_major_trigger_feedback(result, world_pos)

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
