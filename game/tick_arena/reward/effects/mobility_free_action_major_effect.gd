# mobility_free_action_major_effect.gd
# Major reward effect that arms the mobility slot with a conditional free action: a Dash or Smash
# strike that produces a kill, a guard break, or a back-angle hit skips world advancement for that
# action instead of spending it, regardless of whether Dash or Smash occupies the slot.
class_name MobilityFreeActionMajorEffect
extends MajorEffect

# == Effect Contract ==

## Registers the Major through the base contract, then activates the run's Mobility Free Action trigger.
func apply(context: WaveRewardContext, stacks: int) -> void:
    super.apply(context, stacks)
    context.run_build.set_mobility_trigger(RunBuild.TRIGGER_MOBILITY_FREE_ACTION, true)
