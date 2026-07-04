# dash_attack_damage_effect.gd
# Reward effect that adds a run-local bonus to dash attack damage.
class_name DashAttackDamageEffect
extends PlayerStatEffect

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.player.add_dash_attack_damage(magnitude * float(stacks))
