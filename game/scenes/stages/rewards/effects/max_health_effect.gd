# max_health_effect.gd
# Reward effect that adds to the player's max health through Health.
class_name MaxHealthEffect
extends PlayerStatEffect

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.player.add_max_health(magnitude * float(stacks))
