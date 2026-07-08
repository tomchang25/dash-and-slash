# wave_reward_choice_generator.gd
# Pure reward-choice generator that builds point-balanced artifact combinations.
class_name WaveRewardChoiceGenerator
extends RefCounted

enum Profile {
    CONSERVATIVE,
    BALANCED,
    AGGRESSIVE,
}

const MAX_ROLL_ATTEMPTS := 80

## Exclusivity-group id shared by every mobility-slot payload replacement (Smash today, the future
## Chain Dash), since only one can be active at a time.
const SMASH_EXCLUSIVITY_GROUP := &"mobility_slot_replacement"

var _rng: RandomNumberGenerator
var _artifacts: Array[Artifact] = []

# == Lifecycle ==


func _init(rng: RandomNumberGenerator = null) -> void:
    _rng = rng if rng != null else RandomNumberGenerator.new()
    _rng.randomize()
    _artifacts = _make_default_artifacts()

# == Common API ==


func roll_choices(wave_number: int, target_points: float, context: WaveRewardContext) -> Array[WaveRewardChoice]:
    return [
        _roll_choice(Profile.CONSERVATIVE, wave_number, target_points, context),
        _roll_choice(Profile.BALANCED, wave_number, target_points, context),
        _roll_choice(Profile.AGGRESSIVE, wave_number, target_points, context),
    ]

# == Rolling ==


func _roll_choice(
        profile: int,
        wave_number: int,
        target_points: float,
        context: WaveRewardContext,
) -> WaveRewardChoice:
    var available := _available_artifacts(profile, wave_number, context)
    for attempt in MAX_ROLL_ATTEMPTS:
        var effects := _roll_effects_for_profile(profile, available)
        if _is_valid_choice(profile, effects, target_points):
            return WaveRewardChoice.new(profile, target_points, effects)

    return _fallback_choice(profile, target_points, available)


func _roll_effects_for_profile(
        profile: int,
        available: Array[Artifact],
) -> Array[WaveRewardEffect]:
    var effects: Array[WaveRewardEffect] = []
    var picked_ids: Array[StringName] = []
    var desired_count := _random_effect_count(profile)
    var candidates := available.duplicate()
    candidates.shuffle()

    while effects.size() < desired_count and not candidates.is_empty():
        var artifact: Artifact = candidates.pop_back()
        if artifact.id in picked_ids:
            continue
        picked_ids.append(artifact.id)
        var stacks := _rng.randi_range(1, _max_stacks_for_profile(profile, artifact))
        effects.append(artifact.create_effect(stacks))

    return effects


func _is_valid_choice(
        profile: int,
        effects: Array[WaveRewardEffect],
        target_points: float,
) -> bool:
    if effects.is_empty() or not is_equal_approx(_total_points(effects), target_points):
        return false
    match profile:
        Profile.CONSERVATIVE:
            return effects.size() <= 2 and _total_upside(effects) <= 1.0 and _total_downside(effects) <= target_points + 2.0
        Profile.BALANCED:
            return effects.size() >= 2 and effects.size() <= 3 and _total_upside(effects) >= 1.0 and _total_downside(effects) >= 1.0
        Profile.AGGRESSIVE:
            return effects.size() >= 3 and effects.size() <= 4 and _total_upside(effects) >= 3.0 and _total_downside(effects) >= 3.0
        _:
            ToastManager.show_dev_error("Unknown reward profile: %s" % profile)
            return false


## TODO, need cleanup this mess logic
func _fallback_choice(
        profile: int,
        target_points: float,
        available: Array[Artifact],
) -> WaveRewardChoice:
    var best_effects: Array[WaveRewardEffect] = []
    var best_distance := INF
    var options := _expanded_single_effect_options(available, profile)
    var max_count := _max_effect_count(profile)

    for a in options.size():
        var effects := [options[a]]
        best_distance = _capture_best_effects(effects, target_points, best_effects, best_distance)
        for b in range(a + 1, options.size()):
            if _shares_artifact_id(options[b], effects):
                continue
            effects = [options[a], options[b]]
            best_distance = _capture_best_effects(effects, target_points, best_effects, best_distance)
            if max_count < 3:
                continue
            for c in range(b + 1, options.size()):
                if _shares_artifact_id(options[c], effects):
                    continue
                effects = [options[a], options[b], options[c]]
                best_distance = _capture_best_effects(effects, target_points, best_effects, best_distance)
                if max_count < 4:
                    continue
                for d in range(c + 1, options.size()):
                    if _shares_artifact_id(options[d], effects):
                        continue
                    effects = [options[a], options[b], options[c], options[d]]
                    best_distance = _capture_best_effects(effects, target_points, best_effects, best_distance)

    return WaveRewardChoice.new(profile, target_points, best_effects)


func _shares_artifact_id(candidate: WaveRewardEffect, chosen: Array) -> bool:
    for effect: WaveRewardEffect in chosen:
        if effect.artifact.id == candidate.artifact.id:
            return true
    return false


func _capture_best_effects(
        effects: Array,
        target_points: float,
        best_effects: Array[WaveRewardEffect],
        best_distance: float,
) -> float:
    var typed_effects: Array[WaveRewardEffect] = []
    for effect: WaveRewardEffect in effects:
        typed_effects.append(effect)
    var distance := absf(_total_points(typed_effects) - target_points)
    if distance < best_distance:
        best_effects.assign(typed_effects)
        return distance
    return best_distance

# == Artifact Pool ==


func _make_default_artifacts() -> Array[Artifact]:
    return [
        Artifact.new(
            &"future_enemy",
            "Raise Pressure",
            "+%d future enemy",
            Artifact.Rarity.COMMON,
            4,
            &"",
            false,
            1,
            1,
            1.0,
            [Profile.CONSERVATIVE, Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_FUTURE_ENEMY_COUNT, 1.0)],
        ),
        Artifact.new(
            &"attack_up",
            "Sharpened Edge",
            "+%d normal attack damage",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            -1,
            10.0,
            [Profile.CONSERVATIVE, Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_NORMAL_ATTACK_DAMAGE, 10.0)],
        ),
        Artifact.new(
            &"speed_up",
            "Fleet Step",
            "+%d Speed",
            Artifact.Rarity.COMMON,
            5,
            &"",
            false,
            1,
            -1,
            1.0,
            [Profile.CONSERVATIVE, Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_SPEED, 1.0)],
        ),
        Artifact.new(
            &"dash_attack_up",
            "Impact Dash",
            "+%d dash attack damage",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            -1,
            20.0,
            [Profile.CONSERVATIVE, Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_MOBILITY_ATTACK_DAMAGE, 20.0)],
        ),
        Artifact.new(
            &"mobility_cooldown_down",
            "Light Footwork",
            "-%d mobility cooldown (ticks)",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            -1,
            1.0,
            [Profile.CONSERVATIVE, Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_MOBILITY_COOLDOWN, 1.0)],
        ),
        Artifact.new(
            &"attack_range_up",
            "Longer Reach",
            "+%d%% attack range",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            -1,
            10.0,
            [Profile.CONSERVATIVE, Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_ATTACK_RANGE, 10.0)],
        ),
        Artifact.new(
            &"dash_range_up",
            "Longer Dash",
            "+%d%% dash range",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            -1,
            10.0,
            [Profile.CONSERVATIVE, Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_MOBILITY_RANGE, 10.0)],
        ),
        Artifact.new(
            &"max_health_up",
            "Vital Spark",
            "+%d max health",
            Artifact.Rarity.COMMON,
            2,
            &"",
            false,
            1,
            -1,
            20.0,
            [Profile.CONSERVATIVE, Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_MAX_HEALTH, 20.0)],
        ),
        Artifact.new(
            &"enemy_health_pressure",
            "Enemy Vitality",
            "+%d%% future enemy health",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            2,
            5.0,
            [Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_ENEMY_HEALTH_PRESSURE, 5.0, 0.01)],
        ),
        Artifact.new(
            &"enemy_damage_pressure",
            "Enemy Ferocity",
            "+%d%% future enemy damage",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            2,
            5.0,
            [Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_ENEMY_DAMAGE_PRESSURE, 5.0, 0.01)],
        ),
        Artifact.new(
            &"enemy_defense_pressure",
            "Enemy Armor",
            "+%d future enemy defense",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            2,
            3.0,
            [Profile.BALANCED, Profile.AGGRESSIVE],
            [ChannelArtifactEffect.new(RunBuild.CH_ENEMY_DEFENSE_PRESSURE, 3.0)],
        ),
        Artifact.new(
            &"smash",
            "Smash",
            "Replace Dash with an area leap-and-slam (%d)",
            Artifact.Rarity.LEGENDARY,
            1,
            SMASH_EXCLUSIVITY_GROUP,
            false,
            2,
            -4,
            1.0,
            [Profile.AGGRESSIVE],
            [PayloadArtifactEffect.new(RunBuild.PAYLOAD_SMASH)],
        ),
        Artifact.new(
            &"guard_shredder",
            "Guard Shredder",
            "Back-angle dash hits break guard instantly (%d)",
            Artifact.Rarity.LEGENDARY,
            1,
            &"",
            false,
            2,
            -4,
            1.0,
            [Profile.AGGRESSIVE],
            [TriggerArtifactEffect.new(RunBuild.TRIGGER_GUARD_SHREDDER)],
        ),
        Artifact.new(
            &"execution",
            "Execution",
            "Dash hits on staggered targets kill instantly (%d)",
            Artifact.Rarity.LEGENDARY,
            1,
            &"",
            false,
            2,
            -4,
            1.0,
            [Profile.AGGRESSIVE],
            [TriggerArtifactEffect.new(RunBuild.TRIGGER_EXECUTION)],
        ),
        Artifact.new(
            &"mobility_free_action",
            "Flowing Strike",
            "Kill, guard-break, or back-angle mobility strikes skip world time (%d)",
            Artifact.Rarity.LEGENDARY,
            1,
            &"",
            false,
            2,
            -4,
            1.0,
            [Profile.AGGRESSIVE],
            [TriggerArtifactEffect.new(RunBuild.TRIGGER_MOBILITY_FREE_ACTION)],
        ),
    ]


func _available_artifacts(
        profile: int,
        wave_number: int,
        context: WaveRewardContext,
) -> Array[Artifact]:
    var available: Array[Artifact] = []
    for artifact in _artifacts:
        if wave_number < artifact.min_wave or not artifact.allows_profile(profile):
            continue
        if not artifact.is_eligible(context):
            continue
        available.append(artifact)
    return available

# == Constraints ==


func _random_effect_count(profile: int) -> int:
    match profile:
        Profile.CONSERVATIVE:
            return _rng.randi_range(1, 2)
        Profile.BALANCED:
            return _rng.randi_range(2, 3)
        Profile.AGGRESSIVE:
            return _rng.randi_range(3, 4)
        _:
            ToastManager.show_dev_error("Unknown reward profile: %s" % profile)
            return 1


func _max_effect_count(profile: int) -> int:
    match profile:
        Profile.CONSERVATIVE:
            return 2
        Profile.BALANCED:
            return 3
        Profile.AGGRESSIVE:
            return 4
        _:
            ToastManager.show_dev_error("Unknown reward profile: %s" % profile)
            return 1


func _max_stacks_for_profile(
        profile: int,
        artifact: Artifact,
) -> int:
    match profile:
        Profile.CONSERVATIVE:
            return min(artifact.max_stacks, 2)
        Profile.BALANCED:
            return min(artifact.max_stacks, 2)
        Profile.AGGRESSIVE:
            return artifact.max_stacks
        _:
            ToastManager.show_dev_error("Unknown reward profile: %s" % profile)
            return 1


func _expanded_single_effect_options(
        artifacts: Array[Artifact],
        profile: int,
) -> Array[WaveRewardEffect]:
    var options: Array[WaveRewardEffect] = []
    for artifact in artifacts:
        for stacks in range(1, _max_stacks_for_profile(profile, artifact) + 1):
            options.append(artifact.create_effect(stacks))
    return options


func _total_points(effects: Array[WaveRewardEffect]) -> float:
    var total := 0.0
    for effect in effects:
        total += effect.total_points()
    return total


func _total_upside(effects: Array[WaveRewardEffect]) -> float:
    var total := 0.0
    for effect in effects:
        if effect.total_points() < 0:
            total += absf(effect.total_points())
    return total


func _total_downside(effects: Array[WaveRewardEffect]) -> float:
    var total := 0.0
    for effect in effects:
        if effect.total_points() > 0:
            total += effect.total_points()
    return total
