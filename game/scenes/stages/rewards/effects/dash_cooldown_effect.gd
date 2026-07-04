# dash_cooldown_effect.gd
# Reward effect that reduces the run-local dash cooldown.
class_name DashCooldownEffect
extends PlayerStatEffect

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.player.reduce_dash_cooldown(magnitude * float(stacks))
