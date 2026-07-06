# guard_shredder_major_effect.gd
# Major reward effect that arms the mobility slot with an instant guard break: a back-angle Dash or
# Smash hit zeroes the target's guard and enters stagger immediately, bypassing the
# max(half_guard, 32) back guard-damage table.
class_name GuardShredderMajorEffect
extends MajorEffect

# == Effect Contract ==

## Registers the Major through the base contract, then activates the run's Guard Shredder mobility trigger.
func apply(context: WaveRewardContext, stacks: int) -> void:
    super.apply(context, stacks)
    context.run_build.set_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, true)
