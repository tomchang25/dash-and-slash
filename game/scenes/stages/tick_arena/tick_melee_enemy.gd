# tick_melee_enemy.gd
# Interim grey-box melee actor carried over from the prototype to keep the tick arena playable
# replaced by the production enemy kinds in rework phase 2.
extends TickEnemy

# -- Constants --

const TELEGRAPH_TICKS := 1
const RECOVERY_TICKS := 1

# == Lifecycle ==


func _init() -> void:
    max_guard = 32
    max_hp = 60.0
    attack_damage = 10.0
    body_color = Color(0.72, 0.74, 0.78)
    # Playtest tuning: 75 = three actions per four world ticks, so flat running leaks pursuit
    # distance and flanking windows open naturally instead of the chase locking on forever.
    speed = 75

# == Overridden custom methods ==


func _think() -> void:
    var player_cell: Vector2i = _engine.player_cell()
    var delta := player_cell - cell
    if absi(delta.x) + absi(delta.y) == 1:
        if facing != delta:
            _turn_step_toward(delta)
            return
        _attack_tiles = [cell + facing]
        _attack_ticks = TELEGRAPH_TICKS
        queue_redraw()
        return
    _step_toward_player()


func _detonate() -> void:
    if _engine.player_cell() in _attack_tiles:
        _engine.damage_player(attack_damage, self)
    _engine.notify_detonation(_attack_tiles)
    _recovery_ticks = RECOVERY_TICKS
