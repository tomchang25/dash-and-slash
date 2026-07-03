# wave_reward_choice_generator.gd
# Pure reward-choice generator that builds point-balanced effect combinations.
class_name WaveRewardChoiceGenerator
extends RefCounted

const MAX_ROLL_ATTEMPTS := 80

var _rng: RandomNumberGenerator
var _effect_definitions: Array[WaveRewardEffectDefinition] = []

# == Lifecycle ==


func _init(rng: RandomNumberGenerator = null) -> void:
    _rng = rng if rng != null else RandomNumberGenerator.new()
    _rng.randomize()
    _effect_definitions = _make_default_effect_definitions()

# == Common API ==


func roll_choices(wave_number: int, target_points: float, context: Dictionary) -> Array[WaveRewardChoice]:
    return [
        _roll_choice(WaveRewardEffectDefinition.Profile.CONSERVATIVE, wave_number, target_points, context),
        _roll_choice(WaveRewardEffectDefinition.Profile.BALANCED, wave_number, target_points, context),
        _roll_choice(WaveRewardEffectDefinition.Profile.AGGRESSIVE, wave_number, target_points, context),
    ]

# == Rolling ==


func _roll_choice(
        profile: int,
        wave_number: int,
        target_points: float,
        context: Dictionary,
) -> WaveRewardChoice:
    var available := _available_definitions(profile, wave_number, context)
    for attempt in MAX_ROLL_ATTEMPTS:
        var effects := _roll_effects_for_profile(profile, available)
        if _is_valid_choice(profile, effects, target_points):
            return WaveRewardChoice.new(profile, target_points, effects)

    return _fallback_choice(profile, target_points, available)


func _roll_effects_for_profile(
        profile: int,
        available: Array[WaveRewardEffectDefinition],
) -> Array[WaveRewardEffect]:
    var effects: Array[WaveRewardEffect] = []
    var picked_ids: Array[String] = []
    var desired_count := _random_effect_count(profile)
    var candidates := available.duplicate()
    candidates.shuffle()

    while effects.size() < desired_count and not candidates.is_empty():
        var definition: WaveRewardEffectDefinition = candidates.pop_back()
        if definition.effect_id in picked_ids:
            continue
        picked_ids.append(definition.effect_id)
        var stacks := _rng.randi_range(1, _max_stacks_for_profile(profile, definition))
        effects.append(definition.create_effect(stacks))

    return effects


func _is_valid_choice(
        profile: int,
        effects: Array[WaveRewardEffect],
        target_points: float,
) -> bool:
    if effects.is_empty() or not is_equal_approx(_total_points(effects), target_points):
        return false
    match profile:
        WaveRewardEffectDefinition.Profile.CONSERVATIVE:
            return effects.size() <= 2 and _total_upside(effects) <= 1.0 and _total_downside(effects) <= target_points + 2.0
        WaveRewardEffectDefinition.Profile.BALANCED:
            return effects.size() >= 2 and effects.size() <= 3 and _total_upside(effects) >= 1.0 and _total_downside(effects) >= 1.0
        WaveRewardEffectDefinition.Profile.AGGRESSIVE:
            return effects.size() >= 3 and effects.size() <= 4 and _total_upside(effects) >= 3.0 and _total_downside(effects) >= 3.0
        _:
            ToastManager.show_dev_error("Unknown reward profile: %s" % profile)
            return false


func _fallback_choice(
        profile: int,
        target_points: float,
        available: Array[WaveRewardEffectDefinition],
) -> WaveRewardChoice:
    var best_effects: Array[WaveRewardEffect] = []
    var best_distance := INF
    var options := _expanded_single_effect_options(available, profile)
    var max_count := _max_effect_count(profile)

    for a in options.size():
        var effects := [options[a]]
        best_distance = _capture_best_effects(effects, target_points, best_effects, best_distance)
        for b in range(a + 1, options.size()):
            effects = [options[a], options[b]]
            best_distance = _capture_best_effects(effects, target_points, best_effects, best_distance)
            if max_count < 3:
                continue
            for c in range(b + 1, options.size()):
                effects = [options[a], options[b], options[c]]
                best_distance = _capture_best_effects(effects, target_points, best_effects, best_distance)
                if max_count < 4:
                    continue
                for d in range(c + 1, options.size()):
                    effects = [options[a], options[b], options[c], options[d]]
                    best_distance = _capture_best_effects(effects, target_points, best_effects, best_distance)

    return WaveRewardChoice.new(profile, target_points, best_effects)


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

# == Effect Pool ==


func _make_default_effect_definitions() -> Array[WaveRewardEffectDefinition]:
    return [
        WaveRewardEffectDefinition.new(
            "move_land",
            WaveRewardEffectDefinition.Kind.MOVE_RANDOM_SAFE_LAND,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Move Land",
            "Move %d land tile",
            0.5,
            1.0,
            2,
            1,
            [
                WaveRewardEffectDefinition.Profile.CONSERVATIVE,
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "remove_land",
            WaveRewardEffectDefinition.Kind.REMOVE_RANDOM_SAFE_LAND,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Break Land",
            "-%d safe land",
            1,
            1.0,
            2,
            1,
            [
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "future_enemy",
            WaveRewardEffectDefinition.Kind.ADD_FUTURE_ENEMY,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Raise Pressure",
            "+%d future enemy",
            1,
            1.0,
            4,
            1,
            [
                WaveRewardEffectDefinition.Profile.CONSERVATIVE,
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "attack_up",
            WaveRewardEffectDefinition.Kind.ADD_PLAYER_NORMAL_ATTACK_DAMAGE,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Sharpened Edge",
            "+%d normal attack damage",
            -1,
            10.0,
            3,
            1,
            [
                WaveRewardEffectDefinition.Profile.CONSERVATIVE,
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "normal_attack_cooldown_down",
            WaveRewardEffectDefinition.Kind.REDUCE_PLAYER_NORMAL_ATTACK_COOLDOWN,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Quick Hands",
            "-%.2fs normal attack cooldown",
            -1,
            0.04,
            3,
            1,
            [
                WaveRewardEffectDefinition.Profile.CONSERVATIVE,
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "dash_attack_up",
            WaveRewardEffectDefinition.Kind.ADD_PLAYER_DASH_ATTACK_DAMAGE,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Impact Dash",
            "+%d dash attack damage",
            -1,
            20.0,
            3,
            1,
            [
                WaveRewardEffectDefinition.Profile.CONSERVATIVE,
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "dash_cooldown_down",
            WaveRewardEffectDefinition.Kind.REDUCE_PLAYER_DASH_COOLDOWN,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Light Footwork",
            "-%.2fs dash cooldown",
            -1,
            0.15,
            3,
            1,
            [
                WaveRewardEffectDefinition.Profile.CONSERVATIVE,
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "attack_range_up",
            WaveRewardEffectDefinition.Kind.ADD_PLAYER_ATTACK_RANGE,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Longer Reach",
            "+%d%% attack range",
            -1,
            10.0,
            3,
            1,
            [
                WaveRewardEffectDefinition.Profile.CONSERVATIVE,
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "dash_range_up",
            WaveRewardEffectDefinition.Kind.ADD_PLAYER_DASH_RANGE,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Longer Dash",
            "+%d%% dash range",
            -1,
            10.0,
            3,
            1,
            [
                WaveRewardEffectDefinition.Profile.CONSERVATIVE,
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "max_health_up",
            WaveRewardEffectDefinition.Kind.ADD_PLAYER_MAX_HEALTH,
            WaveRewardEffectDefinition.Tier.MINOR,
            "Vital Spark",
            "+%d max health",
            -1,
            20.0,
            2,
            1,
            [
                WaveRewardEffectDefinition.Profile.CONSERVATIVE,
                WaveRewardEffectDefinition.Profile.BALANCED,
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
        WaveRewardEffectDefinition.new(
            "major_placeholder",
            WaveRewardEffectDefinition.Kind.MAJOR_PLACEHOLDER,
            WaveRewardEffectDefinition.Tier.MAJOR,
            "Major Placeholder",
            "Major placeholder (%d)",
            -4,
            1.0,
            1,
            2,
            [
                WaveRewardEffectDefinition.Profile.AGGRESSIVE,
            ],
        ),
    ]


func _available_definitions(
        profile: int,
        wave_number: int,
        context: Dictionary,
) -> Array[WaveRewardEffectDefinition]:
    var available: Array[WaveRewardEffectDefinition] = []
    for definition in _effect_definitions:
        if wave_number < definition.min_wave or not definition.allows_profile(profile):
            continue
        if not _is_definition_applicable(definition, context):
            continue
        available.append(definition)
    return available


func _is_definition_applicable(definition: WaveRewardEffectDefinition, context: Dictionary) -> bool:
    var grid := context.get("grid") as GridArena
    match definition.kind:
        WaveRewardEffectDefinition.Kind.MOVE_RANDOM_SAFE_LAND:
            return grid != null and not grid.get_add_connected_land_candidates().is_empty() and not grid.get_remove_safe_connected_land_candidates().is_empty()
        WaveRewardEffectDefinition.Kind.REMOVE_RANDOM_SAFE_LAND:
            return grid != null and not grid.get_remove_safe_connected_land_candidates().is_empty()
        WaveRewardEffectDefinition.Kind.ADD_FUTURE_ENEMY:
            return true
        WaveRewardEffectDefinition.Kind.ADD_PLAYER_NORMAL_ATTACK_DAMAGE:
            return context.get("player") is Player
        WaveRewardEffectDefinition.Kind.REDUCE_PLAYER_NORMAL_ATTACK_COOLDOWN:
            return context.get("player") is Player
        WaveRewardEffectDefinition.Kind.ADD_PLAYER_DASH_ATTACK_DAMAGE:
            return context.get("player") is Player
        WaveRewardEffectDefinition.Kind.REDUCE_PLAYER_DASH_COOLDOWN:
            return context.get("player") is Player
        WaveRewardEffectDefinition.Kind.ADD_PLAYER_MAX_HEALTH:
            return context.get("player") is Player
        WaveRewardEffectDefinition.Kind.ADD_PLAYER_ATTACK_RANGE:
            return context.get("player") is Player
        WaveRewardEffectDefinition.Kind.ADD_PLAYER_DASH_RANGE:
            return context.get("player") is Player
        WaveRewardEffectDefinition.Kind.MAJOR_PLACEHOLDER:
            return true
        _:
            ToastManager.show_dev_error("Unknown reward effect kind: %s" % definition.kind)
            return false

# == Constraints ==


func _random_effect_count(profile: int) -> int:
    match profile:
        WaveRewardEffectDefinition.Profile.CONSERVATIVE:
            return _rng.randi_range(1, 2)
        WaveRewardEffectDefinition.Profile.BALANCED:
            return _rng.randi_range(2, 3)
        WaveRewardEffectDefinition.Profile.AGGRESSIVE:
            return _rng.randi_range(3, 4)
        _:
            ToastManager.show_dev_error("Unknown reward profile: %s" % profile)
            return 1


func _max_effect_count(profile: int) -> int:
    match profile:
        WaveRewardEffectDefinition.Profile.CONSERVATIVE:
            return 2
        WaveRewardEffectDefinition.Profile.BALANCED:
            return 3
        WaveRewardEffectDefinition.Profile.AGGRESSIVE:
            return 4
        _:
            ToastManager.show_dev_error("Unknown reward profile: %s" % profile)
            return 1


func _max_stacks_for_profile(
        profile: int,
        definition: WaveRewardEffectDefinition,
) -> int:
    match profile:
        WaveRewardEffectDefinition.Profile.CONSERVATIVE:
            return min(definition.max_stacks, 2)
        WaveRewardEffectDefinition.Profile.BALANCED:
            return min(definition.max_stacks, 2)
        WaveRewardEffectDefinition.Profile.AGGRESSIVE:
            return definition.max_stacks
        _:
            ToastManager.show_dev_error("Unknown reward profile: %s" % profile)
            return 1


func _expanded_single_effect_options(
        definitions: Array[WaveRewardEffectDefinition],
        profile: int,
) -> Array[WaveRewardEffect]:
    var options: Array[WaveRewardEffect] = []
    for definition in definitions:
        for stacks in range(1, _max_stacks_for_profile(profile, definition) + 1):
            options.append(definition.create_effect(stacks))
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
