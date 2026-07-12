# tick_combat_feedback.gd
# Owns tick-arena result presentation: the major-trigger VFX for a resolved player hit outcome. Result
# SFX selection lives on GridEnemy (see _select_result_sfx_event()); this presenter is VFX-only and
# holds no player audio-reference export.
class_name TickCombatFeedback
extends Node

# == Common API ==

## Reports one committed player hit outcome: layers Major-trigger VFX over the fallback hit feedback
## VFX GridEnemy already played. Callers with no meaningful hit position (a mobility strike with no
## victims) should skip this call entirely, since an empty outcome carries no Major trigger and no VFX
## should fire.
func report_hit_outcome(result: TickHitOutcome, world_pos: Vector2) -> void:
    _play_major_trigger_feedback(result, world_pos)

# == Major trigger VFX ==


## Layers distinct temporary VFX for a mobility-slot-triggered Major's upgraded result on top of the
## shared hit feedback GridEnemy already played, so Shredder and Execution read clearly without
## silencing the fallback guard-break/kill feedback every hit already has.
func _play_major_trigger_feedback(result: TickHitOutcome, world_pos: Vector2) -> void:
    if result.major_trigger == TickHitOutcome.MajorTrigger.GUARD_SHREDDER:
        MajorTriggerFeedbackVFX.play_guard_shredder(world_pos, self)
    elif result.major_trigger == TickHitOutcome.MajorTrigger.EXECUTION:
        MajorTriggerFeedbackVFX.play_execution(world_pos, self)
