# enemy_level_progression_profile.gd
# Deterministic level-to-stat projection: reads one enemy's authored EnemyData plus a final level
# and base wave, returning a typed EnemyLevelProjection without mutating authored data or combat
# state. HP and damage apply their curves to Level 1 bases; Defense adds raw curve growth because
# combat already applies nonlinear reduction. Guard derives only from the selected profile and base
# wave, so group level offsets cannot change it. No stat has a hidden maximum level or output cap.
class_name EnemyLevelProgressionProfile
extends Resource

# -- Exports --

@export var hp_curve: EnemyStatGrowthCurve
@export var damage_curve: EnemyStatGrowthCurve
@export var defense_curve: EnemyStatGrowthCurve

# == Common API ==


## Projects enemy_data's authored Level 1 stats to the final level and base wave. Levels and waves
## below 1 report a development error and normalize to 1. Missing EnemyData returns a zeroed result.
func project(enemy_data: EnemyData, level: int, base_wave: int = 1) -> EnemyLevelProjection:
    var normalized_level := _normalize_level(level)
    var normalized_base_wave := _normalize_base_wave(base_wave)
    var result := EnemyLevelProjection.new()
    if enemy_data == null:
        ToastManager.show_dev_error("EnemyLevelProgressionProfile: project() requires non-null EnemyData")
        return result

    result.max_health = enemy_data.max_health * _multiplier(hp_curve, normalized_level)
    result.damage_multiplier = _multiplier(damage_curve, normalized_level)
    result.max_guard = enemy_data.guard_profile.max_guard_for_base_wave(normalized_base_wave) if enemy_data.guard_profile != null else 0
    result.defense = enemy_data.defense + _growth(defense_curve, normalized_level)
    return result


## Reports malformed authored profile data (missing or invalid curves) and returns whether the
## profile is safe to use.
func validate() -> bool:
    var valid := true
    valid = _validate_curve(hp_curve, "EnemyLevelProgressionProfile.hp_curve") and valid
    valid = _validate_curve(damage_curve, "EnemyLevelProgressionProfile.damage_curve") and valid
    valid = _validate_curve(defense_curve, "EnemyLevelProgressionProfile.defense_curve") and valid
    return valid

# == Projection helpers ==


func _normalize_level(level: int) -> int:
    if level < 1:
        ToastManager.show_dev_error("EnemyLevelProgressionProfile: level %d is below 1; normalizing to Level 1" % level)
        return 1
    return level


func _normalize_base_wave(base_wave: int) -> int:
    if base_wave < 1:
        ToastManager.show_dev_error("EnemyLevelProgressionProfile: base_wave %d is below 1; normalizing to Wave 1" % base_wave)
        return 1
    return base_wave


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
