# wave_group_definition.gd
# One authored encounter group within a wave: its enemy composition, level offset, warning timing,
# and start condition relative to the immediately preceding group. Fixed composition assigns explicit
# per-entry counts for staged encounters (elites, bosses); weighted composition assigns a total count
# and per-entry selection weights for mixed support groups. The first group in a wave is always
# start-eligible by position, regardless of its authored start_condition; runtime scheduling of that
# eligibility is out of scope for this schema.
class_name WaveGroupDefinition
extends Resource

enum CompositionMode {
    FIXED,
    WEIGHTED,
}

enum StartCondition {
    PREVIOUS_GROUP_CLEARED,
    PREVIOUS_GROUP_SURVIVORS_AT_MOST,
    IMMEDIATE_OVERLAP,
}

# -- Exports --

@export var start_condition: StartCondition = StartCondition.PREVIOUS_GROUP_CLEARED
## Survivor threshold for PREVIOUS_GROUP_SURVIVORS_AT_MOST; unused by the other conditions.
@export var survivor_threshold := 0
## Player actions the spawn warning telegraphs before this group's members enter.
@export var warning_ticks := 0
## Non-negative enemy-level bonus applied to every member of this group.
@export var level_offset := 0
@export var composition_mode: CompositionMode = CompositionMode.FIXED
## Total enemies drawn by weight; positive and required only in weighted mode.
@export var weighted_total_count := 0
@export var entries: Array[WaveCompositionEntry] = []

# == Common API ==


## Reports malformed authored group data and returns whether the group is safe to use.
func validate(group_label: String) -> bool:
    var valid := true
    if warning_ticks < 0:
        ToastManager.show_dev_error("%s: warning_ticks must be non-negative, got %d" % [group_label, warning_ticks])
        valid = false
    if level_offset < 0:
        ToastManager.show_dev_error("%s: level_offset must be non-negative, got %d" % [group_label, level_offset])
        valid = false
    if start_condition == StartCondition.PREVIOUS_GROUP_SURVIVORS_AT_MOST and survivor_threshold < 0:
        ToastManager.show_dev_error("%s: survivor_threshold must be non-negative, got %d" % [group_label, survivor_threshold])
        valid = false
    if entries.is_empty():
        ToastManager.show_dev_error("%s: must have at least one composition entry" % group_label)
        return false

    match composition_mode:
        CompositionMode.FIXED:
            valid = _validate_fixed_entries(group_label) and valid
        CompositionMode.WEIGHTED:
            valid = _validate_weighted_entries(group_label) and valid
        _:
            ToastManager.show_dev_error("%s: unknown composition_mode %s" % [group_label, composition_mode])
            valid = false
    return valid

# == Validation helpers ==


func _validate_fixed_entries(group_label: String) -> bool:
    var valid := true
    for i in entries.size():
        var entry := entries[i]
        if entry == null:
            ToastManager.show_dev_error("%s: fixed entry %d is null" % [group_label, i])
            valid = false
            continue
        if entry.enemy_scene == null:
            ToastManager.show_dev_error("%s: fixed entry %d is missing enemy_scene" % [group_label, i])
            valid = false
        if entry.count <= 0:
            ToastManager.show_dev_error("%s: fixed entry %d count must be positive, got %d" % [group_label, i, entry.count])
            valid = false
    return valid


func _validate_weighted_entries(group_label: String) -> bool:
    var valid := true
    if weighted_total_count <= 0:
        ToastManager.show_dev_error("%s: weighted_total_count must be positive, got %d" % [group_label, weighted_total_count])
        valid = false
    for i in entries.size():
        var entry := entries[i]
        if entry == null:
            ToastManager.show_dev_error("%s: weighted entry %d is null" % [group_label, i])
            valid = false
            continue
        if entry.enemy_scene == null:
            ToastManager.show_dev_error("%s: weighted entry %d is missing enemy_scene" % [group_label, i])
            valid = false
        if entry.weight <= 0.0:
            ToastManager.show_dev_error("%s: weighted entry %d weight must be positive, got %s" % [group_label, i, entry.weight])
            valid = false
    return valid
