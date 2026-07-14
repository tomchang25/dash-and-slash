# wave_catalog.gd
# Root authored catalog for wave progression: the ten explicit demo waves, one reusable endless
# template, and the one enemy-level progression profile shared by every spawned enemy. The wave
# controller does not consume this catalog yet; this slice only establishes and validates its shape.
class_name WaveCatalog
extends Resource

const DEMO_WAVE_COUNT := 10

# -- Exports --

@export var demo_waves: Array[WaveDefinition] = []
@export var endless_template: WaveDefinition
@export var progression_profile: EnemyLevelProgressionProfile

# == Common API ==


## Reports malformed authored catalog data and returns whether the catalog is safe to use.
func validate() -> bool:
    var valid := true
    if demo_waves.size() != DEMO_WAVE_COUNT:
        ToastManager.show_dev_error("WaveCatalog: expected %d demo waves, got %d" % [DEMO_WAVE_COUNT, demo_waves.size()])
        valid = false
    else:
        for i in demo_waves.size():
            var wave := demo_waves[i]
            if wave == null:
                ToastManager.show_dev_error("WaveCatalog: demo wave %d is null" % i)
                valid = false
                continue
            valid = wave.validate("WaveCatalog demo wave %d" % i) and valid

    if endless_template == null:
        ToastManager.show_dev_error("WaveCatalog: endless_template is missing")
        valid = false
    else:
        valid = endless_template.validate("WaveCatalog endless_template") and valid

    if progression_profile == null:
        ToastManager.show_dev_error("WaveCatalog: progression_profile is missing")
        valid = false
    else:
        valid = progression_profile.validate() and valid

    return valid
