# max_health_effect.gd
# Reward effect that raises max health. Always offerable — the legacy Player applies the raw delta
# straight through Health (per Health.add_max_health's own contract: a per-call delta, never a
# recomputed store total), so that path stays a direct call against Player. The tick arena carries no
# legacy player in context, so there the same amount is instead recorded on RunBuild's Max Health
# channel for TickPlayer to project.
class_name MaxHealthEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    var amount := magnitude * float(stacks)
    if context.player != null:
        context.player.add_max_health(amount)
    else:
        context.run_build.record(RunBuild.CH_MAX_HEALTH, amount)
