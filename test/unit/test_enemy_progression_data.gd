# test_enemy_progression_data.gd
# Focused coverage for the wave/group/composition/curve/profile schema graph, EnemyData's Level 1
# base-stat authority, and GridEnemy's EnemyData-driven component initialization plus the deferred
# legacy wave-scaling bridge. See data_driven_wave_progression_and_enemy_levels_01_progression_data_model.implementation_spec.md.
extends GutTest

const SmallEnemyScene := preload("res://game/entities/enemies/small_enemy.tscn")
const ChargeEnemyScene := preload("res://game/entities/enemies/charge_enemy.tscn")
const ModeEnemyScene := preload("res://game/entities/enemies/mode_enemy.tscn")
const PuffEnemyScene := preload("res://game/entities/enemies/puff_enemy.tscn")

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


func test_enemy_data_validate_rejects_negative_max_guard() -> void:
    var data := _make_enemy_data()
    data.max_guard = -1
    assert_false(data.validate())
    assert_push_error("max_guard must be non-negative")


func test_enemy_data_validate_rejects_negative_defense() -> void:
    var data := _make_enemy_data()
    data.defense = -1.0
    assert_false(data.validate())
    assert_push_error("defense must be non-negative")

# == Production EnemyData: preserved Level 1 bases ==


func test_production_enemy_bases_preserve_current_level_one_stats() -> void:
    var expectations := {
        "res://game/entities/enemies/data/small_enemy_line.tres": [100.0, 16, 0.0],
        "res://game/entities/enemies/data/small_enemy_burst.tres": [100.0, 16, 0.0],
        "res://game/entities/enemies/data/small_enemy_pierce.tres": [100.0, 16, 0.0],
        "res://game/entities/enemies/data/small_enemy_sweep.tres": [100.0, 16, 0.0],
        "res://game/entities/enemies/data/charge_enemy.tres": [150.0, 32, 0.0],
        "res://game/entities/enemies/data/mode_enemy.tres": [180.0, 16, 0.0],
        "res://game/entities/enemies/data/puff_enemy.tres": [30.0, 16, 0.0],
    }
    for path: String in expectations.keys():
        var data := load(path) as EnemyData
        var expected: Array = expectations[path]
        assert_almost_eq(data.max_health, expected[0], 0.001, "%s max_health" % path)
        assert_eq(data.max_guard, expected[1], "%s max_guard" % path)
        assert_almost_eq(data.defense, expected[2], 0.001, "%s defense" % path)
        assert_true(data.validate(), "%s should be valid authored data" % path)

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

# == EnemyLevelProgressionProfile ==


func test_profile_project_level_one_is_identity() -> void:
    var profile := _make_profile()
    var data := _make_enemy_data()
    var projection := profile.project(data, 1)

    assert_almost_eq(projection.max_health, data.max_health, 0.001)
    assert_almost_eq(projection.damage_multiplier, 1.0, 0.001)
    assert_eq(projection.max_guard, data.max_guard)
    assert_almost_eq(projection.defense, data.defense, 0.001)


func test_profile_project_applies_stronger_segment_at_level_ten() -> void:
    var profile := _make_profile()
    var data := _make_enemy_data()
    var projection := profile.project(data, 10)

    assert_almost_eq(projection.max_health, 240.0, 0.001, "100 base * (1 + 1.4) hp multiplier")
    assert_almost_eq(projection.damage_multiplier, 2.4, 0.001)
    assert_eq(projection.max_guard, 24, "10 base * 2.4 guard multiplier, rounded")
    assert_almost_eq(projection.defense, 16.0, 0.001, "5 base defense + 11 defense growth")


func test_profile_project_rounds_guard_once() -> void:
    var profile := _make_profile()
    profile.guard_curve = _make_curve(0.07, 1.0, 0.0, 1.0)
    var data := _make_enemy_data()
    data.max_guard = 10

    var projection := profile.project(data, 5)

    assert_eq(projection.max_guard, 13, "10 base * 1.28 multiplier = 12.8, rounds to 13")


func test_profile_project_normalizes_level_below_one() -> void:
    var profile := _make_profile()
    var data := _make_enemy_data()

    var projection := profile.project(data, 0)

    assert_almost_eq(projection.max_health, data.max_health, 0.001, "level 0 should normalize to level 1 identity")
    assert_push_error("is below 1")


func test_profile_project_missing_enemy_data_reports_error_and_returns_default_projection() -> void:
    var profile := _make_profile()

    var projection := profile.project(null, 5)

    assert_almost_eq(projection.max_health, 0.0, 0.001)
    assert_eq(projection.max_guard, 0)
    assert_push_error("requires non-null EnemyData")


func test_profile_project_high_level_is_finite_and_uncapped() -> void:
    var profile := _make_profile()
    var data := _make_enemy_data()

    var projection := profile.project(data, 1000)

    assert_true(is_finite(projection.max_health))
    assert_true(is_finite(projection.damage_multiplier))
    assert_true(is_finite(projection.defense))
    assert_true(projection.max_health > data.max_health * 100.0, "growth should stay uncapped at very high levels")


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


func test_small_enemy_scene_initializes_health_and_guard_from_enemy_data() -> void:
    var enemy := add_child_autofree(SmallEnemyScene.instantiate()) as GridEnemy
    assert_almost_eq(enemy.health.max_health, 100.0, 0.001)
    assert_almost_eq(enemy.health.current(), 100.0, 0.001)
    assert_eq(enemy.get_guard().max_guard, 16)
    assert_eq(enemy.get_guard().current(), 16)


func test_charge_enemy_scene_initializes_health_and_guard_from_enemy_data() -> void:
    var enemy := add_child_autofree(ChargeEnemyScene.instantiate()) as GridEnemy
    assert_almost_eq(enemy.health.max_health, 150.0, 0.001)
    assert_eq(enemy.get_guard().max_guard, 32)


func test_mode_enemy_scene_initializes_health_and_guard_from_enemy_data() -> void:
    var enemy := add_child_autofree(ModeEnemyScene.instantiate()) as GridEnemy
    assert_almost_eq(enemy.health.max_health, 180.0, 0.001)
    assert_eq(enemy.get_guard().max_guard, 16)


func test_puff_enemy_scene_initializes_health_and_guard_from_enemy_data() -> void:
    var enemy := add_child_autofree(PuffEnemyScene.instantiate()) as GridEnemy
    assert_almost_eq(enemy.health.max_health, 30.0, 0.001)
    assert_eq(enemy.get_guard().max_guard, 16)


func test_missing_enemy_data_falls_back_to_component_defaults_and_reports_error() -> void:
    var enemy := SmallEnemyScene.instantiate() as GridEnemy
    enemy.enemy_data = null
    add_child_autofree(enemy)

    assert_eq(enemy.get_guard().max_guard, 4, "Guard's own script default should remain, not Small's authored 16")
    assert_push_error("missing enemy_data")

# == GridEnemy: deferred legacy wave scaling ==


func test_apply_wave_scaling_called_pre_ready_applies_after_enemy_data_initializes() -> void:
    var enemy := SmallEnemyScene.instantiate() as GridEnemy
    enemy.apply_wave_scaling(1.5, 1.2, 3.0)
    add_child_autofree(enemy)

    assert_almost_eq(enemy.health.max_health, 150.0, 0.001, "legacy hp multiplier applies on top of the authored base of 100")
    assert_almost_eq(enemy.get_damage_multiplier(), 1.2, 0.001)
    assert_almost_eq(enemy.get_defense(), 3.0, 0.001, "authored base defense of 0 plus the legacy addition")
    assert_eq(enemy.get_guard().max_guard, 16, "legacy scaling never touches Guard")


func test_apply_wave_scaling_never_called_leaves_identity_scaling() -> void:
    var enemy := add_child_autofree(SmallEnemyScene.instantiate()) as GridEnemy

    assert_almost_eq(enemy.get_damage_multiplier(), 1.0, 0.001)
    assert_almost_eq(enemy.get_defense(), 0.0, 0.001)
    assert_almost_eq(enemy.health.max_health, 100.0, 0.001, "no legacy hp multiplier means the authored base is untouched")


func test_apply_wave_scaling_negative_inputs_are_clamped() -> void:
    var enemy := SmallEnemyScene.instantiate() as GridEnemy
    enemy.apply_wave_scaling(-1.0, -1.0, -5.0)
    add_child_autofree(enemy)

    assert_almost_eq(enemy.get_damage_multiplier(), 0.0, 0.001)
    assert_almost_eq(enemy.get_defense(), 0.0, 0.001)
    assert_almost_eq(enemy.health.max_health, 100.0, 0.001, "a clamped-to-zero hp multiplier must not shrink max health")

# == Test helpers ==


func _make_enemy_data() -> EnemyData:
    var data := EnemyData.new()
    data.enemy_id = "test_enemy"
    data.display_name = "Test Enemy"
    data.max_health = 100.0
    data.max_guard = 10
    data.defense = 5.0
    return data


func _make_curve(standard_coefficient: float, standard_exponent: float, lethal_coefficient: float, lethal_exponent: float) -> EnemyStatGrowthCurve:
    var curve := EnemyStatGrowthCurve.new()
    curve.standard_coefficient = standard_coefficient
    curve.standard_exponent = standard_exponent
    curve.lethal_coefficient = lethal_coefficient
    curve.lethal_exponent = lethal_exponent
    return curve


## hp/damage/guard share one curve (0 at level 1, 1.4 growth by level 10); defense uses a distinct
## curve (0 at level 1, 11.0 growth by level 10) so additive vs multiplicative behavior stays
## distinguishable in assertions.
func _make_profile() -> EnemyLevelProgressionProfile:
    var profile := EnemyLevelProgressionProfile.new()
    var shared_curve := _make_curve(0.1, 1.0, 0.5, 1.0)
    profile.hp_curve = shared_curve
    profile.damage_curve = shared_curve
    profile.guard_curve = shared_curve
    profile.defense_curve = _make_curve(1.0, 1.0, 2.0, 1.0)
    return profile


func _make_fixed_group() -> WaveGroupDefinition:
    var group := WaveGroupDefinition.new()
    group.composition_mode = WaveGroupDefinition.CompositionMode.FIXED
    group.start_condition = WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP
    group.warning_ticks = 2
    group.level_offset = 0
    var entry := WaveCompositionEntry.new()
    entry.enemy_scene = SmallEnemyScene
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
    entry.enemy_scene = SmallEnemyScene
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
