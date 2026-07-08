# attack_range_effect.gd
# Reward effect that adds a run-local bonus to normal attack hit-geometry range.
class_name AttackRangeEffect
extends PlayerStatEffect

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_ATTACK_RANGE, magnitude * float(stacks))
