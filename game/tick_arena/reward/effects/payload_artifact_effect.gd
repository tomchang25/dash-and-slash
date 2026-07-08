# payload_artifact_effect.gd
# Artifact effect that replaces the run's mobility-slot payload (e.g. Smash replacing Dash).
class_name PayloadArtifactEffect
extends ArtifactEffect

@export var payload: StringName = RunBuild.PAYLOAD_DASH

# == Overridden Custom Methods ==


func apply(run_build: RunBuild, _stacks: int) -> void:
    run_build.set_mobility_payload_override(payload)
