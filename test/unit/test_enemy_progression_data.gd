# test_enemy_progression_data.gd
# Focused coverage for wave progression plus shared Guard profiles, authored assignments, and
# GridEnemy's EnemyData-driven component initialization and deferred level-projection application.
extends GutTest

const ThrustEnemyScene := preload("res://game/entities/enemies/thrust_enemy.tscn")
const SlashEnemyScene := preload("res://game/entities/enemies/slash_enemy.tscn")
const ChargeEnemyScene := preload("res://game/entities/enemies/charge_enemy.tscn")
const ModeEnemyScene := preload("res://game/entities/enemies/mode_enemy.tscn")
const BombEnemyScene := preload("res://game/entities/enemies/bomb_enemy.tscn")
const RangedEnemyScene := preload("res://game/entities/enemies/ranged_enemy.tscn")

# == EnemyData: Level 1 authority ==


func test_enemy_data_validate_passes_clean_data() -> void:
    var data := _make_enemy_data()
    assert_true(data.validate())


func test_enemy_data_validate_rejects_empty_id() -> void:
    var data := _make_enemy_data()
    data.enemy_id = ""
    assert_false(data.validate())
    assert_push_error("enemy_id is empty")


func test_enemy_data_validate_rejects_non_positive_max_health() -> void:
    var data := _make_enemy_data()
    data.max_health = 0.0
    assert_false(data.validate())
    assert_push_error("max_health must be positive")


func test_enemy_data_validate_rejects_invalid_guard_profile() -> void:
    var data := _make_enemy_data()
    data.guard_profile.base_guard = 0
    assert_false(data.validate())
    assert_push_error("base_guard must be positive")


func test_enemy_data_validate_rejects_negative_defense() -> void:
    var data := _make_enemy_data()
    data.defense = -1.0
    assert_false(data.validate())
    assert_push_error("defense must be non-negative")

# == Production EnemyData: assigned Guard profiles ==


func test_production_enemy_data_uses_role_profiles() -> void:
    var expectations := {
        "res://game/entities/enemies/data/thrust_enemy.tres": [100.0, 32, 0.0],
        "res://game/entities/enemies/data/slash_enemy.tres": [100.0, 32, 0.0],
        "res://game/entities/enemies/data/ranged_enemy.tres": [100.0, 32, 0.0],
        "res://game/entities/enemies/data/charge_enemy.tres": [150.0, 64, 0.0],
        "res://game/entities/enemies/data/mode_enemy.tres": [180.0, 96, 0.0],
        "res://game/entities/enemies/data/mode_boss.tres": [600.0, 128, 5.0],
    }
    for path: String in expectations.keys():
        var data := load(path) as EnemyData
        var expected: Array = expectations[path]
        assert_almost_eq(data.max_health, expected[0], 0.001, "%s max_health" % path)
        assert_not_null(data.guard_profile, "%s guard_profile" % path)
        assert_eq(data.guard_profile.max_guard_for_base_wave(1), expected[1], "%s Wave 1 max Guard" % path)
        assert_almost_eq(data.defense, expected[2], 0.001, "%s defense" % path)
        assert_true(data.validate(), "%s should be valid authored data" % path)


## Bomb is the roster's only guardless role: no authored guard_profile, plus a level-one HP and
## explosion damage that stay authoritative through the shared wave projection.
func test_bomb_enemy_data_is_guardless_level_one() -> void:
    var data := load("res://game/entities/enemies/data/bomb_enemy.tres") as EnemyData
    assert_almost_eq(data.max_health, 50.0, 0.001)
    assert_null(data.guard_profile, "Bomb must not author a Guard profile")
    assert_almost_eq(data.defense, 0.0, 0.001)
    assert_true(data.validate(), "Bomb should be valid authored data despite the missing guard_profile")

    assert_eq(data.attacks.size(), 1, "Bomb should author exactly one attack")
    var attack := data.attacks[0]
    assert_eq(attack.attack_kind, EnemyAttackData.AttackKind.AREA)
    assert_eq(attack.cell_shape, EnemyAttackData.CellShape.MANHATTAN)
    assert_almost_eq(attack.damage, 50.0, 0.001)
    assert_eq(attack.warning_duration, 3)
    assert_eq(attack.radius, 4)


func test_ranged_enemy_data_authors_the_level_one_cross_pressure_values() -> void:
    var data := load("res://game/entities/enemies/data/ranged_enemy.tres") as EnemyData
    assert_almost_eq(data.max_health, 100.0, 0.001)
    assert_almost_eq(data.defense, 0.0, 0.001)
    assert_not_null(data.guard_profile)
    assert_eq(data.guard_profile.max_guard_for_base_wave(1), 32)
    assert_eq(data.attacks.size(), 1)

    var attack: EnemyAttackData = data.attacks[0]
    assert_eq(attack.attack_kind, EnemyAttackData.AttackKind.TILE)
    assert_eq(attack.cell_shape, EnemyAttackData.CellShape.CUSTOM_OFFSETS)
    assert_almost_eq(attack.damage, 10.0, 0.001)
    assert_eq(attack.warning_duration, 2)
    assert_eq(attack.recovery_duration, 1)
    assert_eq(attack.cell_offsets, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)])

# == EnemyStatGrowthCurve ==


func test_curve_growth_is_zero_at_level_one() -> void:
    var curve := _make_curve(0.1, 1.0, 0.5, 1.0)
    assert_eq(curve.growth(1), 0.0)


func test_curve_growth_standard_segment_before_level_ten() -> void:
    var curve := _make_curve(0.1, 1.0, 0.5, 1.0)
    assert_almost_eq(curve.growth(5), 0.4, 0.001)
    assert_almost_eq(curve.growth(9), 0.8, 0.001, "lethal segment has not started yet at level 9")


func test_curve_growth_lethal_segment_begins_at_level_ten() -> void:
    var curve := _make_curve(0.1, 1.0, 0.5, 1.0)
    assert_almost_eq(curve.growth(10), 1.4, 0.001)
    assert_almost_eq(curve.growth(20), 7.4, 0.001)


func test_curve_validate_rejects_negative_coefficients() -> void:
    var curve := _make_curve(-0.1, 1.0, 0.5, 1.0)
    assert_false(curve.validate("TestCurve"))
    assert_push_error("standard_coefficient must be non-negative")


func test_curve_validate_rejects_non_positive_standard_exponent() -> void:
    var curve := _make_curve(0.1, 0.0, 0.5, 1.0)
    assert_false(curve.validate("TestCurve"))
    assert_push_error("standard_exponent must be positive")


func test_curve_validate_rejects_non_positive_lethal_exponent() -> void:
    var curve := _make_curve(0.1, 1.0, 0.5, -1.0)
    assert_false(curve.validate("TestCurve"))
    assert_push_error("lethal_exponent must be positive")

# == GuardProfile ==


func test_guard_profile_keeps_base_guard_through_wave_twenty() -> void:
    var profile := _make_guard_profile()
    assert_eq(profile.max_guard_for_base_wave(1), 32)
    assert_eq(profile.max_guard_for_base_wave(20), 32)


func test_guard_profile_adds_one_step_in_each_later_five_wave_band() -> void:
    var profile := _make_guard_profile()
    assert_eq(profile.max_guard_for_base_wave(21), 40)
    assert_eq(profile.max_guard_for_base_wave(25), 40)
    assert_eq(profile.max_guard_for_base_wave(26), 48)
    assert_eq(profile.max_guard_for_base_wave(100), 160)


func test_role_profiles_match_documented_fixed_angle_break_counts() -> void:
    var expectations := [
        ["small_guard_profile.tres", 1, 2, 8],
        ["heavy_guard_profile.tres", 2, 4, 16],
        ["elite_guard_profile.tres", 3, 6, 24],
        ["boss_guard_profile.tres", 4, 8, 32],
    ]
    for expected: Array in expectations:
        var profile := load("res://data/enemies/guard_profiles/%s" % expected[0]) as GuardProfile
        var guard := profile.max_guard_for_base_wave(1)
        assert_eq(int(guard / TickCombatRules.BACK_GUARD_DAMAGE), expected[1], "%s Back hits" % expected[0])
        assert_eq(int(guard / TickCombatRules.SIDE_GUARD_DAMAGE), expected[2], "%s Side hits" % expected[0])
        assert_eq(int(guard / TickCombatRules.FRONT_GUARD_DAMAGE), expected[3], "%s Front hits" % expected[0])


func test_guard_profile_validate_rejects_invalid_protection_multiplier() -> void:
    var profile := _make_guard_profile()
    profile.protection_multiplier = 1.1
    assert_false(profile.validate())
    assert_push_error("protection_multiplier must be between 0 and 1")

# == EnemyLevelProgressionProfile ==


func test_profile_project_level_one_is_identity() -> void:
    var profile := _make_profile()
    var data := _make_enemy_data()
    var projection := profile.project(data, 1, 1)

    assert_almost_eq(projection.max_health, data.max_health, 0.001)
    assert_almost_eq(projection.damage_multiplier, 1.0, 0.001)
    assert_eq(projection.max_guard, 32)
    assert_almost_eq(projection.defense, data.defense, 0.001)


func test_profile_project_keeps_guard_independent_of_final_level() -> void:
    var profile := _make_profile()
    var data := _make_enemy_data()
    var projection := profile.project(data, 10, 20)

    assert_almost_eq(projection.max_health, 240.0, 0.001, "100 base * (1 + 1.4) hp multiplier")
    assert_almost_eq(projection.damage_multiplier, 2.4, 0.001)
    assert_eq(projection.max_guard, 32, "final level must not affect Guard")
    assert_almost_eq(projection.defense, 16.0, 0.001, "5 base defense + 11 defense growth")


func test_profile_project_uses_base_wave_not_group_offset_level_for_guard() -> void:
    var profile := _make_profile()
    var data := _make_enemy_data()
    var projection := profile.project(data, 50, 20)

    assert_eq(projection.max_guard, 32, "a high final level in Wave 20 keeps base Guard")


func test_profile_project_normalizes_level_below_one() -> void:
    var profile := _make_profile()
    var data := _make_enemy_data()

    var projection := profile.project(data, 0, 0)

    assert_almost_eq(projection.max_health, data.max_health, 0.001, "level 0 should normalize to level 1 identity")
    assert_push_error("is below 1")
    assert_push_error("base_wave 0 is below 1")


func test_profile_project_missing_enemy_data_reports_error_and_returns_default_projection() -> void:
    var profile := _make_profile()

    var projection := profile.project(null, 5)

    assert_almost_eq(projection.max_health, 0.0, 0.001)
    assert_eq(projection.max_guard, 0)
    assert_push_error("requires non-null EnemyData")


func test_profile_project_high_level_is_finite_and_uncapped() -> void:
    var profile := _make_profile()
    var data := _make_enemy_data()

    var projection := profile.project(data, 1000, 1000)

    assert_true(is_finite(projection.max_health))
    assert_true(is_finite(projection.damage_multiplier))
    assert_true(is_finite(projection.defense))
    assert_true(projection.max_health > data.max_health * 100.0, "growth should stay uncapped at very high levels")
    assert_eq(projection.max_guard, 1600, "Guard tier growth should stay uncapped at high base waves")


func test_profile_validate_reports_missing_curve() -> void:
    var profile := _make_profile()
    profile.hp_curve = null

    assert_false(profile.validate())
    assert_push_error("hp_curve is missing")


func test_profile_validate_passes_a_fully_authored_profile() -> void:
    assert_true(_make_profile().validate())

# == WaveCompositionEntry / WaveGroupDefinition ==


func test_group_validate_fixed_mode_passes_positive_counts() -> void:
    var group := _make_fixed_group()
    assert_true(group.validate("TestGroup"))


func test_group_validate_fixed_mode_rejects_non_positive_count() -> void:
    var group := _make_fixed_group()
    group.entries[0].count = 0
    assert_false(group.validate("TestGroup"))
    assert_push_error("count must be positive")


func test_group_validate_fixed_mode_rejects_missing_enemy_scene() -> void:
    var group := _make_fixed_group()
    group.entries[0].enemy_scene = null
    assert_false(group.validate("TestGroup"))
    assert_push_error("missing enemy_scene")


func test_group_validate_weighted_mode_requires_positive_total_and_weights() -> void:
    var group := _make_weighted_group()
    assert_true(group.validate("TestGroup"))

    group.weighted_total_count = 0
    assert_false(group.validate("TestGroup"))
    assert_push_error("weighted_total_count must be positive")


func test_group_validate_weighted_mode_rejects_non_positive_weight() -> void:
    var group := _make_weighted_group()
    group.entries[0].weight = 0.0
    assert_false(group.validate("TestGroup"))
    assert_push_error("weight must be positive")


func test_group_validate_rejects_negative_warning_ticks() -> void:
    var group := _make_fixed_group()
    group.warning_ticks = -1
    assert_false(group.validate("TestGroup"))
    assert_push_error("warning_ticks must be non-negative")


func test_group_validate_rejects_negative_level_offset() -> void:
    var group := _make_fixed_group()
    group.level_offset = -1
    assert_false(group.validate("TestGroup"))
    assert_push_error("level_offset must be non-negative")


func test_group_validate_survivors_condition_requires_non_negative_threshold() -> void:
    var group := _make_fixed_group()
    group.start_condition = WaveGroupDefinition.StartCondition.PREVIOUS_GROUP_SURVIVORS_AT_MOST
    group.survivor_threshold = -1
    assert_false(group.validate("TestGroup"))
    assert_push_error("survivor_threshold must be non-negative")


func test_group_validate_rejects_empty_entries() -> void:
    var group := _make_fixed_group()
    group.entries = []
    assert_false(group.validate("TestGroup"))
    assert_push_error("must have at least one composition entry")


## Edge case: a first group authored with a predecessor-relative condition still validates cleanly
## position (not the condition value) is what makes a first group start-eligible at runtime.
func test_group_with_predecessor_condition_still_validates_regardless_of_position() -> void:
    var group := _make_fixed_group()
    group.start_condition = WaveGroupDefinition.StartCondition.PREVIOUS_GROUP_CLEARED
    assert_true(group.validate("TestGroup"), "a predecessor condition on what would be the first group must not fail validation")


func test_group_is_boss_defaults_false() -> void:
    var group := _make_fixed_group()
    assert_false(group.is_boss)


func test_group_is_boss_can_be_authored_true_and_still_validates() -> void:
    var group := _make_fixed_group()
    group.is_boss = true
    assert_true(group.validate("TestGroup"), "the authored boss role must not affect validation")

# == WaveDefinition ==


func test_wave_validate_requires_positive_population_cap() -> void:
    var wave := _make_wave()
    wave.population_cap = 0
    assert_false(wave.validate("TestWave"))
    assert_push_error("population_cap must be positive")


func test_wave_validate_requires_at_least_one_group() -> void:
    var wave := _make_wave()
    wave.groups = []
    assert_false(wave.validate("TestWave"))
    assert_push_error("must have at least one group")


func test_wave_validate_passes_a_clean_wave() -> void:
    assert_true(_make_wave().validate("TestWave"))

# == WaveCatalog ==


func test_catalog_validate_requires_ten_demo_waves() -> void:
    var catalog := _make_catalog()
    catalog.demo_waves.resize(9)
    assert_false(catalog.validate())
    assert_push_error("expected 10 demo waves")


func test_catalog_validate_requires_endless_template() -> void:
    var catalog := _make_catalog()
    catalog.endless_template = null
    assert_false(catalog.validate())
    assert_push_error("endless_template is missing")


func test_catalog_validate_requires_progression_profile() -> void:
    var catalog := _make_catalog()
    catalog.progression_profile = null
    assert_false(catalog.validate())
    assert_push_error("progression_profile is missing")


func test_catalog_validate_passes_a_fully_authored_catalog() -> void:
    assert_true(_make_catalog().validate())


func test_catalog_validate_supports_fixed_and_weighted_groups_and_all_conditions() -> void:
    var catalog := _make_catalog()
    var wave := catalog.demo_waves[0]
    var overlap_group := _make_fixed_group()
    overlap_group.start_condition = WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP
    var survivors_group := _make_fixed_group()
    survivors_group.start_condition = WaveGroupDefinition.StartCondition.PREVIOUS_GROUP_SURVIVORS_AT_MOST
    survivors_group.survivor_threshold = 2
    var weighted_group := _make_weighted_group()
    wave.groups = [overlap_group, survivors_group, weighted_group]

    assert_true(catalog.validate(), "a catalog mixing fixed/weighted groups and all three conditions must validate")

# == GridEnemy: EnemyData-driven component initialization ==


func test_thrust_slash_and_ranged_scenes_initialize_shared_small_health_and_guard() -> void:
    for enemy_scene: PackedScene in [ThrustEnemyScene, SlashEnemyScene, RangedEnemyScene]:
        var enemy := add_child_autofree(enemy_scene.instantiate()) as GridEnemy
        assert_almost_eq(enemy.health.max_health, 100.0, 0.001)
        assert_almost_eq(enemy.health.current(), 100.0, 0.001)
        assert_eq(enemy.get_guard().max_guard, 32)
        assert_eq(enemy.get_guard().current(), 32)


func test_charge_enemy_scene_initializes_health_and_guard_from_enemy_data() -> void:
    var enemy := add_child_autofree(ChargeEnemyScene.instantiate()) as GridEnemy
    assert_almost_eq(enemy.health.max_health, 150.0, 0.001)
    assert_eq(enemy.get_guard().max_guard, 64)


func test_mode_enemy_scene_initializes_health_and_guard_from_enemy_data() -> void:
    var enemy := add_child_autofree(ModeEnemyScene.instantiate()) as GridEnemy
    assert_almost_eq(enemy.health.max_health, 180.0, 0.001)
    assert_eq(enemy.get_guard().max_guard, 96)


## Bomb's scene omits the Guard node entirely rather than carrying a disabled component.
func test_bomb_enemy_scene_initializes_health_with_no_guard_component() -> void:
    var enemy := add_child_autofree(BombEnemyScene.instantiate()) as GridEnemy
    assert_almost_eq(enemy.health.max_health, 50.0, 0.001)
    assert_null(enemy.get_guard(), "Bomb's scene must not wire a Guard node")


func test_missing_guard_profile_disables_the_scene_guard_component() -> void:
    var enemy := ThrustEnemyScene.instantiate() as GridEnemy
    enemy.enemy_data = enemy.enemy_data.duplicate()
    enemy.enemy_data.guard_profile = null
    add_child_autofree(enemy)

    assert_false(enemy.get_guard().is_enabled())
    assert_eq(enemy.get_guard().current(), 0)

# == GridEnemy: deferred level projection ==


func test_apply_level_projection_called_pre_ready_applies_after_enemy_data_initializes() -> void:
    var enemy := ThrustEnemyScene.instantiate() as GridEnemy
    var projection := EnemyLevelProjection.new()
    projection.max_health = 150.0
    projection.max_guard = 20
    projection.defense = 3.0
    projection.damage_multiplier = 1.2
    enemy.apply_level_projection(5, projection)
    add_child_autofree(enemy)

    assert_almost_eq(enemy.health.max_health, 150.0, 0.001, "the projected max health replaces the authored base of 100")
    assert_almost_eq(enemy.health.current(), 150.0, 0.001, "current health starts full at the projected max")
    assert_eq(enemy.get_guard().max_guard, 20, "the projected max guard replaces the authored base of 16")
    assert_almost_eq(enemy.get_damage_multiplier(), 1.2, 0.001)
    assert_almost_eq(enemy.get_defense(), 3.0, 0.001)
    assert_eq(enemy.get_level(), 5)


func test_apply_level_projection_never_called_leaves_level_one_identity() -> void:
    var enemy := add_child_autofree(ThrustEnemyScene.instantiate()) as GridEnemy

    assert_almost_eq(enemy.get_damage_multiplier(), 1.0, 0.001)
    assert_almost_eq(enemy.get_defense(), 0.0, 0.001)
    assert_almost_eq(enemy.health.max_health, 100.0, 0.001, "no projection means the authored base is untouched")
    assert_eq(enemy.get_level(), 1, "an enemy that never receives a projection reports Level 1")


func test_apply_level_projection_via_progression_profile_matches_projected_stats() -> void:
    var profile := _make_profile()
    var enemy := ThrustEnemyScene.instantiate() as GridEnemy
    var projection := profile.project(enemy.enemy_data, 10, 21)
    enemy.apply_level_projection(10, projection)
    add_child_autofree(enemy)

    assert_almost_eq(enemy.health.max_health, projection.max_health, 0.001)
    assert_eq(enemy.get_guard().max_guard, projection.max_guard)
    assert_almost_eq(enemy.get_defense(), projection.defense, 0.001)
    assert_almost_eq(enemy.get_damage_multiplier(), projection.damage_multiplier, 0.001)

# == Test helpers ==


func _make_enemy_data() -> EnemyData:
    var data := EnemyData.new()
    data.enemy_id = "test_enemy"
    data.display_name = "Test Enemy"
    data.max_health = 100.0
    data.guard_profile = _make_guard_profile()
    data.defense = 5.0
    return data


func _make_curve(standard_coefficient: float, standard_exponent: float, lethal_coefficient: float, lethal_exponent: float) -> EnemyStatGrowthCurve:
    var curve := EnemyStatGrowthCurve.new()
    curve.standard_coefficient = standard_coefficient
    curve.standard_exponent = standard_exponent
    curve.lethal_coefficient = lethal_coefficient
    curve.lethal_exponent = lethal_exponent
    return curve


## HP and damage share one curve (0 at level 1, 1.4 growth by level 10); defense uses a distinct
## curve (0 at level 1, 11.0 growth by level 10) so additive vs multiplicative behavior stays clear.
func _make_profile() -> EnemyLevelProgressionProfile:
    var profile := EnemyLevelProgressionProfile.new()
    var shared_curve := _make_curve(0.1, 1.0, 0.5, 1.0)
    profile.hp_curve = shared_curve
    profile.damage_curve = shared_curve
    profile.defense_curve = _make_curve(1.0, 1.0, 2.0, 1.0)
    return profile


func _make_guard_profile() -> GuardProfile:
    var profile := GuardProfile.new()
    profile.base_guard = 32
    profile.guard_per_lethal_tier = 8
    profile.stagger_ticks = 3
    profile.protection_ticks = 5
    profile.protection_multiplier = 0.5
    return profile


func _make_fixed_group() -> WaveGroupDefinition:
    var group := WaveGroupDefinition.new()
    group.composition_mode = WaveGroupDefinition.CompositionMode.FIXED
    group.start_condition = WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP
    group.warning_ticks = 2
    group.level_offset = 0
    var entry := WaveCompositionEntry.new()
    entry.enemy_scene = ThrustEnemyScene
    entry.count = 2
    group.entries = [entry]
    return group


func _make_weighted_group() -> WaveGroupDefinition:
    var group := WaveGroupDefinition.new()
    group.composition_mode = WaveGroupDefinition.CompositionMode.WEIGHTED
    group.start_condition = WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP
    group.warning_ticks = 2
    group.level_offset = 0
    group.weighted_total_count = 4
    var entry := WaveCompositionEntry.new()
    entry.enemy_scene = ThrustEnemyScene
    entry.weight = 1.0
    group.entries = [entry]
    return group


func _make_wave() -> WaveDefinition:
    var wave := WaveDefinition.new()
    wave.population_cap = 3
    wave.groups = [_make_fixed_group()]
    return wave


func _make_catalog() -> WaveCatalog:
    var catalog := WaveCatalog.new()
    var demo_waves: Array[WaveDefinition] = []
    for i in WaveCatalog.DEMO_WAVE_COUNT:
        demo_waves.append(_make_wave())
    catalog.demo_waves = demo_waves
    catalog.endless_template = _make_wave()
    catalog.progression_profile = _make_profile()
    return catalog
