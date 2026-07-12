# tick_hit_sfx_context.gd
# Carries player-owned optional Result SFX overrides from a committed mobility action (Dash or Smash)
# to one target hit. Immutable input data for GridEnemy's single-result SFX selection; not a playback
# owner and not a second hit resolver. A normal attack passes no context at all.
class_name TickHitSfxContext
extends RefCounted

# -- State --

var mobility_kill_event: SpatialAudioEvent
var guard_shredder_event: SpatialAudioEvent
var execution_event: SpatialAudioEvent

# == Lifecycle ==


func _init(mobility_kill: SpatialAudioEvent = null, guard_shredder: SpatialAudioEvent = null, execution: SpatialAudioEvent = null) -> void:
    mobility_kill_event = mobility_kill
    guard_shredder_event = guard_shredder
    execution_event = execution
