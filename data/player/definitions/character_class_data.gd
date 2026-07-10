# character_class_data.gd
# Authored baseline identity for one tick-arena character class.
class_name CharacterClassData
extends Resource

# -- Constants --

const MOBILITY_DASH := &"dash"
const MOBILITY_SMASH := &"smash"

# -- Exports --

@export var id := &""
@export var display_name := ""
@export var base_speed_fill := 1
@export var mobility_id := MOBILITY_DASH
@export var body_texture: Texture2D
@export var weapon_texture: Texture2D

# == Common API ==


## Reports malformed authored class data and returns whether the resource is safe to use.
func validate() -> bool:
    var valid := true
    if id == &"":
        ToastManager.show_dev_error("CharacterClassData: class id is empty")
        valid = false
    if display_name.is_empty():
        ToastManager.show_dev_error("CharacterClassData: display name is empty for '%s'" % id)
        valid = false
    if base_speed_fill <= 0:
        ToastManager.show_dev_error("CharacterClassData: base Speed fill must be positive for '%s'" % id)
        valid = false
    if not is_supported_mobility(mobility_id):
        ToastManager.show_dev_error("CharacterClassData: unsupported Mobility '%s' for '%s'" % [mobility_id, id])
        valid = false
    if body_texture == null:
        ToastManager.show_dev_error("CharacterClassData: body texture is missing for '%s'" % id)
        valid = false
    if weapon_texture == null:
        ToastManager.show_dev_error("CharacterClassData: weapon texture is missing for '%s'" % id)
        valid = false
    return valid


## Returns the player-facing label for this class's fixed Mobility.
func mobility_display_name() -> String:
    match mobility_id:
        MOBILITY_DASH:
            return "Dash"
        MOBILITY_SMASH:
            return "Smash"
        _:
            ToastManager.show_dev_error("CharacterClassData: unsupported Mobility '%s'" % mobility_id)
            return "Unknown"


## Returns whether an id is one of the fixed Mobility verbs supported by the first class slice.
static func is_supported_mobility(candidate: StringName) -> bool:
    return candidate == MOBILITY_DASH or candidate == MOBILITY_SMASH
