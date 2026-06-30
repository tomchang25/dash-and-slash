# wave_reward_effect.gd
# Runtime reward effect value rolled into one wave reward choice.
class_name WaveRewardEffect
extends RefCounted

var definition: WaveRewardEffectDefinition
var stacks := 1

# == Lifecycle ==


func _init(init_definition: WaveRewardEffectDefinition, init_stacks: int = 1) -> void:
    definition = init_definition
    stacks = max(init_stacks, 1)

# == Common API ==


func total_points() -> float:
    return definition.point_value * stacks


func total_magnitude() -> float:
    return definition.magnitude * float(stacks)


func description() -> String:
    var amount := total_magnitude()
    if is_equal_approx(amount, roundf(amount)):
        return definition.description_template % int(amount)
    return definition.description_template % amount
