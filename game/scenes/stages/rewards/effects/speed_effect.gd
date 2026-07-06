# speed_effect.gd
# Reward effect that adds Speed stacks to the run's shared move/normal-attack meter fill rate,
# recorded on RunBuild's Speed channel. Always offerable — carries no player/grid dependency, since
# TickPlayer reads the recorded total itself at fill time.
class_name SpeedEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_SPEED, magnitude * float(stacks))
