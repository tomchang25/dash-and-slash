# enemy_level_progression_profile.gd
# Deterministic level-to-stat projection: reads one enemy's authored EnemyData plus a final level
# and returns a typed EnemyLevelProjection, without mutating the authored data or any combat state.
# HP, damage, and Guard apply their curve as a multiplier over the authored base (1.0 at Level 1,
# identity); Defense adds its curve's raw growth to the authored base Defense, since combat already
# applies Defense through nonlinear damage reduction. Guard rounds to an integer once, after
# projection. No stat has a hidden maximum level or output cap.
class_name EnemyLevelProgressionProfile
extends Resource

# -- Exports --

@export var hp_curve: EnemyStatGrowthCurve
@export var damage_curve: EnemyStatGrowthCurve
@export var guard_curve: EnemyStatGrowthCurve
@export var defense_curve: EnemyStatGrowthCurve

# == Common API ==


## Projects enemy_data's authored Level 1 stats to the given level. Levels below 1 report a
## development error and normalize to Level 1. Missing enemy_data reports a development error and
## returns a zeroed Level 1 identity projection.
func project(enemy_data: EnemyData, level: int) -> EnemyLevelProjection:
    var normalized_level := _normalize_level(level)
    var result := EnemyLevelProjection.new()
    if enemy_data == null:
        ToastManager.show_dev_error("EnemyLevelProgressionProfile: project() requires non-null EnemyData")
        return result

    result.max_health = enemy_data.max_health * _multiplier(hp_curve, normalized_level)
    result.damage_multiplier = _multiplier(damage_curve, normalized_level)
    result.max_guard = roundi(float(enemy_data.max_guard) * _multiplier(guard_curve, normalized_level))
    result.defense = enemy_data.defense + _growth(defense_curve, normalized_level)
    return result


## Reports malformed authored profile data (missing or invalid curves) and returns whether the
## profile is safe to use.
func validate() -> bool:
    var valid := true
    valid = _validate_curve(hp_curve, "EnemyLevelProgressionProfile.hp_curve") and valid
    valid = _validate_curve(damage_curve, "EnemyLevelProgressionProfile.damage_curve") and valid
    valid = _validate_curve(guard_curve, "EnemyLevelProgressionProfile.guard_curve") and valid
    valid = _validate_curve(defense_curve, "EnemyLevelProgressionProfile.defense_curve") and valid
    return valid

# == Projection helpers ==


func _normalize_level(level: int) -> int:
    if level < 1:
        ToastManager.show_dev_error("EnemyLevelProgressionProfile: level %d is below 1; normalizing to Level 1" % level)
        return 1
    return level


func _growth(curve: EnemyStatGrowthCurve, level: int) -> float:
    if curve == null:
        return 0.0
    return curve.growth(level)


func _multiplier(curve: EnemyStatGrowthCurve, level: int) -> float:
    return 1.0 + _growth(curve, level)


func _validate_curve(curve: EnemyStatGrowthCurve, curve_label: String) -> bool:
    if curve == null:
        ToastManager.show_dev_error("%s is missing" % curve_label)
        return false
    return curve.validate(curve_label)
