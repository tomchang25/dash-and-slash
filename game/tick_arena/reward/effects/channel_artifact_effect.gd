# channel_artifact_effect.gd
# Artifact effect that records a signed per-stack amount on one RunBuild channel. unit_scale
# converts a percent-authored amount (e.g. 5.0 meaning 5%) into the fraction RunBuild's consumers
# expect; flat channels use the default unit_scale of 1.0.
class_name ChannelArtifactEffect
extends ArtifactEffect

var channel := &""
var amount := 0.0
var unit_scale := 1.0

# == Lifecycle ==


func _init(init_channel: StringName, init_amount: float, init_unit_scale: float = 1.0) -> void:
    channel = init_channel
    amount = init_amount
    unit_scale = init_unit_scale

# == Overridden Custom Methods ==


func apply(run_build: RunBuild, stacks: int) -> void:
    run_build.record(channel, amount * unit_scale * float(stacks))
