# wave_reward_applier.gd
# Applies selected wave reward effects by asking each to apply itself
# against a shared context bundle.
class_name WaveRewardApplier
extends RefCounted

# == Common API ==

func apply(choice: WaveRewardChoice, context: WaveRewardContext) -> void:
    for effect in choice.effects:
        effect.apply(context)
