# wave_group_slot.gd
# One occurrence of a reusable SpawnGroupDefinition within a wave's ordered schedule: when it may
# begin relative to the preceding slot, its warning timing, its enemy-level offset, and its boss
# role. Composition and placement strategy live on the referenced group so authors can reuse one
# group across many wave slots without duplicating enemy data. The first slot in a wave is always
# start-eligible by position, regardless of its authored start_condition; runtime scheduling of that
# eligibility is out of scope for this schema.
class_name WaveGroupSlot
extends Resource

enum StartCondition {
    PREVIOUS_GROUP_CLEARED,
    PREVIOUS_GROUP_SURVIVORS_AT_MOST,
    IMMEDIATE_OVERLAP,
}

# -- Exports --

@export var spawn_group: SpawnGroupDefinition
@export var start_condition: StartCondition = StartCondition.PREVIOUS_GROUP_CLEARED
## Survivor threshold for PREVIOUS_GROUP_SURVIVORS_AT_MOST; unused by the other conditions.
@export var survivor_threshold := 0
## Player actions the spawn warning telegraphs before this slot's members enter.
@export var warning_ticks := 0
## Non-negative enemy-level bonus applied to every member spawned from this slot.
@export var level_offset := 0
## Authored boss role, read by wave display and boss treatment. Runtime code must never compare a
## scene against a boss scene reference to detect boss behavior or demo completion.
@export var is_boss := false

# == Common API ==


## Reports malformed authored slot data and returns whether the slot is safe to use.
func validate(slot_label: String) -> bool:
    var valid := true
    if warning_ticks < 0:
        ToastManager.show_dev_error("%s: warning_ticks must be non-negative, got %d" % [slot_label, warning_ticks])
        valid = false
    if level_offset < 0:
        ToastManager.show_dev_error("%s: level_offset must be non-negative, got %d" % [slot_label, level_offset])
        valid = false
    if start_condition == StartCondition.PREVIOUS_GROUP_SURVIVORS_AT_MOST and survivor_threshold < 0:
        ToastManager.show_dev_error("%s: survivor_threshold must be non-negative, got %d" % [slot_label, survivor_threshold])
        valid = false
    if spawn_group == null:
        ToastManager.show_dev_error("%s: missing spawn_group" % slot_label)
        return false
    return spawn_group.validate("%s spawn_group" % slot_label) and valid
