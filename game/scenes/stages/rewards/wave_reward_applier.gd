# wave_reward_applier.gd
# Applies selected wave reward effects to their owning gameplay systems.
class_name WaveRewardApplier
extends RefCounted

var _grid: GridArena
var _player: Player
var _add_future_enemy_callback: Callable
var _rng: RandomNumberGenerator

# == Lifecycle ==


func _init(
        grid: GridArena,
        player: Player,
        add_future_enemy_callback: Callable,
        rng: RandomNumberGenerator = null,
) -> void:
    _grid = grid
    _player = player
    _add_future_enemy_callback = add_future_enemy_callback
    _rng = rng if rng != null else RandomNumberGenerator.new()
    _rng.randomize()

# == Common API ==


func apply(choice: WaveRewardChoice) -> void:
    for effect in choice.effects:
        _apply_effect(effect)

# == Effects ==


func _apply_effect(effect: WaveRewardEffect) -> void:
    match effect.definition.kind:
        WaveRewardEffectDefinition.Kind.MOVE_RANDOM_SAFE_LAND:
            _apply_move_land(effect)
        WaveRewardEffectDefinition.Kind.REMOVE_RANDOM_SAFE_LAND:
            _apply_remove_land(effect)
        WaveRewardEffectDefinition.Kind.ADD_FUTURE_ENEMY:
            _add_future_enemy_callback.call(int(effect.total_magnitude()))
        WaveRewardEffectDefinition.Kind.ADD_PLAYER_ATTACK_DAMAGE:
            if _player != null:
                _player.add_normal_attack_damage(effect.total_magnitude())
        WaveRewardEffectDefinition.Kind.ADD_PLAYER_MAX_HEALTH:
            if _player != null:
                _player.add_max_health(effect.total_magnitude())
        WaveRewardEffectDefinition.Kind.MAJOR_PLACEHOLDER:
            pass


func _apply_move_land(effect: WaveRewardEffect) -> void:
    if _grid == null:
        return
    for i in int(effect.total_magnitude()):
        _grid.move_random_safe_land(_rng)


func _apply_remove_land(effect: WaveRewardEffect) -> void:
    if _grid == null:
        return
    for i in int(effect.total_magnitude()):
        _grid.remove_random_safe_connected_land(_rng)
