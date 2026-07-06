# dash_attack_damage_effect.gd
# Reward effect that adds a run-local bonus to the mobility slot's attack damage, recorded on
# RunBuild's Mobility Attack Damage channel. Named for Dash since it is the default mobility payload,
# but Smash reads the same channel once a Major replaces the slot. Always offerable — Player and the
# tick arena's action controller both project their own base damage plus this channel's total.
class_name DashAttackDamageEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_MOBILITY_ATTACK_DAMAGE, magnitude * float(stacks))
