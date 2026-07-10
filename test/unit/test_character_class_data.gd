# test_character_class_data.gd
# Tests authored Ninja/Viking class identity, fixed Mobility, Speed fill, and presentation assets.
extends GutTest

const NINJA_PATH := "res://game/tick_arena/player/data/ninja.tres"
const VIKING_PATH := "res://game/tick_arena/player/data/viking.tres"


func test_ninja_authors_dash_identity() -> void:
    var ninja := load(NINJA_PATH) as CharacterClassData

    assert_not_null(ninja)
    assert_true(ninja.validate())
    assert_eq(ninja.id, &"ninja")
    assert_eq(ninja.display_name, "Ninja")
    assert_eq(ninja.base_speed_fill, 20)
    assert_eq(ninja.mobility_id, CharacterClassData.MOBILITY_DASH)
    assert_not_null(ninja.body_texture)
    assert_not_null(ninja.weapon_texture)


func test_viking_authors_smash_identity() -> void:
    var viking := load(VIKING_PATH) as CharacterClassData

    assert_not_null(viking)
    assert_true(viking.validate())
    assert_eq(viking.id, &"viking")
    assert_eq(viking.display_name, "Viking")
    assert_eq(viking.base_speed_fill, 10)
    assert_eq(viking.mobility_id, CharacterClassData.MOBILITY_SMASH)
    assert_not_null(viking.body_texture)
    assert_not_null(viking.weapon_texture)


func test_supported_mobility_ids_are_explicit() -> void:
    assert_true(CharacterClassData.is_supported_mobility(CharacterClassData.MOBILITY_DASH))
    assert_true(CharacterClassData.is_supported_mobility(CharacterClassData.MOBILITY_SMASH))
    assert_false(CharacterClassData.is_supported_mobility(&"teleport"))
