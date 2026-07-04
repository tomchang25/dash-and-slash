# normal_attack_cooldown_effect.gd
# Reward effect that reduces the run-local normal attack cooldown.
class_name NormalAttackCooldownEffect
extends PlayerStatEffect

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.player.reduce_normal_attack_cooldown(magnitude * float(stacks))
