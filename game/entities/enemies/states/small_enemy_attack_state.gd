# small_enemy_attack_state.gd
# Attack state — positions the hitbox in front of the enemy, enables it for
# ATTACK_DURATION, then transitions to RECOVERY.
extends SmallEnemyState

var _timer: Timer


func _init() -> void:
    state_id = SmallEnemyStateId.ATTACK


func _enter() -> void:
    var grid: GridArena = enemy.get_grid()
    var front_tile := enemy.get_grid_pos() + Vector2i(int(enemy.get_facing().x), int(enemy.get_facing().y))
    var hit_pos := grid.cell_center(front_tile)

    if enemy.global_position.distance_squared_to(hit_pos) > enemy.tile_size() * 2.0:
        enemy.global_position = hit_pos

    enemy.set_attack_hitbox_position(hit_pos)
    enemy.enable_attack_hitbox()

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    add_child(_timer)
    _timer.start(enemy.ATTACK_DURATION)


func _exit() -> void:
    enemy.disable_attack_hitbox()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_timer_timeout() -> void:
    change_state(SmallEnemyStateId.RECOVERY)
