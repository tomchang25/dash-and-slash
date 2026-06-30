# wave_controller.gd
# Scene-local RefCounted that owns wave progression, enemy counts, and future pressure modifier.
class_name WaveController
extends RefCounted

const WAVE_DEFINITIONS := [
    { "index": 1, "kind": "normal", "base_count": 5 },
    { "index": 2, "kind": "normal", "base_count": 6 },
    { "index": 3, "kind": "normal", "base_count": 7 },
    { "index": 4, "kind": "normal", "base_count": 8 },
    { "index": 5, "kind": "boss", "boss_id": "first_boss", "support_base_count": 8 },
]

var _current_wave_index := -1
var _future_enemy_count_modifier := 0


## Returns the current wave definition, or an empty Dictionary before the first wave.
func get_current_wave() -> Dictionary:
    if _current_wave_index < 0 or _current_wave_index >= WAVE_DEFINITIONS.size():
        return { }
    return WAVE_DEFINITIONS[_current_wave_index]


## Advances to the next wave. Returns false if there are no more waves.
func advance_wave() -> bool:
    _current_wave_index += 1
    return _current_wave_index < WAVE_DEFINITIONS.size()


## Returns true when the current wave is a boss wave.
func is_boss_wave() -> bool:
    return get_current_wave().get("kind", "") == "boss"


## Returns the number of support enemies to spawn for the current wave,
## including any future enemy count modifier.
func get_support_spawn_count() -> int:
    var wave := get_current_wave()
    if wave.is_empty():
        return 0
    var base := 0
    if wave["kind"] == "boss":
        base = int(wave.get("support_base_count", 0))
    else:
        base = int(wave.get("base_count", 0))
    return base + _future_enemy_count_modifier


## Returns 1 for boss waves, 0 otherwise.
func get_boss_spawn_count() -> int:
    return 1 if is_boss_wave() else 0


## Adds non-negative future enemy count pressure to subsequent waves.
func add_future_enemy_count(amount: int) -> void:
    _future_enemy_count_modifier += max(amount, 0)


## Returns the 1-based wave number for display (1-5).
func get_wave_number() -> int:
    return _current_wave_index + 1


## Resets all state for a fresh run.
func reset() -> void:
    _current_wave_index = -1
    _future_enemy_count_modifier = 0
