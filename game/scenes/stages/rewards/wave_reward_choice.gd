# wave_reward_choice.gd
# Runtime value object representing one generated reward choice.
class_name WaveRewardChoice
extends RefCounted

var profile := WaveRewardEffectDefinition.Profile.CONSERVATIVE
var target_points := 0.0
var effects: Array[WaveRewardEffect] = []
var display_name := ""

# == Lifecycle ==


func _init(
        init_profile: int,
        init_target_points: float,
        init_effects: Array[WaveRewardEffect],
) -> void:
    profile = init_profile as WaveRewardEffectDefinition.Profile
    target_points = init_target_points
    effects = init_effects.duplicate()
    display_name = _make_display_name()

# == Common API ==


func total_points() -> float:
    var total := 0.0
    for effect in effects:
        total += effect.total_points()
    return total


func description_lines() -> Array[String]:
    var lines: Array[String] = []
    for effect in effects:
        lines.append(effect.description())
    return lines


func effect_count() -> int:
    return effects.size()

# == Display ==


func _make_display_name() -> String:
    match profile:
        WaveRewardEffectDefinition.Profile.CONSERVATIVE:
            return "Steady Offer"
        WaveRewardEffectDefinition.Profile.BALANCED:
            return "Balanced Offer"
        WaveRewardEffectDefinition.Profile.AGGRESSIVE:
            return "Bold Offer"
    push_warning("Unknown reward profile: %s" % profile)
    return "Reward Offer"
