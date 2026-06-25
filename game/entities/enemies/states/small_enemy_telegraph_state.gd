# small_enemy_telegraph_state.gd
# Telegraph state — shows a warning on the tile in front of the enemy for
# TELEGRAPH_DURATION, then transitions to ATTACK.
extends SmallEnemyState

var _timer: Timer


func _init() -> void:
    state_id = SmallEnemyStateId.TELEGRAPH


func _enter() -> void:
    var grid: GridArena = enemy.get_grid()
    var front_tile := enemy.get_grid_pos() + Vector2i(int(enemy.get_facing().x), int(enemy.get_facing().y))

    if not grid.is_in_bounds(front_tile):
        change_state(SmallEnemyStateId.IDLE)
        return

    enemy.start_telegraph([front_tile])

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    add_child(_timer)
    _timer.start(enemy.TELEGRAPH_DURATION)


func _exit() -> void:
    enemy.clear_telegraph()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_timer_timeout() -> void:
    change_state(SmallEnemyStateId.ATTACK)
