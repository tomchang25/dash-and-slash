# wave_definition.gd
# One authored wave: its concurrent-population safety cap and its ordered list of group slots. The
# cap protects board readability; it does not define encounter order, which slots establish
# themselves through their own start_condition. Used for both the ten explicit demo waves and the
# one reusable endless template.
class_name WaveDefinition
extends Resource

# -- Exports --

@export var population_cap := 3
@export var slots: Array[WaveGroupSlot] = []

# == Common API ==


## Reports malformed authored wave data and returns whether the wave is safe to use.
func validate(wave_label: String) -> bool:
    var valid := true
    if population_cap <= 0:
        ToastManager.show_dev_error("%s: population_cap must be positive, got %d" % [wave_label, population_cap])
        valid = false
    if slots.is_empty():
        ToastManager.show_dev_error("%s: must have at least one slot" % wave_label)
        return false

    for i in slots.size():
        var slot := slots[i]
        if slot == null:
            ToastManager.show_dev_error("%s: slot %d is null" % [wave_label, i])
            valid = false
            continue
        valid = slot.validate("%s slot %d" % [wave_label, i]) and valid
        valid = _validate_atomic_cap_fit(wave_label, i, slot) and valid
    return valid

# == Validation helpers ==


## Rejects a slot whose referenced group could expand past this wave's population cap, since such a
## group could never pass the whole-remaining-group atomic admission check at runtime.
func _validate_atomic_cap_fit(wave_label: String, index: int, slot: WaveGroupSlot) -> bool:
    if slot.spawn_group == null:
        return true
    var max_count := slot.spawn_group.max_member_count()
    if max_count > population_cap:
        ToastManager.show_dev_error(
            "%s: slot %d's group can expand to %d members, exceeding population_cap %d" % [wave_label, index, max_count, population_cap],
        )
        return false
    return true
