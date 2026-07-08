# max_health_effect.gd
# Reward effect that raises max health through RunBuild's Max Health channel for TickPlayer to project.
class_name MaxHealthEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    var amount := magnitude * float(stacks)
    context.run_build.record(RunBuild.CH_MAX_HEALTH, amount)
