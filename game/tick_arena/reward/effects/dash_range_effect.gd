# dash_range_effect.gd
# Reward effect that adds a run-local percentage bonus to the mobility slot's travel/reach range,
# recorded on RunBuild's Mobility Range channel. Named for Dash since it is the default mobility
# payload, but Smash reads the same channel once a Major replaces the slot. Always offerable — Player
# and the tick arena's action controller both project their own base range plus this channel's total.
class_name DashRangeEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_MOBILITY_RANGE, magnitude * float(stacks))
