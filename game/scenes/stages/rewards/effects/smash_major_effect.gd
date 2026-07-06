# smash_major_effect.gd
# Major reward effect that replaces the run's mobility-slot payload with Smash: an area leap-and-slam
# that trades Dash's instant single-target reach for a delayed 3x3 guard-breaker.
class_name SmashMajorEffect
extends MajorEffect

## Exclusivity-group id shared with the future Chain Dash Major, since only one mobility-slot
## replacement can be active at a time.
const EXCLUSIVITY_GROUP := "mobility_slot_replacement"

# == Effect Contract ==


## Registers the Major through the base contract, then swaps the run's mobility-slot payload to Smash.
func apply(context: WaveRewardContext, stacks: int) -> void:
    super.apply(context, stacks)
    context.run_build.set_mobility_payload_override(RunBuild.PAYLOAD_SMASH)
