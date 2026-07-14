# enemy_stat_growth_curve.gd
# Authored per-stat growth curve: a standard segment from Level 1 and a stronger lethal segment
# beginning at Level 10, combined as growth(level) = standard + lethal. EnemyLevelProgressionProfile
# turns this raw growth into a multiplier (HP, damage, Guard) or a flat addition (Defense).
class_name EnemyStatGrowthCurve
extends Resource

# -- Exports --

@export var standard_coefficient := 0.0
@export var standard_exponent := 1.0
@export var lethal_coefficient := 0.0
@export var lethal_exponent := 1.0

# == Common API ==


## Returns this curve's raw growth at the given level: 0 at Level 1, uncapped and finite at any
## higher level. The lethal term only contributes once level exceeds 9.
func growth(level: int) -> float:
    var standard_term := standard_coefficient * pow(max(level - 1, 0), standard_exponent)
    var lethal_term := lethal_coefficient * pow(max(level - 9, 0), lethal_exponent)
    return standard_term + lethal_term


## Reports malformed authored curve data and returns whether the curve is safe to use.
func validate(curve_label: String) -> bool:
    var valid := true
    if standard_coefficient < 0.0:
        ToastManager.show_dev_error("%s: standard_coefficient must be non-negative, got %s" % [curve_label, standard_coefficient])
        valid = false
    if standard_exponent <= 0.0:
        ToastManager.show_dev_error("%s: standard_exponent must be positive, got %s" % [curve_label, standard_exponent])
        valid = false
    if lethal_coefficient < 0.0:
        ToastManager.show_dev_error("%s: lethal_coefficient must be non-negative, got %s" % [curve_label, lethal_coefficient])
        valid = false
    if lethal_exponent <= 0.0:
        ToastManager.show_dev_error("%s: lethal_exponent must be positive, got %s" % [curve_label, lethal_exponent])
        valid = false
    return valid
