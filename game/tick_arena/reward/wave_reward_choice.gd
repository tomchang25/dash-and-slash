# wave_reward_choice.gd
# Runtime owned-artifact value object representing one offered reward choice.
class_name WaveRewardChoice
extends RefCounted

var artifact: Artifact
var stacks := 1

# == Lifecycle ==


func _init(init_artifact: Artifact, init_stacks: int = 1) -> void:
    artifact = init_artifact
    stacks = max(init_stacks, 1)

# == Common API ==


## Registers the artifact in the run build's owned-artifact registry, then applies its effect
## contributions. A rejected registration here signals a programmer error, since is_eligible is the
## pre-offer filter that should have already excluded a conflicting or already-owned artifact.
func apply(context: WaveRewardContext) -> void:
    if not context.run_build.acquire_artifact(artifact, stacks):
        ToastManager.show_dev_error("WaveRewardChoice: %s rejected by RunBuild after passing is_eligible" % artifact.id)
        return
    artifact.apply(context, stacks)


func description() -> String:
    var amount := artifact.magnitude * float(stacks)
    if is_equal_approx(amount, roundf(amount)):
        return artifact.description_template % int(amount)
    return artifact.description_template % amount
