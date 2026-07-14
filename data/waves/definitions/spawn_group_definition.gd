# spawn_group_definition.gd
# One reusable authored encounter group: its enemy composition and one placement strategy. Fixed
# composition assigns explicit per-entry counts for staged encounters (elites, bosses); weighted
# composition assigns a total count and per-entry selection weights for mixed support groups.
# Groups are referenced by external WaveGroupSlot resources across any number of waves; this
# resource owns no occurrence-specific scheduling, warning, level, or boss data.
class_name SpawnGroupDefinition
extends Resource

enum CompositionMode {
    FIXED,
    WEIGHTED,
}

enum PlacementStrategy {
    PLAYER_RING,
    ANCHOR_CLUSTER,
    SCATTER,
}

# -- Exports --

@export var placement_strategy: PlacementStrategy = PlacementStrategy.SCATTER
@export var composition_mode: CompositionMode = CompositionMode.FIXED
## Total enemies drawn by weight; positive and required only in weighted mode.
@export var weighted_total_count := 0
@export var entries: Array[WaveCompositionEntry] = []

# == Common API ==


## Reports malformed authored group data and returns whether the group is safe to use.
func validate(group_label: String) -> bool:
    var valid := true
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


## Returns the largest possible member count this group can expand to: the summed fixed counts, or
## the weighted draw total. WaveDefinition uses this to reject a group whose remaining membership
## could never fit a referencing wave's population cap, without simulating a weighted draw.
func max_member_count() -> int:
    match composition_mode:
        CompositionMode.FIXED:
            var total := 0
            for entry in entries:
                if entry != null:
                    total += entry.count
            return total
        CompositionMode.WEIGHTED:
            return weighted_total_count
        _:
            return 0

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
