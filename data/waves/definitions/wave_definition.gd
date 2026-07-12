# wave_definition.gd
# One authored wave: its concurrent-population safety cap and its ordered list of encounter groups.
# The cap protects board readability; it does not define encounter order, which groups establish
# themselves through their own start_condition. Used for both the ten explicit demo waves and the
# one reusable endless template.
class_name WaveDefinition
extends Resource

# -- Exports --

@export var population_cap := 3
@export var groups: Array[WaveGroupDefinition] = []

# == Common API ==


## Reports malformed authored wave data and returns whether the wave is safe to use.
func validate(wave_label: String) -> bool:
    var valid := true
    if population_cap <= 0:
        ToastManager.show_dev_error("%s: population_cap must be positive, got %d" % [wave_label, population_cap])
        valid = false
    if groups.is_empty():
        ToastManager.show_dev_error("%s: must have at least one group" % wave_label)
        return false

    for i in groups.size():
        var group := groups[i]
        if group == null:
            ToastManager.show_dev_error("%s: group %d is null" % [wave_label, i])
            valid = false
            continue
        valid = group.validate("%s group %d" % [wave_label, i]) and valid
    return valid
