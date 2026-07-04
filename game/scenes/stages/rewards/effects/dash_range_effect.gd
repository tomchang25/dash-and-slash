# dash_range_effect.gd
# Reward effect that adds a run-local bonus to dash travel range.
class_name DashRangeEffect
extends PlayerStatEffect

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.player.add_dash_range(magnitude * float(stacks))
