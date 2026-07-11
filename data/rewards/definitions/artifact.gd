# artifact.gd
# Resource definition for one reward artifact: identity, rarity/stack/exclusivity/curse metadata,
# the list of effect contributions applied to RunBuild when picked, and the icon reward cards
# render. Authored directly as .tres content and cataloged by ArtifactRegistry — the read-only
# content source WaveRewardChoiceGenerator rolls and filters against; the generator never authors
# artifact content itself.
class_name Artifact
extends Resource

enum Rarity {
    COMMON,
    LEGENDARY,
}

@export var id := &""
@export var display_name := ""
@export var description_template := ""
@export var rarity: Rarity = Rarity.COMMON
@export var max_stacks := 1
@export var exclusivity_group := &""
@export var is_curse := false
@export var min_wave := 1
@export var magnitude := 1.0
@export var required_mobility := &""
@export var effects: Array[ArtifactEffect] = []
@export var icon: Texture2D

# == Common API ==


## Returns whether this artifact can be offered against the given context's run build: not already
## owned if unique (max_stacks == 1), no exclusivity conflict, and a free legendary slot if this
## artifact is legendary. Caller applies the separate min_wave/kind filters, matching the split
## WaveRewardChoiceGenerator already uses for every candidate.
func is_eligible(context: WaveRewardContext) -> bool:
    if context.run_build == null:
        return false
    if required_mobility != &"" and required_mobility != context.mobility_id:
        return false
    if max_stacks <= 1 and context.run_build.has_artifact(id):
        return false
    return context.run_build.can_acquire_artifact(self)


## Applies each effect contribution in turn against the run build.
func apply(context: WaveRewardContext, stacks: int) -> void:
    for effect in effects:
        effect.apply(context.run_build, stacks)


## Formats description_template scaled by the given stack count, sharing one magnitude-times-stacks
## rounding rule between reward-card and build-inspection-panel display text.
func format_description(stacks: int) -> String:
    var amount := magnitude * float(stacks)
    if is_equal_approx(amount, roundf(amount)):
        return description_template % int(amount)
    return description_template % amount
