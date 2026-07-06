# normal_attack_damage_effect.gd
# Reward effect that adds a run-local bonus to normal attack damage, recorded on RunBuild's Normal
# Attack Damage channel. Always offerable — Player and the tick arena's action controller both
# project their own base damage plus this channel's total, so no player reference is required here.
class_name NormalAttackDamageEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_NORMAL_ATTACK_DAMAGE, magnitude * float(stacks))
