# wave_reward_effect_definition.gd
# Runtime definition for one reward effect candidate used by wave reward rolling.
class_name WaveRewardEffectDefinition
extends RefCounted

enum Kind {
    MOVE_RANDOM_SAFE_LAND,
    REMOVE_RANDOM_SAFE_LAND,
    ADD_FUTURE_ENEMY,
    ADD_PLAYER_NORMAL_ATTACK_DAMAGE,
    REDUCE_PLAYER_NORMAL_ATTACK_COOLDOWN,
    ADD_PLAYER_DASH_ATTACK_DAMAGE,
    REDUCE_PLAYER_DASH_COOLDOWN,
    ADD_PLAYER_MAX_HEALTH,
    MAJOR_PLACEHOLDER,
}

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
var kind := Kind.MOVE_RANDOM_SAFE_LAND
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
        init_kind: int,
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
    kind = init_kind as Kind
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
