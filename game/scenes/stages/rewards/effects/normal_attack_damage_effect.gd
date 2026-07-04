# normal_attack_damage_effect.gd
# Reward effect that adds a run-local bonus to normal attack damage.
class_name NormalAttackDamageEffect
extends PlayerStatEffect

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.player.add_normal_attack_damage(magnitude * float(stacks))
