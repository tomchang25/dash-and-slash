# trigger_artifact_effect.gd
# Artifact effect that activates one mobility-slot trigger (Guard Shredder, Execution, Flowing
# Strike). The active mobility strike's resolution reads the trigger from RunBuild directly, so
# this effect only needs to flip it on.
class_name TriggerArtifactEffect
extends ArtifactEffect

var trigger := &""

# == Lifecycle ==


func _init(init_trigger: StringName) -> void:
    trigger = init_trigger

# == Overridden Custom Methods ==


func apply(run_build: RunBuild, _stacks: int) -> void:
    run_build.set_mobility_trigger(trigger, true)
