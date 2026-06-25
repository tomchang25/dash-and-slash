# small_enemy_face_target_state.gd
# Face once state — applies committed cardinal facing, then returns to idle.
extends SmallEnemyState

const IDLE_RETURN_DELAY := 3.0

var _timer: Timer


func _init() -> void:
    state_id = SmallEnemyStateId.FACE_ONCE


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    enemy.face_target_position()

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_timer_timeout)
    add_child(_timer) # node-src: timer

    _timer.start(IDLE_RETURN_DELAY)


func _exit() -> void:
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _on_timer_timeout() -> void:
    change_state(SmallEnemyStateId.IDLE)
