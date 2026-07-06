# mobility_cooldown_effect.gd
# Reward effect that adds Mobility Cooldown reduction stacks to the run's shared Dash/Smash cooldown
# projection, recorded on RunBuild's Mobility Cooldown channel. Always offerable — carries no
# player/grid dependency, since the mobility-slot verb reads the recorded total itself at cooldown-set time.
class_name MobilityCooldownEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_MOBILITY_COOLDOWN, magnitude * float(stacks))
