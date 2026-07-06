# player_stat_effect.gd
# Abstract intermediate base for reward effects that require a legacy real-time Player in context and
# have no honest tick-arena projection yet. Attack Range is the only remaining concrete effect; every
# other former player-stat effect now records straight to RunBuild so it can offer and apply in the
# tick arena too. This gate is also what excludes Attack Range from tick reward generation, since the
# tick reward context never carries a legacy player.
@abstract
class_name PlayerStatEffect
extends WaveRewardEffectDefinition

# == Effect Contract ==

func is_applicable(context: WaveRewardContext) -> bool:
    return context.player != null
