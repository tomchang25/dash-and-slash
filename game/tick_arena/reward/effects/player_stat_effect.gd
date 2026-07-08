# player_stat_effect.gd
# Abstract intermediate base for retired legacy player-stat reward effects that have no active tick projection.
@abstract
class_name PlayerStatEffect
extends WaveRewardEffectDefinition

# == Effect Contract ==

func is_applicable(context: WaveRewardContext) -> bool:
    return false
