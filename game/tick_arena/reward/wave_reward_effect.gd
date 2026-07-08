# wave_reward_effect.gd
# Runtime owned-artifact value rolled into one wave reward choice.
class_name WaveRewardEffect
extends RefCounted

var artifact: Artifact
var stacks := 1

# == Lifecycle ==


func _init(init_artifact: Artifact, init_stacks: int = 1) -> void:
    artifact = init_artifact
    stacks = max(init_stacks, 1)

# == Common API ==


func total_points() -> float:
    return artifact.point_value * stacks


func total_magnitude() -> float:
    return artifact.magnitude * float(stacks)


## Registers the artifact in the run build's owned-artifact registry, then applies its effect
## contributions. A rejected registration here signals a programmer error, since is_eligible is the
## pre-offer filter that should have already excluded a conflicting or already-owned artifact.
func apply(context: WaveRewardContext) -> void:
    if not context.run_build.acquire_artifact(artifact, stacks):
        ToastManager.show_dev_error("WaveRewardEffect: %s rejected by RunBuild after passing is_eligible" % artifact.id)
        return
    artifact.apply(context, stacks)


func description() -> String:
    var amount := total_magnitude()
    if is_equal_approx(amount, roundf(amount)):
        return artifact.description_template % int(amount)
    return artifact.description_template % amount
