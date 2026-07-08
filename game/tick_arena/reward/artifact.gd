# artifact.gd
# Prototype definition for one reward artifact: identity, rarity/stack/exclusivity/curse metadata,
# roll-balance metadata read by WaveRewardChoiceGenerator, and the list of effect contributions
# applied to RunBuild when picked. Replaces the former WaveRewardEffectDefinition tier hierarchy —
# rarity, stack rule, exclusivity, and curse status are data instead of subclasses.
class_name Artifact
extends RefCounted

enum Rarity {
    COMMON,
    LEGENDARY,
}

var id := &""
var display_name := ""
var description_template := ""
var rarity := Rarity.COMMON
var max_stacks := 1
var exclusivity_group := &""
var is_curse := false
var min_wave := 1
var point_value := 0.0
var magnitude := 1.0
var allowed_profiles: Array[int] = []
var effects: Array[ArtifactEffect] = []

# == Lifecycle ==


func _init(
        init_id: StringName,
        init_display_name: String,
        init_description_template: String,
        init_rarity: Rarity,
        init_max_stacks: int,
        init_exclusivity_group: StringName,
        init_is_curse: bool,
        init_min_wave: int,
        init_point_value: float,
        init_magnitude: float,
        init_allowed_profiles: Array[int],
        init_effects: Array[ArtifactEffect],
) -> void:
    id = init_id
    display_name = init_display_name
    description_template = init_description_template
    rarity = init_rarity
    max_stacks = init_max_stacks
    exclusivity_group = init_exclusivity_group
    is_curse = init_is_curse
    min_wave = init_min_wave
    point_value = init_point_value
    magnitude = init_magnitude
    allowed_profiles = init_allowed_profiles.duplicate()
    effects = init_effects.duplicate()

# == Common API ==


func allows_profile(profile: int) -> bool:
    return profile in allowed_profiles


func create_effect(stacks: int) -> WaveRewardEffect:
    return WaveRewardEffect.new(self, stacks)


## Returns whether this artifact can be offered against the given context's run build: not already
## owned if unique (max_stacks == 1), no exclusivity conflict, and a free legendary slot if this
## artifact is legendary. Caller applies the separate min_wave/profile filters, matching the split
## WaveRewardChoiceGenerator already uses for every candidate.
func is_eligible(context: WaveRewardContext) -> bool:
    if context.run_build == null:
        return false
    if max_stacks <= 1 and context.run_build.has_artifact(id):
        return false
    return context.run_build.can_acquire_artifact(self)


## Applies each effect contribution in turn against the run build.
func apply(context: WaveRewardContext, stacks: int) -> void:
    for effect in effects:
        effect.apply(context.run_build, stacks)
