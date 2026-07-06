# wave_reward_effect_definition.gd
# Abstract base for one reward effect candidate used by wave reward rolling.
# Carries authored balance metadata; each concrete subclass owns its own
# offer-eligibility and application.
@abstract
class_name WaveRewardEffectDefinition
extends RefCounted

enum Profile {
    CONSERVATIVE,
    BALANCED,
    AGGRESSIVE,
}

enum Tier {
    MINOR,
    MAJOR,
}

var effect_id := ""
var tier := Tier.MINOR
var display_name := ""
var description_template := ""
var point_value := 0.0
var magnitude := 1.0
var max_stacks := 1
var min_wave := 1
var allowed_profiles: Array[int] = []

# == Lifecycle ==


func _init(
        init_effect_id: String,
        init_tier: int,
        init_display_name: String,
        init_description_template: String,
        init_point_value: float,
        init_magnitude: float,
        init_max_stacks: int,
        init_min_wave: int,
        init_allowed_profiles: Array[int],
) -> void:
    effect_id = init_effect_id
    tier = init_tier as Tier
    display_name = init_display_name
    description_template = init_description_template
    point_value = init_point_value
    magnitude = init_magnitude
    max_stacks = init_max_stacks
    min_wave = init_min_wave
    allowed_profiles = init_allowed_profiles.duplicate()

# == Common API ==


func allows_profile(profile: int) -> bool:
    return profile in allowed_profiles


func is_major() -> bool:
    return tier == Tier.MAJOR


func is_minor() -> bool:
    return tier == Tier.MINOR


func create_effect(stacks: int) -> WaveRewardEffect:
    return WaveRewardEffect.new(self, stacks)

# == Effect Contract ==


## Returns whether this effect can be offered given the current run context.
## Defaults to true for effects with no context dependency (e.g. future-enemy
## pressure, the major placeholder); override for effects that require a
## specific owner to be present.
func is_applicable(_context: WaveRewardContext) -> bool:
    return true


## Applies this effect's contribution for the given stack count against the
## owners exposed by context. Every concrete subclass must implement this.
@abstract func apply(context: WaveRewardContext, stacks: int) -> void
