# guard_profile.gd
# Reusable enemy Guard role data, including base-wave lethal scaling and post-Stagger protection.
class_name GuardProfile
extends Resource

const STANDARD_WAVE_LIMIT := 20
const LETHAL_TIER_WAVE_COUNT := 5

# -- Exports --

@export var base_guard := 32
@export var guard_per_lethal_tier := 8
@export var stagger_ticks := 3
@export var protection_ticks := 5
@export var protection_multiplier := 0.5

# == Common API ==


## Returns this profile's Guard maximum for a base wave; group level offsets never enter this calculation.
func max_guard_for_base_wave(base_wave: int) -> int:
    var normalized_wave := maxi(base_wave, 1)
    var lethal_tier := 0
    if normalized_wave > STANDARD_WAVE_LIMIT:
        lethal_tier = int((normalized_wave - STANDARD_WAVE_LIMIT - 1) / LETHAL_TIER_WAVE_COUNT) + 1
    return base_guard + guard_per_lethal_tier * lethal_tier


## Reports malformed authored Guard role data and returns whether the resource is safe to use.
func validate() -> bool:
    var valid := true
    if base_guard <= 0:
        ToastManager.show_dev_error("GuardProfile: base_guard must be positive, got %d" % base_guard)
        valid = false
    if guard_per_lethal_tier < 0:
        ToastManager.show_dev_error("GuardProfile: guard_per_lethal_tier must be non-negative, got %d" % guard_per_lethal_tier)
        valid = false
    if stagger_ticks <= 0:
        ToastManager.show_dev_error("GuardProfile: stagger_ticks must be positive, got %d" % stagger_ticks)
        valid = false
    if protection_ticks < 0:
        ToastManager.show_dev_error("GuardProfile: protection_ticks must be non-negative, got %d" % protection_ticks)
        valid = false
    if protection_multiplier < 0.0 or protection_multiplier > 1.0:
        ToastManager.show_dev_error("GuardProfile: protection_multiplier must be between 0 and 1, got %s" % protection_multiplier)
        valid = false
    return valid
