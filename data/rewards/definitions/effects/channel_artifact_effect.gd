# channel_artifact_effect.gd
# Artifact effect that records a signed per-stack amount on one RunBuild channel. unit_scale
# converts a percent-authored amount (e.g. 5.0 meaning 5%) into the fraction RunBuild's consumers
# expect; flat channels use the default unit_scale of 1.0.
class_name ChannelArtifactEffect
extends ArtifactEffect

@export var channel := &""
@export var amount := 0.0
@export var unit_scale := 1.0

# == Overridden Custom Methods ==


func apply(run_build: RunBuild, stacks: int) -> void:
    run_build.record(channel, amount * unit_scale * float(stacks))
