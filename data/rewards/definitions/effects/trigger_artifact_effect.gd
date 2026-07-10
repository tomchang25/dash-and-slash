# trigger_artifact_effect.gd
# Artifact effect that activates one class-Mobility trigger (Guard Shredder, Execution, or Chain
# Dash). The active Dash resolution reads the trigger from RunBuild directly, so this effect only
# needs to flip it on.
class_name TriggerArtifactEffect
extends ArtifactEffect

@export var trigger := &""

# == Overridden Custom Methods ==


func apply(run_build: RunBuild, _stacks: int) -> void:
    run_build.set_mobility_trigger(trigger, true)
