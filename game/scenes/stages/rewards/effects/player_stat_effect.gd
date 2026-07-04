# player_stat_effect.gd
# Abstract intermediate base for reward effects that mutate a player-owned
# run stat. Requires a player in context; leaves implement apply().
@abstract
class_name PlayerStatEffect
extends WaveRewardEffectDefinition

# == Effect Contract ==

func is_applicable(context: WaveRewardContext) -> bool:
    return context.player != null
