# test_artifact_registry.gd
# Tests ArtifactRegistry as the read-only reward-artifact catalog: id lookup, validation of null
# entries, empty/duplicate ids, and invalid Mobility requirements, and that the production default
# registry loads a clean, fully migrated catalog.
extends GutTest

const DEFAULT_REGISTRY_PATH := "res://data/rewards/default_artifact_registry.tres"


func test_get_by_id_returns_matching_artifact() -> void:
    var registry := ArtifactRegistry.new()
    var artifact := _make_artifact(&"speed_up")
    registry.artifacts = [artifact]

    assert_eq(registry.get_by_id(&"speed_up"), artifact)


func test_get_by_id_returns_null_for_unknown_id() -> void:
    var registry := ArtifactRegistry.new()
    registry.artifacts = [_make_artifact(&"speed_up")]

    assert_null(registry.get_by_id(&"unknown_id"))


func test_get_artifacts_returns_every_entry_in_authored_order() -> void:
    var registry := ArtifactRegistry.new()
    var first := _make_artifact(&"first")
    var second := _make_artifact(&"second")
    registry.artifacts = [first, second]

    assert_eq(registry.get_artifacts(), [first, second])


func test_validate_passes_a_clean_registry() -> void:
    var registry := ArtifactRegistry.new()
    registry.artifacts = [_make_artifact(&"first"), _make_artifact(&"second")]

    assert_true(registry.validate())


func test_validate_fails_on_null_entry() -> void:
    var registry := ArtifactRegistry.new()
    registry.artifacts = [_make_artifact(&"first"), null]

    assert_false(registry.validate())
    assert_push_error("artifact at index 1 is null")


func test_validate_fails_on_empty_id() -> void:
    var registry := ArtifactRegistry.new()
    registry.artifacts = [_make_artifact(&"")]

    assert_false(registry.validate())
    assert_push_error("artifact at index 0 has an empty id")


func test_validate_fails_on_duplicate_id() -> void:
    var registry := ArtifactRegistry.new()
    registry.artifacts = [_make_artifact(&"dup"), _make_artifact(&"dup")]

    assert_false(registry.validate())
    assert_push_error("duplicate artifact id 'dup'")


func test_validate_fails_on_unknown_required_mobility() -> void:
    var registry := ArtifactRegistry.new()
    var artifact := _make_artifact(&"invalid_mobility")
    artifact.required_mobility = &"teleport"
    registry.artifacts = [artifact]

    assert_false(registry.validate())
    assert_push_error("requires unknown Mobility 'teleport'")


func test_production_default_registry_is_valid() -> void:
    var registry := _load_default_registry()

    assert_true(registry.validate(), "the production catalog must be free of null/empty/duplicate ids")


func test_production_default_registry_contains_every_migrated_artifact() -> void:
    var registry := _load_default_registry()
    var expected_ids: Array[StringName] = [
        &"future_enemy",
        &"attack_up",
        &"speed_up",
        &"dash_attack_up",
        &"mobility_cooldown_down",
        &"mobility_range_up",
        &"max_health_up",
        &"enemy_health_pressure",
        &"enemy_damage_pressure",
        &"enemy_defense_pressure",
        &"guard_shredder",
        &"execution",
        &"chain_dash",
    ]

    assert_eq(registry.get_artifacts().size(), expected_ids.size(), "the production catalog must carry every migrated artifact and no extras")
    for id in expected_ids:
        assert_not_null(registry.get_by_id(id), "the production catalog must still contain '%s'" % id)


func _make_artifact(id: StringName) -> Artifact:
    var artifact := Artifact.new()
    artifact.id = id
    return artifact


func _load_default_registry() -> ArtifactRegistry:
    return load(DEFAULT_REGISTRY_PATH) as ArtifactRegistry
