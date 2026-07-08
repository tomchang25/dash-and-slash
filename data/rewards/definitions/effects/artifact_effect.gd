# artifact_effect.gd
# Abstract contribution applied by an Artifact when picked. Every concrete effect writes through
# one of RunBuild's existing mutators, so the store's read API never changes shape.
@abstract
class_name ArtifactEffect
extends Resource

# == Effect Contract ==

## Applies this contribution against the run build for the given stack count.
@abstract func apply(run_build: RunBuild, stacks: int) -> void
