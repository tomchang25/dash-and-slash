# execution_major_effect.gd
# Major reward effect that arms the mobility slot with an execute condition: a Dash or Smash hit on
# an already-staggered target kills instantly instead of dealing its normal stagger-burst damage.
class_name ExecutionMajorEffect
extends MajorEffect

# == Effect Contract ==

## Registers the Major through the base contract, then activates the run's Execution mobility trigger.
func apply(context: WaveRewardContext, stacks: int) -> void:
    super.apply(context, stacks)
    context.run_build.set_mobility_trigger(RunBuild.TRIGGER_EXECUTION, true)
